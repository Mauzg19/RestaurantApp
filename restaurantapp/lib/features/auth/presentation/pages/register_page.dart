import 'package:flutter/material.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../domain/usecases/register_user.dart';
import '../widgets/auth_page_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.registerUser});

  final RegisterUser registerUser;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    String? errorMessage;
    try {
      final user = await widget.registerUser(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: AuthRole.customer,
      );
      if (user == null) {
        errorMessage = 'Supabase no devolvió un usuario creado.';
      }
    } on AuthRegistrationException catch (error) {
      errorMessage = switch (error.failure) {
        AuthRegistrationFailure.duplicateEmail =>
          'Ya existe una cuenta con ese correo.',
        AuthRegistrationFailure.emailConfirmationRequired =>
          'Cuenta creada. Revisa tu correo para confirmarla.',
        AuthRegistrationFailure.emailRateLimit => 'Supabase alcanzó el límite de correos. Espera unos minutos o desactiva la confirmación de email en Supabase para desarrollo.',
        AuthRegistrationFailure.unknown => error.message,
      };
    } catch (_) {
      errorMessage =
          'No fue posible conectar con Supabase. Revisa la configuración.';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFB76A1A),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta creada correctamente')),
    );
    Navigator.of(context).pop();
  }

  int _passwordStrength(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      badgeTop: 'PRIMER PEDIDO',
      badgeBottom: '-20%',
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
                  TextSpan(text: 'Únete y\n'),
                  TextSpan(
                    text: 'come',
                    style: TextStyle(backgroundColor: AuthColors.lime),
                  ),
                  TextSpan(text: ' primero.'),
                ],
              ),
              subtitle: 'Tu cuenta lista en menos de un minuto.',
            ),
            const SizedBox(height: 20),
            AuthTextField(
              label: 'NOMBRE COMPLETO',
              controller: _fullNameController,
              hintText: 'Tu nombre',
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Escribe tu nombre completo'
                  : null,
            ),
            const SizedBox(height: 14),
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
              hintText: 'Mínimo 8 caracteres',
              enabled: !_isLoading,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (value) => value == null || value.length < 8
                  ? 'Usa al menos 8 caracteres'
                  : null,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _passwordController,
              builder: (context, value, child) {
                final score = _passwordStrength(value.text);
                const colors = [
                  Color(0xFFFF5A4D),
                  AuthColors.orange,
                  Color(0xFFFFD23A),
                  AuthColors.lime,
                ];
                const labels = ['Muy débil', 'Débil', 'Aceptable', '¡Fuerte!'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      label: 'Seguridad de la contraseña',
                      value: score == 0 ? 'Sin evaluar' : labels[score - 1],
                      child: Row(
                        children: List.generate(
                          4,
                          (index) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: index == 3 ? 0 : 6,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 10,
                                decoration: BoxDecoration(
                                  color: index < score
                                      ? colors[score - 1]
                                      : Colors.white,
                                  border: Border.all(
                                    color: AuthColors.ink,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.text.isEmpty
                          ? 'Mayúsculas, números y símbolos suman.'
                          : labels[score == 0 ? 0 : score - 1],
                      style: const TextStyle(
                        color: AuthColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            AuthPrimaryButton(
              label: 'CREAR CUENTA',
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 70),
            AuthSwitchLink(
              question: '¿Ya tienes cuenta?',
              label: 'Entrar',
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
