import 'package:flutter_test/flutter_test.dart';
import 'package:restaurantapp/core/services/biometric_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  group('BiometricAuthService Tests', () {
    late BiometricAuthService biometricService;
    late FlutterSecureStorage secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secureStorage = const FlutterSecureStorage();
      await secureStorage.deleteAll();
      biometricService = BiometricAuthService.instance;
    });

    test('Debe activar y desactivar el login biométrico correctamente', () async {
      // 1. Activar
      await biometricService.enableBiometricLogin(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(await biometricService.isBiometricLoginEnabled(), isTrue);

      final creds = await biometricService.getStoredCredentials();
      expect(creds?.email, 'test@example.com');
      expect(creds?.password, 'password123');

      // 2. Desactivar
      await biometricService.disableBiometricLogin();

      expect(await biometricService.isBiometricLoginEnabled(), isFalse);
      final credsAfter = await biometricService.getStoredCredentials();
      expect(credsAfter, isNull);
    });

    test('getStoredCredentials debe retornar null si no hay datos', () async {
      final creds = await biometricService.getStoredCredentials();
      expect(creds, isNull);
    });
  });
}
