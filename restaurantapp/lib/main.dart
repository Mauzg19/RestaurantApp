import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/supabase_auth_repository.dart';
import 'features/auth/domain/usecases/register_user.dart';
import 'features/auth/domain/usecases/sign_in.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/administrator/data/repositories/administrator_repository_impl.dart';
import 'features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'features/customer/data/repositories/order_repository_impl.dart';
import 'features/customer/data/repositories/product_repository_impl.dart';
import 'features/customer/data/repositories/user_settings_repository_impl.dart';
import 'features/customer/data/repositories/supabase_order_repository.dart';
import 'features/customer/data/repositories/supabase_product_repository.dart';
import 'features/customer/data/repositories/supabase_user_settings_repository.dart';
import 'features/customer/domain/repositories/order_repository.dart';
import 'features/customer/domain/usecases/get_products.dart';
import 'features/customer/domain/repositories/product_repository.dart';
import 'features/customer/domain/repositories/user_settings_repository.dart';
import 'features/splash/presentation/pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final localProductRepository = ProductRepositoryImpl();
  final productRepository = await _buildProductRepository(
    localProductRepository,
  );
  final orderRepository = _buildOrderRepository();
  final settingsRepository = _buildUserSettingsRepository();
  final authRepository = SupabaseConfig.isConfigured
      ? SupabaseAuthRepository(Supabase.instance.client)
      : AuthRepositoryImpl();
  final signIn = SignIn(authRepository);
  final registerUser = RegisterUser(authRepository);
  final getProducts = GetProducts(productRepository);
  final getAdministratorDashboard = GetAdministratorDashboard(
    AdministratorRepositoryImpl(productRepository, orderRepository),
  );

  runApp(
    RestaurantApp(
      signIn: signIn,
      registerUser: registerUser,
      getProducts: getProducts,
      getAdministratorDashboard: getAdministratorDashboard,
      productRepository: productRepository,
      orderRepository: orderRepository,
      settingsRepository: settingsRepository,
    ),
  );
}

OrderRepository _buildOrderRepository() {
  if (!SupabaseConfig.isConfigured) {
    return OrderRepositoryImpl();
  }

  return SupabaseOrderRepository(Supabase.instance.client);
}

UserSettingsRepository _buildUserSettingsRepository() {
  if (!SupabaseConfig.isConfigured) {
    return UserSettingsRepositoryImpl();
  }

  return SupabaseUserSettingsRepository(Supabase.instance.client);
}

Future<ProductRepository> _buildProductRepository(
  ProductRepositoryImpl fallback,
) async {
  if (!SupabaseConfig.isConfigured) return fallback;

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final repository = SupabaseProductRepository(
    Supabase.instance.client,
    fallback: fallback.getProducts(),
  );
  await repository.load();
  return repository;
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({
    super.key,
    required this.signIn,
    required this.registerUser,
    required this.getProducts,
    required this.getAdministratorDashboard,
    required this.productRepository,
    required this.orderRepository,
    required this.settingsRepository,
  });

  final SignIn signIn;
  final RegisterUser registerUser;
  final GetProducts getProducts;
  final GetAdministratorDashboard getAdministratorDashboard;
  final ProductRepository productRepository;
  final OrderRepository orderRepository;
  final UserSettingsRepository settingsRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Fast',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: SplashPage(
        onFinished: () => LoginPage(
          signIn: signIn,
          registerUser: registerUser,
          getProducts: getProducts,
          getAdministratorDashboard: getAdministratorDashboard,
          productRepository: productRepository,
          orderRepository: orderRepository,
          settingsRepository: settingsRepository,
        ),
      ),
    );
  }
}
