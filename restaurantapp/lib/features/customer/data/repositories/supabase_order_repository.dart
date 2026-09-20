import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this.client, {List<CustomerOrder> fallback = const []})
    : _orders = [...fallback];

  final SupabaseClient client;
  final List<CustomerOrder> _orders;

  @override
  List<CustomerOrder> getOrders() => List.unmodifiable(_orders);

  @override
  List<CustomerOrder> getOrdersByEmail(String email) {
    return _orders
        .where(
          (order) =>
              order.customerEmail.trim().toLowerCase() ==
              email.trim().toLowerCase(),
        )
        .toList();
  }

  @override
  Future<void> load() async {
    final session = client.auth.currentSession;
    if (session == null) {
      throw StateError('No hay una sesión autenticada para cargar pedidos.');
    }

    final rows = await client
      .from('orders')
      .select('*')
      .order('created_at', ascending: false);
    final loadedOrders = <CustomerOrder>[];
    Object? firstParseError;
    for (final row in rows) {
      try {
        loadedOrders.add(
          CustomerOrder.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        );
      } catch (error) {
        firstParseError ??= error;
      }
    }
    if (rows.isNotEmpty && loadedOrders.isEmpty) {
      throw StateError(
        'Supabase devolvió ${rows.length} pedido(s), pero no se pudo interpretar ninguno: $firstParseError',
      );
    }
    final loadedIds = loadedOrders.map((order) => order.id).toSet();
    final locallySavedOrders = _orders
        .where((order) => !loadedIds.contains(order.id))
        .toList();
    _orders
      ..clear()
      ..addAll(loadedOrders)
      ..addAll(locallySavedOrders)
      ..sort(
        (first, second) => second.createdAt.compareTo(first.createdAt),
      );
  }

  @override
  Future<void> saveOrder(CustomerOrder order) async {
    await client.from('orders').insert(order.toJson());
    _orders.add(order);
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final updatedRows = await client
        .from('orders')
        .update({'status': status})
        .eq('id', orderId)
        .select('id');

    if (updatedRows.isEmpty) {
      throw StateError(
        'Supabase no actualizó ninguna fila. Ejecuta supabase/schema.sql y verifica que el perfil de la sesión tenga role = administrator y que el pedido exista en public.orders.',
      );
    }

    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(status: status);
    }
  }
}
