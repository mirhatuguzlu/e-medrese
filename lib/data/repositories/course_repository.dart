import 'dart:convert';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

/// Kullanıcının medreselerine hocaların verdiği kurslar.
final assignmentsProvider =
    FutureProvider<Result<List<CourseAssignment>, AppFailure>>((ref) {
      if (ref.watch(sessionProvider).valueOrNull == null) return const Ok([]);
      return ref.watch(courseRepositoryProvider).assignments();
    });

/// Öğrencilerin verilen kurstaki ilerlemesi (hocalar).
final AutoDisposeFutureProviderFamily<
  Result<List<StudentCourseProgress>, AppFailure>,
  ({String medreseId, String courseId})
>
assignmentProgressProvider = FutureProvider.autoDispose
    .family<
      Result<List<StudentCourseProgress>, AppFailure>,
      ({String medreseId, String courseId})
    >(
      (ref, key) => ref
          .watch(courseRepositoryProvider)
          .assignmentProgress(medreseId: key.medreseId, courseId: key.courseId),
    );

/// Kullanıcının bir dersteki notları.
final AutoDisposeFutureProviderFamily<
  Result<List<LessonNote>, AppFailure>,
  String
>
lessonNotesProvider = FutureProvider.autoDispose
    .family<Result<List<LessonNote>, AppFailure>, String>(
      (ref, lessonId) => ref.watch(courseRepositoryProvider).notes(lessonId),
    );

/// Kullanıcı uygulama yöneticisi mi (kurs yönetimi).
final courseAdminProvider = FutureProvider<Result<bool, AppFailure>>((ref) {
  if (ref.watch(sessionProvider).valueOrNull == null) return const Ok(false);
  return ref.watch(courseRepositoryProvider).isAdmin();
});

/// Yönetim için taslaklar dahil bütün kurslar.
final adminCoursesProvider = FutureProvider<Result<List<Course>, AppFailure>>((
  ref,
) {
  ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
  return ref.watch(courseRepositoryProvider).allCourses();
});

/// Kurslar, ders ilerlemesi ve kurs rızası (KVKK m.6).
class CourseRepository {
  /// Supabase istemcisiyle oluşturur.
  CourseRepository(this._client);

  final SupabaseClient _client;

  /// Yayındaki kurslar, sırasıyla. Yönetici RLS'te taslakları da görür;
  /// katalogda gösterilmezler.
  Future<Result<List<Course>, AppFailure>> courses() =>
      _courses(onlyPublished: true);

  /// Taslaklar dahil bütün kurslar (yalnız yönetici; RLS).
  Future<Result<List<Course>, AppFailure>> allCourses() =>
      _courses(onlyPublished: false);

  // shortcut: bütün kurslar dersleriyle tek sorguda gelir; katalog yüzlerce
  // kursa çıkınca sayfalı sorguya geçilmeli.
  Future<Result<List<Course>, AppFailure>> _courses({
    required bool onlyPublished,
  }) => guardSupabase(() async {
    var query = _client
        .from('courses')
        .select(
          'id, title, subtitle, description, teacher, category, cover_url, '
          'published, lessons(id, position, section, title, description, '
          'youtube_id, duration_seconds)',
        );
    if (onlyPublished) query = query.eq('published', true);
    final rows = await query
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

  /// İlerlemeyi kaydeder; ders sunucuda tamamlanmış sayılıyorsa `true`.
  /// Sunucu izlenen süreyi gerçek zamana göre sınırlar, tamamlanmayı %90
  /// izlenmeden kabul etmez; rıza yoksa reddeder.
  Future<Result<bool, AppFailure>> saveProgress({
    required String lessonId,
    required int positionSeconds,
    required int watchedSeconds,
    required bool completed,
  }) => guardSupabase(() async {
    final row = await _client
        .from('lesson_progress')
        .upsert({
          'user_id': _client.auth.currentUser!.id,
          'lesson_id': lessonId,
          'position_seconds': positionSeconds,
          'watched_seconds': watchedSeconds,
          if (completed)
            'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('completed_at')
        .single();
    return row['completed_at'] != null;
  });

  /// Kullanıcının geçerli (hocalarla paylaşımı da kapsayan, 2.) sürüm rızası
  /// var mı. Eski sürüm rıza verenlere yeniden sorulur.
  Future<Result<bool, AppFailure>> hasConsent() => guardSupabase(() async {
    final row = await _client
        .from('course_consents')
        .select('version')
        .maybeSingle();
    return (row?['version'] as int? ?? 0) >= 2;
  });

  // Hocanın verdiği kurslar ------------------------------------------------

  /// Kullanıcının medreselerine verilen kurslar (RLS: üye olduğu medreseler).
  Future<Result<List<CourseAssignment>, AppFailure>> assignments() =>
      guardSupabase(() async {
        final rows = await _client
            .from('course_assignments')
            .select('medrese_id, course_id, due_on, created_at, medreses(name)')
            .order('created_at', ascending: false);
        return rows.map(CourseAssignment.fromJson).toList();
      });

  /// [medreseId]'ye [courseId] kursunu verir (hocalar); öğrencilere bildirim
  /// gider.
  Future<Result<void, AppFailure>> assign({
    required String medreseId,
    required String courseId,
    required DateTime? dueOn,
  }) => guardSupabase(
    () => _client.from('course_assignments').insert({
      'medrese_id': medreseId,
      'course_id': courseId,
      if (dueOn != null)
        'due_on': DateTime.utc(
          dueOn.year,
          dueOn.month,
          dueOn.day,
        ).toIso8601String().substring(0, 10),
    }),
  );

  /// Verilen kursu geri alır; öğrencilerin ilerlemesi silinmez.
  Future<Result<void, AppFailure>> unassign({
    required String medreseId,
    required String courseId,
  }) => guardSupabase(
    () => _client
        .from('course_assignments')
        .delete()
        .eq('medrese_id', medreseId)
        .eq('course_id', courseId),
  );

  /// Medresenin öğrencilerinin verilen kurstaki ilerlemesi (hocalar).
  Future<Result<List<StudentCourseProgress>, AppFailure>> assignmentProgress({
    required String medreseId,
    required String courseId,
  }) => guardSupabase(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'assignment_progress',
      params: {'m': medreseId, 'c': courseId},
    );
    return [
      for (final r in rows)
        StudentCourseProgress.fromJson(r as Map<String, dynamic>),
    ];
  });

  // Ders notları -------------------------------------------------------------

  /// Kullanıcının [lessonId] dersindeki notları, videodaki sırasıyla.
  Future<Result<List<LessonNote>, AppFailure>> notes(String lessonId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('lesson_notes')
            .select('id, lesson_id, seconds, body, created_at')
            .eq('lesson_id', lessonId)
            .order('seconds');
        return rows.map(LessonNote.fromJson).toList();
      });

  /// Dersin [seconds]. saniyesine not ekler.
  Future<Result<void, AppFailure>> addNote({
    required String lessonId,
    required int seconds,
    required String body,
  }) => guardSupabase(
    () => _client.from('lesson_notes').insert({
      'lesson_id': lessonId,
      'seconds': seconds,
      'body': body.trim(),
    }),
  );

  /// Notu siler.
  Future<Result<void, AppFailure>> deleteNote(String id) =>
      guardSupabase(() => _client.from('lesson_notes').delete().eq('id', id));

  /// Rıza verir.
  Future<Result<void, AppFailure>> giveConsent() =>
      guardSupabase(() => _client.rpc<void>('give_course_consent'));

  /// Rızayı geri alır; bütün ders ilerlemesi silinir.
  Future<Result<void, AppFailure>> revokeConsent() =>
      guardSupabase(() => _client.rpc<void>('revoke_course_consent'));

  // Yönetim (uygulama yöneticileri; RLS `is_app_admin()`) -------------------

  /// Kullanıcı uygulama yöneticisi mi.
  Future<Result<bool, AppFailure>> isAdmin() => guardSupabase(() async {
    final row = await _client
        .from('app_admins')
        .select('user_id')
        .maybeSingle();
    return row != null;
  });

  /// Kursu ekler ([id] yoksa) ya da günceller; kimliğini döner.
  Future<Result<String, AppFailure>> saveCourse({
    required String? id,
    required String title,
    required String subtitle,
    required String description,
    required String teacher,
    required CourseCategory category,
    required bool published,
  }) => guardSupabase(() async {
    final row = {
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'teacher': teacher.trim(),
      'category': category.name,
      'published': published,
    };
    if (id != null) {
      await _client.from('courses').update(row).eq('id', id);
      return id;
    }
    final created = await _client
        .from('courses')
        .insert(row)
        .select('id')
        .single();
    return created['id'] as String;
  });

  /// Kursu, derslerini ve öğrencilerin o derslerdeki ilerlemesini siler.
  Future<Result<void, AppFailure>> deleteCourse(String id) =>
      guardSupabase(() => _client.from('courses').delete().eq('id', id));

  /// Dersi ekler ([id] yoksa, [position] sırasına) ya da günceller.
  Future<Result<void, AppFailure>> saveLesson({
    required String? id,
    required String courseId,
    required int position,
    required String section,
    required String title,
    required String description,
    required String youtubeId,
    required int durationSeconds,
  }) => guardSupabase(() async {
    final row = {
      'section': section.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'youtube_id': youtubeId,
      'duration_seconds': durationSeconds,
    };
    if (id != null) {
      await _client.from('lessons').update(row).eq('id', id);
    } else {
      await _client.from('lessons').insert({
        ...row,
        'course_id': courseId,
        'position': position,
      });
    }
  });

  /// Kursun derslerini [lessonIds] sırasına dizer (hepsi verilmeli).
  Future<Result<void, AppFailure>> reorderLessons(
    String courseId,
    List<String> lessonIds,
  ) => guardSupabase(
    () => _client.rpc<void>(
      'reorder_lessons',
      params: {'p_course': courseId, 'p_ids': lessonIds},
    ),
  );

  /// Dersi ve öğrencilerin o dersteki ilerlemesini siler.
  Future<Result<void, AppFailure>> deleteLesson(String id) =>
      guardSupabase(() => _client.from('lessons').delete().eq('id', id));

  /// Videonun YouTube'daki başlığı (oEmbed, anahtarsız); alınamazsa `null`.
  Future<String?> videoTitle(String youtubeId) async {
    try {
      final response = await http
          .get(
            Uri.https('www.youtube.com', '/oembed', {
              'url': 'https://www.youtube.com/watch?v=$youtubeId',
              'format': 'json',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['title'] as String?;
    } on Exception {
      return null;
    }
  }
}
