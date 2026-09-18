import 'package:flutter/material.dart';

class DashboardMetric {
  const DashboardMetric({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

enum OrderStatus { pending, preparing, ready, delivered }

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.preparing:
        return 'Preparando';
      case OrderStatus.ready:
        return 'Listo';
      case OrderStatus.delivered:
        return 'Entregado';
    }
  }

  OrderStatus get next {
    switch (this) {
      case OrderStatus.pending:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
      case OrderStatus.delivered:
        return OrderStatus.delivered;
    }
  }
}

class DashboardOrder {
  const DashboardOrder({
    required this.id,
    required this.customer,
    required this.items,
    required this.time,
    required this.total,
    required this.status,
  });

  final String id;
  final String customer;
  final String items;
  final String time;
  final double total;
  final OrderStatus status;

  DashboardOrder copyWith({OrderStatus? status}) => DashboardOrder(
    id: id,
    customer: customer,
    items: items,
    time: time,
    total: total,
    status: status ?? this.status,
  );
}

class DashboardMenuItem {
  const DashboardMenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.price,
    this.imagePath,
  });

  final String id;
  final String name;
  final String category;
  final int stock;
  final double price;
  final String? imagePath;

  DashboardMenuItem copyWith({
    String? name,
    String? category,
    int? stock,
    double? price,
    String? imagePath,
  }) => DashboardMenuItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    stock: stock ?? this.stock,
    price: price ?? this.price,
    imagePath: imagePath ?? this.imagePath,
  );
}

class AdministratorDashboard {
  const AdministratorDashboard({
    required this.metrics,
    required this.orders,
    required this.menu,
  });

  final List<DashboardMetric> metrics;
  final List<DashboardOrder> orders;
  final List<DashboardMenuItem> menu;
}
