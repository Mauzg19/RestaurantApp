import '../../domain/entities/order.dart';
import '../../domain/repositories/user_settings_repository.dart';

class UserSettingsRepositoryImpl implements UserSettingsRepository {
  final Map<String, Address> _addresses = {};
  final Map<String, PaymentMethod> _paymentMethods = {};

  @override
  Future<Address?> getDeliveryAddress(String email) async => _addresses[email];

  @override
  Future<void> saveDeliveryAddress(String email, Address address) async {
    _addresses[email] = address;
  }

  @override
  Future<PaymentMethod?> getPaymentMethod(String email) async => _paymentMethods[email];

  @override
  Future<void> savePaymentMethod(String email, PaymentMethod method) async {
    _paymentMethods[email] = method;
  }
}
