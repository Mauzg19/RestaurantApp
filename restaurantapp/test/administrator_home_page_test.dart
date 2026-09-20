import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/administrator/data/repositories/administrator_repository_impl.dart';
import 'package:restaurantapp/features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'package:restaurantapp/features/administrator/presentation/pages/administrator_home_page.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/customer/data/repositories/order_repository_impl.dart';
import 'package:restaurantapp/features/customer/data/repositories/product_repository_impl.dart';
import 'package:restaurantapp/features/customer/domain/entities/order.dart';

void main() {
  testWidgets('el administrador puede marcar un producto como agotado', (
    tester,
  ) async {
    final productRepository = ProductRepositoryImpl();

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
            AdministratorRepositoryImpl(productRepository),
          ),
          productRepository: productRepository,
        ),
      ),
    );

    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();
    final availabilitySwitch = find.byType(Switch).first;
    await tester.ensureVisible(availabilitySwitch);
    await tester.tap(availabilitySwitch);
    await tester.pumpAndSettle();

    expect(productRepository.getProducts().first.isAvailable, isFalse);
    expect(find.text('Agotado'), findsAtLeastNWidgets(1));
  });

  Widget buildSubject() {
    return MaterialApp(
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
        onLogout: (context) {},
      ),
    );
  }

  testWidgets('muestra el dashboard y permite avanzar un pedido', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Bienvenido, Admin Principal'), findsOneWidget);
    expect(find.text('Pedidos recientes'), findsOneWidget);
    expect(find.text('Inventario rápido'), findsOneWidget);

    await tester.tap(find.text('Avanzar').first);
    await tester.pump();

    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('filtra pedidos y permite crear un producto en inventario', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Inventario'));
    await tester.pump();
    expect(find.text('Inventario'), findsAtLeastNWidgets(1));
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_box_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo producto'), findsOneWidget);

    final formFields = find.byType(TextFormField);
    await tester.enterText(formFields.at(0), 'Ensalada Fresh');
    await tester.enterText(formFields.at(1), 'Bowls');
    await tester.enterText(formFields.at(2), '7.50');
    await tester.enterText(formFields.at(3), '20');
    final saveButton = find.text('Guardar');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ensalada');
    await tester.pump();
    expect(find.text('Ensalada Fresh'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos'), findsAtLeastNWidgets(1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendientes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#1049'), findsOneWidget);
    expect(find.textContaining('#1048'), findsNothing);
  });

  testWidgets('muestra un pedido guardado en el repositorio del administrador', (
    tester,
  ) async {
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
          street: 'Calle Falsa 123',
          city: 'Ciudad Ejemplo',
          postalCode: '12345',
        ),
        paymentMethod: const PaymentMethod(
          type: 'Tarjeta',
          details: '**** 1234',
        ),
      ),
    );

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
            AdministratorRepositoryImpl(ProductRepositoryImpl(), orderRepository),
          ),
          productRepository: ProductRepositoryImpl(),
          orderRepository: orderRepository,
          onLogout: (context) {},
        ),
      ),
    );

    expect(find.textContaining('Ana López'), findsOneWidget);
    expect(find.textContaining('Bowl BBQ'), findsAtLeastNWidgets(1));

    await orderRepository.updateOrderStatus(
      orderRepository.getOrders().single.id,
      'delivered',
    );
    expect(orderRepository.getOrders().single.status, 'delivered');
  });
}
