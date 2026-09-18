import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/exceptions/auth_exception.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Map<String, _StoredUser> _users = {};

  @override
  Future<AuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final storedUser = _users[email.trim().toLowerCase()];
    if (storedUser == null || storedUser.password != password) return null;
    return storedUser.user;
  }

  @override
  Future<AuthUser?> register({
    required String fullName,
    required String email,
    required String password,
    required AuthRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final normalizedEmail = email.trim().toLowerCase();
    if (_users.containsKey(normalizedEmail)) {
      throw const AuthRegistrationException(
        AuthRegistrationFailure.duplicateEmail,
        'Este correo ya está registrado en el entorno local.',
      );
    }

    final user = AuthUser(
      fullName: fullName.trim(),
      email: normalizedEmail,
      role: role,
    );
    _users[normalizedEmail] = _StoredUser(user: user, password: password);
    return user;
  }
}

class _StoredUser {
  const _StoredUser({required this.user, required this.password});

  final AuthUser user;
  final String password;
}
