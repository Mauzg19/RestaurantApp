abstract final class SupabaseConfig {
  static const projectId = 'owshtbrfipmldwgjepyr';
  static const url = 'https://$projectId.supabase.co';
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_w7PaoswDBKhWKtXcVpX0mg_9Bth8hu5',
  );
  static const stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_51RDnllIcNHCVNtywdqBrM9rMTl9miURhZiuDrhn02X1K6kbVZxwqEcRJHCwj4eKuzyFxaBzYGUtIH0N95JMYVWrj00XXsS6BiH',
  );

  static bool get isConfigured => anonKey.isNotEmpty;
}
