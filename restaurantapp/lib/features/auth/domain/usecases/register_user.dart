import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class RegisterUser {
  const RegisterUser(this.repository);

  final AuthRepository repository;

  Future<AuthUser?> call({
    required String fullName,
    required String email,
    required String password,
    required AuthRole role,
  }) {
    return repository.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
    );
  }
}
