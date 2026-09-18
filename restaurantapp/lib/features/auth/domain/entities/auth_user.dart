enum AuthRole { customer, administrator }

extension AuthRoleLabel on AuthRole {
  String get label {
    switch (this) {
      case AuthRole.customer:
        return 'Cliente';
      case AuthRole.administrator:
        return 'Administrador';
    }
  }
}

class AuthUser {
  const AuthUser({
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String fullName;
  final String email;
  final AuthRole role;
}
