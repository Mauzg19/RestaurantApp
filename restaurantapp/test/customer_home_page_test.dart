import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/customer/data/repositories/order_repository_impl.dart';
import 'package:restaurantapp/features/customer/data/repositories/product_repository_impl.dart';
import 'package:restaurantapp/features/customer/data/repositories/user_settings_repository_impl.dart';
import 'package:restaurantapp/features/customer/domain/entities/order.dart';
import 'package:restaurantapp/features/customer/domain/usecases/get_products.dart';
import 'package:restaurantapp/features/customer/presentation/pages/customer_home_page.dart';
import 'package:restaurantapp/features/customer/presentation/pages/customer_orders_page.dart';
import 'package:restaurantapp/features/customer/domain/entities/product.dart';

void main() {
  test('el repositorio local conserva la disponibilidad del producto', () async {
    final repository = ProductRepositoryImpl();
    final product = repository.getProducts().first;

    await repository.updateProductAvailability(product.id, false);

    expect(repository.getProducts().first.isAvailable, isFalse);
  });

  testWidgets('el cliente no muestra productos agotados', (tester) async {
    final repository = ProductRepositoryImpl();
    final product = repository.getProducts().first;
    await repository.updateProductAvailability(product.id, false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: GetProducts(repository),
        ),
      ),
    );

    expect(find.text(product.name), findsNothing);
  });

  testWidgets('el cliente puede buscar productos y añadirlos al carrito', (tester) async {
    final getProducts = GetProducts(ProductRepositoryImpl());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: getProducts,
        ),
      ),
    );

    expect(find.text('Restaurant Fast'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bowl');
    await tester.pumpAndSettle();

    expect(find.text('Bowl BBQ'), findsAtLeastNWidgets(1));

    final addButton = find.byIcon(Icons.add).first;
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pump();

    expect(find.text('1').first, findsOneWidget);
  });

  testWidgets('el cliente ve productos creados en el catálogo compartido', (tester) async {
    final repository = ProductRepositoryImpl();
    repository.saveProduct(
      const Product(
        id: 'new-menu-item',
        name: 'Ensalada Fresh',
        category: ProductCategory.bowls,
        price: 7.50,
        icon: Icons.rice_bowl,
        accentColor: Color(0xFFF28C28),
        imagePath: 'C:/restaurant-images/ensalada-fresh.jpg',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: GetProducts(repository),
        ),
      ),
    );

    expect(find.text('Ensalada Fresh'), findsOneWidget);
    expect(find.text('£7.50'), findsOneWidget);
  });

  testWidgets('el menú muestra productos reales y permite confirmar un pedido', (tester) async {
    final repository = ProductRepositoryImpl();
    final orderRepository = OrderRepositoryImpl();
    final settingsRepository = UserSettingsRepositoryImpl();
    await settingsRepository.saveDeliveryAddress(
      'ana@example.com',
      const Address(street: 'Calle 1', city: 'Madrid', postalCode: '28001'),
    );
    await settingsRepository.savePaymentMethod(
      'ana@example.com',
      const PaymentMethod(type: 'Efectivo', details: 'Pago al recibir'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: GetProducts(repository),
          orderRepository: orderRepository,
          settingsRepository: settingsRepository,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.grid_view_outlined).last);
    await tester.pumpAndSettle();

    expect(find.text('Burrito de pollo'), findsOneWidget);
    expect(find.byType(GridView), findsWidgets);

    await tester.tap(find.text('Añadir').first);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    await tester.tap(find.text('Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(orderRepository.getOrders(), isNotEmpty);
  });

  testWidgets('el cliente ve sus pedidos realizados', (tester) async {
    final orderRepository = OrderRepositoryImpl();
    await orderRepository.saveOrder(
      CustomerOrder(
        customerName: 'Ana López',
        customerEmail: 'ana@example.com',
        items: [
          CustomerOrderItem(
            productId: 'bowl-bbq',
            name: 'Bowl BBQ',
            quantity: 1,
            unitPrice: 8.25,
          ),
        ],
        deliveryAddress: const Address(
          street: 'Calle 1',
          city: 'Madrid',
          postalCode: '28001',
        ),
        paymentMethod: const PaymentMethod(
          type: 'Efectivo',
          details: 'Pago al recibir',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerOrdersPage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          orderRepository: orderRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedidos Activos'), findsOneWidget);
    expect(find.textContaining('Bowl BBQ'), findsOneWidget);
  });

  testWidgets('permite quitar un producto antes de confirmar el pedido', (
    tester,
  ) async {
    final repository = ProductRepositoryImpl();
    final orderRepository = OrderRepositoryImpl();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: GetProducts(repository),
          orderRepository: orderRepository,
        ),
      ),
    );

    final addButton = find.text('Añadir').first;
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final cartButton = find.byIcon(Icons.shopping_cart_outlined).first;
    await tester.ensureVisible(cartButton);
    await tester.tap(cartButton);
    await tester.pumpAndSettle();

    expect(find.text('1 artículo'), findsOneWidget);

    final removeButton = find.byIcon(Icons.remove_circle_outline).first;
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.text('Tu carrito está vacío.'), findsOneWidget);
  });

  testWidgets('el perfil del cliente muestra la opción de cerrar sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerHomePage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: 'ana@example.com',
            role: AuthRole.customer,
          ),
          getProducts: GetProducts(ProductRepositoryImpl()),
          onLogout: (context) {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();

    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}
