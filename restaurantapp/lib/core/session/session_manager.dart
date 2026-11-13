import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final FlutterSecureStorage _secureStorage;
  String? _token;
  String? _email;
  String? _name;
  String? _role;

  SessionManager._(
    this._prefs,
    this._secureStorage, {
    required this._token,
    required this._email,
    required this._name,
    required this._role,
  });

  static Future<SessionManager> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      const secureStorage = FlutterSecureStorage();
      var token = await secureStorage.read(key: _keyToken);
      if (token == null || token.isEmpty) {
        token = prefs.getString(_keyToken);
        if (token != null && token.isNotEmpty) {
          await secureStorage.write(key: _keyToken, value: token);
          await prefs.remove(_keyToken);
        }
      }
      Future<String?> loadAndMigrate(String key) async {
        var value = await secureStorage.read(key: key);
        if (value == null) {
          value = prefs.getString(key);
          if (value != null) {
            await secureStorage.write(key: key, value: value);
            await prefs.remove(key);
          }
        }
        return value;
      }

      _instance = SessionManager._(
        prefs,
        secureStorage,
        token: token,
        email: await loadAndMigrate(_keyEmail),
        name: await loadAndMigrate(_keyName),
        role: await loadAndMigrate(_keyRole),
      );
    }
    return _instance!;
  }

  /// Guarda la sesión activa tras un login o registro exitoso.
  Future<void> saveSession({
    required String token,
    required AuthUser user,
  }) async {
    await _secureStorage.write(key: _keyToken, value: token);
    await _secureStorage.write(key: _keyEmail, value: user.email);
    await _secureStorage.write(key: _keyName, value: user.fullName);
    await _secureStorage.write(key: _keyRole, value: user.role.name);
    _token = token;
    _email = user.email;
    _name = user.fullName;
    _role = user.role.name;
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyEmail);
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyRole);
  }

  /// Retorna el token JWT actual o null si no existe.
  String? getToken() => _token;

  /// Retorna el usuario autenticado actualmente en caché.
  AuthUser? getCurrentUser() {
    if (!_hasUnexpiredToken) return null;
    final email = _email;
    final name = _name;
    final roleStr = _role;

    if (email == null || name == null) return null;

    final role = AuthRole.values.where((value) => value.name == roleStr).firstOrNull
        ?? AuthRole.customer;

    return AuthUser(
      fullName: name,
      email: email,
      role: role,
    );
  }

  /// Elimina los datos de sesión (Logout).
  Future<void> clearSession() async {
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyEmail);
    await _secureStorage.delete(key: _keyName);
    await _secureStorage.delete(key: _keyRole);
    _token = null;
    _email = null;
    _name = null;
    _role = null;
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyEmail);
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyRole);
  }

  /// Comprueba si hay una sesión activa persistida.
  bool get isAuthenticated => _hasUnexpiredToken;

  bool get _hasUnexpiredToken {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final segments = token.split('.');
    if (segments.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      final expiry = payload is Map ? payload['exp'] : null;
      if (expiry is! num) return false;
      return expiry > DateTime.now().millisecondsSinceEpoch / 1000;
    } on FormatException {
      return false;
    }
  }
}
