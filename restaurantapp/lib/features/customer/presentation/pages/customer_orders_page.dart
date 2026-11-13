import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/offline/offline_sync_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/order_repository.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({
    super.key,
    required this.user,
    required this.orderRepository,
    this.offlineSyncService,
  });

  final AuthUser user;
  final OrderRepository orderRepository;
  final OfflineSyncService? offlineSyncService;

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  @override
  void initState() {
    super.initState();
    final repository = widget.orderRepository;
    if (repository case final Listenable listenable) {
      listenable.addListener(_onOrdersChanged);
    }
    widget.offlineSyncService?.addListener(_onSyncStateChanged);
    _loadOrders();
  }

  void _onOrdersChanged() {
    if (mounted) setState(() {});
  }

  void _onSyncStateChanged() {
    if (widget.offlineSyncService?.state == OfflineSyncState.synchronized) {
      unawaited(_loadOrders());
    }
  }

  Future<void> _loadOrders() async {
    try {
      await widget.orderRepository.load();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar pedidos: $e')));
      }
    }
  }

  List<CustomerOrder> get _userOrders =>
      widget.orderRepository.getOrdersByEmail(widget.user.email);

  List<CustomerOrder> get _activeOrders =>
      _userOrders.where((order) => order.status != 'delivered').toList();

  List<CustomerOrder> get _pastOrders =>
      _userOrders.where((order) => order.status == 'delivered').toList();

  @override
  void dispose() {
    final repository = widget.orderRepository;
    if (repository case final Listenable listenable) {
      listenable.removeListener(_onOrdersChanged);
    }
    widget.offlineSyncService?.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text(
          'Mis Pedidos',
          style: TextStyle(
            color: Color(0xFF3B2115),
            fontWeight: FontWeight.bold,
          ),
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
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Color(0xFFEBDCCE),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aún no has realizado pedidos.',
                        style: TextStyle(
                          color: Color(0xFF937A6B),
                          fontSize: 16,
                        ),
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
    if (order.status == 'offline_pending') return Colors.deepOrange;
    if (order.status == 'pending_payment' &&
        order.paymentStatus.toLowerCase() == 'pending') {
      return Colors.orange;
    }
    if (order.paymentStatus.toLowerCase() == 'paid' &&
        order.status.toLowerCase() == 'pending') {
      return Colors.green;
    }
    switch (order.paymentStatus.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
    }
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

  String get _statusLabel {
    if (order.status == 'offline_pending') {
      return 'PENDIENTE DE SINCRONIZAR';
    }
    if (order.status == 'pending_payment' &&
        order.paymentStatus.toLowerCase() == 'pending') {
      return 'PAGO PENDIENTE';
    }
    if (order.paymentStatus.toLowerCase() == 'paid' &&
        order.status.toLowerCase() == 'pending') {
      return 'CONFIRMADO';
    }
    switch (order.paymentStatus.toLowerCase()) {
      case 'failed':
        return 'PAGO FALLIDO';
      case 'cancelled':
        return 'CANCELADO';
      default:
        return switch (order.status.toLowerCase()) {
          'preparing' => 'Preparando',
          'ready' => 'Listo',
          'out_for_delivery' => 'En camino',
          'delivered' || 'completed' => 'Entregado',
          _ => order.status,
        };
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
                  _StatusBadge(status: _statusLabel, color: _statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.items.map((item) {
                  final notes = item.notes?.trim();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}× ${item.name}',
                          style: const TextStyle(
                            color: Color(0xFF937A6B),
                            fontSize: 13,
                          ),
                        ),
                        if (notes != null && notes.isNotEmpty)
                          Text(
                            'Personalización: $notes',
                            style: const TextStyle(
                              color: Color(0xFF563524),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${formatCop(order.total)}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (order.discountAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Descuento de premios: -${formatCop(order.discountAmount)}',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                  ),
                ),
              ],
              if (order.status == 'offline_pending') ...[
                const SizedBox(height: 8),
                const Text(
                  'Se enviará al servidor cuando vuelva la conexión. El pedido aún no está confirmado ni pagado.',
                  style: TextStyle(color: Color(0xFF8A5A00), fontSize: 12),
                ),
              ],
              if (order.checkoutUrl != null &&
                  order.paymentStatus.toLowerCase() == 'pending') ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(order.checkoutUrl!);
                    if (uri == null ||
                        !await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir Stripe Checkout.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Continuar al pago'),
                ),
              ],
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
