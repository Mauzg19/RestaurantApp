import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de autenticación biométrica (huella digital / reconocimiento facial).
///
/// Utiliza [LocalAuthentication] para la verificación biométrica nativa y
/// [FlutterSecureStorage] para almacenar credenciales de forma segura
/// cuando el usuario activa el inicio de sesión biométrico.
class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService _instance = BiometricAuthService._();
  static BiometricAuthService get instance => _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keySecureEmail = 'biometric_email';
  static const String _keySecurePassword = 'biometric_password';

  // ---------------------------------------------------------------------------
  // Consultas de disponibilidad
  // ---------------------------------------------------------------------------

  /// Verifica si el dispositivo tiene hardware biométrico disponible.
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Verifica si el dispositivo puede verificar biometría (hardware presente
  /// y al menos una huella/rostro registrado).
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Retorna la lista de tipos biométricos disponibles en el dispositivo
  /// (huella, rostro, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  // ---------------------------------------------------------------------------
  // Autenticación
  // ---------------------------------------------------------------------------

  /// Muestra el diálogo biométrico nativo y retorna `true` si la verificación
  /// fue exitosa.
  Future<bool> authenticate({
    String reason = 'Verifica tu identidad para continuar',
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Gestión de credenciales seguras
  // ---------------------------------------------------------------------------

  /// Verifica si el usuario activó el inicio de sesión biométrico.
  Future<bool> isBiometricLoginEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Activa la autenticación biométrica y guarda las credenciales de forma
  /// segura. Antes de llamar a este método se debe verificar la huella.
  Future<void> enableBiometricLogin({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(key: _keySecureEmail, value: email);
    await _secureStorage.write(key: _keySecurePassword, value: password);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, true);
  }

  /// Desactiva la autenticación biométrica y elimina las credenciales seguras.
  Future<void> disableBiometricLogin() async {
    await _secureStorage.delete(key: _keySecureEmail);
    await _secureStorage.delete(key: _keySecurePassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, false);
  }

  /// Recupera las credenciales almacenadas de forma segura.
  /// Retorna `null` si no existen.
  Future<({String email, String password})?> getStoredCredentials() async {
    final email = await _secureStorage.read(key: _keySecureEmail);
    final password = await _secureStorage.read(key: _keySecurePassword);
    if (email != null && password != null) {
      return (email: email, password: password);
    }
    return null;
  }
}
