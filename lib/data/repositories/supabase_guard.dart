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
      (_, 'chest not available') => const ValidationFailure(
        'Bu sandık artık açılamaz; puanın geçmişine aktarıldı.',
      ),
      (_, 'task consent required') => const ValidationFailure(
        'Öğrenci görev takibine açık rıza vermedi.',
      ),
      (_, 'transfer ownership first') => const ValidationFailure(
        'Kurucusu olduğun medreselerde önce başka bir üyeyi kurucu yap.',
      ),
      (_, 'not enough points') => const ValidationFailure(
        'Bu ödül için birikmiş puanın yetmiyor.',
      ),
      (_, 'already requested') => const ValidationFailure(
        'Bu ödülü zaten istedin; hocanın teslim etmesini bekle.',
      ),
      (_, 'not pending') => const ValidationFailure(
        'Bu istek zaten teslim edildi ya da reddedildi.',
      ),
      (_, 'reason required') => const ValidationFailure(
        'Reddetme nedenini yaz.',
        field: 'reason',
      ),
      ('42501', _) ||
      (_, 'not allowed') ||
      (_, 'not a student of this medrese') ||
      (_, 'not staff of this medrese') => const UnauthorizedFailure(),
      _ => UnexpectedFailure(e.message),
    });
  } on Exception catch (e, st) {
    return Err(ExceptionMapper.fromException(e, st));
  }
}
