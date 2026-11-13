import 'package:flutter/foundation.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../../../core/offline/offline_database.dart';
import '../../../../core/services/cart_service.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class SpringBootOrderRepository extends ChangeNotifier
    implements OrderRepository {
  SpringBootOrderRepository({
    required this.httpClient,
    required this.restaurantId,
    this.restaurantIdProvider,
    this.restaurantIdForProduct,
    required this.isAdministrator,
    this.offlineDatabase,
    this.currentOwnerEmail,
  });

  final HttpClientService httpClient;
  final int? restaurantId;
  final int? Function()? restaurantIdProvider;
  final int? Function(String productId)? restaurantIdForProduct;
  final bool Function() isAdministrator;
  final OfflineDatabase? offlineDatabase;
  final String? Function()? currentOwnerEmail;
  final List<CustomerOrder> _orders = [];

  @override
  bool get requiresCheckout => true;

  int? get _activeRestaurantId => restaurantIdProvider?.call() ?? restaurantId;

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
    await _loadCachedOrders();
    if (_orders.isNotEmpty) notifyListeners();
    try {
      final url = isAdministrator()
          ? '${ApiConfig.baseUrl}/api/admin/order/restaurant/'
                '${_activeRestaurantId ?? (throw StateError('No se encontró el restaurante asociado al backend.'))}'
          : '${ApiConfig.ordersUrl}/user';
      final response = await httpClient.get(url);
      if (response is! List) {
        throw const FormatException(
          'Spring Boot devolvió los pedidos con formato inválido.',
        );
      }
      final remoteOrders = response
          .whereType<Map>()
          .map((row) => _fromBackend(Map<String, dynamic>.from(row)))
          .toList();
      final previousById = {for (final order in _orders) order.id: order};
      for (var index = 0; index < remoteOrders.length; index++) {
        final remote = remoteOrders[index];
        final previous = previousById[remote.id];
        if (remote.paymentStatus == 'pending' &&
            remote.paymentIntentId != null &&
            previous?.paymentIntentId == remote.paymentIntentId) {
          remoteOrders[index] = remote.copyWith(
            checkoutUrl: previous?.checkoutUrl,
          );
        }
      }
      await _mergeCachedPendingOrders(remoteOrders);
      _orders
        ..clear()
        ..addAll(remoteOrders);
      await _cacheOrders(remoteOrders);
      notifyListeners();
    } on NetworkUnavailableException {
      await _loadCachedOrders();
      notifyListeners();
    }
  }

  @override
  Future<String?> saveOrder(CustomerOrder order) async {
    final restaurantIds = order.items
        .map((item) => restaurantIdForProduct?.call(item.productId))
        .whereType<int>()
        .toSet();
    if (restaurantIds.length > 1) {
      throw StateError(
        'El pedido debe contener productos de un solo restaurante.',
      );
    }
    final id = restaurantIds.firstOrNull ?? _activeRestaurantId;
    if (id == null) {
      throw StateError('No se encontró un restaurante en la base de datos.');
    }

    final clientRequestId =
        order.clientRequestId ??
        await CartService().getOrCreateCheckoutRequestId();
    final request = _createRequest(order, id, clientRequestId);
    if (offlineDatabase == null) {
      return _submitCheckout(order, clientRequestId, request);
    }

    final draft = order.copyWith(
      id: 'offline-$clientRequestId',
      clientRequestId: clientRequestId,
      checkoutUrl: null,
      status: 'offline_pending',
      paymentStatus: 'pending',
    );
    _orders.removeWhere(
      (existing) =>
          existing.id == draft.id ||
          existing.clientRequestId == clientRequestId,
    );
    _orders.insert(0, draft);
    await _cacheOrder(draft);
    await offlineDatabase!.enqueueOperation(
      ownerEmail: _owner,
      entityType: 'order',
      entityId: clientRequestId,
      operationType: 'CREATE',
      payload: {'request': request, 'order': draft.toJson()},
      operationId: clientRequestId,
    );
    notifyListeners();
    try {
      return await _submitCheckout(draft, clientRequestId, request);
    } on NetworkUnavailableException {
      return null;
    } catch (error) {
      final operation = (await offlineDatabase!.getPendingOperations(
        _owner,
        entityType: 'order',
      )).where((candidate) => candidate.id == clientRequestId);
      if (operation.isNotEmpty) {
        await offlineDatabase!.markOperationFailed(clientRequestId, error);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _createRequest(
    CustomerOrder order,
    int restaurantId,
    String clientRequestId,
  ) {
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

    return {
      'clientRequestId': clientRequestId,
      'restaurantId': restaurantId,
      'deliveryAddress': {
        'fullName': order.customerName,
        'streetAddress': order.deliveryAddress.street,
        'city': order.deliveryAddress.city,
        'postalCode': order.deliveryAddress.postalCode,
        'country': 'Colombia',
        'notes': order.deliveryAddress.notes,
      },
      'items': items,
      'rewardId': order.rewardId,
    };
  }

  Future<String?> _submitCheckout(
    CustomerOrder order,
    String clientRequestId,
    Map<String, dynamic> request,
  ) async {
    final response = await httpClient.post(
      ApiConfig.createOrderUrl,
      body: request,
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
    final savedOrder = order.copyWith(
      id: orderId,
      clientRequestId: clientRequestId,
      checkoutUrl: paymentUrl,
      paymentIntentId: checkoutSessionId,
      paymentStatus:
          response['payment_status']?.toString().toLowerCase() ?? 'pending',
      status:
          response['order_status']?.toString().toLowerCase() ??
          'pending_payment',
      discountAmount: _asDouble(response['discount_amount']),
      finalTotal: response['total_amount'] == null
          ? null
          : _asDouble(response['total_amount']),
    );
    await _replaceCachedOrder(order, savedOrder);
    _orders.removeWhere(
      (existing) =>
          existing.id == order.id ||
          existing.id == orderId ||
          existing.clientRequestId == clientRequestId,
    );
    _orders.insert(0, savedOrder);
    notifyListeners();
    final database = offlineDatabase;
    if (database != null) {
      await database.completeOperation(clientRequestId);
    }
    return paymentUrl;
  }

  Future<bool> syncPendingOperations() async {
    final database = offlineDatabase;
    if (database == null) return false;
    final operations = await database.getReadyOperations(_owner);
    var synchronized = false;
    Object? firstError;
    for (final operation in operations.where(
      (candidate) =>
          candidate.entityType == 'order' ||
          candidate.entityType == 'order_status',
    )) {
      await database.markOperationInFlight(operation.id);
      try {
        if (operation.entityType == 'order_status') {
          final status = operation.payload['status'] as String;
          await httpClient.put(
            ApiConfig.orderByIdUrl(operation.entityId, status),
            body: const {},
          );
          await database.completeOperation(operation.id);
          synchronized = true;
          continue;
        }
        final request = Map<String, dynamic>.from(
          operation.payload['request'] as Map,
        );
        final order = CustomerOrder.fromJson(
          Map<String, dynamic>.from(operation.payload['order'] as Map),
        );
        await _submitCheckout(order, operation.id, request);
        synchronized = true;
      } catch (error) {
        await database.markOperationFailed(operation.id, error);
        firstError ??= error;
      }
    }
    if (firstError != null) {
      throw StateError('No se pudieron sincronizar los pedidos: $firstError');
    }
    return synchronized;
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
      checkoutUrl: response['payment_url']?.toString(),
      status: response['order_status']?.toString().toLowerCase(),
      paymentIntentId:
          response['checkout_session_id']?.toString() ??
          _orders[index].paymentIntentId,
    );
    _orders[index] = updated;
    await _cacheOrder(updated);
    notifyListeners();
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
    try {
      await httpClient.put(
        ApiConfig.orderByIdUrl(orderId, backendStatus),
        body: const {},
      );
      await load();
    } on NetworkUnavailableException {
      final database = offlineDatabase;
      if (database == null) rethrow;
      final index = _orders.indexWhere((order) => order.id == orderId);
      if (index == -1) rethrow;
      final updated = _orders[index].copyWith(status: status.toLowerCase());
      _orders[index] = updated;
      await _cacheOrder(updated);
      await database.enqueueOperation(
        ownerEmail: _owner,
        entityType: 'order_status',
        entityId: orderId,
        operationType: 'UPDATE',
        payload: {'status': backendStatus},
      );
      notifyListeners();
    }
  }

  String get _owner => currentOwnerEmail?.call()?.trim().toLowerCase() ?? '';

  Future<void> _mergeCachedPendingOrders(
    List<CustomerOrder> remoteOrders,
  ) async {
    final database = offlineDatabase;
    if (database == null) return;
    final pending = await database.getPendingOperations(_owner);
    if (pending.isEmpty) return;
    final cached = await database.readRecords(
      scope: 'orders',
      ownerEmail: _owner,
    );
    for (final row in cached) {
      final order = CustomerOrder.fromJson(
        Map<String, dynamic>.from(row)..remove('recordId'),
      );
      if (!pending.any((operation) {
        if (operation.entityType == 'order') {
          return operation.entityId == order.clientRequestId;
        }
        return operation.entityType == 'order_status' &&
            operation.entityId == order.id;
      })) {
        continue;
      }
      remoteOrders.removeWhere(
        (remote) =>
            remote.id == order.id ||
            remote.clientRequestId == order.clientRequestId,
      );
      remoteOrders.insert(0, order);
    }
  }

  Future<void> _loadCachedOrders() async {
    final database = offlineDatabase;
    if (database == null) return;
    final cached = await database.readRecords(
      scope: 'orders',
      ownerEmail: _owner,
    );
    _orders
      ..clear()
      ..addAll(
        cached.map(
          (row) => CustomerOrder.fromJson(
            Map<String, dynamic>.from(row)..remove('recordId'),
          ),
        ),
      );
  }

  Future<void> _cacheOrders(List<CustomerOrder> orders) async {
    final database = offlineDatabase;
    if (database == null) return;
    final pendingOperations = await database.getPendingOperations(_owner);
    final pendingIds = pendingOperations.map((operation) {
      return operation.entityType == 'order'
          ? 'offline-${operation.entityId}'
          : operation.entityId;
    }).toSet();
    await database.replaceRecords(
      scope: 'orders',
      ownerEmail: _owner,
      records: orders
          .map((order) => {'recordId': order.id, ...order.toJson()})
          .toList(),
      preserveIds: pendingIds,
    );
  }

  Future<void> _cacheOrder(CustomerOrder order) async {
    final database = offlineDatabase;
    if (database == null) return;
    await database.cacheRecord(
      scope: 'orders',
      ownerEmail: _owner,
      recordId: order.id,
      payload: order.toJson(),
    );
  }

  Future<void> _replaceCachedOrder(
    CustomerOrder oldOrder,
    CustomerOrder newOrder,
  ) async {
    final database = offlineDatabase;
    if (database == null) return;
    await database.deleteRecord(
      scope: 'orders',
      ownerEmail: _owner,
      recordId: oldOrder.id,
    );
    await _cacheOrder(newOrder);
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
      rewardId: order['appliedReward'] is Map
          ? _asNullableInt(
              Map<String, dynamic>.from(order['appliedReward'] as Map)['id'],
            )
          : null,
      discountAmount: _asDouble(order['discountAmount']),
      finalTotal: order['totalAmount'] == null
          ? null
          : _asDouble(order['totalAmount']),
    );
  }

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 1;

  int? _asNullableInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  double _asDouble(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
}
