import '../../domain/entities/auth_user.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../../../core/session/session_manager.dart';

/// Implementación del repositorio de autenticación contra el backend Spring Boot.
class SpringBootAuthRepository implements AuthRepository {
  final HttpClientService httpClient;
  final SessionManager sessionManager;

  SpringBootAuthRepository({
    required this.httpClient,
    required this.sessionManager,
  });

  @override
  Future<AuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    try {
      final response = await httpClient.post(
        ApiConfig.signinUrl,
        body: body,
        requiresAuth: false,
      );

      final token = response['jwt']?.toString() ?? '';
      if (token.isEmpty) {
        throw const FormatException('Spring Boot no devolvió un token JWT.');
      }
      final roleString = response['role']?.toString() ?? 'ROLE_CUSTOMER';

      final role = (roleString.contains('ADMIN') || roleString.contains('OWNER'))
          ? AuthRole.administrator
          : AuthRole.customer;

      final user = AuthUser(
        fullName: email.split('@').first.toUpperCase(),
        email: email.trim().toLowerCase(),
        role: role,
      );

      // Persistir token y sesión en SharedPreferences
      await sessionManager.saveSession(token: token, user: user);

      return user;
    } on UnauthorizedApiException {
      throw const AuthRegistrationException(
        AuthRegistrationFailure.unknown,
        'Credenciales inválidas. Compruebe correo y contraseña.',
      );
    } catch (e) {
      throw AuthRegistrationException(
        AuthRegistrationFailure.unknown,
        e.toString(),
      );
    }
  }

  @override
  Future<AuthUser?> register({
    required String fullName,
    required String email,
    required String password,
    required AuthRole role,
  }) async {
    final backendRole = role == AuthRole.administrator
        ? 'ROLE_ADMIN'
        : 'ROLE_CUSTOMER';

    final body = {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'role': backendRole,
    };

    try {
      final response = await httpClient.post(
        ApiConfig.signupUrl,
        body: body,
        requiresAuth: false,
      );

      final token = response['jwt']?.toString() ?? '';
      if (token.isEmpty) {
        throw const FormatException('Spring Boot no devolvió un token JWT.');
      }
      final user = AuthUser(
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        role: role,
      );

      await sessionManager.saveSession(token: token, user: user);
      return user;
    } catch (e) {
      if (e is HttpApiException && e.statusCode == 409 ||
          e.toString().contains('Already Used')) {
        throw const AuthRegistrationException(
          AuthRegistrationFailure.duplicateEmail,
          'Este correo ya se encuentra registrado.',
        );
      }
      throw AuthRegistrationException(
        AuthRegistrationFailure.unknown,
        e.toString(),
      );
    }
  }
}
