import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/administrator/data/repositories/administrator_repository_impl.dart';
import 'package:restaurantapp/features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/auth/domain/repositories/auth_repository.dart';
import 'package:restaurantapp/features/auth/domain/usecases/register_user.dart';
import 'package:restaurantapp/features/auth/domain/usecases/sign_in.dart';
import 'package:restaurantapp/features/auth/presentation/pages/login_page.dart';
import 'package:restaurantapp/features/auth/presentation/pages/register_page.dart';
import 'package:restaurantapp/features/customer/data/repositories/product_repository_impl.dart';
import 'package:restaurantapp/features/customer/domain/usecases/get_products.dart';

class _TestAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> register({
    required String fullName,
    required String email,
    required String password,
    required AuthRole role,
  }) async {
    return AuthUser(fullName: fullName, email: email, role: role);
  }

  @override
  Future<AuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    return null;
  }
}

void main() {
  testWidgets(
    'la pantalla de acceso abre el registro con el diseño compartido',
    (tester) async {
      final authRepository = _TestAuthRepository();
      final productRepository = ProductRepositoryImpl();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LoginPage(
            signIn: SignIn(authRepository),
            registerUser: RegisterUser(authRepository),
            getProducts: GetProducts(productRepository),
            getAdministratorDashboard: GetAdministratorDashboard(
              AdministratorRepositoryImpl(productRepository),
            ),
            productRepository: productRepository,
          ),
        ),
      );

      expect(find.text('Restaurant Fast'), findsOneWidget);
      expect(find.text('ENTRAR'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final registerLink = find.text('Crea cuenta');
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await tester.pumpAndSettle();

      expect(find.text('NOMBRE COMPLETO'), findsOneWidget);
      expect(find.text('CREAR CUENTA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el registro mide la contraseña y exige ocho caracteres', (
    tester,
  ) async {
    final repository = _TestAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: RegisterPage(registerUser: RegisterUser(repository)),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), 'abcdefgh');
    await tester.pump();
    expect(find.text('Muy débil'), findsOneWidget);

    await tester.enterText(fields.at(2), 'Abcdef1!');
    await tester.pump();
    expect(find.text('¡Fuerte!'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Ana López');
    await tester.enterText(fields.at(1), 'ana@example.com');
    await tester.enterText(fields.at(2), 'Abcdef1');
    await tester.ensureVisible(find.text('CREAR CUENTA'));
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pump();

    expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
