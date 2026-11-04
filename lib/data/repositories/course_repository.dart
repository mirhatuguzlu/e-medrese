import 'dart:convert';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/legacy_saved_courses.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/feed.dart';
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

/// Kullanıcının kaydettiği kurslar, en son kaydedilen başta.
final savedCoursesProvider = FutureProvider<Result<List<String>, AppFailure>>((
  ref,
) async {
  final user = ref.watch(sessionProvider).valueOrNull?.user.id;
  if (user == null) return const Ok([]);
  final repo = ref.watch(courseRepositoryProvider);
  // 2.9'da telefona kaydedilenler rıza 4 verilince sunucuya taşınır.
  if (await ref.watch(courseConsentProvider.future) case Ok(value: true)) {
    final legacy = ref.watch(legacySavedCoursesProvider);
    final local = await legacy.read(user);
    final courses = await ref.watch(coursesProvider.future);
    if (courses case Ok(:final value) when local.isNotEmpty) {
      // Yayından kalkan kurslar taşınmaz (sunucu kabul etmez).
      final published = {for (final c in value) c.id};
      local.removeWhere((id, _) => !published.contains(id));
      // Taşınamazsa telefonda kalır, sonra yeniden denenir.
      if (local.isEmpty || await repo.importSaved(local) is Ok) {
        await legacy.remove(user);
      }
    }
  }
  return repo.savedCourses();
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

/// Tekrar sorularındaki ilk cevaplar.
final questionResultsProvider =
    FutureProvider<Result<QuestionResults, AppFailure>>((ref) {
      if (ref.watch(sessionProvider).valueOrNull == null) return const Ok({});
      return ref.watch(courseRepositoryProvider).questionResults();
    });

/// Medresenin bir ders hakkındaki tartışması.
final AutoDisposeFutureProviderFamily<
  Result<List<LessonComment>, AppFailure>,
  ({String medreseId, String lessonId})
>
lessonCommentsProvider = FutureProvider.autoDispose
    .family<
      Result<List<LessonComment>, AppFailure>,
      ({String medreseId, String lessonId})
    >(
      (ref, key) => ref
          .watch(courseRepositoryProvider)
          .lessonComments(medreseId: key.medreseId, lessonId: key.lessonId),
    );

/// Medresede bir kursun bütün derslerinde yazılanlar, yeniden eskiye.
final AutoDisposeFutureProviderFamily<
  Result<List<LessonComment>, AppFailure>,
  ({String medreseId, Course course})
>
courseCommentsProvider = FutureProvider.autoDispose
    .family<
      Result<List<LessonComment>, AppFailure>,
      ({String medreseId, Course course})
    >(
      (ref, key) => ref
          .watch(courseRepositoryProvider)
          .courseComments(
            medreseId: key.medreseId,
            lessonIds: [for (final l in key.course.lessons) l.id],
          ),
    );

/// Kullanıcının icazet istekleri ve hocası olduğu medreselere gelenler.
final icazetRequestsProvider =
    FutureProvider<Result<List<IcazetRequest>, AppFailure>>((ref) {
      if (ref.watch(sessionProvider).valueOrNull == null) return const Ok([]);
      return ref.watch(courseRepositoryProvider).icazetRequests();
    });

/// Kursların ortalama puanları.
final courseRatingsProvider =
    FutureProvider<Result<Map<String, CourseRating>, AppFailure>>((ref) {
      ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
      return ref.watch(courseRepositoryProvider).ratings();
    });

/// Kursun değerlendirmeleri.
final AutoDisposeFutureProviderFamily<
  Result<List<CourseReview>, AppFailure>,
  String
>
courseReviewsProvider = FutureProvider.autoDispose
    .family<Result<List<CourseReview>, AppFailure>, String>(
      (ref, courseId) => ref.watch(courseRepositoryProvider).reviews(courseId),
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
          'level, outcomes, '
          'published, lessons(id, position, section, title, description, '
          'youtube_id, duration_seconds, lesson_questions(id, lesson_id, '
          'position, question, options, answer, explanation), '
          'lesson_resources(id, position, title, url))',
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

  /// Geçerli rıza metninin sürümü (`assets/legal/kurs_riza.txt`). 3: tekrar
  /// soruları, değerlendirmeler, icazet ve haftalık puan da kapsanır. 4:
  /// kaydedilen kurslar da kapsanır.
  static const consentVersion = 4;

  /// Kullanıcının geçerli sürüm rızası var mı. Eski sürüm rıza verenlere
  /// yeniden sorulur.
  Future<Result<bool, AppFailure>> hasConsent() => guardSupabase(() async {
    final row = await _client
        .from('course_consents')
        .select('version')
        .maybeSingle();
    return (row?['version'] as int? ?? 0) >= consentVersion;
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
  Future<Result<void, AppFailure>> giveConsent() => guardSupabase(
    () =>
        _client.rpc<void>('give_course_consent', params: {'v': consentVersion}),
  );

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
    CourseLevel? level,
    String outcomes = '',
  }) => guardSupabase(() async {
    final row = {
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'teacher': teacher.trim(),
      'category': category.name,
      'published': published,
      'level': level?.name,
      'outcomes': outcomes.trim(),
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

  // Tekrar soruları ----------------------------------------------------------

  /// Kullanıcının ilk cevapları: soru kimliği -> doğru mu.
  Future<Result<QuestionResults, AppFailure>> questionResults() =>
      guardSupabase(() async {
        final rows = await _client
            .from('question_answers')
            .select('question_id, correct');
        return {
          for (final r in rows)
            r['question_id'] as String: r['correct'] as bool,
        };
      });

  /// Sorunun ilk cevabını kaydeder; daha önce cevaplandıysa bir şey olmaz.
  /// Doğruluk sunucuda hesaplanır; ders bitmemişse ya da rıza yoksa reddedilir.
  Future<Result<void, AppFailure>> answerQuestion({
    required String questionId,
    required int choice,
  }) => guardSupabase(
    () => _client.from('question_answers').upsert({
      'user_id': _client.auth.currentUser!.id,
      'question_id': questionId,
      'choice': choice,
    }, ignoreDuplicates: true),
  );

  /// Soruyu ekler ([id] yoksa) ya da günceller (yönetici).
  Future<Result<void, AppFailure>> saveQuestion({
    required String? id,
    required String lessonId,
    required int position,
    required String question,
    required List<String> options,
    required int answer,
    required String explanation,
  }) => guardSupabase(() async {
    final row = {
      'question': question.trim(),
      'options': [for (final o in options) o.trim()],
      'answer': answer,
      'explanation': explanation.trim(),
    };
    if (id != null) {
      await _client.from('lesson_questions').update(row).eq('id', id);
    } else {
      await _client.from('lesson_questions').insert({
        ...row,
        'lesson_id': lessonId,
        'position': position,
      });
    }
  });

  /// Soruyu ve öğrencilerin cevaplarını siler (yönetici).
  Future<Result<void, AppFailure>> deleteQuestion(String id) => guardSupabase(
    () => _client.from('lesson_questions').delete().eq('id', id),
  );

  // Ders kaynakları ----------------------------------------------------------

  /// Derse kaynak linki ekler (yönetici).
  Future<Result<void, AppFailure>> addResource({
    required String lessonId,
    required int position,
    required String title,
    required String url,
  }) => guardSupabase(
    () => _client.from('lesson_resources').insert({
      'lesson_id': lessonId,
      'position': position,
      'title': title.trim(),
      'url': url,
    }),
  );

  /// Kaynağı siler (yönetici).
  Future<Result<void, AppFailure>> deleteResource(String id) => guardSupabase(
    () => _client.from('lesson_resources').delete().eq('id', id),
  );

  // Medrese içi ders tartışması ----------------------------------------------

  /// [medreseId]'nin [lessonId] dersi hakkında yazılanlar, eskiden yeniye.
  Future<Result<List<LessonComment>, AppFailure>> lessonComments({
    required String medreseId,
    required String lessonId,
  }) => guardSupabase(() async {
    final rows = await _client
        .from('lesson_comments')
        .select(
          'id, author_id, seconds, body, created_at, '
          'author:profiles(full_name)',
        )
        .eq('medrese_id', medreseId)
        .eq('lesson_id', lessonId)
        .order('created_at');
    return rows.map(LessonComment.fromJson).toList();
  });

  /// [medreseId]'nin [lessonIds] derslerinde yazılanlar, yeniden eskiye.
  Future<Result<List<LessonComment>, AppFailure>> courseComments({
    required String medreseId,
    required List<String> lessonIds,
  }) => guardSupabase(() async {
    final rows = await _client
        .from('lesson_comments')
        .select(
          'id, lesson_id, author_id, seconds, body, created_at, '
          'author:profiles(full_name)',
        )
        .eq('medrese_id', medreseId)
        .inFilter('lesson_id', lessonIds)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map(LessonComment.fromJson).toList();
  });

  /// Tartışmaya yazar; [seconds] verilirse videonun o anına bağlanır.
  Future<Result<void, AppFailure>> addLessonComment({
    required String medreseId,
    required String lessonId,
    required String body,
    int? seconds,
  }) => guardSupabase(
    () => _client.from('lesson_comments').insert({
      'medrese_id': medreseId,
      'lesson_id': lessonId,
      'body': body.trim(),
      'seconds': ?seconds,
    }),
  );

  /// Yazıyı siler (yazan ya da medresenin kurucusu/hocaları).
  Future<Result<void, AppFailure>> deleteLessonComment(String id) =>
      guardSupabase(
        () => _client.from('lesson_comments').delete().eq('id', id),
      );

  /// Ders tartışmasındaki bir yazıyı ([lessonCommentId]) ya da bir
  /// değerlendirmeyi ([reviewId]) şikayet eder.
  Future<Result<void, AppFailure>> report({
    required ReportReason reason,
    required String note,
    String? lessonCommentId,
    String? reviewId,
  }) => guardSupabase(
    () => _client.rpc<void>(
      'report_course_content',
      params: {
        'lc': lessonCommentId,
        'r': reviewId,
        'reason': reason.name,
        'note': note.trim(),
      },
    ),
  );

  // İcazet --------------------------------------------------------------------

  /// Kullanıcının istekleri ve hocası olduğu medreselere gelen istekler.
  Future<Result<List<IcazetRequest>, AppFailure>> icazetRequests() =>
      guardSupabase(() async {
        final rows = await _client
            .from('icazet_requests')
            .select(
              'id, medrese_id, course_id, user_id, status, note, '
              'decided_by_name, decided_at, created_at, '
              'student:profiles!icazet_requests_user_id_fkey(full_name)',
            )
            .order('created_at', ascending: false);
        return rows.map(IcazetRequest.fromJson).toList();
      });

  /// Bitirilen, hocanın verdiği kurs için icazet ister.
  Future<Result<void, AppFailure>> requestIcazet({
    required String medreseId,
    required String courseId,
  }) => guardSupabase(
    () => _client.rpc<void>(
      'request_icazet',
      params: {'m': medreseId, 'c': courseId},
    ),
  );

  /// İsteği onaylar ya da geri çevirir (hocalar).
  Future<Result<void, AppFailure>> decideIcazet({
    required String id,
    required bool approve,
    required String note,
  }) => guardSupabase(
    () => _client.rpc<void>(
      'decide_icazet',
      params: {'r': id, 'approve': approve, 'note': note.trim()},
    ),
  );

  // Değerlendirmeler ----------------------------------------------------------

  /// Yayındaki kursların ortalama puanları, kurs kimliğine göre.
  Future<Result<Map<String, CourseRating>, AppFailure>> ratings() =>
      guardSupabase(() async {
        final rows = await _client.rpc<List<dynamic>>('course_ratings');
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['course_id'] as String: (
              average: (r['average'] as num).toDouble(),
              count: r['count'] as int,
            ),
        };
      });

  /// Kaydedilen kurslar, en son kaydedilen başta (RLS: yalnız kendisininki).
  Future<Result<List<String>, AppFailure>> savedCourses() =>
      guardSupabase(() async {
        final rows = await _client
            .from('saved_courses')
            .select('course_id')
            .order('created_at', ascending: false);
        return [for (final r in rows) r['course_id'] as String];
      });

  /// Telefonda kalan kayıtları kaydetme zamanlarıyla sunucuya yazar;
  /// zaten kayıtlı olanlar atlanır.
  Future<Result<void, AppFailure>> importSaved(Map<String, DateTime> saved) =>
      guardSupabase(
        () => _client.from('saved_courses').upsert([
          for (final e in saved.entries)
            {
              'course_id': e.key,
              'created_at': e.value.toUtc().toIso8601String(),
            },
        ], ignoreDuplicates: true),
      );

  /// Kursu kaydeder ya da kayıtlılardan çıkarır (kaydetmek rıza 4 ister).
  Future<Result<void, AppFailure>> setSaved(
    String courseId, {
    required bool saved,
  }) => guardSupabase(
    () => saved
        ? _client
              .from('saved_courses')
              .upsert({'course_id': courseId}, ignoreDuplicates: true)
        : _client.from('saved_courses').delete().eq('course_id', courseId),
  );

  /// Kursun isimsiz değerlendirmeleri; kullanıcınınki başta.
  Future<Result<List<CourseReview>, AppFailure>> reviews(String courseId) =>
      guardSupabase(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'course_reviews_of',
          params: {'c': courseId},
        );
        return [
          for (final r in rows)
            CourseReview.fromJson(r as Map<String, dynamic>),
        ];
      });

  /// Değerlendirmeyi yazar ya da günceller (en az bir ders bitmiş olmalı).
  Future<Result<void, AppFailure>> saveReview({
    required String courseId,
    required int rating,
    required String body,
  }) => guardSupabase(
    () => _client.rpc<void>(
      'save_review',
      params: {'c': courseId, 'rating': rating, 'body': body.trim()},
    ),
  );

  /// Değerlendirmeyi siler (kendi değerlendirmesi ya da yönetici).
  Future<Result<void, AppFailure>> deleteReview(String id) =>
      guardSupabase(() => _client.from('course_reviews').delete().eq('id', id));

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
