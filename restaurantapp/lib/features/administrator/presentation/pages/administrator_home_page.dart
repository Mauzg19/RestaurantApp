import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'dart:typed_data';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../customer/domain/entities/product.dart';
import '../../../customer/domain/repositories/product_repository.dart';
import '../../domain/entities/administrator_dashboard.dart';
import '../../domain/usecases/get_administrator_dashboard.dart';

class AdministratorHomePage extends StatefulWidget {
  const AdministratorHomePage({
    super.key,
    required this.user,
    required this.getDashboard,
    required this.productRepository,
    this.onLogout,
  });

  final AuthUser user;
  final GetAdministratorDashboard getDashboard;
  final ProductRepository productRepository;
  final void Function(BuildContext)? onLogout;

  @override
  State<AdministratorHomePage> createState() => _AdministratorHomePageState();
}

class _AdministratorHomePageState extends State<AdministratorHomePage> {
  late final List<DashboardMetric> _metrics;
  late List<DashboardOrder> _orders;
  late List<DashboardMenuItem> _menu;
  int _selectedTab = 0;
  String _orderFilter = 'Todos';
  String _menuQuery = '';
  bool _hasUnreadNotifications = true;

  @override
  void initState() {
    super.initState();
    final dashboard = widget.getDashboard();
    _metrics = dashboard.metrics;
    _orders = [...dashboard.orders];
    _menu = [...dashboard.menu];
  }

  List<DashboardOrder> get _filteredOrders {
    final status = switch (_orderFilter) {
      'Pendientes' => OrderStatus.pending,
      'Preparando' => OrderStatus.preparing,
      'Listos' => OrderStatus.ready,
      _ => null,
    };
    return status == null
        ? _orders
        : _orders.where((order) => order.status == status).toList();
  }

  List<DashboardMenuItem> get _filteredMenu {
    final query = _menuQuery.trim().toLowerCase();
    if (query.isEmpty) return _menu;
    return _menu
        .where(
          (item) =>
              item.name.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query),
        )
        .toList();
  }

  void _advanceOrder(DashboardOrder order) {
    if (order.status == OrderStatus.delivered) return;
    setState(
      () => _orders = _orders
          .map(
            (current) => current.id == order.id
                ? current.copyWith(status: order.status.next)
                : current,
          )
          .toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.id}: ${order.status.next.label}')),
    );
  }

  Future<void> _showNotifications() async {
    setState(() => _hasUnreadNotifications = false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notificaciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.warning_amber_rounded),
                title: Text('2 productos tienen stock bajo.'),
              ),
              ListTile(
                leading: Icon(Icons.receipt_long),
                title: Text('Hay pedidos pendientes de atención.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProduct([DashboardMenuItem? product]) async {
    final name = TextEditingController(text: product?.name ?? '');
    final category = TextEditingController(text: product?.category ?? '');
    final price = TextEditingController(
      text: product?.price.toStringAsFixed(2) ?? '',
    );
    final stock = TextEditingController(text: product?.stock.toString() ?? '');
    String? imagePath = product?.imagePath;
    Uint8List? imageBytes;
    String? imageFileName;
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<DashboardMenuItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          title: Text(product == null ? 'Nuevo producto' : 'Editar producto'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Precio'),
                    validator: _decimal,
                  ),
                  TextFormField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    validator: _integer,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          final path = picked?.files.single.path;
                          final file = picked?.files.single;
                          if (file != null) {
                            dialogSetState(() {
                              imagePath = path;
                              imageBytes = file.bytes;
                              imageFileName = file.name;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Elegir foto'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          imagePath == null ? 'Sin foto' : 'Foto seleccionada',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final id =
                    product?.id ??
                    'product-${DateTime.now().millisecondsSinceEpoch}';
                Navigator.pop(
                  context,
                  DashboardMenuItem(
                    id: id,
                    name: name.text.trim(),
                    category: category.text.trim(),
                    price: double.parse(price.text.replaceAll(',', '.')),
                    stock: int.parse(stock.text),
                    imagePath: imagePath,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    category.dispose();
    price.dispose();
    stock.dispose();
    if (result == null) return;
    final uploadedImagePath = imageBytes != null
        ? await widget.productRepository.uploadProductImageBytes(
            imageBytes!,
            imageFileName ?? 'product.jpg',
            result.id,
          )
        : result.imagePath == null || result.imagePath!.startsWith('http')
        ? null
        : await widget.productRepository.uploadProductImage(
            result.imagePath!,
            result.id,
          );
    final savedImagePath =
        uploadedImagePath ??
        (result.imagePath != null && result.imagePath!.startsWith('http')
            ? result.imagePath
            : null);
    final categoryValue = _categoryFromLabel(result.category);
    widget.productRepository.saveProduct(
      Product(
        id: result.id,
        name: result.name,
        category: categoryValue,
        price: result.price,
        icon: categoryValue.icon,
        accentColor: AppTheme.accent,
        imagePath: savedImagePath,
      ),
    );
    setState(
      () => _menu = product == null
          ? [..._menu, result.copyWith(imagePath: savedImagePath)]
          : _menu
                .map(
                  (item) => item.name == product.name
                      ? result.copyWith(imagePath: savedImagePath)
                      : item,
                )
                .toList(),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  static String? _decimal(String? value) =>
      value == null || double.tryParse(value.replaceAll(',', '.')) == null
      ? 'Escribe un precio válido'
      : null;
  static String? _integer(String? value) =>
      value == null || int.tryParse(value) == null
      ? 'Escribe un stock válido'
      : null;

  static ProductCategory _categoryFromLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'burritos' => ProductCategory.burritos,
      'tacos' => ProductCategory.tacos,
      'bowls' => ProductCategory.bowls,
      'sides' => ProductCategory.sides,
      'drinks' => ProductCategory.drinks,
      _ => ProductCategory.bowls,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab,
          children: [
            _DashboardTab(
              user: widget.user,
              metrics: _metrics,
              orders: _orders,
              menu: _menu,
              hasUnread: _hasUnreadNotifications,
              onNotifications: _showNotifications,
              onAdvance: _advanceOrder,
              onOpenOrders: () => setState(() => _selectedTab = 1),
              onOpenInventory: () => setState(() => _selectedTab = 2),
              onLogout: widget.onLogout,
            ),
            _OrdersTab(
              orders: _filteredOrders,
              selectedFilter: _orderFilter,
              onFilterChanged: (filter) =>
                  setState(() => _orderFilter = filter),
              onAdvance: _advanceOrder,
            ),
            _InventoryTab(
              items: _filteredMenu,
              query: _menuQuery,
              onQueryChanged: (query) => setState(() => _menuQuery = query),
              onAdd: () => _editProduct(),
              onEdit: _editProduct,
            ),
            _ProfileTab(user: widget.user),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.accent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.user,
    required this.metrics,
    required this.orders,
    required this.menu,
    required this.hasUnread,
    required this.onNotifications,
    required this.onAdvance,
    required this.onOpenOrders,
    required this.onOpenInventory,
    this.onLogout,
  });
  final AuthUser user;
  final List<DashboardMetric> metrics;
  final List<DashboardOrder> orders;
  final List<DashboardMenuItem> menu;
  final bool hasUnread;
  final VoidCallback onNotifications;
  final ValueChanged<DashboardOrder> onAdvance;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenInventory;
  final void Function(BuildContext)? onLogout;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LogoBadge(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Restaurant Fast',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF3B2115),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _HeaderAction(
                icon: hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                onPressed: onNotifications,
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: Icons.logout_rounded,
                onPressed: () {
                  if (onLogout != null) {
                    onLogout!(context);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Bienvenido, ${user.fullName}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF2D1A10),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Resumen del restaurante y gestión operativa.',
            style: TextStyle(color: AppTheme.mutedText),
          ),
          const SizedBox(height: 22),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 155,
            ),
            itemBuilder: (context, index) =>
                _MetricCard(metric: metrics[index]),
          ),
          const SizedBox(height: 26),
          _SectionHeader(
            title: 'Pedidos recientes',
            action: 'Ver todo',
            onPressed: onOpenOrders,
          ),
          const SizedBox(height: 12),
          ...orders
              .take(3)
              .map(
                (order) =>
                    _OrderCard(order: order, onAdvance: () => onAdvance(order)),
              ),
          const SizedBox(height: 14),
          _SectionHeader(
            title: 'Inventario rápido',
            action: 'Editar',
            onPressed: onOpenInventory,
          ),
          const SizedBox(height: 12),
          ...menu.take(4).map((item) => _InventoryItem(item: item)),
        ],
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.orders,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onAdvance,
  });
  final List<DashboardOrder> orders;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<DashboardOrder> onAdvance;
  @override
  Widget build(BuildContext context) {
    const filters = ['Todos', 'Pendientes', 'Preparando', 'Listos'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
      children: [
        const _PageTitle(
          title: 'Pedidos',
          subtitle: 'Supervisa y actualiza cada pedido.',
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selectedFilter == filter,
                      onSelected: (_) => onFilterChanged(filter),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        if (orders.isEmpty)
          const _EmptyState(message: 'No hay pedidos en este estado.')
        else
          ...orders.map(
            (order) =>
                _OrderCard(order: order, onAdvance: () => onAdvance(order)),
          ),
      ],
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({
    required this.items,
    required this.query,
    required this.onQueryChanged,
    required this.onAdd,
    required this.onEdit,
  });
  final List<DashboardMenuItem> items;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAdd;
  final ValueChanged<DashboardMenuItem> onEdit;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: _PageTitle(
                title: 'Inventario',
                subtitle: 'Administra productos, precios y existencias.',
              ),
            ),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_box_rounded),
              tooltip: 'Agregar producto',
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar producto o categoría',
          ),
        ),
        const SizedBox(height: 18),
        ...items.map(
          (item) => _InventoryItem(item: item, onEdit: () => onEdit(item)),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});
  final AuthUser user;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const _PageTitle(
          title: 'Perfil del administrador',
          subtitle: 'Información de la cuenta y del negocio.',
        ),
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 38,
          backgroundColor: AppTheme.accent,
          child: Text(
            user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user.fullName,
            style: const TextStyle(
              color: Color(0xFF2D1A10),
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            user.email,
            style: const TextStyle(color: AppTheme.mutedText),
          ),
        ),
        const SizedBox(height: 28),
        _ProfileInfo(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Rol',
          value: user.role.label,
        ),
        _ProfileInfo(
          icon: Icons.storefront_outlined,
          title: 'Restaurante',
          value: 'Restaurant Fast',
        ),
        _ProfileInfo(
          icon: Icons.security_outlined,
          title: 'Permisos',
          value: 'Gestión completa',
        ),
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFF2D1A10),
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppTheme.mutedText)),
    ],
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onPressed,
  });
  final String title;
  final String action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2D1A10),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      TextButton(onPressed: onPressed, child: Text(action)),
    ],
  );
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: const BoxDecoration(
      color: AppTheme.accent,
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.restaurant_menu, color: Colors.white),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF563524)),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final DashboardMetric metric;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: metric.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(metric.icon, size: 20, color: metric.color),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            metric.value,
            style: const TextStyle(
              color: Color(0xFF2D1A10),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF5A4031),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAdvance});
  final DashboardOrder order;
  final VoidCallback onAdvance;
  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      OrderStatus.pending => const Color(0xFFE8A93D),
      OrderStatus.preparing => const Color(0xFFF28C28),
      OrderStatus.ready => const Color(0xFF7CCB9A),
      OrderStatus.delivered => const Color(0xFF4B8DFF),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.customer} • ${order.id}',
                  style: const TextStyle(
                    color: Color(0xFF2D1A10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  order.items,
                  style: const TextStyle(color: AppTheme.mutedText),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hora: ${order.time} • Total: £${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF5A4031),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (order.status != OrderStatus.delivered)
                FilledButton(
                  onPressed: onAdvance,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    order.status == OrderStatus.ready ? 'Entregar' : 'Avanzar',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  const _InventoryItem({required this.item, this.onEdit});
  final DashboardMenuItem item;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final isLowStock = item.stock <= 7;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Color(0xFF2D1A10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} • £${item.price.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Stock: ${item.stock}',
                style: TextStyle(
                  color: isLowStock
                      ? const Color(0xFFD97706)
                      : const Color(0xFF1E7A52),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              onEdit == null
                  ? Text(
                      isLowStock ? 'Reponer pronto' : 'Normal',
                      style: TextStyle(
                        color: isLowStock
                            ? const Color(0xFFD97706)
                            : const Color(0xFF1E7A52),
                        fontSize: 12,
                      ),
                    )
                  : TextButton(onPressed: onEdit, child: const Text('Editar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppTheme.accent),
    title: Text(title, style: const TextStyle(color: AppTheme.mutedText)),
    subtitle: Text(
      value,
      style: const TextStyle(
        color: Color(0xFF2D1A10),
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 64),
    child: Center(
      child: Text(message, style: const TextStyle(color: AppTheme.mutedText)),
    ),
  );
}
