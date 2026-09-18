import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

class SignIn {
  const SignIn(this.repository);

  final AuthRepository repository;

  Future<AuthUser?> call({required String email, required String password}) {
    return repository.signIn(email: email, password: password);
  }
}
