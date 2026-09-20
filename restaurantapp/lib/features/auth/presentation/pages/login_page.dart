import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../administrator/domain/usecases/get_administrator_dashboard.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/usecases/register_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../../administrator/presentation/pages/administrator_home_page.dart';
import '../../../customer/domain/usecases/get_products.dart';
import '../../../customer/domain/repositories/order_repository.dart';
import '../../../customer/domain/repositories/product_repository.dart';
import '../../../customer/domain/repositories/user_settings_repository.dart';
import '../../../customer/presentation/pages/customer_home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.signIn,
    required this.registerUser,
    required this.getProducts,
    required this.getAdministratorDashboard,
    required this.productRepository,
    this.orderRepository,
    this.settingsRepository,
  });

  final SignIn signIn;
  final RegisterUser registerUser;
  final GetProducts getProducts;
  final GetAdministratorDashboard getAdministratorDashboard;
  final ProductRepository productRepository;
  final OrderRepository? orderRepository;
  final UserSettingsRepository? settingsRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = await widget.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (user != null) {
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await widget.productRepository.load();
        await widget.orderRepository?.load();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron cargar los pedidos: $error'),
            backgroundColor: const Color(0xFFB3261E),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user.role == AuthRole.customer
              ? CustomerHomePage(
                  user: user,
                  getProducts: widget.getProducts,
                  orderRepository: widget.orderRepository,
                  settingsRepository: widget.settingsRepository,
                  onLogout: (context) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => LoginPage(
                          signIn: widget.signIn,
                          registerUser: widget.registerUser,
                          getProducts: widget.getProducts,
                          getAdministratorDashboard:
                              widget.getAdministratorDashboard,
                          productRepository: widget.productRepository,
                          orderRepository: widget.orderRepository,
                          settingsRepository: widget.settingsRepository,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                )
              : AdministratorHomePage(
                  user: user,
                  getDashboard: widget.getAdministratorDashboard,
                  productRepository: widget.productRepository,
                  orderRepository: widget.orderRepository,
                  onLogout: (context) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => LoginPage(
                          signIn: widget.signIn,
                          registerUser: widget.registerUser,
                          getProducts: widget.getProducts,
                          getAdministratorDashboard:
                              widget.getAdministratorDashboard,
                          productRepository: widget.productRepository,
                          orderRepository: widget.orderRepository,
                          settingsRepository: widget.settingsRepository,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Correo o contraseña incorrectos'),
        backgroundColor: Color(0xFFB76A1A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 42),
                    Text(
                      'Bienvenido de nuevo',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entra para pedir tus favoritos más rápido.',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Escribe un correo válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Usa al menos 6 caracteres'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.background,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.background,
                              ),
                            )
                          : const Text(
                              'INICIAR SESIÓN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes una cuenta? ',
                          style: TextStyle(color: AppTheme.mutedText),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RegisterPage(
                                registerUser: widget.registerUser,
                              ),
                            ),
                          ),
                          child: const Text('REGÍSTRATE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.restaurant_menu,
            color: AppTheme.accent,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Restaurant Fast',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ],
    );
  }
}
