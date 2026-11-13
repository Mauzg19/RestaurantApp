enum AuthRole { customer, administrator, restaurantOwner, restaurantManager }

extension AuthRoleLabel on AuthRole {
  bool get canOperateRestaurant =>
      this == AuthRole.administrator || this == AuthRole.restaurantOwner;

  String get label {
    switch (this) {
      case AuthRole.customer:
        return 'Cliente';
      case AuthRole.administrator:
        return 'Administrador';
      case AuthRole.restaurantOwner:
        return 'Propietario';
      case AuthRole.restaurantManager:
        return 'Gerente';
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
