import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final List<CustomerOrder> _orders = [];

  @override
  bool get requiresCheckout => false;

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
  Future<CustomerOrder?> refreshPaymentStatus(String orderId) async => null;

  @override
  Future<String?> saveOrder(CustomerOrder order) async {
    _orders.add(order);
    return null;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(status: status);
  }
}
