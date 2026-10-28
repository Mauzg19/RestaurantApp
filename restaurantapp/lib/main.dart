import 'package:flutter/material.dart';

import 'core/network/http_client_service.dart';
import 'core/session/session_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/spring_boot_auth_repository.dart';
import 'features/auth/domain/entities/auth_user.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/register_user.dart';
import 'features/auth/domain/usecases/sign_in.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/administrator/data/repositories/administrator_repository_impl.dart';
import 'features/administrator/domain/usecases/get_administrator_dashboard.dart';
import 'features/customer/data/repositories/spring_boot_order_repository.dart';
import 'features/customer/data/repositories/spring_boot_product_repository.dart';
import 'features/customer/data/repositories/spring_boot_user_settings_repository.dart';
import 'features/customer/data/services/payment_service.dart';
import 'features/customer/domain/repositories/order_repository.dart';
import 'features/customer/domain/usecases/get_products.dart';
import 'features/customer/domain/repositories/product_repository.dart';
import 'features/customer/domain/repositories/user_settings_repository.dart';
import 'features/splash/presentation/pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializar sesión persistente y cliente HTTP Spring Boot
  final sessionManager = await SessionManager.getInstance();
  final httpClient = HttpClientService(sessionManager: sessionManager);
  final currentUser = sessionManager.getCurrentUser();

  // Los datos de negocio y la autenticación se gestionan en Spring Boot/MySQL.
  final productRepository = SpringBootProductRepository(httpClient: httpClient);
  await productRepository.load();
  final orderRepository = SpringBootOrderRepository(
    httpClient: httpClient,
    restaurantId: productRepository.restaurantId,
    isAdministrator: () =>
        sessionManager.getCurrentUser()?.role == AuthRole.administrator,
  );
  final settingsRepository = SpringBootUserSettingsRepository(
    httpClient: httpClient,
  );

  final AuthRepository authRepository = SpringBootAuthRepository(
    httpClient: httpClient,
    sessionManager: sessionManager,
  );

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
      paymentService: null,
      initialUser: currentUser,
    ),
  );
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
    this.paymentService,
    this.initialUser,
  });

  final SignIn signIn;
  final RegisterUser registerUser;
  final GetProducts getProducts;
  final GetAdministratorDashboard getAdministratorDashboard;
  final ProductRepository productRepository;
  final OrderRepository orderRepository;
  final UserSettingsRepository settingsRepository;
  final PaymentService? paymentService;
  final AuthUser? initialUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Fast & AI',
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
          paymentService: paymentService,
        ),
      ),
    );
  }
}
