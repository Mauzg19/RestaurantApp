import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/entities/auth_user.dart';

/// Gestor de persistencia de sesión local y token JWT.
class SessionManager {
  static const String _keyToken = 'auth_jwt_token';
  static const String _keyEmail = 'auth_user_email';
  static const String _keyName = 'auth_user_name';
  static const String _keyRole = 'auth_user_role';

  static SessionManager? _instance;
  final SharedPreferences _prefs;

  SessionManager._(this._prefs);

  static Future<SessionManager> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = SessionManager._(prefs);
    }
    return _instance!;
  }

  /// Guarda la sesión activa tras un login o registro exitoso.
  Future<void> saveSession({
    required String token,
    required AuthUser user,
  }) async {
    await _prefs.setString(_keyToken, token);
    await _prefs.setString(_keyEmail, user.email);
    await _prefs.setString(_keyName, user.fullName);
    await _prefs.setString(_keyRole, user.role.name);
  }

  /// Retorna el token JWT actual o null si no existe.
  String? getToken() => _prefs.getString(_keyToken);

  /// Retorna el usuario autenticado actualmente en caché.
  AuthUser? getCurrentUser() {
    final email = _prefs.getString(_keyEmail);
    final name = _prefs.getString(_keyName);
    final roleStr = _prefs.getString(_keyRole);

    if (email == null || name == null) return null;

    final role = roleStr == AuthRole.administrator.name
        ? AuthRole.administrator
        : AuthRole.customer;

    return AuthUser(
      fullName: name,
      email: email,
      role: role,
    );
  }

  /// Elimina los datos de sesión (Logout).
  Future<void> clearSession() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyEmail);
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyRole);
  }

  /// Comprueba si hay una sesión activa persistida.
  bool get isAuthenticated => getToken() != null && getToken()!.isNotEmpty;
}
