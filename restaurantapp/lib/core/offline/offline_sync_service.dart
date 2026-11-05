import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../network/api_config.dart';
import '../network/http_client_service.dart';

enum OfflineSyncState {
  checking,
  connected,
  offline,
  syncing,
  synchronized,
  syncError,
}

class OfflineSyncService extends ChangeNotifier {
  OfflineSyncService({
    required this.httpClient,
    Connectivity? connectivity,
    this.connectivityCheck,
    this.connectivityChanges,
  }) : _connectivity = connectivity ?? Connectivity();

  final HttpClientService httpClient;
  final Connectivity _connectivity;
  final Future<List<ConnectivityResult>> Function()? connectivityCheck;
  final Stream<List<ConnectivityResult>>? connectivityChanges;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _probeTimer;
  Timer? _statusTimer;
  Future<bool> Function()? _syncPendingOperations;
  bool _checking = false;
  OfflineSyncState _state = OfflineSyncState.checking;
  String? _lastError;

  OfflineSyncState get state => _state;
  String? get lastError => _lastError;
  bool get isOnline =>
      _state == OfflineSyncState.connected ||
      _state == OfflineSyncState.syncing ||
      _state == OfflineSyncState.synchronized ||
      _state == OfflineSyncState.syncError;

  void setSyncHandler(Future<bool> Function() handler) {
    _syncPendingOperations = handler;
  }

  Future<void> initialize() async {
    _subscription = (connectivityChanges ?? _connectivity.onConnectivityChanged).listen(
      (_) => unawaited(checkNow()),
      onError: (Object error, StackTrace stackTrace) {
        _lastError = 'No se pudo detectar el estado de la red: $error';
        _setState(OfflineSyncState.offline);
      },
    );
    _probeTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(checkNow()),
    );
    await checkNow();
  }

  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;
    try {
      final networks = connectivityCheck == null
          ? await _connectivity.checkConnectivity()
          : await connectivityCheck!();
      if (networks.isEmpty ||
          networks.every((network) => network == ConnectivityResult.none)) {
        _setState(OfflineSyncState.offline);
        return;
      }

      try {
        await httpClient.get(
          ApiConfig.foodsUrl,
          requiresAuth: false,
          timeout: const Duration(seconds: 5),
        );
      } on NetworkUnavailableException {
        _setState(OfflineSyncState.offline);
        return;
      } on HttpApiException {
        // An HTTP response confirms that the backend is reachable.
      }

      final sync = _syncPendingOperations;
      if (sync == null) {
        _lastError = null;
        _setState(OfflineSyncState.connected);
        return;
      }

      final previousError = _lastError;
      _setState(OfflineSyncState.syncing);
      try {
        final didSynchronize = await sync();
        _lastError = null;
        if (didSynchronize) {
          _lastError = null;
          _setState(OfflineSyncState.synchronized);
          _statusTimer?.cancel();
          _statusTimer = Timer(const Duration(seconds: 4), () {
            if (_state == OfflineSyncState.synchronized) {
              _setState(OfflineSyncState.connected);
            }
          });
        } else {
          if (previousError == null) {
            _setState(OfflineSyncState.connected);
          } else {
            _lastError = previousError;
            _setState(OfflineSyncState.syncError);
          }
        }
      } catch (error) {
        _lastError = error.toString();
        _setState(OfflineSyncState.syncError);
      }
    } catch (error) {
      _lastError = 'No se pudo comprobar el acceso al servidor: $error';
      _setState(OfflineSyncState.offline);
    } finally {
      _checking = false;
    }
  }

  void _setState(OfflineSyncState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _probeTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }
}
