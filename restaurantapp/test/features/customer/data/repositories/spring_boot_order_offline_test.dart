import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/network/http_client_service.dart';
import 'package:restaurantapp/core/offline/offline_database.dart';
import 'package:restaurantapp/features/customer/data/repositories/spring_boot_order_repository.dart';
import 'package:restaurantapp/features/customer/domain/entities/order.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'keeps an order draft across restarts and syncs it idempotently',
    () async {
      final directory = await Directory.systemTemp.createTemp('restaurantapp-');
      final path = '${directory.path}${Platform.pathSeparator}orders.db';
      final firstDatabase = await OfflineDatabase.open(databasePath: path);
      final offlineClient = _FakeHttpClient()..offline = true;
      final firstRepository = _repository(firstDatabase, offlineClient);

      final paymentUrl = await firstRepository.saveOrder(_order());

      expect(paymentUrl, isNull);
      expect(firstRepository.getOrders().single.status, 'offline_pending');
      await firstDatabase.close();

      final database = await OfflineDatabase.open(databasePath: path);
      addTearDown(() async {
        firstRepository.dispose();
        await database.close();
        await directory.delete(recursive: true);
      });
      final client = _FakeHttpClient();
      final repository = _repository(database, client);

      await repository.load();
      expect(repository.getOrders().single.status, 'offline_pending');
      expect(repository.getOrdersByEmail('other@example.com'), isEmpty);

      final didSync = await repository.syncPendingOperations();
      final repeatedSync = await repository.syncPendingOperations();

      expect(didSync, isTrue);
      expect(repeatedSync, isFalse);
      expect(client.createOrderRequests, 1);
      expect(client.lastRequest?['clientRequestId'], 'checkout-operation');
      expect(repository.getOrders().single.id, '81');
      expect(
        repository.getOrders().single.checkoutUrl,
        'https://checkout.test/81',
      );
      expect(await database.pendingCount('ana@example.com'), 0);
    },
  );
}

SpringBootOrderRepository _repository(
  OfflineDatabase database,
  _FakeHttpClient client,
) => SpringBootOrderRepository(
  httpClient: client,
  restaurantId: 7,
  isAdministrator: () => false,
  offlineDatabase: database,
  currentOwnerEmail: () => 'ana@example.com',
);

CustomerOrder _order() => CustomerOrder(
  id: 'temporary',
  clientRequestId: 'checkout-operation',
  customerName: 'Ana',
  customerEmail: 'ana@example.com',
  items: const [
    CustomerOrderItem(
      productId: '13',
      name: 'Arepa',
      quantity: 1,
      unitPrice: 15000,
    ),
  ],
  deliveryAddress: const Address(
    street: 'Calle 1',
    city: 'Bogotá',
    postalCode: '110111',
  ),
  paymentMethod: const PaymentMethod(type: 'Stripe', details: ''),
);

class _FakeHttpClient extends HttpClientService {
  bool offline = false;
  int createOrderRequests = 0;
  Map<String, dynamic>? lastRequest;

  @override
  Future<dynamic> post(
    String url, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    if (offline) throw const NetworkUnavailableException();
    createOrderRequests++;
    lastRequest = body;
    return {
      'payment_url': 'https://checkout.test/81',
      'order_id': 81,
      'checkout_session_id': 'cs_test_81',
      'payment_status': 'PENDING',
      'order_status': 'PENDING_PAYMENT',
    };
  }

  @override
  Future<dynamic> get(
    String url, {
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    if (offline) throw const NetworkUnavailableException();
    return const [];
  }
}
