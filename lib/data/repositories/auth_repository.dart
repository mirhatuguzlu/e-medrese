import 'package:e_medrese/core/constants/supabase_config.dart';
import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    Supabase.instance.client,
    GoogleSignIn(
      serverClientId: SupabaseConfig.googleWebClientId,
      clientId: SupabaseConfig.googleIosClientId.isEmpty
          ? null
          : SupabaseConfig.googleIosClientId,
    ),
  ),
);

/// Oturum değişiklikleri; `null` = giriş yapılmamış.
final sessionProvider = StreamProvider<Session?>(
  (ref) => ref.watch(authRepositoryProvider).sessionChanges,
);

/// Google ile giriş/kayıt, çıkış ve hesap silme.
class AuthRepository {
  /// Supabase istemcisiyle oluşturur.
  AuthRepository(this._client, this._google);

  final SupabaseClient _client;
  final GoogleSignIn _google;

  GoTrueClient get _auth => _client.auth;

  /// Açılışta mevcut oturumu, sonra her değişikliği yayar.
  Stream<Session?> get sessionChanges =>
      _auth.onAuthStateChange.map((state) => state.session);

  /// Google hesabıyla giriş yapar; hesap yoksa açılır. Değer `false` ise
  /// kullanıcı hesap seçmeden vazgeçmiştir.
  Future<Result<bool, AppFailure>> signInWithGoogle() => _guard(() async {
    final account = await _google.signIn();
    if (account == null) return false;
    final tokens = await account.authentication;
    final idToken = tokens.idToken;
    if (idToken == null) {
      throw const AuthException('Google kimlik belirteci alınamadı.');
    }
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: tokens.accessToken,
    );
    return true;
  });

  /// Oturumu kapatır. Google oturumu da kapanır ki sonraki girişte hesap
  /// seçilebilsin.
  Future<Result<void, AppFailure>> signOut() => _guard(() async {
    if (await _google.isSignedIn()) await _google.signOut();
    await _auth.signOut();
  });

  /// Hesabı ve bütün verilerini siler, sonra oturumu kapatır. Başka üyesi
  /// olan bir medresenin kurucusuysa önce kurucu devretmesi gerekir.
  Future<Result<void, AppFailure>> deleteAccount() async {
    final deleted = await guardSupabase(
      () => _client.rpc<void>('delete_my_account'),
    );
    if (deleted is Err) return deleted;
    return signOut();
  }

  Future<Result<T, AppFailure>> _guard<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on AuthRetryableFetchException {
      return const Err(ConnectionFailure());
    } on AuthException catch (e) {
      return Err(_mapAuthException(e));
    } on Exception catch (e, st) {
      return Err(ExceptionMapper.fromException(e, st));
    }
  }

  static AppFailure _mapAuthException(AuthException e) => switch (e.code) {
    'over_request_rate_limit' => const ValidationFailure(
      'Çok fazla deneme yapıldı, biraz bekle.',
    ),
    _ => UnexpectedFailure(e.message),
  };
}
