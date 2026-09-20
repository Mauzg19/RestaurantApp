import '../entities/order.dart';

abstract interface class OrderRepository {
  List<CustomerOrder> getOrders();
  List<CustomerOrder> getOrdersByEmail(String email);

  Future<void> load();

  Future<void> saveOrder(CustomerOrder order);

  Future<void> updateOrderStatus(String orderId, String status);
}
