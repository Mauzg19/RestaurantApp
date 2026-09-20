import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/order.dart';
import '../../domain/repositories/user_settings_repository.dart';

class SupabaseUserSettingsRepository implements UserSettingsRepository {
  SupabaseUserSettingsRepository(this.client);

  final SupabaseClient client;

  @override
  Future<Address?> getDeliveryAddress(String email) async {
    try {
      final data = await client
          .from('user_settings')
          .select()
          .eq('user_email', email)
          .maybeSingle();

      if (data == null) return null;
      return Address.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDeliveryAddress(String email, Address address) async {
    final settings = await _getSettings(email);

    await client.from('user_settings').upsert({
      'user_email': email,
      'street': address.street,
      'city': address.city,
      'postal_code': address.postalCode,
      'payment_type': settings?['payment_type'] ?? '',
      'payment_details': settings?['payment_details'] ?? '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<PaymentMethod?> getPaymentMethod(String email) async {
    try {
      final data = await client
          .from('user_settings')
          .select()
          .eq('user_email', email)
          .maybeSingle();

      if (data == null) return null;
      final row = data as Map<String, dynamic>;
      return PaymentMethod(
        type: row['payment_type'] as String? ?? '',
        details: row['payment_details'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePaymentMethod(String email, PaymentMethod method) async {
    final settings = await _getSettings(email);

    await client.from('user_settings').upsert({
      'user_email': email,
      'payment_type': method.type,
      'payment_details': method.details,
      'street': settings?['street'] ?? '',
      'city': settings?['city'] ?? '',
      'postal_code': settings?['postal_code'] ?? '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> _getSettings(String email) async {
    try {
      return await client
          .from('user_settings')
          .select()
          .eq('user_email', email)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
