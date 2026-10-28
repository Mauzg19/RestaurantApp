import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../customer/domain/entities/order.dart';
import '../../../customer/domain/entities/product.dart';
import '../../../customer/domain/repositories/order_repository.dart';
import '../../../customer/domain/repositories/product_repository.dart';
import '../../domain/entities/administrator_dashboard.dart';
import '../../domain/repositories/administrator_repository.dart';

class AdministratorRepositoryImpl implements AdministratorRepository {
  AdministratorRepositoryImpl(this.productRepository, [this.orderRepository]);

  final ProductRepository productRepository;
  final OrderRepository? orderRepository;

  @override
  AdministratorDashboard getDashboard() {
    final savedOrders = orderRepository?.getOrders() ?? const <CustomerOrder>[];
    final products = productRepository.getProducts();
    final activeOrders = savedOrders
        .where((order) => order.status != 'delivered')
        .length;
    final salesTotal = savedOrders.fold<double>(
      0,
      (total, order) => total + order.total,
    );
    final customerCount = savedOrders
        .map((order) => order.customerEmail)
        .where((email) => email.isNotEmpty)
        .toSet()
        .length;
    final orders = savedOrders.isNotEmpty
        ? savedOrders.map(_toDashboardOrder).toList()
        : orderRepository == null
        ? const [
            DashboardOrder(
              id: '#1048',
              customer: 'Ana García',
              items: '2 Bowls + 1 bebida',
              time: '12:15',
              total: 26.50,
              status: OrderStatus.preparing,
            ),
            DashboardOrder(
              id: '#1049',
              customer: 'Luis Pérez',
              items: '3 Burritos',
              time: '12:42',
              total: 31.75,
              status: OrderStatus.pending,
            ),
            DashboardOrder(
              id: '#1050',
              customer: 'Sara Díaz',
              items: '1 taco box + sides',
              time: '13:05',
              total: 22.00,
              status: OrderStatus.ready,
            ),
          ]
        : const <DashboardOrder>[];

    return AdministratorDashboard(
      metrics: [
        DashboardMetric(
          title: 'Pedidos activos',
          value: '$activeOrders',
          detail: 'Pedidos registrados',
          icon: Icons.receipt_long,
          color: AppTheme.accent,
        ),
        DashboardMetric(
          title: 'Ventas registradas',
          value: formatCop(salesTotal),
          detail: 'Total de pedidos cargados',
          icon: Icons.trending_up,
          color: Color(0xFF7CCB9A),
        ),
        DashboardMetric(
          title: 'Productos',
          value: '${products.length}',
          detail: 'En el catálogo del backend',
          icon: Icons.restaurant_menu,
          color: Color(0xFFEDB15A),
        ),
        DashboardMetric(
          title: 'Clientes',
          value: '$customerCount',
          detail: 'Con pedidos registrados',
          icon: Icons.people_alt_rounded,
          color: Color(0xFFB88DFF),
        ),
      ],
      orders: orders,
      menu: products.map(_toMenuItem).toList(),
    );
  }

  DashboardOrder _toDashboardOrder(CustomerOrder order) => DashboardOrder(
    id: '#${order.id}',
    customer: order.customerName,
    items: order.summary,
    time:
        '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
    total: order.total,
    status: _statusFromString(order.status),
  );

  OrderStatus _statusFromString(String status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'delivered':
        return OrderStatus.delivered;
      default:
        return OrderStatus.pending;
    }
  }

  DashboardMenuItem _toMenuItem(Product product) => DashboardMenuItem(
    id: product.id,
    name: product.name,
    category: product.categoryName ?? product.category.label,
    stock: 20,
    isAvailable: product.isAvailable,
    price: product.price,
    imagePath: product.imagePath,
  );
}
