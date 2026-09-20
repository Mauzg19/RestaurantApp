import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/user_settings_repository.dart';
import '../../domain/usecases/get_products.dart';
import 'customer_orders_page.dart';
import 'customer_details_page.dart';
import 'product_detail_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
    required this.user,
    required this.getProducts,
    this.orderRepository,
    this.settingsRepository,
    this.onLogout,
  });

  final AuthUser user;
  final GetProducts getProducts;
  final OrderRepository? orderRepository;
  final UserSettingsRepository? settingsRepository;
  final void Function(BuildContext)? onLogout;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  ProductCategory? _selectedCategory;
  final Map<String, int> _cart = {};
  String _searchQuery = '';

  List<Product> get _products => widget.getProducts();

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();

    return _products.where((product) {
      final matchesCategory =
          _selectedCategory == null || product.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.label.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  List<_CartLine> get _cartLines {
    return _cart.entries.map((entry) {
      final product = _products.firstWhere(
        (item) => item.id == entry.key,
        orElse: () => const Product(
          id: '',
          name: 'Producto',
          category: ProductCategory.bowls,
          price: 0,
          icon: Icons.fastfood,
          accentColor: Color(0xFFC95D32),
        ),
      );
      return _CartLine(product: product, quantity: entry.value);
    }).where((line) => line.product.id.isNotEmpty).toList();
  }

  int get cartCount =>
      _cart.values.fold<int>(0, (sum, quantity) => sum + quantity);

  double get cartTotal => _cartLines.fold(
    0.0,
    (sum, line) => sum + (line.product.price * line.quantity),
  );

  void _toggleCart(Product product) {
    setState(() {
      final current = _cart[product.id] ?? 0;
      _cart[product.id] = current + 1;
    });
  }

  void _openProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          onAddToCart: () => _toggleCart(product),
        ),
      ),
    );
  }

  void _removeFromCart(String productId, [BuildContext? context]) {
    final wasEmptyBefore = _cart.isEmpty;
    setState(() {
      if (!_cart.containsKey(productId)) return;
      final next = (_cart[productId] ?? 1) - 1;
      if (next <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = next;
      }
    });

    if ((context != null) && (_cart.isEmpty || wasEmptyBefore)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu carrito está vacío.')),
      );
      if (_cart.isEmpty) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _confirmOrder(BuildContext context) async {
    if (_cart.isEmpty || widget.orderRepository == null) {
      if (_cart.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu carrito está vacío.')),
        );
      }
      return;
    }

    if (widget.settingsRepository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de configuración de repositorio.')),
      );
      return;
    }

    final address = await widget.settingsRepository!.getDeliveryAddress(widget.user.email);
    final payment = await widget.settingsRepository!.getPaymentMethod(widget.user.email);

    if (address == null || payment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa tus datos de entrega y pago en tu perfil.'),
          backgroundColor: Color(0xFFB76A1A),
        ),
      );
      _goToDetails();
      return;
    }

    final order = CustomerOrder(
      customerName: widget.user.fullName,
      customerEmail: widget.user.email,
      items: _cartLines
          .map(
            (line) => CustomerOrderItem(
              productId: line.product.id,
              name: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.price,
            ),
          )
          .toList(),
      deliveryAddress: address,
      paymentMethod: payment,
    );

    try {
      await widget.orderRepository!.saveOrder(order);
      // Forzamos la recarga de pedidos para que se vean reflejados inmediatamente
      await widget.orderRepository!.load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el pedido: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _cart.clear());
    Navigator.pop(this.context);
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text('Pedido confirmado.')),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _openCartSheet(BuildContext context) {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu carrito está vacío.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tu pedido',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF3B2115),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$cartCount ${cartCount == 1 ? 'artículo' : 'artículos'}',
                      style: const TextStyle(color: Color(0xFF563524)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _cartLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _removeFromCart(line.product.id, context),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppTheme.accent,
                                ),
                                tooltip: 'Quitar producto',
                              ),
                              Expanded(
                                child: Text(
                                  '${line.quantity}× ${line.product.name}',
                                  style: const TextStyle(
                                    color: Color(0xFF3B2115),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '£${(line.product.price * line.quantity).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          color: Color(0xFF563524),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '£${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF3B2115),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _confirmOrder(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirmar pedido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToProfile() => setState(() => _selectedTab = 3);

  Future<void> _selectTab(int index) async {
    if (index == 2 && widget.orderRepository != null) {
      try {
        await widget.orderRepository!.load();
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

  void _goToDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailsPage(
          user: widget.user,
          settingsRepository: widget.settingsRepository!,
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    if (widget.onLogout != null) {
      widget.onLogout!(context);
      return;
    }

    Navigator.of(context).pop();
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBDCCE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Notificaciones',
                style: TextStyle(
                  color: Color(0xFF3B2115),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: AppTheme.accent.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No tienes notificaciones nuevas',
                      style: TextStyle(
                        color: Color(0xFF937A6B),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab,
          children: [
            _HomeContent(
              user: widget.user,
              searchController: _searchController,
              selectedCategory: _selectedCategory,
              onCategoryChanged: (category) =>
                  setState(() => _selectedCategory = category),
              onSearchChanged: _onSearchChanged,
              products: _filteredProducts,
              cartCount: cartCount,
              onAddToCart: _toggleCart,
              onProductTap: _openProductDetail,
              onOpenCart: () => _openCartSheet(context),
              onProfileTap: _goToProfile,
              onNotificationsTap: () => _showNotificationsSheet(context),
            ),
            _MenuTab(
              searchController: _searchController,
              products: _filteredProducts,
              selectedCategory: _selectedCategory,
              onCategoryChanged: (category) =>
                  setState(() => _selectedCategory = category),
              onSearchChanged: _onSearchChanged,
              onAddToCart: _toggleCart,
              onProductTap: _openProductDetail,
              onOpenCart: () => _openCartSheet(context),
              cartCount: cartCount,
            ),
            CustomerOrdersPage(
              user: widget.user,
              orderRepository: widget.orderRepository ?? OrderRepositoryImpl(),
            ),
            _SimpleTab(
              title: 'Recompensas',
              icon: Icons.star_border_rounded,
            ),
            _ProfileTab(
              user: widget.user,
              onLogout: _handleLogout,
              onDetailsTap: _goToDetails,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: _selectTab,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.accent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Menú',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star),
            label: 'Premios',
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

class _CartLine {
  const _CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.searchController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.products,
    required this.cartCount,
    required this.onAddToCart,
    required this.onProductTap,
    required this.onOpenCart,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final AuthUser user;
  final TextEditingController searchController;
  final ProductCategory? selectedCategory;
  final ValueChanged<ProductCategory?> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final List<Product> products;
  final int cartCount;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onProductTap;
  final VoidCallback onOpenCart;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LogoMark(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Restaurant Fast',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF3B2115),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  _HeaderIcon(
                    icon: Icons.shopping_cart_outlined,
                    onPressed: onOpenCart,
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              _HeaderIcon(icon: Icons.person_outline_rounded, onPressed: onProfileTap),
              const SizedBox(width: 8),
              _HeaderIcon(
                icon: Icons.notifications_none_rounded,
                onPressed: onNotificationsTap,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SearchBar(controller: searchController, onChanged: onSearchChanged),
          const SizedBox(height: 18),
          _WelcomeText(name: user.fullName),
          const SizedBox(height: 16),
          _HeroCarousel(products: products, onAddToCart: onAddToCart),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Categorías', action: 'Ver todas'),
          const SizedBox(height: 12),
          _CategoryRow(
            selectedCategory: selectedCategory,
            onCategoryChanged: onCategoryChanged,
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Favoritos populares', action: 'Ver todo'),
          const SizedBox(height: 12),
          _ProductRow(
            products: products,
            onAddToCart: onAddToCart,
            onProductTap: onProductTap,
          ),
          const SizedBox(height: 24),
          const _RewardsBanner(),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: const BoxDecoration(
      color: AppTheme.accent,
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.restaurant_menu, color: Colors.white),
  );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF563524), size: 21),
      tooltip: 'Abrir',
    ),
  );
}


class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEBDCCE)),
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: '¿Qué se te antoja hoy?',
        border: InputBorder.none,
        prefixIcon: Icon(Icons.search, color: Color(0xFF563524)),
      ),
    ),
  );
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Text(
    'Hola, ${name.split(' ').first} 👋',
    style: const TextStyle(
      color: Color(0xFF3B2115),
      fontSize: 23,
      fontWeight: FontWeight.bold,
    ),
  );
}

// ── Hero Carousel ──────────────────────────────────────────────────────────────

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({
    required this.products,
    required this.onAddToCart,
  });

  final List<Product> products;
  final ValueChanged<Product> onAddToCart;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.products.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.products.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didUpdateWidget(_HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFC95D32),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: Text(
            'No hay platillos disponibles',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.products.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final product = widget.products[index];
              return _HeroSlide(
                product: product,
                onAddToCart: () => widget.onAddToCart(product),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.products.length, (index) {
            final isActive = _currentPage == index;
            return GestureDetector(
              onTap: () => _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accent
                      : const Color(0xFFEBDCCE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Single product slide ───────────────────────────────────────────────────────

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({required this.product, required this.onAddToCart});

  final Product product;
  final VoidCallback onAddToCart;

  /// Darkens the product accent colour slightly for the circle background.
  Color get _circleColor =>
      Color.lerp(product.accentColor, Colors.black, 0.15) ??
      product.accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            product.accentColor,
            Color.lerp(product.accentColor, const Color(0xFF3B2115), 0.35)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: product.accentColor.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: text + button ──────────────────────────────
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.category.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Product name
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                // Price
                Text(
                  product.formattedPrice,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                // CTA button
                FilledButton(
                  onPressed: onAddToCart,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: product.accentColor,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Pedir ahora'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // ── Right: product visual in circle ─────────────────
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: _circleColor,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: _ProductVisual(product: product),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF3B2115),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      TextButton(
        onPressed: () {},
        child: Text(action, style: const TextStyle(color: AppTheme.accent)),
      ),
    ],
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final ProductCategory? selectedCategory;
  final ValueChanged<ProductCategory?> onCategoryChanged;

  static const categories = [
    (ProductCategory.burritos, 'Burritos', Icons.lunch_dining),
    (ProductCategory.tacos, 'Tacos', Icons.local_pizza),
    (ProductCategory.bowls, 'Bowls', Icons.rice_bowl),
    (ProductCategory.sides, 'Sides', Icons.fastfood),
    (ProductCategory.drinks, 'Drinks', Icons.local_drink),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 100,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 2),
          _CategoryChip(
            label: 'Todo',
            icon: Icons.all_inclusive,
            selected: selectedCategory == null,
            onTap: () => onCategoryChanged(null),
          ),
          const SizedBox(width: 16),
          ...categories.map((category) {
            final isSelected = selectedCategory == category.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _CategoryChip(
                label: category.$2,
                icon: category.$3,
                selected: isSelected,
                onTap: () => onCategoryChanged(isSelected ? null : category.$1),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEBDCCE)),
          ),
          child: Icon(icon, color: selected ? Colors.white : AppTheme.accent),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF563524), fontSize: 11),
        ),
      ],
    ),
  );
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.products, required this.onAddToCart, required this.onProductTap});

  final List<Product> products;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onProductTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBDCCE)),
        ),
        child: const Text(
          'No encontramos productos con ese criterio.',
          style: TextStyle(color: Color(0xFF563524)),
        ),
      );
    }

    return SizedBox(
      height: 285,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...products.map((product) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 152,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEBDCCE)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: InkWell(
                      onTap: () => onProductTap(product),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 104,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE5BF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _ProductVisual(product: product),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3B2115),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 6,
                          spacing: 6,
                          children: [
                            Text(
                              product.formattedPrice,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => onAddToCart(product),
                              icon: const Icon(Icons.add, size: 15),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                minimumSize: const Size(0, 30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              label: const Text('Añadir'),
                            ),
                          ],
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab({
    required this.searchController,
    required this.products,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onSearchChanged,
    required this.onAddToCart,
    required this.onProductTap,
    required this.onOpenCart,
    required this.cartCount,
  });

  final TextEditingController searchController;
  final List<Product> products;
  final ProductCategory? selectedCategory;
  final ValueChanged<ProductCategory?> onCategoryChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Product> onAddToCart;
  final ValueChanged<Product> onProductTap;
  final VoidCallback onOpenCart;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Menú',
                      style: TextStyle(
                        color: Color(0xFF3B2115),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      _HeaderIcon(
                        icon: Icons.shopping_cart_outlined,
                        onPressed: onOpenCart,
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SearchBar(controller: searchController, onChanged: onSearchChanged),
              const SizedBox(height: 18),
              _CategoryRow(
                selectedCategory: selectedCategory,
                onCategoryChanged: onCategoryChanged,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: products.isEmpty
                    ? const Center(
                        child: Text(
                          'No encontramos productos con ese criterio.',
                          style: TextStyle(color: Color(0xFF563524)),
                        ),
                      )
                    : GridView.builder(
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 185,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFEBDCCE),
                              ),
                            ),
                            child: InkWell(
                              onTap: () => onProductTap(product),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 74,
                                    color: const Color(0xFFFFE5BF),
                                    child: _ProductVisual(product: product),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF3B2115),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 4,
                                  spacing: 4,
                                  children: [
                                    Text(
                                      product.formattedPrice,
                                      style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => onAddToCart(product),
                                      icon: const Icon(Icons.add, size: 14),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        minimumSize: const Size(0, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      label: const Text('Añadir'),
                                    ),
                                  ],
                                ),
                              ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductVisual extends StatelessWidget {
  const _ProductVisual({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imagePath = product.imagePath;
    if (imagePath != null && imagePath.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imagePath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() =>
      Center(child: Icon(product.icon, size: 64, color: product.accentColor));
}

class _RewardsBanner extends StatelessWidget {
  const _RewardsBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE5BF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESTAURANT REWARDS',
                          style: TextStyle(
                            color: Color(0xFF563524),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gana puntos con cada pedido.',
                          style: TextStyle(
                            color: Color(0xFF937A6B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC95D32),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Unirme'),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESTAURANT REWARDS',
                    style: TextStyle(
                      color: Color(0xFF563524),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gana puntos con cada pedido.',
                    style: TextStyle(color: Color(0xFF937A6B), fontSize: 11),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC95D32),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Unirme'),
            ),
          ],
        );
      },
    ),
  );
}

class _SimpleTab extends StatelessWidget {
  const _SimpleTab({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: AppTheme.accent),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF3B2115),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
    required this.onLogout,
    required this.onDetailsTap,
  });

  final AuthUser user;
  final void Function(BuildContext) onLogout;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi cuenta',
            style: TextStyle(
              color: Color(0xFF3B2115),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBDCCE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: Color(0xFF3B2115),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Color(0xFF937A6B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cuenta',
            style: TextStyle(
              color: Color(0xFF563524),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.location_on_outlined, color: AppTheme.accent),
            title: const Text('Datos de entrega y pago'),
            subtitle: const Text('Gestionar dirección y método de pago'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onDetailsTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: Colors.white,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppTheme.accent),
            title: const Text('Cerrar sesión'),
            subtitle: const Text('Salir de la cuenta actual'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => onLogout(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: Colors.white,
          ),
        ],
      ),
    ),
  );
}
