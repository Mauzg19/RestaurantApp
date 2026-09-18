import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/administrator/data/repositories/administrator_repository_impl.dart';
import 'package:restaurantapp/features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'package:restaurantapp/features/administrator/presentation/pages/administrator_home_page.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/customer/data/repositories/order_repository_impl.dart';
import 'package:restaurantapp/features/customer/data/repositories/product_repository_impl.dart';
import 'package:restaurantapp/features/customer/domain/usecases/get_products.dart';
import 'package:restaurantapp/features/customer/presentation/pages/customer_home_page.dart';

void main() {
  const testSizes = [
    Size(320 * 2, 568 * 2), // Pantalla compacta (iPhone SE / similar)
    Size(360 * 2, 780 * 2), // Android estándar
    Size(390 * 2, 844 * 2), // iPhone estándar
    Size(412 * 2, 915 * 2), // Android grande
  ];

  for (final size in testSizes) {
    testWidgets(
      'no tiene overflow en AdministratorHomePage en tamaño ${size.width / 2}x${size.height / 2}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: AdministratorHomePage(
              user: const AuthUser(
                fullName: 'Admin Principal',
                email: 'admin@example.com',
                role: AuthRole.administrator,
              ),
              getDashboard: GetAdministratorDashboard(
                AdministratorRepositoryImpl(ProductRepositoryImpl()),
              ),
              productRepository: ProductRepositoryImpl(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Abrir notificaciones
        await tester.tap(find.byIcon(Icons.notifications_active_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Notificaciones'), findsOneWidget);
      },
    );

    testWidgets(
      'no tiene overflow en CustomerHomePage en tamaño ${size.width / 2}x${size.height / 2}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final getProducts = GetProducts(ProductRepositoryImpl());
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
              getProducts: getProducts,
              orderRepository: orderRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Comprobar inicio
        expect(find.text('Favoritos populares'), findsOneWidget);

        // Añadir varios productos al carrito con ensureVisible
        final addButtons = find.text('Añadir');
        for (int i = 0; i < addButtons.evaluate().length && i < 2; i++) {
          final btn = addButtons.at(i);
          await tester.ensureVisible(btn);
          await tester.pumpAndSettle();
          await tester.tap(btn);
          await tester.pumpAndSettle();
        }

        // Abrir el carrito
        final cartButton = find.byIcon(Icons.shopping_cart_outlined).first;
        await tester.ensureVisible(cartButton);
        await tester.pumpAndSettle();
        await tester.tap(cartButton);
        await tester.pumpAndSettle();
        expect(find.text('Tu pedido'), findsOneWidget);

        // Cerrar carrito tocando fuera o con Navigator.pop
        Navigator.of(tester.element(find.text('Tu pedido'))).pop();
        await tester.pumpAndSettle();

        // Cambiar al tab Menú
        final menuTab = find.byIcon(Icons.grid_view_outlined).last;
        await tester.tap(menuTab);
        await tester.pumpAndSettle();
        expect(find.text('Menú'), findsAtLeastNWidgets(1));
      },
    );
  }
}
