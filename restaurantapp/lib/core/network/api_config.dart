import 'package:flutter/foundation.dart';

/// Configuración central de URLs y endpoints para el backend Spring Boot.
class ApiConfig {
  ApiConfig._();

  /// URL base por defecto del backend Spring Boot.
  /// En Android Emulator suele usarse 10.0.2.2:5454.
  /// Para un dispositivo físico, configure BACKEND_BASE_URL con la IP LAN del equipo.
  static String _baseUrl = _initialBaseUrl();

  static String _initialBaseUrl() {
    final configured = const String.fromEnvironment('BACKEND_BASE_URL').trim();
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/+$'), '');
    }
    return kIsWeb
        ? 'http://localhost:5454'
        : (defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:5454'
              : 'http://localhost:5454');
  }

  static String get baseUrl => _baseUrl;

  static void setBaseUrl(String newUrl) {
    if (newUrl.trim().isNotEmpty) {
      _baseUrl = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }
  }

  // Rutas de autenticación
  static String get signinUrl => '$baseUrl/auth/signin';
  static String get signupUrl => '$baseUrl/auth/signup';
  static String get userProfileUrl => '$baseUrl/api/users/profile';

  // Rutas de menú y pedidos
  static String get foodsUrl => '$baseUrl/api/food';
  static String get ordersUrl => '$baseUrl/api/order';
  static String get restaurantsUrl => '$baseUrl/api/restaurants';
  static String categoryRestaurantUrl(int id) =>
      '$baseUrl/api/category/restaurant/$id';
  static String get currentUserUrl => '$baseUrl/api/users/profile';
  static String get deliveryAddressUrl => '$baseUrl/api/users/address';
  static String get userSettingsUrl => '$baseUrl/api/users/settings';
  static String get addCartItemUrl => '$baseUrl/api/cart/add';
  static String get clearCartUrl => '$baseUrl/api/cart/clear';
  static String get createOrderUrl => '$baseUrl/api/order';
  static String foodAvailabilityUrl(String id) =>
      '$baseUrl/api/admin/food/$id/availability';
  static String foodByIdUrl(String id) => '$baseUrl/api/admin/food/$id';
  static String foodImageUploadUrl(String id) =>
      '$baseUrl/api/admin/food/$id/image';
  static String orderByIdUrl(String id, String status) =>
      '$baseUrl/api/admin/orders/$id/$status';
}
