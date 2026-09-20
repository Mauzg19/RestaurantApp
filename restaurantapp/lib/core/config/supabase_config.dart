abstract final class SupabaseConfig {
  static const projectId = 'owshtbrfipmldwgjepyr';
  static const url = 'https://$projectId.supabase.co';
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_w7PaoswDBKhWKtXcVpX0mg_9Bth8hu5',
  );

  static bool get isConfigured => anonKey.isNotEmpty;
}
