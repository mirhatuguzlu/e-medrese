import 'package:e_medrese/core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(Supabase.instance.client.auth),
);

/// Oturum değişiklikleri; `null` = giriş yapılmamış.
final sessionProvider = StreamProvider<Session?>(
  (ref) => ref.watch(authRepositoryProvider).sessionChanges,
);

/// E-posta/şifre ile giriş, kayıt ve çıkış.
class AuthRepository {
  /// Supabase auth istemcisiyle oluşturur.
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  /// Açılışta mevcut oturumu, sonra her değişikliği yayar.
  Stream<Session?> get sessionChanges =>
      _auth.onAuthStateChange.map((state) => state.session);

  /// E-posta ve şifreyle giriş yapar.
  Future<Result<void, AppFailure>> signIn({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithPassword(email: email.trim(), password: password),
  );

  /// Yeni hesap açar. Değer `false` ise e-posta onayı bekleniyordur.
  Future<Result<bool, AppFailure>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => _guard(() async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
    return response.session != null;
  });

  /// Oturumu kapatır.
  Future<Result<void, AppFailure>> signOut() => _guard(_auth.signOut);

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
    'invalid_credentials' => const InvalidCredentialsFailure(),
    'email_not_confirmed' => const ValidationFailure(
      'Giriş yapmadan önce e-postandaki onay bağlantısına tıkla.',
    ),
    'user_already_exists' => const ValidationFailure(
      'Bu e-posta zaten kayıtlı.',
      field: 'email',
    ),
    'weak_password' => const ValidationFailure(
      'Şifre çok zayıf; en az 6 karakter kullan.',
      field: 'password',
    ),
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      const ValidationFailure('Çok fazla deneme yapıldı, biraz bekle.'),
    _ => UnexpectedFailure(e.message),
  };
}
