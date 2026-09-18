import '../entities/order.dart';

abstract interface class OrderRepository {
  List<CustomerOrder> getOrders();

  Future<void> load();

  Future<void> saveOrder(CustomerOrder order);
}
