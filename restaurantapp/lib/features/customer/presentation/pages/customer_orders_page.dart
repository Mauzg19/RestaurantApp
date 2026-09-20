import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({
    super.key,
    required this.user,
    required this.orderRepository,
  });

  final AuthUser user;
  final OrderRepository orderRepository;

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      await widget.orderRepository.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar pedidos: $e')),
        );
      }
    }
  }

  List<CustomerOrder> get _userOrders =>
      widget.orderRepository.getOrdersByEmail(widget.user.email);

  List<CustomerOrder> get _activeOrders => _userOrders
      .where((order) => order.status != 'delivered')
      .toList();

  List<CustomerOrder> get _pastOrders => _userOrders
      .where((order) => order.status == 'delivered')
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text(
          'Mis Pedidos',
          style: TextStyle(color: Color(0xFF3B2115), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF3B2115),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeOrders.isNotEmpty) ...[
              const _SectionHeader(title: 'Pedidos Activos'),
              const SizedBox(height: 12),
              ..._activeOrders.map((order) => _OrderCard(order: order)),
              const SizedBox(height: 32),
            ],
            if (_pastOrders.isNotEmpty) ...[
              const _SectionHeader(title: 'Historial de Pedidos'),
              const SizedBox(height: 12),
              ..._pastOrders.map((order) => _OrderCard(order: order)),
            ],
            if (_userOrders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFFEBDCCE)),
                      SizedBox(height: 16),
                      Text(
                        'Aún no has realizado pedidos.',
                        style: TextStyle(color: Color(0xFF937A6B), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          color: Color(0xFF563524),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CustomerOrder order;

  Color get _statusColor {
    switch (order.status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'delivered':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBDCCE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pedido #${order.id.substring(order.id.length > 6 ? order.id.length - 6 : 0)}',
                        style: const TextStyle(
                          color: Color(0xFF3B2115),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      _StatusBadge(status: order.status, color: _statusColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF937A6B), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: £${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFEBDCCE)),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
}
