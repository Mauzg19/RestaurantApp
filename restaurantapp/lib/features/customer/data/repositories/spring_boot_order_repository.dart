import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../../../core/services/cart_service.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class SpringBootOrderRepository implements OrderRepository {
  SpringBootOrderRepository({
    required this.httpClient,
    required this.restaurantId,
    required this.isAdministrator,
  });

  final HttpClientService httpClient;
  final int? restaurantId;
  final bool Function() isAdministrator;
  final List<CustomerOrder> _orders = [];

  @override
  bool get requiresCheckout => true;

  @override
  List<CustomerOrder> getOrders() => List.unmodifiable(_orders);

  @override
  List<CustomerOrder> getOrdersByEmail(String email) => _orders
      .where(
        (order) => order.customerEmail.toLowerCase() == email.toLowerCase(),
      )
      .toList();

  @override
  Future<void> load() async {
    final url = isAdministrator()
        ? '${ApiConfig.baseUrl}/api/admin/order/restaurant/'
              '${restaurantId ?? (throw StateError('No se encontró el restaurante asociado al backend.'))}'
        : '${ApiConfig.ordersUrl}/user';
    final response = await httpClient.get(url);
    if (response is! List) {
      throw const FormatException(
        'Spring Boot devolvió los pedidos con formato inválido.',
      );
    }
    _orders
      ..clear()
      ..addAll(
        response.whereType<Map>().map(
          (row) => _fromBackend(Map<String, dynamic>.from(row)),
        ),
      );
  }

  @override
  Future<String?> saveOrder(CustomerOrder order) async {
    final id = restaurantId;
    if (id == null) {
      throw StateError('No se encontró un restaurante en la base de datos.');
    }

    final clientRequestId =
        order.clientRequestId ??
        await CartService().getOrCreateCheckoutRequestId();
    final items = order.items.map((item) {
      final menuItemId = int.tryParse(item.productId);
      if (menuItemId == null) {
        throw FormatException(
          'El producto ${item.name} no tiene un id del backend.',
        );
      }
      return {
        'menuItemId': menuItemId,
        'quantity': item.quantity,
        'notes': item.notes,
      };
    }).toList();

    final response = await httpClient.post(
      ApiConfig.createOrderUrl,
      body: {
        'clientRequestId': clientRequestId,
        'restaurantId': id,
        'deliveryAddress': {
          'fullName': order.customerName,
          'streetAddress': order.deliveryAddress.street,
          'city': order.deliveryAddress.city,
          'postalCode': order.deliveryAddress.postalCode,
          'country': 'Colombia',
          'notes': order.deliveryAddress.notes,
        },
        'items': items,
      },
    );
    if (response is! Map) {
      throw const FormatException(
        'Spring Boot no devolvió los datos de Checkout.',
      );
    }
    final paymentUrl = response['payment_url']?.toString();
    final orderId = response['order_id']?.toString();
    final checkoutSessionId = response['checkout_session_id']?.toString();
    if (paymentUrl == null ||
        paymentUrl.isEmpty ||
        orderId == null ||
        orderId.isEmpty) {
      throw const FormatException(
        'Spring Boot no generó el enlace de pago del pedido.',
      );
    }
    _orders.removeWhere((existing) => existing.id == orderId);
    _orders.insert(
      0,
      order.copyWith(
        id: orderId,
        clientRequestId: clientRequestId,
        paymentIntentId: checkoutSessionId,
        paymentStatus:
            response['payment_status']?.toString().toLowerCase() ?? 'pending',
        status:
            response['order_status']?.toString().toLowerCase() ??
            'pending_payment',
      ),
    );
    return paymentUrl;
  }

  @override
  Future<CustomerOrder?> refreshPaymentStatus(String orderId) async {
    final response = await httpClient.get(
      ApiConfig.paymentStatusUrl(orderId),
      timeout: const Duration(seconds: 30),
    );
    if (response is! Map) {
      throw const FormatException(
        'Spring Boot devolvió el estado de pago inválido.',
      );
    }
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return null;

    final updated = _orders[index].copyWith(
      paymentStatus: response['payment_status']?.toString().toLowerCase(),
      status: response['order_status']?.toString().toLowerCase(),
      paymentIntentId:
          response['checkout_session_id']?.toString() ??
          _orders[index].paymentIntentId,
    );
    _orders[index] = updated;
    return updated;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final backendStatus = switch (status.toLowerCase()) {
      'pending' => 'PENDING',
      'preparing' => 'PREPARING',
      'ready' => 'READY',
      'delivered' => 'DELIVERED',
      _ => throw ArgumentError.value(status, 'status', 'Estado no soportado'),
    };
    await httpClient.put(
      ApiConfig.orderByIdUrl(orderId, backendStatus),
      body: const {},
    );
    await load();
  }

  CustomerOrder _fromBackend(Map<String, dynamic> order) {
    final customer = order['customer'] is Map
        ? Map<String, dynamic>.from(order['customer'] as Map)
        : const <String, dynamic>{};
    final address = order['deliveryAddress'] is Map
        ? Map<String, dynamic>.from(order['deliveryAddress'] as Map)
        : const <String, dynamic>{};
    final payment = order['payment'] is Map
        ? Map<String, dynamic>.from(order['payment'] as Map)
        : const <String, dynamic>{};
    final items = order['items'] is List
        ? (order['items'] as List).whereType<Map>().map((row) {
            final item = Map<String, dynamic>.from(row);
            final food = item['food'] is Map
                ? Map<String, dynamic>.from(item['food'] as Map)
                : const <String, dynamic>{};
            final quantity = _asInt(item['quantity']);
            final totalPrice = _asDouble(item['totalPrice']);
            return CustomerOrderItem(
              productId: food['id']?.toString() ?? '',
              name: food['name']?.toString() ?? 'Producto',
              quantity: quantity,
              unitPrice: _asDouble(
                food['price'],
                fallback: quantity > 0 ? totalPrice / quantity : 0,
              ),
              notes: item['notes']?.toString(),
            );
          }).toList()
        : <CustomerOrderItem>[];
    return CustomerOrder(
      id: order['id']?.toString() ?? '',
      customerName: customer['fullName']?.toString() ?? '',
      customerEmail: customer['email']?.toString() ?? '',
      items: items,
      deliveryAddress: Address(
        street: address['streetAddress']?.toString() ?? '',
        city: address['city']?.toString() ?? '',
        postalCode: address['postalCode']?.toString() ?? '',
        notes: address['notes']?.toString(),
      ),
      paymentMethod: const PaymentMethod(type: 'Backend', details: ''),
      paymentIntentId: payment['stripeCheckoutSessionId']?.toString(),
      clientRequestId: order['clientRequestId']?.toString(),
      paymentStatus:
          (order['paymentStatus'] ?? payment['paymentStatus'] ?? 'pending')
              .toString()
              .toLowerCase(),
      createdAt: DateTime.tryParse(order['createdAt']?.toString() ?? ''),
      status: order['orderStatus']?.toString().toLowerCase() ?? 'pending',
    );
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 1;

  double _asDouble(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
}
