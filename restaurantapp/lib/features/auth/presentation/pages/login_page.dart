import 'package:flutter/material.dart';

import '../../../administrator/domain/usecases/get_administrator_dashboard.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/usecases/register_user.dart';
import '../../domain/usecases/sign_in.dart';
import '../../../administrator/presentation/pages/administrator_home_page.dart';
import '../../../customer/domain/usecases/get_products.dart';
import '../../../customer/domain/repositories/order_repository.dart';
import '../../../customer/domain/repositories/product_repository.dart';
import '../../../customer/domain/repositories/user_settings_repository.dart';
import '../../../customer/data/services/payment_service.dart';
import '../../../customer/presentation/pages/customer_home_page.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/services/biometric_auth_service.dart';
import 'register_page.dart';
import '../widgets/auth_page_widgets.dart';

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
    this.paymentService,
  });

  final SignIn signIn;
  final RegisterUser registerUser;
  final GetProducts getProducts;
  final GetAdministratorDashboard getAdministratorDashboard;
  final ProductRepository productRepository;
  final OrderRepository? orderRepository;
  final UserSettingsRepository? settingsRepository;
  final PaymentService? paymentService;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // --- Biometría ---
  final BiometricAuthService _biometricService = BiometricAuthService.instance;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  /// Verifica si la biometría está disponible y habilitada, e intenta
  /// auto-login si corresponde.
  Future<void> _checkBiometric() async {
    final available = await _biometricService.canCheckBiometrics();
    final enabled = await _biometricService.isBiometricLoginEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
    // Auto-intentar login biométrico si está habilitado
    if (available && enabled) {
      _authenticateWithBiometric();
    }
  }

  /// Flujo de autenticación por huella digital.
  Future<void> _authenticateWithBiometric() async {
    final credentials = await _biometricService.getStoredCredentials();
    if (credentials == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay credenciales guardadas. Inicia sesión con correo y contraseña primero.',
          ),
          backgroundColor: Color(0xFFB76A1A),
        ),
      );
      return;
    }

    final authenticated = await _biometricService.authenticate(
      reason: 'Usa tu huella digital para iniciar sesión',
    );
    if (!authenticated || !mounted) return;

    // Huella verificada → iniciar sesión con credenciales guardadas
    setState(() => _isLoading = true);
    AuthUser? user;
    try {
      user = await widget.signIn(
        email: credentials.email,
        password: credentials.password,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      _navigateToHome(user);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las credenciales guardadas ya no son válidas. Inicia sesión manualmente.',
          ),
          backgroundColor: Color(0xFFB3261E),
        ),
      );
      // Desactivar biometría si las credenciales ya no sirven
      await _biometricService.disableBiometricLogin();
      if (mounted) setState(() => _biometricEnabled = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    AuthUser? user;
    try {
      user = await widget.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar sesión con el backend: $error'),
          backgroundColor: const Color(0xFFB3261E),
        ),
      );
      return;
    }
    final signedInUser = user;
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (signedInUser != null) {
      // Si la biometría está disponible pero no habilitada, ofrecer activarla
      if (_biometricAvailable && !_biometricEnabled) {
        _offerBiometricSetup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      _navigateToHome(signedInUser);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Correo o contraseña incorrectos'),
        backgroundColor: Color(0xFFB76A1A),
      ),
    );
  }

  /// Ofrece al usuario activar la huella digital después de un login exitoso.
  void _offerBiometricSetup({
    required String email,
    required String password,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.fingerprint, color: Color(0xFFC95D32), size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('Activar huella digital')),
            ],
          ),
          content: const Text(
            '¿Deseas iniciar sesión con tu huella digital la próxima vez?\n\n'
            'Tus credenciales se guardarán de forma segura en tu dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final authenticated = await _biometricService.authenticate(
                  reason: 'Confirma tu huella para activar el inicio rápido',
                );
                if (authenticated) {
                  await _biometricService.enableBiometricLogin(
                    email: email,
                    password: password,
                  );
                }
              },
              icon: const Icon(Icons.fingerprint),
              label: const Text('Activar'),
            ),
          ],
        ),
      );
    });
  }

  /// Navega a la pantalla principal según el rol del usuario.
  Future<void> _navigateToHome(AuthUser signedInUser) async {
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
        builder: (_) => signedInUser.role == AuthRole.customer
            ? CustomerHomePage(
                user: signedInUser,
                getProducts: widget.getProducts,
                orderRepository: widget.orderRepository,
                settingsRepository: widget.settingsRepository,
                paymentService: widget.paymentService,
                onLogout: (context) async {
                  final session = await SessionManager.getInstance();
                  await session.clearSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    _createFadeRoute(
                      (context) => LoginPage(
                        signIn: widget.signIn,
                        registerUser: widget.registerUser,
                        getProducts: widget.getProducts,
                        getAdministratorDashboard:
                            widget.getAdministratorDashboard,
                        productRepository: widget.productRepository,
                        orderRepository: widget.orderRepository,
                        settingsRepository: widget.settingsRepository,
                        paymentService: widget.paymentService,
                      ),
                    ),
                    (route) => false,
                  );
                },
              )
            : AdministratorHomePage(
                user: signedInUser,
                getDashboard: widget.getAdministratorDashboard,
                productRepository: widget.productRepository,
                orderRepository: widget.orderRepository,
                onLogout: (context) async {
                  final session = await SessionManager.getInstance();
                  await session.clearSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    _createFadeRoute(
                      (context) => LoginPage(
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
  }

  Route _createFadeRoute(WidgetPageBuilder builder) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showUnavailableAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action todavía no está configurado.')),
    );
  }

  Widget _socialButton(String label) {
    return Expanded(
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: AuthColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: OutlinedButton(
          onPressed: _isLoading ? null : () => _showUnavailableAction(label),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AuthColors.ink,
            side: const BorderSide(color: AuthColors.ink, width: 2.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }

  /// Botón de autenticación con huella digital.
  Widget _biometricButton() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: AuthColors.ink, offset: Offset(5, 5)),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _authenticateWithBiometric,
        icon: const Icon(Icons.fingerprint, size: 26),
        label: const Text(
          'ENTRAR CON HUELLA',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AuthColors.ink,
          side: const BorderSide(color: AuthColors.ink, width: 2.5),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      badgeTop: 'ENVÍO GRATIS',
      badgeBottom: '25 MIN',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader(),
            const SizedBox(height: 38),
            AuthPageHeading(
              title: const TextSpan(
                children: [
                  TextSpan(text: '¿Qué se te\n'),
                  TextSpan(
                    text: 'antoja',
                    style: TextStyle(backgroundColor: AuthColors.lime),
                  ),
                  TextSpan(text: ' hoy?'),
                ],
              ),
              subtitle: 'Entra y repite tu pedido favorito en dos toques.',
            ),
            const SizedBox(height: 20),
            AuthTextField(
              label: 'CORREO',
              controller: _emailController,
              hintText: 'tu@correo.com',
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: (value) => value == null || !value.contains('@')
                  ? 'Escribe un correo válido'
                  : null,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'CONTRASEÑA',
              controller: _passwordController,
              hintText: '••••••••',
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (value) => value == null || value.length < 6
                  ? 'Usa al menos 6 caracteres'
                  : null,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _showUnavailableAction(
                        'La recuperación de contraseña',
                      ),
                style: TextButton.styleFrom(
                  foregroundColor: AuthColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.centerLeft,
                ),
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AuthPrimaryButton(
              label: 'ENTRAR',
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
            ),
            // --- Botón de huella digital ---
            if (_biometricAvailable && _biometricEnabled) ...[
              const SizedBox(height: 12),
              _biometricButton(),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Divider(color: AuthColors.ink, thickness: 2),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'O CON',
                    style: TextStyle(
                      color: AuthColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: AuthColors.ink, thickness: 2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _socialButton('Google'),
                const SizedBox(width: 10),
                _socialButton('Apple'),
              ],
            ),
            const SizedBox(height: 54),
            AuthSwitchLink(
              question: '¿Primera vez?',
              label: 'Crea cuenta',
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).push(
                      _createFadeRoute(
                        (context) =>
                            RegisterPage(registerUser: widget.registerUser),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef WidgetPageBuilder = Widget Function(BuildContext context);
