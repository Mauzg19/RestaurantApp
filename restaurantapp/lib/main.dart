import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/network/http_client_service.dart';
import 'core/offline/offline_database.dart';
import 'core/offline/offline_status_notifier.dart';
import 'core/offline/offline_sync_service.dart';
import 'core/session/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/spring_boot_auth_repository.dart';
import 'features/auth/domain/entities/auth_user.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/register_user.dart';
import 'features/auth/domain/usecases/sign_in.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/administrator/data/repositories/administrator_repository_impl.dart';
import 'features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'features/customer/data/repositories/spring_boot_order_repository.dart';
import 'features/customer/data/repositories/spring_boot_product_repository.dart';
import 'features/customer/data/repositories/spring_boot_rewards_repository.dart';
import 'features/customer/data/repositories/spring_boot_user_settings_repository.dart';
import 'features/customer/data/services/payment_service.dart';
import 'features/customer/domain/repositories/order_repository.dart';
import 'features/customer/domain/repositories/rewards_repository.dart';
import 'features/customer/domain/usecases/get_products.dart';
import 'features/customer/domain/repositories/product_repository.dart';
import 'features/customer/domain/repositories/user_settings_repository.dart';
import 'features/notifications/data/repositories/spring_boot_notification_repository.dart';
import 'features/notifications/data/services/notification_center_service.dart';
import 'features/splash/presentation/pages/splash_page.dart';

final _rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 1. Inicializar sesión persistente y cliente HTTP Spring Boot
  final sessionManager = await SessionManager.getInstance();
  final offlineDatabase = kIsWeb ? null : await OfflineDatabase.open();
  final httpClient = HttpClientService(sessionManager: sessionManager);
  final currentUser = sessionManager.getCurrentUser();
  final offlineSyncService = OfflineSyncService(httpClient: httpClient);
  final notificationCenter = NotificationCenterService(
    repository: SpringBootNotificationRepository(httpClient: httpClient),
  );
  await notificationCenter.initialize();

  // Los datos de negocio y la autenticación se gestionan en Spring Boot/MySQL.
  final productRepository = SpringBootProductRepository(
    httpClient: httpClient,
    offlineDatabase: offlineDatabase,
    currentOwnerEmail: () => sessionManager.getCurrentUser()?.email,
    serverReachable: () => offlineSyncService.isOnline,
  );
  final orderRepository = SpringBootOrderRepository(
    httpClient: httpClient,
    restaurantId: productRepository.restaurantId,
    restaurantIdProvider: () => productRepository.restaurantId,
    isAdministrator: () =>
        sessionManager.getCurrentUser()?.role == AuthRole.administrator,
    offlineDatabase: offlineDatabase,
    currentOwnerEmail: () => sessionManager.getCurrentUser()?.email,
  );
  final settingsRepository = SpringBootUserSettingsRepository(
    httpClient: httpClient,
    offlineDatabase: offlineDatabase,
  );
  final RewardsRepository rewardsRepository = SpringBootRewardsRepository(
    httpClient: httpClient,
  );

  final AuthRepository authRepository = SpringBootAuthRepository(
    httpClient: httpClient,
    sessionManager: sessionManager,
  );

  final signIn = SignIn(authRepository);
  final registerUser = RegisterUser(authRepository);
  final getProducts = GetProducts(productRepository);
  final getAdministratorDashboard = GetAdministratorDashboard(
    AdministratorRepositoryImpl(productRepository, orderRepository),
  );

  offlineSyncService.setSyncHandler(() async {
    final user = sessionManager.getCurrentUser();
    if (user == null) return false;

    var synchronized = false;
    Object? firstError;
    Future<void> sync(Future<bool> Function() task) async {
      try {
        synchronized = await task() || synchronized;
      } catch (error) {
        firstError ??= error;
      }
    }

    await sync(productRepository.syncPendingOperations);
    await sync(orderRepository.syncPendingOperations);
    await sync(() => settingsRepository.syncPendingOperations(user.email));
    if (firstError != null) {
      throw StateError('La cola local requiere otro intento: $firstError');
    }
    return synchronized;
  });

  runApp(
    RestaurantApp(
      signIn: signIn,
      registerUser: registerUser,
      getProducts: getProducts,
      getAdministratorDashboard: getAdministratorDashboard,
      productRepository: productRepository,
      orderRepository: orderRepository,
      settingsRepository: settingsRepository,
      rewardsRepository: rewardsRepository,
      notificationCenter: notificationCenter,
      offlineSyncService: offlineSyncService,
      paymentService: null,
      initialUser: currentUser,
    ),
  );
  unawaited(offlineSyncService.initialize());
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({
    super.key,
    required this.signIn,
    required this.registerUser,
    required this.getProducts,
    required this.getAdministratorDashboard,
    required this.productRepository,
    required this.orderRepository,
    required this.settingsRepository,
    required this.rewardsRepository,
    required this.notificationCenter,
    required this.offlineSyncService,
    this.paymentService,
    this.initialUser,
  });

  final SignIn signIn;
  final RegisterUser registerUser;
  final GetProducts getProducts;
  final GetAdministratorDashboard getAdministratorDashboard;
  final ProductRepository productRepository;
  final OrderRepository orderRepository;
  final UserSettingsRepository settingsRepository;
  final RewardsRepository rewardsRepository;
  final NotificationCenterService notificationCenter;
  final OfflineSyncService offlineSyncService;
  final PaymentService? paymentService;
  final AuthUser? initialUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Fast & AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scaffoldMessengerKey: _rootScaffoldMessengerKey,
      builder: (context, child) => OfflineStatusNotifier(
        syncService: offlineSyncService,
        messengerKey: _rootScaffoldMessengerKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: SplashPage(
        onFinished: () => LoginPage(
          signIn: signIn,
          registerUser: registerUser,
          getProducts: getProducts,
          getAdministratorDashboard: getAdministratorDashboard,
          productRepository: productRepository,
          orderRepository: orderRepository,
          settingsRepository: settingsRepository,
          rewardsRepository: rewardsRepository,
          notificationCenter: notificationCenter,
          offlineSyncService: offlineSyncService,
          paymentService: paymentService,
          initialUser: initialUser,
        ),
      ),
    );
  }
}
