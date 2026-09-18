abstract final class SupabaseConfig {
  static const projectId = 'owshtbrfipmldwgjepyr';
  static const url = 'https://$projectId.supabase.co';
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => anonKey.isNotEmpty;
}
