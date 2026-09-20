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
      metrics: const [
        DashboardMetric(
          title: 'Pedidos activos',
          value: '12',
          detail: '+4 desde la última hora',
          icon: Icons.receipt_long,
          color: AppTheme.accent,
        ),
        DashboardMetric(
          title: 'Ventas del día',
          value: '£842',
          detail: '+18% vs ayer',
          icon: Icons.trending_up,
          color: Color(0xFF7CCB9A),
        ),
        DashboardMetric(
          title: 'Productos',
          value: '36',
          detail: '8 con stock bajo',
          icon: Icons.restaurant_menu,
          color: Color(0xFFEDB15A),
        ),
        DashboardMetric(
          title: 'Clientes',
          value: '1.2k',
          detail: '90 nuevos esta semana',
          icon: Icons.people_alt_rounded,
          color: Color(0xFFB88DFF),
        ),
      ],
      orders: orders,
      menu: productRepository.getProducts().map(_toMenuItem).toList(),
    );
  }

  DashboardOrder _toDashboardOrder(CustomerOrder order) => DashboardOrder(
    id: '#${order.id}',
    customer: order.customerName,
    items: order.summary,
    time: '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
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
    category: product.category.label,
    stock: 20,
    price: product.price,
    imagePath: product.imagePath,
  );
}
