import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/offline/offline_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('persists cached data and keeps records isolated by account', () async {
    final directory = await Directory.systemTemp.createTemp('restaurantapp-');
    final path = '${directory.path}${Platform.pathSeparator}offline.db';
    final database = await OfflineDatabase.open(databasePath: path);

    await database.cacheRecord(
      scope: 'menu',
      ownerEmail: 'ana@example.com',
      recordId: '13',
      payload: {'name': 'Arepa', 'price': 15000},
    );
    await database.close();

    final reopened = await OfflineDatabase.open(databasePath: path);
    addTearDown(() async {
      await reopened.close();
      await directory.delete(recursive: true);
    });

    expect(
      await reopened.readRecords(
        scope: 'menu',
        ownerEmail: 'ANA@example.com',
      ),
      [
        {'recordId': '13', 'name': 'Arepa', 'price': 15000},
      ],
    );
    expect(
      await reopened.readRecords(
        scope: 'menu',
        ownerEmail: 'otra@example.com',
      ),
      isEmpty,
    );
  });

  test('coalesces operations and retains failures for retry', () async {
    final directory = await Directory.systemTemp.createTemp('restaurantapp-');
    final path = '${directory.path}${Platform.pathSeparator}outbox.db';
    final database = await OfflineDatabase.open(databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final operationId = await database.enqueueOperation(
      ownerEmail: 'ana@example.com',
      entityType: 'address',
      entityId: 'home',
      operationType: 'CREATE',
      payload: {'street': 'Calle 1'},
      operationId: 'address-operation',
    );
    final coalescedId = await database.enqueueOperation(
      ownerEmail: 'ana@example.com',
      entityType: 'address',
      entityId: 'home',
      operationType: 'UPDATE',
      payload: {'city': 'Bogotá'},
    );

    expect(coalescedId, operationId);
    await database.markOperationInFlight(operationId!);
    await database.markOperationFailed(operationId, StateError('sin red'));

    final pending = await database.getPendingOperations('ana@example.com');
    expect(pending, hasLength(1));
    expect(pending.single.operationType, 'CREATE');
    expect(pending.single.payload, {
      'street': 'Calle 1',
      'city': 'Bogotá',
    });
    expect(pending.single.attempts, 1);
    expect(await database.pendingCount('ana@example.com'), 1);
  });

  test('cancels a local create when its entity is deleted before sync', () async {
    final directory = await Directory.systemTemp.createTemp('restaurantapp-');
    final path = '${directory.path}${Platform.pathSeparator}cancel.db';
    final database = await OfflineDatabase.open(databasePath: path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    await database.enqueueOperation(
      ownerEmail: 'admin@example.com',
      entityType: 'product',
      entityId: 'local-product',
      operationType: 'CREATE',
      payload: {'name': 'Arepa'},
    );
    final deleteId = await database.enqueueOperation(
      ownerEmail: 'admin@example.com',
      entityType: 'product',
      entityId: 'local-product',
      operationType: 'DELETE',
      payload: const {},
    );

    expect(deleteId, isNull);
    expect(await database.pendingCount('admin@example.com'), 0);
  });
}
