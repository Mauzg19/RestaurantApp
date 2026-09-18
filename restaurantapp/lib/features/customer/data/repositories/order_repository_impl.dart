import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final List<CustomerOrder> _orders = [];

  @override
  List<CustomerOrder> getOrders() => List.unmodifiable(_orders);

  @override
  Future<void> load() async {
    // Local in-memory repository does not need a remote fetch.
  }

  @override
  Future<void> saveOrder(CustomerOrder order) async {
    _orders.add(order);
  }
}
