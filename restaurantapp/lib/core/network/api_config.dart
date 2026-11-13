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

  static String resolveImageUrl(String imageUrl) {
    final imageUri = Uri.parse(imageUrl);
    final baseUri = Uri.parse(_baseUrl);
    if (!imageUri.hasScheme) {
      return baseUri.resolveUri(imageUri).toString();
    }
    if (_isProductUpload(imageUri) || _isLoopbackHost(imageUri.host)) {
      return baseUri.resolve(_pathAndQuery(imageUri)).toString();
    }
    return imageUri.toString();
  }

  static String imageUrlForStorage(String imageUrl) {
    final imageUri = Uri.tryParse(imageUrl);
    if (imageUri == null || !imageUri.hasScheme) return imageUrl;

    final baseUri = Uri.parse(_baseUrl);
    final isBackendUrl =
        (imageUri.host == baseUri.host && imageUri.port == baseUri.port) ||
        _isLoopbackHost(imageUri.host) ||
        _isProductUpload(imageUri);
    if (!isBackendUrl) return imageUrl;
    return _pathAndQuery(imageUri);
  }

  static bool _isProductUpload(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.path.startsWith('/uploads/product-images/');

  static String _pathAndQuery(Uri uri) =>
      '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}'
      '${uri.hasFragment ? '#${uri.fragment}' : ''}';

  static bool _isLoopbackHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

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
  static String get notificationsUrl => '$baseUrl/api/notifications';
  static String get notificationsReadAllUrl => '$notificationsUrl/read-all';
  static String notificationReadUrl(int id) => '$notificationsUrl/$id/read';
  static String get notificationDeviceTokenUrl =>
      '$notificationsUrl/device-token';
  static String get rewardsUrl => '$baseUrl/api/rewards';
  static String get rewardsJoinUrl => '$rewardsUrl/join';
  static String get rewardsCatalogUrl => '$rewardsUrl/catalog';
  static String get rewardsHistoryUrl => '$rewardsUrl/history';
  static String get addCartItemUrl => '$baseUrl/api/cart/add';
  static String get clearCartUrl => '$baseUrl/api/cart/clear';
  static String get createOrderUrl => '$baseUrl/api/order';
  static String paymentStatusUrl(String orderId) =>
      '$ordersUrl/$orderId/payment-status';
  static String foodAvailabilityUrl(String id) =>
      '$baseUrl/api/admin/food/$id/availability';
  static String foodByIdUrl(String id) => '$baseUrl/api/admin/food/$id';
  static String foodImageUploadUrl(String id) =>
      '$baseUrl/api/admin/food/$id/image';
  static String orderByIdUrl(String id, String status) =>
      '$baseUrl/api/admin/orders/$id/$status';
}
