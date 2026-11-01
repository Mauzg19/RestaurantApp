import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/network/api_config.dart';
import 'package:restaurantapp/core/network/http_client_service.dart';
import 'package:restaurantapp/features/customer/data/repositories/spring_boot_order_repository.dart';
import 'package:restaurantapp/features/customer/domain/entities/order.dart';

void main() {
  test(
    'creates checkout with item quantities and refreshes the backend status',
    () async {
      final client = _FakeHttpClient();
      final repository = SpringBootOrderRepository(
        httpClient: client,
        restaurantId: 7,
        isAdministrator: () => false,
      );
      final order = CustomerOrder(
        id: 'local-id',
        clientRequestId: 'request-id',
        customerName: 'Ana',
        customerEmail: 'ana@example.com',
        items: const [
          CustomerOrderItem(
            productId: '13',
            name: 'Arepa',
            quantity: 3,
            unitPrice: 15000,
            notes: 'Sin salsa',
          ),
        ],
        deliveryAddress: const Address(
          street: 'Calle 1',
          city: 'Bogotá',
          postalCode: '110111',
        ),
        paymentMethod: const PaymentMethod(type: 'Stripe', details: ''),
      );

      final checkoutUrl = await repository.saveOrder(order);

      expect(checkoutUrl, 'https://checkout.stripe.test/session');
      expect(client.postedUrl, ApiConfig.createOrderUrl);
      expect(client.postedBody?['clientRequestId'], 'request-id');
      expect(client.postedBody?['items'], [
        {'menuItemId': 13, 'quantity': 3, 'notes': 'Sin salsa'},
      ]);
      expect(client.putCount, 0);
      expect(repository.getOrders().single.id, '81');
      expect(repository.getOrders().single.paymentStatus, 'pending');

      client.getResponse = {
        'order_id': 81,
        'checkout_session_id': 'cs_test_81',
        'payment_status': 'PAID',
        'order_status': 'PENDING',
      };
      final updated = await repository.refreshPaymentStatus('81');

      expect(client.getUrl, ApiConfig.paymentStatusUrl('81'));
      expect(client.getTimeout, const Duration(seconds: 30));
      expect(updated?.paymentStatus, 'paid');
      expect(updated?.status, 'pending');
      expect(updated?.paymentIntentId, 'cs_test_81');
    },
  );
}

class _FakeHttpClient extends HttpClientService {
  String? postedUrl;
  Map<String, dynamic>? postedBody;
  String? getUrl;
  Duration? getTimeout;
  dynamic getResponse = {
    'payment_url': 'https://checkout.stripe.test/session',
    'order_id': 81,
    'checkout_session_id': 'cs_test_81',
    'payment_status': 'PENDING',
    'order_status': 'PENDING_PAYMENT',
  };
  int putCount = 0;

  @override
  Future<dynamic> post(
    String url, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    postedUrl = url;
    postedBody = body;
    return getResponse;
  }

  @override
  Future<dynamic> get(
    String url, {
    bool requiresAuth = true,
    Duration? timeout,
  }) async {
    getUrl = url;
    getTimeout = timeout;
    return getResponse;
  }

  @override
  Future<dynamic> put(
    String url, {
    required Map<String, dynamic> body,
    bool requiresAuth = true,
  }) async {
    putCount++;
    return null;
  }
}
