import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
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
      .where((order) => order.customerEmail.toLowerCase() == email.toLowerCase())
      .toList();

  @override
  Future<void> load() async {
    final url = isAdministrator()
        ? '${ApiConfig.baseUrl}/api/admin/order/restaurant/'
            '${restaurantId ?? (throw StateError('No se encontró el restaurante asociado al backend.'))}'
        : '${ApiConfig.ordersUrl}/user';
    final response = await httpClient.get(url);
    if (response is! List) {
      throw const FormatException('Spring Boot devolvió los pedidos con formato inválido.');
    }
    _orders
      ..clear()
      ..addAll(response.whereType<Map>().map(
        (row) => _fromBackend(Map<String, dynamic>.from(row)),
      ));
  }

  @override
  Future<String?> saveOrder(CustomerOrder order) async {
    final id = restaurantId;
    if (id == null) {
      throw StateError('No se encontró un restaurante en la base de datos.');
    }

    await httpClient.put(ApiConfig.clearCartUrl, body: const {});
    for (final item in order.items) {
      final menuItemId = int.tryParse(item.productId);
      if (menuItemId == null) {
        throw FormatException('El producto ${item.name} no tiene un id del backend.');
      }
      await httpClient.put(
        ApiConfig.addCartItemUrl,
        body: {'menuItemId': menuItemId, 'quantity': item.quantity},
      );
    }

    final response = await httpClient.post(
      ApiConfig.createOrderUrl,
      body: {
        'restaurantId': id,
        'deliveryAddress': {
          'fullName': order.customerName,
          'streetAddress': order.deliveryAddress.street,
          'city': order.deliveryAddress.city,
          'postalCode': order.deliveryAddress.postalCode,
          'country': 'UK',
          'notes': order.deliveryAddress.notes,
        },
      },
    );
    await load();
    if (response is! Map) {
      throw const FormatException('Spring Boot no devolvió el enlace de pago del pedido.');
    }
    final paymentUrl = response['payment_url']?.toString();
    if (paymentUrl == null || paymentUrl.isEmpty) {
      throw const FormatException('Spring Boot no generó el enlace de pago del pedido.');
    }
    return paymentUrl;
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
      createdAt: DateTime.tryParse(order['createdAt']?.toString() ?? ''),
      status: order['orderStatus']?.toString().toLowerCase() ?? 'pending',
    );
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 1;

  double _asDouble(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
}
