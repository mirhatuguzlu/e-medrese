import 'package:e_medrese/core/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase çağrısını çalıştırır; hataları Türkçe [AppFailure]'a çevirir.
///
/// Mesajlar `supabase/migrations` içindeki `raise exception` metinleridir.
Future<Result<T, AppFailure>> guardSupabase<T>(
  Future<T> Function() action,
) async {
  try {
    return Ok(await action());
  } on PostgrestException catch (e) {
    return Err(switch ((e.code, e.message)) {
      (_, 'invalid invite code') => const ValidationFailure(
        'Bu kodla bir medrese bulunamadı.',
        field: 'code',
      ),
      (_, 'already a member') => const ValidationFailure(
        'Zaten bu medresenin üyesisin.',
        field: 'code',
      ),
      (_, 'user not found') => const ValidationFailure(
        'Bu e-postayla kayıtlı bir kullanıcı yok.',
        field: 'email',
      ),
      ('42501', _) || (_, 'not allowed') => const UnauthorizedFailure(),
      _ => UnexpectedFailure(e.message),
    });
  } on Exception catch (e, st) {
    return Err(ExceptionMapper.fromException(e, st));
  }
}
