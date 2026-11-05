import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/offline/offline_sync_service.dart';
import 'package:restaurantapp/core/network/http_client_service.dart';

void main() {
  test('treats a connected network without backend access as offline', () async {
    final service = OfflineSyncService(
      httpClient: _FakeHttpClient()..failWithNetworkError = true,
      connectivityCheck: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
    );
    addTearDown(service.dispose);

    await service.initialize();

    expect(service.state, OfflineSyncState.offline);
    expect(service.isOnline, isFalse);
  });

  test('reports synchronized only after the backend and outbox succeed', () async {
    final service = OfflineSyncService(
      httpClient: _FakeHttpClient(),
      connectivityCheck: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
    );
    var synchronizationCount = 0;
    service.setSyncHandler(() async {
      synchronizationCount++;
      return true;
    });
    addTearDown(service.dispose);

    await service.initialize();

    expect(synchronizationCount, 1);
    expect(service.state, OfflineSyncState.synchronized);
    expect(service.isOnline, isTrue);
  });

  test('retains a visible sync error when queued work is not completed', () async {
    final service = OfflineSyncService(
      httpClient: _FakeHttpClient(),
      connectivityCheck: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
    );
    service.setSyncHandler(() async => throw StateError('falló el servidor'));
    addTearDown(service.dispose);

    await service.initialize();

    expect(service.state, OfflineSyncState.syncError);
    expect(service.lastError, contains('falló el servidor'));
  });
}

class _FakeHttpClient extends HttpClientService {
  bool failWithNetworkError = false;

  @override
  Future<dynamic> get(
    String url, {
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    if (failWithNetworkError) {
      throw const NetworkUnavailableException();
    }
    return const [];
  }
}
