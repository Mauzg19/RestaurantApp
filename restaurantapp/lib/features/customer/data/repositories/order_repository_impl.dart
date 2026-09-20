import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final List<CustomerOrder> _orders = [];

  @override
  List<CustomerOrder> getOrders() => List.unmodifiable(_orders);

  @override
  List<CustomerOrder> getOrdersByEmail(String email) =>
      _orders
        .where(
        (order) =>
          order.customerEmail.trim().toLowerCase() ==
          email.trim().toLowerCase(),
        )
        .toList();

  @override
  Future<void> load() async {
    // Local in-memory repository does not need a remote fetch.
  }

  @override
  Future<void> saveOrder(CustomerOrder order) async {
    _orders.add(order);
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(status: status);
  }
}
