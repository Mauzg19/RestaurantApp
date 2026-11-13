import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/network/http_client_service.dart';
import 'package:restaurantapp/core/offline/offline_database.dart';
import 'package:restaurantapp/features/customer/data/repositories/spring_boot_user_settings_repository.dart';
import 'package:restaurantapp/features/customer/domain/entities/order.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('persists and synchronizes a delivery address after reconnecting', () async {
    final directory = await Directory.systemTemp.createTemp('restaurantapp-');
    final path = '${directory.path}${Platform.pathSeparator}settings.db';
    final database = await OfflineDatabase.open(databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final client = _FakeHttpClient()..offline = true;
    final repository = SpringBootUserSettingsRepository(
      httpClient: client,
      offlineDatabase: database,
    );
    const address = Address(
      street: 'Calle 1',
      city: 'Bogotá',
      postalCode: '110111',
      notes: 'Apto 2',
    );

    await repository.saveDeliveryAddress('ana@example.com', address);
    expect(
      await repository.getDeliveryAddress('ana@example.com'),
      address,
    );
    final pending = await database.getPendingOperations('ana@example.com');
    expect(pending, hasLength(1));
    expect(pending.single.payload['clientOperationId'], pending.single.id);
    expect(await database.pendingCount('ana@example.com'), 1);

    client.offline = false;
    expect(
      await repository.syncPendingOperations('ana@example.com'),
      isTrue,
    );
    expect(
      await repository.syncPendingOperations('ana@example.com'),
      isFalse,
    );
    expect(client.addressRequests, 1);
    expect(client.lastAddressBody?['street'], 'Calle 1');
    expect(client.lastAddressBody?['clientOperationId'], pending.single.id);
    expect(await database.pendingCount('ana@example.com'), 0);
  });
}

class _FakeHttpClient extends HttpClientService {
  bool offline = false;
  int addressRequests = 0;
  Map<String, dynamic>? lastAddressBody;

  @override
  Future<dynamic> post(
    String url, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    if (offline) throw const NetworkUnavailableException();
    addressRequests++;
    lastAddressBody = body;
    return {
      'id': 42,
      'streetAddress': body['street'],
      'city': body['city'],
      'postalCode': body['postalCode'],
      'notes': body['notes'],
    };
  }
}
