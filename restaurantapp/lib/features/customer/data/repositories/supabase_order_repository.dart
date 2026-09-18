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
  Future<void> load() async {
    try {
      final rows = await client.from('orders').select();
      _orders
        ..clear()
        ..addAll(
          rows.map((row) {
            final items = (row['items'] as List?) ?? const [];
            return CustomerOrder(
              id: row['id'] as String,
              customerName: row['customer_name'] as String,
              customerEmail: row['customer_email'] as String,
              items: items.map<CustomerOrderItem>((item) {
                final map = item as Map<String, dynamic>;
                return CustomerOrderItem(
                  productId: map['product_id'] as String? ?? '',
                  name: map['name'] as String? ?? 'Producto',
                  quantity: (map['quantity'] as num?)?.toInt() ?? 1,
                  unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
                );
              }).toList(),
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
              status: row['status'] as String? ?? 'pending',
            );
          }).toList(),
        );
    } catch (_) {
      // Keep the in-memory state if Supabase is unavailable.
    }
  }

  @override
  Future<void> saveOrder(CustomerOrder order) async {
    _orders.add(order);

    try {
      await client.from('orders').insert({
        'id': order.id,
        'customer_name': order.customerName,
        'customer_email': order.customerEmail,
        'items': order.items
            .map(
              (item) => {
                'product_id': item.productId,
                'name': item.name,
                'quantity': item.quantity,
                'unit_price': item.unitPrice,
              },
            )
            .toList(),
        'total': order.total,
        'status': order.status,
        'created_at': order.createdAt.toUtc().toIso8601String(),
      });
    } catch (_) {
      // Keep the order available in memory even if Supabase is temporarily offline.
    }
  }
}
