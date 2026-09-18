class CustomerOrderItem {
  const CustomerOrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;

  double get subtotal => unitPrice * quantity;
}

class CustomerOrder {
  CustomerOrder({
    String? id,
    required this.customerName,
    required this.customerEmail,
    required this.items,
    DateTime? createdAt,
    this.status = 'pending',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String customerName;
  final String customerEmail;
  final List<CustomerOrderItem> items;
  final DateTime createdAt;
  final String status;

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get summary => items
      .map((item) => '${item.quantity}× ${item.name}')
      .join(', ');
}
