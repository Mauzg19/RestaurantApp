import '../../../../core/network/api_config.dart';
import '../../../../core/network/http_client_service.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/user_settings_repository.dart';

class SpringBootUserSettingsRepository implements UserSettingsRepository {
  SpringBootUserSettingsRepository({required this.httpClient});

  final HttpClientService httpClient;

  @override
  Future<Address?> getDeliveryAddress(String email) async {
    final response = await httpClient.get(ApiConfig.currentUserUrl);
    if (response is! Map) {
      throw const FormatException('Spring Boot devolvió el perfil con formato inválido.');
    }
    final addresses = response['addresses'];
    if (addresses is! List || addresses.isEmpty || addresses.last is! Map) {
      return null;
    }
    return _addressFromBackend(Map<String, dynamic>.from(addresses.last as Map));
  }

  @override
  Future<void> saveDeliveryAddress(String email, Address address) async {
    await httpClient.post(
      ApiConfig.deliveryAddressUrl,
      body: {
        'street': address.street,
        'city': address.city,
        'postalCode': address.postalCode,
        'notes': address.notes,
      },
    );
  }

  @override
  Future<PaymentMethod?> getPaymentMethod(String email) async {
    final response = await httpClient.get(ApiConfig.userSettingsUrl);
    if (response is! Map) {
      throw const FormatException('Spring Boot devolvió las preferencias con formato inválido.');
    }
    final type = response['paymentType']?.toString() ?? '';
    final details = response['paymentDetails']?.toString() ?? '';
    if (type.isEmpty && details.isEmpty) return null;
    return PaymentMethod(type: type, details: details);
  }

  @override
  Future<void> savePaymentMethod(String email, PaymentMethod method) async {
    await httpClient.put(
      ApiConfig.userSettingsUrl,
      body: {
        'paymentType': method.type,
        'paymentDetails': method.details,
      },
    );
  }

  Address _addressFromBackend(Map<String, dynamic> json) => Address(
        street: json['streetAddress']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        postalCode: json['postalCode']?.toString() ?? '',
        notes: json['notes']?.toString(),
      );
}
