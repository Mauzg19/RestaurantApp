import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/app_notification.dart';
import '../repositories/spring_boot_notification_repository.dart';

class NotificationCenterService extends ChangeNotifier {
  NotificationCenterService({required this.repository});

  static const _channelId = 'restaurant_order_updates';
  static const _channelName = 'Pedidos y actividad';

  final SpringBootNotificationRepository repository;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Set<String> _pushNotificationIds = {};
  final List<AppNotification> _notifications = [];

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  Timer? _refreshTimer;
  bool _pushEnabled = false;
  bool _localNotificationsAvailable = false;
  bool _authenticated = false;
  bool _hasLoaded = false;
  bool _pendingOpenInbox = false;
  String? _registeredToken;
  Completer<void>? _pendingTokenRegistration;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  bool consumeOpenInboxRequest() {
    final shouldOpen = _pendingOpenInbox;
    _pendingOpenInbox = false;
    return shouldOpen;
  }

  Future<void> initialize() async {
    _localNotificationsAvailable =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (_localNotificationsAvailable) {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) {
          _pendingOpenInbox = true;
          if (_authenticated) unawaited(refresh());
          notifyListeners();
        },
      );
      await _createNotificationChannel();
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      _pendingOpenInbox = launchDetails?.didNotificationLaunchApp ?? false;
    }
    _pushEnabled = await _initializeFirebase();
    if (_pushEnabled) {
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_handleForegroundMessage(message)),
        onError: (Object error) =>
            debugPrint('Error recibiendo un push en primer plano: $error'),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_handleOpenedMessage(message)),
        onError: (Object error) =>
            debugPrint('Error abriendo un push recibido: $error'),
      );
    }
  }

  Future<void> startForAuthenticatedUser() async {
    _authenticated = true;
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_refreshFromTimer()),
    );
    Object? pushSetupError;
    NotificationSettings? permissionSettings;
    try {
      permissionSettings = await _requestNotificationPermissions();
    } catch (error, stackTrace) {
      pushSetupError = error;
      debugPrint(
        'No se pudieron solicitar permisos de notificación: $error\n$stackTrace',
      );
    }

    final pushPermissionDenied =
        permissionSettings?.authorizationStatus == AuthorizationStatus.denied;
    if (_pushEnabled && !pushPermissionDenied && pushSetupError == null) {
      final registered = Completer<void>();
      _pendingTokenRegistration = registered;
      _tokenSubscription ??= FirebaseMessaging.instance.onRegistered.listen(
        (token) => unawaited(_registerTokenFromStream(token)),
        onError: (Object error, StackTrace stackTrace) {
          final pending = _pendingTokenRegistration;
          if (pending != null && !pending.isCompleted) {
            pending.completeError(error, stackTrace);
          }
        },
      );
      try {
        await FirebaseMessaging.instance.register();
        await registered.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Firebase no devolvió el token del dispositivo a tiempo.',
          ),
        );
      } catch (error, stackTrace) {
        pushSetupError = error;
        debugPrint(
          'No se pudo registrar el dispositivo para push: $error\n$stackTrace',
        );
      } finally {
        _pendingTokenRegistration = null;
      }
    } else if (pushPermissionDenied) {
      debugPrint('Permiso push denegado; la bandeja seguirá sincronizándose.');
    }

    if (_pushEnabled && pushPermissionDenied) {
      pushSetupError = StateError(
        'El permiso de notificaciones fue denegado; la bandeja seguirá disponible.',
      );
    }

    await refresh();
    if (_pushEnabled) {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        await _handleOpenedMessage(initialMessage);
      }
    }
    if (pushSetupError != null) {
      throw StateError(
        'No se pudo habilitar push; la bandeja permanece disponible: $pushSetupError',
      );
    }
  }

  Future<void> endAuthenticatedSession() async {
    final shouldUnregister = _pushEnabled && _authenticated;
    final token = _registeredToken;
    _authenticated = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _notifications.clear();
    _hasLoaded = false;
    notifyListeners();

    if (shouldUnregister) {
      try {
        if (token != null) {
          await repository.unregisterDeviceToken(token);
        }
      } finally {
        await FirebaseMessaging.instance.unregister();
        _registeredToken = null;
      }
    }
  }

  Future<void> refresh() async {
    if (!_authenticated) return;
    final updated = await repository.load();
    final previousIds = _notifications.map((item) => item.id).toSet();
    _notifications
      ..clear()
      ..addAll(updated);

    if (_hasLoaded) {
      for (final notification in updated) {
        if (previousIds.contains(notification.id)) continue;
        if (_pushNotificationIds.remove(notification.id.toString())) continue;
        await _showLocalNotification(notification);
      }
    }
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> markAsRead(int notificationId) async {
    await repository.markAsRead(notificationId);
    final index = _notifications.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index == -1) return;
    final notification = _notifications[index];
    _notifications[index] = AppNotification(
      id: notification.id,
      title: notification.title,
      message: notification.message,
      type: notification.type,
      sentAt: notification.sentAt,
      isRead: true,
      orderId: notification.orderId,
      restaurantId: notification.restaurantId,
    );
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await repository.markAllAsRead();
    for (var index = 0; index < _notifications.length; index++) {
      final notification = _notifications[index];
      _notifications[index] = AppNotification(
        id: notification.id,
        title: notification.title,
        message: notification.message,
        type: notification.type,
        sentAt: notification.sentAt,
        isRead: true,
        orderId: notification.orderId,
        restaurantId: notification.restaurantId,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    super.dispose();
  }

  Future<bool> _initializeFirebase() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
    const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    final appId = defaultTargetPlatform == TargetPlatform.android
        ? androidAppId
        : iosAppId;

    if (apiKey.isEmpty ||
        projectId.isEmpty ||
        senderId.isEmpty ||
        appId.isEmpty) {
      debugPrint(
        'Firebase push no configurado. Defina las opciones Firebase de la plataforma para habilitar push.',
      );
      return false;
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
          iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
              ? const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID')
              : null,
        ),
      );
    }
    return true;
  }

  Future<void> _createNotificationChannel() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Cambios de estado y actividad de pedidos.',
        importance: Importance.high,
      ),
    );
  }

  Future<NotificationSettings?> _requestNotificationPermissions() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    if (_pushEnabled) {
      return FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return null;
  }

  Future<void> _registerToken(String token) async {
    _registeredToken = token;
    await repository.registerDeviceToken(
      token: token,
      platform: defaultTargetPlatform.name,
    );
  }

  Future<void> _registerTokenFromStream(String token) async {
    try {
      if (_authenticated) await _registerToken(token);
      final pending = _pendingTokenRegistration;
      if (pending != null && !pending.isCompleted) pending.complete();
    } catch (error, stackTrace) {
      final pending = _pendingTokenRegistration;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(error, stackTrace);
      } else {
        debugPrint(
          'No se pudo registrar el token push del dispositivo: $error',
        );
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notificationId = message.data['notificationId'];
    if (notificationId is String && notificationId.isNotEmpty) {
      _pushNotificationIds.add(notificationId);
    }
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['message'];
    if (title is String && body is String) {
      await _localNotifications.show(
        id: message.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Cambios de estado y actividad de pedidos.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
    if (_authenticated) await refresh();
  }

  Future<void> _handleOpenedMessage(RemoteMessage message) async {
    _pendingOpenInbox = true;
    final notificationId = message.data['notificationId'];
    if (notificationId is String && notificationId.isNotEmpty) {
      _pushNotificationIds.add(notificationId);
    }
    if (_authenticated) await refresh();
  }

  Future<void> _refreshFromTimer() async {
    try {
      await refresh();
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudieron sincronizar las notificaciones: $error\n$stackTrace',
      );
    }
  }

  Future<void> _showLocalNotification(AppNotification notification) async {
    if (!_localNotificationsAvailable) return;
    await _localNotifications.show(
      id: notification.id,
      title: notification.title,
      body: notification.message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Cambios de estado y actividad de pedidos.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        'notificationId': notification.id.toString(),
        'orderId': notification.orderId?.toString(),
      }),
    );
  }
}
