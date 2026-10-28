import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../customer/domain/entities/product.dart';
import '../../../customer/domain/repositories/order_repository.dart';
import '../../../customer/domain/repositories/product_repository.dart';
import '../../domain/entities/administrator_dashboard.dart';
import '../../domain/usecases/get_administrator_dashboard.dart';

class AdministratorHomePage extends StatefulWidget {
  const AdministratorHomePage({
    super.key,
    required this.user,
    required this.getDashboard,
    required this.productRepository,
    this.orderRepository,
    this.onLogout,
  });

  final AuthUser user;
  final GetAdministratorDashboard getDashboard;
  final ProductRepository productRepository;
  final OrderRepository? orderRepository;
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

  Future<void> _advanceOrder(DashboardOrder order) async {
    if (order.status == OrderStatus.delivered) return;

    final nextStatus = order.status.next;
    if (widget.orderRepository != null) {
      try {
        await widget.orderRepository!.updateOrderStatus(
          order.id.replaceFirst('#', ''),
          _statusValue(nextStatus),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar el pedido: $error'),
            backgroundColor: const Color(0xFFB3261E),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(
      () => _orders = _orders
          .map(
            (current) => current.id == order.id
                ? current.copyWith(status: nextStatus)
                : current,
          )
          .toList(),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${order.id}: ${nextStatus.label}')));
  }

  Future<void> _selectTab(int index) async {
    if (index == 1 && widget.orderRepository != null) {
      try {
        await widget.orderRepository!.load();
        if (!mounted) return;
        final dashboard = widget.getDashboard();
        setState(() => _orders = [...dashboard.orders]);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los pedidos: $error'),
            backgroundColor: const Color(0xFFB3261E),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() => _selectedTab = index);
  }

  String _statusValue(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.delivered:
        return 'delivered';
    }
  }

  Future<void> _updateAvailability(DashboardMenuItem item, bool value) async {
    try {
      await widget.productRepository.updateProductAvailability(item.id, value);
      if (!mounted) return;
      setState(() {
        _menu = _menu
            .map(
              (current) => current.id == item.id
                  ? current.copyWith(isAvailable: value)
                  : current,
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la disponibilidad: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  Future<void> _deleteProduct(DashboardMenuItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Eliminar producto'),
        content: Text('¿Estás seguro de que deseas eliminar "${item.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.productRepository.deleteProduct(item.id);
      if (!mounted) return;
      setState(() {
        _menu = _menu.where((current) => current.id != item.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Producto "${item.name}" eliminado con éxito')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar el producto: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
    }
  }

  Future<void> _showNotifications() async {
    setState(() => _hasUnreadNotifications = false);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificaciones',
                      style: AppTheme.serif(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.offBlack,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.periwinkle,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      'OPERACIÓN',
                      style: AppTheme.mono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.lakeBlue,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _NotificationTile(
                icon: Icons.warning_amber_rounded,
                iconColor: AppTheme.coral,
                title: '2 productos tienen stock bajo.',
                time: 'Hace 5m',
              ),
              const SizedBox(height: 10),
              _NotificationTile(
                icon: Icons.receipt_long,
                iconColor: AppTheme.lakeBlue,
                title: 'Hay pedidos pendientes de atención.',
                time: 'Hace 12m',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProduct([DashboardMenuItem? product]) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Cargando categorías...'),
        duration: Duration(seconds: 30),
      ),
    );
    late final List<ProductCategoryOption> categories;
    try {
      categories = await widget.productRepository.getCategories();
    } catch (error) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudieron cargar las categorías: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }
    messenger.hideCurrentSnackBar();
    if (!mounted) return;

    final name = TextEditingController(text: product?.name ?? '');
    ProductCategoryOption? selectedCategory;
    for (final category in categories) {
      if (category.name.toLowerCase() == product?.category.toLowerCase()) {
        selectedCategory = category;
        break;
      }
    }
    final price = TextEditingController(
      text: product?.price.round().toString() ?? '',
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.ash, width: 1),
          ),
          title: Text(
            product == null ? 'Nuevo producto' : 'Editar producto',
            style: AppTheme.serif(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.offBlack,
            ),
          ),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ProductCategoryOption>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      hintText: 'Selecciona una categoría',
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category.name),
                          ),
                        )
                        .toList(),
                    onChanged: (category) {
                      dialogSetState(() => selectedCategory = category);
                    },
                    validator: (category) => category == null
                        ? 'Selecciona una categoría existente'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio en COP (sin separadores)',
                    ),
                    validator: _currencyAmount,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    validator: _integer,
                  ),
                  const SizedBox(height: 16),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.offBlack,
                          side: const BorderSide(color: AppTheme.ash, width: 1),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Elegir foto'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          imagePath == null ? 'Sin foto' : 'Foto seleccionada',
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.mono(
                            fontSize: 12,
                            color: imagePath == null
                                ? AppTheme.smoke
                                : AppTheme.lakeBlue,
                          ),
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
              style: TextButton.styleFrom(foregroundColor: AppTheme.graphite),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final category = selectedCategory!;
                final id =
                    product?.id ??
                    'product-${DateTime.now().millisecondsSinceEpoch}';
                Navigator.pop(
                  context,
                  DashboardMenuItem(
                    id: id,
                    name: name.text.trim(),
                    category: category.name,
                    price: double.parse(price.text.replaceAll(',', '.')),
                    stock: int.parse(stock.text),
                    isAvailable: product?.isAvailable ?? true,
                    imagePath: imagePath,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.lakeBlue,
                shape: const StadiumBorder(),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    price.dispose();
    stock.dispose();
    if (result == null) return;

    String? savedImagePath;
    try {
      if (imageBytes != null) {
        savedImagePath = await widget.productRepository.uploadProductImageBytes(
          imageBytes!,
          imageFileName ?? 'product.jpg',
          result.id,
        );
      } else if (result.imagePath != null &&
          !result.imagePath!.startsWith('http')) {
        savedImagePath = await widget.productRepository.uploadProductImage(
          result.imagePath!,
          result.id,
        );
      } else {
        savedImagePath = result.imagePath;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo subir la imagen: $e'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    final categoryValue = _categoryFromLabel(result.category);
    final categoryOption = categories.firstWhere(
      (category) => category.name == result.category,
    );

    try {
      await widget.productRepository.saveProduct(
        Product(
          id: result.id,
          name: result.name,
          category: categoryValue,
          categoryName: result.category,
          price: result.price,
          icon: categoryValue.icon,
          accentColor: AppTheme.accent,
          isAvailable: result.isAvailable,
          imagePath: savedImagePath,
        ),
        category: categoryOption,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar el producto: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

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

  static String? _integer(String? value) =>
      value == null || int.tryParse(value) == null
      ? 'Escribe un stock válido'
      : null;

  static String? _currencyAmount(String? value) =>
      value == null || int.tryParse(value.trim()) == null
      ? 'Escribe un importe entero en COP'
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
      backgroundColor: AppTheme.parchment,
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
              onAvailabilityChanged: _updateAvailability,
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
              onDelete: _deleteProduct,
              onAvailabilityChanged: _updateAvailability,
            ),
            const SizedBox.expand(),
            _ProfileTab(
              user: widget.user,
              onLogout: widget.onLogout != null
                  ? () => widget.onLogout!(context)
                  : null,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.ash, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTab,
          onDestinationSelected: _selectTab,
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.periwinkle,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 64,
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
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'Predicción IA',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
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
    required this.onAvailabilityChanged,
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
  final void Function(DashboardMenuItem, bool) onAvailabilityChanged;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenInventory;
  final void Function(BuildContext)? onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Brand & Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.parchment,
            border: Border(bottom: BorderSide(color: AppTheme.ash, width: 1)),
          ),
          child: Row(
            children: [
              const _LogoBadge(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Restaurant Fast',
                      style: AppTheme.serif(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.offBlack,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'PANEL DE CONTROL',
                      style: AppTheme.mono(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.smoke,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _HeaderAction(
                icon: hasUnread
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                hasBadge: hasUnread,
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
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome
                Text(
                  'Bienvenido, ${user.fullName}',
                  style: AppTheme.serif(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.offBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Resumen operativo del negocio.',
                  style: AppTheme.mono(fontSize: 12, color: AppTheme.graphite),
                ),
                const SizedBox(height: 14),

                // Compact Monad Metrics Grid (2x2)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: metrics.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 72,
                  ),
                  itemBuilder: (context, index) =>
                      _MetricCard(metric: metrics[index]),
                ),
                const SizedBox(height: 20),

                // Recent Orders Section
                _SectionHeader(
                  title: 'Pedidos recientes',
                  action: 'Ver todo',
                  onPressed: onOpenOrders,
                ),
                const SizedBox(height: 10),
                if (orders.isEmpty)
                  const _EmptyState(
                    message: 'No hay pedidos activos registrados.',
                  )
                else
                  ...orders
                      .take(2)
                      .map(
                        (order) => _OrderCard(
                          order: order,
                          onAdvance: () => onAdvance(order),
                        ),
                      ),
                const SizedBox(height: 20),

                // Quick Inventory Section
                _SectionHeader(
                  title: 'Inventario rápido',
                  action: 'Gestionar',
                  onPressed: onOpenInventory,
                ),
                const SizedBox(height: 10),
                if (menu.isEmpty)
                  const _EmptyState(message: 'No hay productos en inventario.')
                else
                  ...menu
                      .take(4)
                      .map(
                        (item) => _InventoryItem(
                          item: item,
                          onAvailabilityChanged: (value) =>
                              onAvailabilityChanged(item, value),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const _PageTitle(
          title: 'Pedidos',
          subtitle: 'Supervisa y actualiza cada pedido.',
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 12,
                          fontWeight: selectedFilter == filter
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selectedFilter == filter
                              ? Colors.white
                              : AppTheme.offBlack,
                        ),
                      ),
                      selected: selectedFilter == filter,
                      selectedColor: AppTheme.lakeBlue,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selectedFilter == filter
                            ? AppTheme.lakeBlue
                            : AppTheme.ash,
                        width: 1,
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      onSelected: (_) => onFilterChanged(filter),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
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
    required this.onDelete,
    required this.onAvailabilityChanged,
  });

  final List<DashboardMenuItem> items;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAdd;
  final ValueChanged<DashboardMenuItem> onEdit;
  final ValueChanged<DashboardMenuItem> onDelete;
  final void Function(DashboardMenuItem, bool) onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
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
              icon: const Icon(
                Icons.add_box_rounded,
                color: AppTheme.lakeBlue,
                size: 26,
              ),
              tooltip: 'Agregar producto',
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: onQueryChanged,
          style: AppTheme.mono(fontSize: 13, color: AppTheme.offBlack),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppTheme.smoke,
            ),
            hintText: 'Buscar producto o categoría',
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTag),
              borderSide: const BorderSide(color: AppTheme.ash, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTag),
              borderSide: const BorderSide(color: AppTheme.ash, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusTag),
              borderSide: const BorderSide(
                color: AppTheme.lakeBlue,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const _EmptyState(
            message: 'No se encontraron productos coincidentes.',
          )
        else
          ...items.map(
            (item) => _InventoryItem(
              item: item,
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
              onAvailabilityChanged: (value) =>
                  onAvailabilityChanged(item, value),
            ),
          ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user, this.onLogout});

  final AuthUser user;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const _PageTitle(
          title: 'Perfil del administrador',
          subtitle: 'Información de la cuenta y del negocio.',
        ),
        const SizedBox(height: 22),
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.ash, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.lakeBlue,
              child: Text(
                user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTheme.serifFont,
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            user.fullName,
            style: AppTheme.serif(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppTheme.offBlack,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Center(
          child: Text(
            user.email,
            style: AppTheme.mono(fontSize: 12, color: AppTheme.smoke),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.periwinkle,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppTheme.ash, width: 1),
            ),
            child: Text(
              'ADMINISTRADOR • RESTAURANT FAST',
              style: AppTheme.mono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.lakeBlue,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.ash, width: 1),
          ),
          child: Column(
            children: [
              _ProfileInfo(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Rol',
                value: user.role.label,
              ),
              const Divider(height: 1, color: AppTheme.ash),
              const _ProfileInfo(
                icon: Icons.storefront_outlined,
                title: 'Restaurante',
                value: 'Restaurant Fast',
              ),
              const Divider(height: 1, color: AppTheme.ash),
              const _ProfileInfo(
                icon: Icons.security_outlined,
                title: 'Permisos',
                value: 'Gestión completa',
              ),
            ],
          ),
        ),
        if (onLogout != null) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E), width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const StadiumBorder(),
              textStyle: AppTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Cerrar sesión (Spring Boot)'),
          ),
        ],
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
        style: AppTheme.serif(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppTheme.offBlack,
        ),
      ),
      const SizedBox(height: 2),
      Text(subtitle, style: AppTheme.mono(fontSize: 12, color: AppTheme.smoke)),
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
          style: AppTheme.serif(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.offBlack,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action,
              style: AppTheme.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.lakeBlue,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 13,
              color: AppTheme.lakeBlue,
            ),
          ],
        ),
      ),
    ],
  );
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: AppTheme.lakeBlue,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.ash, width: 1),
    ),
    child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 18),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onPressed,
    this.hasBadge = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.ash, width: 1),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: AppTheme.offBlack, size: 17),
        ),
      ),
      if (hasBadge)
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.coral,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final DashboardMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.ash, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, size: 16, color: metric.color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    style: AppTheme.serif(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.offBlack,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.graphite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAdvance});

  final DashboardOrder order;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg) = switch (order.status) {
      OrderStatus.pending => (const Color(0xFFD97706), const Color(0xFFFEF3C7)),
      OrderStatus.preparing => (AppTheme.lakeBlue, const Color(0xFFEEF3FF)),
      OrderStatus.ready => (const Color(0xFF0E8345), const Color(0xFFE8FDF2)),
      OrderStatus.delivered => (AppTheme.smoke, AppTheme.parchment),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ash, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order ID, Customer name, and Status Tag
          Row(
            children: [
              Text(
                order.id,
                style: AppTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lakeBlue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.customer,
                  style: AppTheme.serif(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.offBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  order.status.label,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFont,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Items summary
          Text(
            order.items,
            style: AppTheme.mono(fontSize: 11, color: AppTheme.graphite),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Footer: Time, Total COP and Action Button
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 13,
                      color: AppTheme.smoke,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      order.time,
                      style: AppTheme.mono(fontSize: 11, color: AppTheme.smoke),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.payments_outlined,
                      size: 13,
                      color: AppTheme.smoke,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        formatCop(order.total),
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.offBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (order.status != OrderStatus.delivered) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: onAdvance,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.lakeBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                      textStyle: AppTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      order.status == OrderStatus.ready
                          ? 'Entregar'
                          : 'Avanzar',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  const _InventoryItem({
    required this.item,
    required this.onAvailabilityChanged,
    this.onEdit,
    this.onDelete,
  });

  final DashboardMenuItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final isLowStock = item.stock <= 7;
    final (stockColor, stockBg) = !item.isAvailable
        ? (const Color(0xFFB3261E), const Color(0xFFFEE2E2))
        : isLowStock
        ? (const Color(0xFFD97706), const Color(0xFFFEF3C7))
        : (const Color(0xFF1E7A52), const Color(0xFFE8FDF2));

    final stockLabel = !item.isAvailable
        ? 'Agotado'
        : isLowStock
        ? 'Reponer pronto'
        : 'Normal';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ash, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTheme.serif(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.offBlack,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFB3261E),
                        size: 20,
                      ),
                      tooltip: 'Eliminar producto',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.category} • ${formatCop(item.price)}',
                  style: AppTheme.mono(fontSize: 11, color: AppTheme.graphite),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Stock: ${item.stock}',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: stockColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: stockBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stockLabel,
                      style: TextStyle(
                        fontFamily: AppTheme.monoFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: stockColor,
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Editar',
                        style: AppTheme.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.lakeBlue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 6),
              Switch(
                value: item.isAvailable,
                activeThumbColor: AppTheme.lakeBlue,
                activeTrackColor: AppTheme.periwinkle,
                onChanged: onAvailabilityChanged,
              ),
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
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.ash, width: 1),
      ),
      child: Icon(icon, color: AppTheme.lakeBlue, size: 20),
    ),
    title: Text(
      title,
      style: AppTheme.mono(fontSize: 11, color: AppTheme.smoke),
    ),
    subtitle: Text(
      value,
      style: AppTheme.serif(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.offBlack,
      ),
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.parchment,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.ash, width: 1),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppTheme.mono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.offBlack,
            ),
          ),
        ),
        Text(time, style: AppTheme.mono(fontSize: 11, color: AppTheme.smoke)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.ash, width: 1),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: AppTheme.smoke,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTheme.mono(fontSize: 12, color: AppTheme.smoke),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
