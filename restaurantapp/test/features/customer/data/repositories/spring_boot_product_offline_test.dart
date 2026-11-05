import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/network/http_client_service.dart';
import 'package:restaurantapp/core/offline/offline_database.dart';
import 'package:restaurantapp/features/customer/data/repositories/spring_boot_product_repository.dart';
import 'package:restaurantapp/features/customer/domain/entities/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'retains offline product changes and syncs creates idempotently',
    () async {
      final directory = await Directory.systemTemp.createTemp('restaurantapp-');
      final path = '${directory.path}${Platform.pathSeparator}products.db';
      final database = await OfflineDatabase.open(databasePath: path);
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });

      await database.cacheRecord(
        scope: 'products',
        ownerEmail: 'admin@example.com',
        recordId: '11',
        payload: {
          'id': 11,
          'name': 'Té',
          'description': 'Té negro',
          'price': 1000,
          'available': true,
          'foodCategory': {'id': 5, 'name': 'Bebidas'},
          'restaurant': {'id': 7},
          'images': [],
        },
      );
      await database.cacheRecord(
        scope: 'categories',
        ownerEmail: 'admin@example.com',
        recordId: '5',
        payload: {'id': 5, 'name': 'Bebidas'},
      );
      final client = _FakeHttpClient()..offline = true;
      final repository = SpringBootProductRepository(
        httpClient: client,
        offlineDatabase: database,
        currentOwnerEmail: () => 'admin@example.com',
      );

      await repository.load();
      await repository.saveProduct(
        _product(id: '11', name: 'Té actualizado', price: 1200),
      );
      await repository.saveProduct(
        _product(id: 'draft-product', name: 'Agua', price: 2500),
        category: const ProductCategoryOption(id: 5, name: 'Bebidas'),
      );

      final pending = await database.getPendingOperations('admin@example.com');
      final createOperation = pending.singleWhere(
        (operation) => operation.operationType == 'CREATE',
      );
      expect(pending, hasLength(2));
      expect(createOperation.payload['clientOperationId'], createOperation.id);
      expect(
        repository.getProducts().map((product) => product.name),
        containsAll(['Té actualizado', 'Agua']),
      );

      client.offline = false;
      expect(await repository.syncPendingOperations(), isTrue);
      expect(await repository.syncPendingOperations(), isFalse);
      expect(client.createRequests, 1);
      expect(client.lastCreateBody?['clientOperationId'], createOperation.id);
      expect(await database.pendingCount('admin@example.com'), 0);
      expect(
        repository.getProducts().map((product) => product.id),
        contains('99'),
      );
    },
  );
}

Product _product({
  required String id,
  required String name,
  required double price,
}) => Product(
  id: id,
  name: name,
  category: ProductCategory.drinks,
  categoryName: 'Bebidas',
  price: price,
  icon: Icons.local_drink,
  accentColor: const Color(0xFFC95D32),
);

class _FakeHttpClient extends HttpClientService {
  bool offline = false;
  int createRequests = 0;
  Map<String, dynamic>? lastCreateBody;

  void _requireOnline() {
    if (offline) throw const NetworkUnavailableException();
  }

  @override
  Future<dynamic> get(
    String url, {
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    _requireOnline();
    return const [];
  }

  @override
  Future<dynamic> post(
    String url, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    _requireOnline();
    createRequests++;
    lastCreateBody = body;
    return {
      'id': 99,
      'name': body['name'],
      'description': body['description'],
      'price': body['price'],
      'available': body['available'],
      'foodCategory': {'id': 5, 'name': 'Bebidas'},
      'restaurant': {'id': 7},
      'images': [],
    };
  }

  @override
  Future<dynamic> put(
    String url, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    _requireOnline();
    return null;
  }
}
