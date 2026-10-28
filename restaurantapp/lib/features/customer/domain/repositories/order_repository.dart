import '../entities/order.dart';

abstract interface class OrderRepository {
  bool get requiresCheckout => false;

  List<CustomerOrder> getOrders();
  List<CustomerOrder> getOrdersByEmail(String email);

  Future<void> load();

  Future<String?> saveOrder(CustomerOrder order);

  Future<void> updateOrderStatus(String orderId, String status);
}
