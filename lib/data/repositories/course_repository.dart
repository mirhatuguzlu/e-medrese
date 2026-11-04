import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [CourseRepository].
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(Supabase.instance.client),
);

/// Yayındaki kurslar ve dersleri.
final coursesProvider = FutureProvider<Result<List<Course>, AppFailure>>((ref) {
  ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
  return ref.watch(courseRepositoryProvider).courses();
});

/// Giriş yapan kullanıcının ders ilerlemeleri, ders kimliğine göre.
final lessonProgressProvider =
    FutureProvider<Result<Map<String, LessonProgress>, AppFailure>>((ref) {
      if (ref.watch(sessionProvider).valueOrNull == null) return const Ok({});
      return ref.watch(courseRepositoryProvider).progress();
    });

/// Kullanıcı kurs ilerlemesine açık rıza verdi mi.
final courseConsentProvider = FutureProvider<Result<bool, AppFailure>>((ref) {
  if (ref.watch(sessionProvider).valueOrNull == null) return const Ok(false);
  return ref.watch(courseRepositoryProvider).hasConsent();
});

/// Kurslar, ders ilerlemesi ve kurs rızası (KVKK m.6).
class CourseRepository {
  /// Supabase istemcisiyle oluşturur.
  CourseRepository(this._client);

  final SupabaseClient _client;

  /// Yayındaki kurslar (RLS), sırasıyla.
  // shortcut: bütün kurslar dersleriyle tek sorguda gelir; katalog yüzlerce
  // kursa çıkınca sayfalı sorguya geçilmeli.
  Future<Result<List<Course>, AppFailure>> courses() => guardSupabase(() async {
    final rows = await _client
        .from('courses')
        .select(
          'id, title, subtitle, description, teacher, category, cover_url, '
          'lessons(id, position, section, title, description, youtube_id, '
          'duration_seconds)',
        )
        .order('sort')
        .order('created_at', ascending: false);
    return rows.map(Course.fromJson).toList();
  });

  /// Kullanıcının ilerlemeleri (RLS yalnız kendi satırlarını döner).
  Future<Result<Map<String, LessonProgress>, AppFailure>> progress() =>
      guardSupabase(() async {
        final rows = await _client
            .from('lesson_progress')
            .select(
              'lesson_id, position_seconds, watched_seconds, completed_at, '
              'updated_at',
            );
        return {
          for (final p in rows.map(LessonProgress.fromJson)) p.lessonId: p,
        };
      });

  /// İlerlemeyi kaydeder. Sunucu izlenen en ileri saniyeyi ve tamamlanmayı
  /// geri almaz; rıza yoksa reddeder.
  Future<Result<void, AppFailure>> saveProgress({
    required String lessonId,
    required int positionSeconds,
    required int watchedSeconds,
    required bool completed,
  }) => guardSupabase(
    () => _client.from('lesson_progress').upsert({
      'user_id': _client.auth.currentUser!.id,
      'lesson_id': lessonId,
      'position_seconds': positionSeconds,
      'watched_seconds': watchedSeconds,
      if (completed) 'completed_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );

  /// Kullanıcının rızası var mı.
  Future<Result<bool, AppFailure>> hasConsent() => guardSupabase(() async {
    final row = await _client
        .from('course_consents')
        .select('user_id')
        .maybeSingle();
    return row != null;
  });

  /// Rıza verir.
  Future<Result<void, AppFailure>> giveConsent() =>
      guardSupabase(() => _client.rpc<void>('give_course_consent'));

  /// Rızayı geri alır; bütün ders ilerlemesi silinir.
  Future<Result<void, AppFailure>> revokeConsent() =>
      guardSupabase(() => _client.rpc<void>('revoke_course_consent'));
}
