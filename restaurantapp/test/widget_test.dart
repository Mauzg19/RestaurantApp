import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurantapp/core/theme/app_theme.dart';
import 'package:restaurantapp/features/administrator/data/repositories/administrator_repository_impl.dart';
import 'package:restaurantapp/features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'package:restaurantapp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:restaurantapp/features/auth/domain/entities/auth_user.dart';
import 'package:restaurantapp/features/auth/domain/usecases/register_user.dart';
import 'package:restaurantapp/features/auth/domain/usecases/sign_in.dart';
import 'package:restaurantapp/features/auth/presentation/pages/login_page.dart';
import 'package:restaurantapp/features/auth/presentation/pages/register_page.dart';
import 'package:restaurantapp/features/customer/data/repositories/product_repository_impl.dart';
import 'package:restaurantapp/features/customer/domain/usecases/get_products.dart';

void main() {
  final repository = AuthRepositoryImpl();
  final signIn = SignIn(repository);
  final registerUser = RegisterUser(repository);
  final getProducts = GetProducts(ProductRepositoryImpl());
  final productRepository = ProductRepositoryImpl();
  final getAdministratorDashboard = GetAdministratorDashboard(
    AdministratorRepositoryImpl(productRepository),
  );

  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.dark,
      home: LoginPage(
        signIn: signIn,
        registerUser: registerUser,
        getProducts: getProducts,
        getAdministratorDashboard: getAdministratorDashboard,
        productRepository: productRepository,
      ),
    );
  }

  testWidgets('muestra el formulario de inicio de sesión', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });

  testWidgets('valida los campos obligatorios antes de enviar', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('INICIAR SESIÓN'));
    await tester.pump();

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(find.text('Usa al menos 6 caracteres'), findsOneWidget);
  });

  testWidgets('muestra el formulario de registro solo para clientes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: RegisterPage(registerUser: registerUser),
      ),
    );

    expect(find.text('Crear una cuenta'), findsOneWidget);
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Administrador'), findsNothing);
  });

  test(
    'registra un cliente y permite iniciar sesión con sus credenciales',
    () async {
      final repository = AuthRepositoryImpl();
      final register = RegisterUser(repository);
      final signIn = SignIn(repository);

      await register(
        fullName: 'Ana Perez',
        email: 'ana@example.com',
        password: 'secreto123',
        role: AuthRole.customer,
      );
      final user = await signIn(
        email: 'ana@example.com',
        password: 'secreto123',
      );

      expect(user?.fullName, 'Ana Perez');
      expect(user?.role, AuthRole.customer);
    },
  );
}
