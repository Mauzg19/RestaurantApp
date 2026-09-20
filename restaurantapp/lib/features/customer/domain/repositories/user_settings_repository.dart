import '../entities/order.dart';

abstract interface class UserSettingsRepository {
  Future<Address?> getDeliveryAddress(String email);
  Future<void> saveDeliveryAddress(String email, Address address);

  Future<PaymentMethod?> getPaymentMethod(String email);
  Future<void> savePaymentMethod(String email, PaymentMethod method);
}
