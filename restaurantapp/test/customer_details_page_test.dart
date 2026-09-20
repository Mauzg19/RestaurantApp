import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/customer/data/repositories/user_settings_repository_impl.dart';
import 'package:restaurantapp/features/customer/presentation/pages/customer_details_page.dart';

void main() {
  testWidgets('guarda la dirección y el método de pago', (tester) async {
    final repository = UserSettingsRepositoryImpl();
    const email = 'ana@example.com';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomerDetailsPage(
          user: const AuthUser(
            fullName: 'Ana López',
            email: email,
            role: AuthRole.customer,
          ),
          settingsRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Calle y Número'), 'Calle 1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Madrid');
    await tester.enterText(find.widgetWithText(TextFormField, 'Código Postal'), '28001');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tipo (Ej: Tarjeta, Efectivo)'),
      'Efectivo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Detalles (Ej: **** 1234)'),
      'Pago al recibir',
    );

    final saveButton = find.text('Guardar Información');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect((await repository.getDeliveryAddress(email))?.fullAddress, 'Calle 1, Madrid, 28001');
    expect((await repository.getPaymentMethod(email))?.type, 'Efectivo');
    expect(find.text('Datos de Entrega y Pago'), findsNothing);
  });
}
