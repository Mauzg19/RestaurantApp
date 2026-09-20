class Address {
  const Address({
    required this.street,
    required this.city,
    required this.postalCode,
    this.notes,
  });

  final String street;
  final String city;
  final String postalCode;
  final String? notes;

  String get fullAddress => '$street, $city, $postalCode${notes != null ? " ($notes)" : ""}';

  Map<String, dynamic> toJson() => {
        'street': street,
        'city': city,
        'postal_code': postalCode,
        'notes': notes,
      };

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        street: json['street'] as String,
        city: json['city'] as String,
        postalCode: json['postal_code'] as String,
        notes: json['notes'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address &&
          runtimeType == other.runtimeType &&
          street == other.street &&
          city == other.city &&
          postalCode == other.postalCode &&
          notes == other.notes;

  @override
  int get hashCode => street.hashCode ^ city.hashCode ^ postalCode.hashCode ^ notes.hashCode;
}

class PaymentMethod {
  const PaymentMethod({
    required this.type,
    required this.details,
  });

  final String type; // e.g., 'Credit Card', 'PayPal', 'Cash'
  final String details; // e.g., '**** 1234'

  Map<String, dynamic> toJson() => {
        'type': type,
        'details': details,
      };

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        type: json['type'] as String,
        details: json['details'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentMethod &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          details == other.details;

  @override
  int get hashCode => type.hashCode ^ details.hashCode;
}

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

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) => CustomerOrderItem(
        productId: json['product_id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Producto',
        quantity: _toInt(json['quantity']),
        unitPrice: _toDouble(json['unit_price']),
      );
}

class CustomerOrder {
  CustomerOrder({
    String? id,
    required this.customerName,
    required this.customerEmail,
    required this.items,
    required this.deliveryAddress,
    required this.paymentMethod,
    DateTime? createdAt,
    this.status = 'pending',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String customerName;
  final String customerEmail;
  final List<CustomerOrderItem> items;
  final Address deliveryAddress;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final String status;

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get summary => items
      .map((item) => '${item.quantity}× ${item.name}')
      .join(', ');

  CustomerOrder copyWith({String? status}) => CustomerOrder(
        id: id,
        customerName: customerName,
        customerEmail: customerEmail,
        items: items,
        deliveryAddress: deliveryAddress,
        paymentMethod: paymentMethod,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_name': customerName,
        'customer_email': customerEmail,
        'items': items.map((i) => i.toJson()).toList(),
        'delivery_street': deliveryAddress.street,
        'delivery_city': deliveryAddress.city,
        'delivery_postal_code': deliveryAddress.postalCode,
        'delivery_notes': deliveryAddress.notes,
        'payment_type': paymentMethod.type,
        'payment_details': paymentMethod.details,
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
        'total': total,
      };

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsJson = rawItems is List ? rawItems : const <dynamic>[];
    return CustomerOrder(
      id: json['id']?.toString() ?? '',
      customerName: json['customer_name'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
        items: itemsJson
            .whereType<Map>()
            .map(
              (item) => CustomerOrderItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
          .toList(),
      deliveryAddress: Address(
        street: json['delivery_street'] as String? ?? '',
        city: json['delivery_city'] as String? ?? '',
        postalCode: json['delivery_postal_code'] as String? ?? '',
        notes: json['delivery_notes'] as String?,
      ),
      paymentMethod: PaymentMethod(
        type: json['payment_type'] as String? ?? '',
        details: json['payment_details'] as String? ?? '',
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'pending',
    );
  }
}

int _toInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
