/// Supabase proje bilgileri.
///
/// Publishable anahtar istemcide durabilir; yetkiyi RLS sağlar.
/// `secret` / `service_role` anahtarı asla buraya konmamalı.
abstract final class SupabaseConfig {
  /// Proje adresi.
  static const url = 'https://abtsartfcblqeqwpsdxl.supabase.co';

  /// Publishable (anon) anahtar.
  static const publishableKey =
      'sb_publishable__upV5nCQ2V3Z9Je96LvvEw_e2lZkUT_';
}
