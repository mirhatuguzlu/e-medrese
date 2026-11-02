import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [ConsentRepository].
final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(Supabase.instance.client),
);

/// Giriş yapan kullanıcı görev takibine açık rıza verdi mi.
final taskConsentProvider = FutureProvider<Result<bool, AppFailure>>((ref) {
  if (ref.watch(sessionProvider).valueOrNull == null) return const Ok(false);
  return ref.watch(consentRepositoryProvider).hasTaskConsent();
});

/// Görev takibi açık rızası (KVKK m.6). Rıza yoksa sunucu girdi yazdırmaz.
class ConsentRepository {
  /// Supabase istemcisiyle oluşturur.
  ConsentRepository(this._client);

  final SupabaseClient _client;

  /// Kullanıcının rızası var mı.
  Future<Result<bool, AppFailure>> hasTaskConsent() => guardSupabase(() async {
    final row = await _client
        .from('task_consents')
        .select('user_id')
        .maybeSingle();
    return row != null;
  });

  /// Rıza verir.
  Future<Result<void, AppFailure>> giveTaskConsent() =>
      guardSupabase(() => _client.rpc<void>('give_task_consent'));

  /// Rızayı geri alır; görev girdileri ve haftalık puanlar silinir.
  Future<Result<void, AppFailure>> revokeTaskConsent() =>
      guardSupabase(() => _client.rpc<void>('revoke_task_consent'));
}
