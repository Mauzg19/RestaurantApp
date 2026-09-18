import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../domain/entities/auth_user.dart';
import '../../domain/exceptions/auth_exception.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this.client);

  final SupabaseClient client;

  @override
  Future<AuthUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = response.user;
      if (user == null) return null;
      return await _toAuthUser(user);
    } on AuthException {
      return null;
    }
  }

  @override
  Future<AuthUser?> register({
    required String fullName,
    required String email,
    required String password,
    required AuthRole role,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': fullName.trim(), 'role': 'customer'},
      );
      final user = response.user;
      if (user == null) return null;
      if (user.identities?.isEmpty ?? false) {
        throw const AuthRegistrationException(
          AuthRegistrationFailure.duplicateEmail,
          'Supabase indica que este correo ya está registrado.',
        );
      }
      return await _toAuthUser(
        user,
        fallbackName: fullName,
        fallbackRole: AuthRole.customer,
      );
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (error.statusCode == '429' ||
          message.contains('email rate limit') ||
          message.contains('rate limit exceeded')) {
        throw const AuthRegistrationException(
          AuthRegistrationFailure.emailRateLimit,
          'Supabase alcanzó el límite temporal de correos de confirmación.',
        );
      }
      if (message.contains('already registered') ||
          message.contains('user already exists')) {
        throw const AuthRegistrationException(
          AuthRegistrationFailure.duplicateEmail,
          'Supabase indica que este correo ya está registrado.',
        );
      }
      throw AuthRegistrationException(
        AuthRegistrationFailure.unknown,
        error.message,
      );
    }
  }

  Future<AuthUser> _toAuthUser(
    User user, {
    String? fallbackName,
    AuthRole? fallbackRole,
  }) async {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final roleName = metadata['role'] as String?;
    final metadataRole = switch (roleName) {
      'administrator' => AuthRole.administrator,
      _ => fallbackRole ?? AuthRole.customer,
    };
    final role = await _loadRole(user.id) ?? metadataRole;
    return AuthUser(
      fullName:
          metadata['full_name'] as String? ?? fallbackName ?? user.email ?? '',
      email: user.email ?? '',
      role: role,
    );
  }

  Future<AuthRole?> _loadRole(String userId) async {
    try {
      final row = await client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return switch (row?['role']) {
        'administrator' => AuthRole.administrator,
        'customer' => AuthRole.customer,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}
