import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/consent_repository.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:e_medrese/services/update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testMedrese = Medrese(
  id: 'm1',
  name: 'Süleymaniye',
  description: '',
  inviteCode: 'AB12CD34',
  myRole: MemberRole.owner,
);

class FakeMedreseRepository implements MedreseRepository {
  final medreses = <Medrese>[];
  final memberList = <Member>[];
  final calls = <String>[];

  @override
  Future<Result<List<Member>, AppFailure>> members(String medreseId) async =>
      Ok(List.of(memberList));

  @override
  Future<Result<void, AppFailure>> addMemberByEmail({
    required String medreseId,
    required String email,
    required MemberRole role,
  }) async {
    calls.add('add $email ${role.name}');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> removeMember({
    required String medreseId,
    required String userId,
  }) async {
    calls.add('remove $userId');
    memberList.removeWhere((m) => m.userId == userId);
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> changeRole({
    required String medreseId,
    required String userId,
    required MemberRole role,
  }) async {
    calls.add('role $userId ${role.name}');
    final i = memberList.indexWhere((m) => m.userId == userId);
    final m = memberList[i];
    memberList[i] = Member(
      userId: m.userId,
      name: m.name,
      role: role,
      joinedAt: m.joinedAt,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> transferOwnership({
    required String medreseId,
    required String userId,
  }) async {
    calls.add('owner $userId');
    return const Ok(null);
  }

  @override
  Future<Result<List<Medrese>, AppFailure>> myMedreses(String userId) async =>
      Ok(List.of(medreses));

  @override
  Future<Result<Medrese, AppFailure>> create({
    required String name,
    required String description,
  }) async {
    medreses.add(testMedrese);
    return const Ok(testMedrese);
  }

  @override
  Future<Result<String, AppFailure>> join(String code) async {
    if (code.trim() != 'AB12CD34') {
      return const Err(ValidationFailure('Bu kodla bir medrese bulunamadı.'));
    }
    medreses.add(testMedrese);
    return const Ok('m1');
  }
}

final testSession = Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: const User(
    id: 'u1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '',
  ),
);

class FakeFeedRepository implements FeedRepository {
  final announcementList = <Announcement>[];
  final postList = <Post>[];
  final commentList = <Comment>[];
  final calls = <String>[];

  @override
  Future<Result<List<Announcement>, AppFailure>> announcements(
    String medreseId,
  ) async => Ok(List.of(announcementList));

  @override
  Future<Result<void, AppFailure>> createAnnouncement({
    required String medreseId,
    required String title,
    required String body,
  }) async {
    calls.add('announcement $title');
    announcementList.insert(
      0,
      Announcement(
        id: 'a${announcementList.length}',
        title: title,
        body: body,
        authorId: 'u1',
        authorName: 'Hoca',
        createdAt: DateTime(2026),
        edited: false,
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<List<Post>, AppFailure>> posts(String medreseId) async =>
      Ok(List.of(postList));

  @override
  Future<Result<Post?, AppFailure>> post(String id) async =>
      Ok(postList.where((p) => p.id == id).firstOrNull);

  @override
  Future<Result<void, AppFailure>> createPost({
    required String medreseId,
    required String body,
  }) async {
    calls.add('post $body');
    postList.insert(
      0,
      Post(
        id: 'p${postList.length}',
        body: body,
        authorId: 'u1',
        authorName: 'Ali',
        createdAt: DateTime(2026),
        edited: false,
        commentCount: 0,
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> updateAnnouncement({
    required String id,
    required String title,
    required String body,
  }) async {
    calls.add('edit announcement $title');
    final i = announcementList.indexWhere((a) => a.id == id);
    final a = announcementList[i];
    announcementList[i] = Announcement(
      id: a.id,
      title: title,
      body: body,
      authorId: a.authorId,
      authorName: a.authorName,
      createdAt: a.createdAt,
      edited: true,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteAnnouncement(String id) async {
    calls.add('delete announcement $id');
    announcementList.removeWhere((a) => a.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> updatePost({
    required String id,
    required String body,
  }) async {
    calls.add('edit post $body');
    final i = postList.indexWhere((p) => p.id == id);
    postList[i] = postList[i].withBody(body);
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deletePost(String id) async {
    calls.add('delete post $id');
    postList.removeWhere((p) => p.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<int, AppFailure>> postCount({
    required String medreseId,
    required String userId,
  }) async => Ok(postList.where((p) => p.authorId == userId).length);

  @override
  Future<Result<List<Comment>, AppFailure>> comments(String postId) async =>
      Ok(List.of(commentList));

  @override
  Future<Result<void, AppFailure>> deleteComment(String id) async {
    calls.add('delete comment $id');
    commentList.removeWhere((c) => c.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> report({
    required ReportReason reason,
    required String note,
    String? postId,
    String? commentId,
  }) async {
    calls.add('report ${postId ?? commentId} ${reason.name} $note');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> createComment({
    required String postId,
    required String body,
  }) async {
    calls.add('comment $body');
    commentList.add(
      Comment(
        id: 'c${commentList.length}',
        body: body,
        authorId: 'u1',
        authorName: 'Ali',
        createdAt: DateTime(2026),
      ),
    );
    return const Ok(null);
  }
}

/// Migration'daki görev tanımlarının aynısı (JSON ayrıştırmasını da sınar).
final List<TaskDefinition> testTasks = [
  for (final json in [
    {
      'id': 'namaz',
      'title': 'Namaz',
      'description': 'Her vakit için işaretle.',
      'config': {
        'kind': 'checks',
        'items': ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'],
        'target': 35,
        'points': 25,
        'cap': 35,
      },
    },
    {
      'id': 'risale',
      'title': 'Risale-i Nur okuma',
      'description': 'Günde 3 sayfa.',
      'config': {
        'kind': 'pages',
        'presets': [
          {'label': 'Okudum (3 sayfa)', 'pages': 3},
        ],
        'target': 21,
        'points': 25,
        'cap': 63,
      },
    },
    {
      'id': 'ders',
      'title': 'Derse katılım',
      'description': 'Salı ve Perşembe dersleri.',
      'config': {
        'kind': 'checks',
        'items': ['Derse katıldım'],
        'weekdays': [2, 4],
        'target': 2,
        'points': 30,
        'cap': 2,
      },
    },
    {
      'id': 'cuz',
      'title': "Kur'an-ı Kerim (cüz)",
      'description': 'Haftada 1 cüz.',
      'config': {
        'kind': 'pages',
        'presets': [
          {'label': '1 cüz', 'pages': 20},
          {'label': '2 cüz', 'pages': 40},
          {'label': '3 cüz', 'pages': 60},
        ],
        'target': 20,
        'points': 20,
        'cap': 60,
      },
    },
    {
      'id': 'kitap',
      'title': 'İslami kitap okuma',
      'description': 'Günde 10 sayfa.',
      'config': {
        'kind': 'pages',
        'presets': <Map<String, dynamic>>[],
        'target': 70,
        'points': 25,
        'cap': 210,
      },
    },
    {
      'id': 'cevsen',
      'title': 'Cevşen okuma',
      'description': 'Haftada kaç kez bitirdiğini işaretle.',
      'config': {'kind': 'weekly', 'target': 1, 'points': 25, 'cap': 3},
    },
    {
      'id': 'uyum',
      'title': 'Uyum',
      'description': 'Hocanın haftalık değerlendirmesi.',
      'config': {'kind': 'teacher', 'target': 25, 'points': 25, 'cap': 25},
    },
    {
      'id': 'kurs',
      'title': 'Online kurs',
      'description': 'Hocanın verdiği kurslarda bitirdiğin her ders 5 puan.',
      'config': {'kind': 'course', 'target': 1, 'points': 5, 'cap': 10},
    },
  ])
    TaskDefinition.fromJson(json),
];

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({this.taskProgram});

  TaskProgram? taskProgram;
  final entryList = <TaskEntry>[];
  final scoreList = <WeeklyScore>[];
  final grades = <String, UyumGrade>{};
  final calls = <String>[];

  @override
  Future<Result<Map<String, UyumGrade>, AppFailure>> uyumGrades({
    required String medreseId,
    required DateTime periodStart,
  }) async => Ok(Map.of(grades));

  @override
  Future<Result<void, AppFailure>> setUyum({
    required String medreseId,
    required String studentId,
    required num points,
    required String note,
  }) async {
    calls.add('uyum $studentId $points $note');
    grades[studentId] = UyumGrade(
      studentId: studentId,
      points: points,
      note: note,
    );
    return const Ok(null);
  }

  @override
  Future<Result<List<WeeklyScore>, AppFailure>> weeklyScores(
    String medreseId,
  ) async => Ok(List.of(scoreList));

  @override
  Future<Result<WeeklyScore, AppFailure>> openChest({
    required String medreseId,
    required DateTime periodStart,
  }) async {
    calls.add('open ${periodStart.day}');
    final i = scoreList.indexWhere((s) => s.periodStart == periodStart);
    final s = scoreList[i];
    scoreList[i] = WeeklyScore(
      studentId: s.studentId,
      studentName: s.studentName,
      periodStart: s.periodStart,
      total: s.total,
      details: s.details,
      opened: true,
      note: s.note,
    );
    return Ok(scoreList[i]);
  }

  @override
  Future<Result<List<TaskDefinition>, AppFailure>> definitions() async =>
      Ok(testTasks);

  @override
  Future<Result<TaskProgram?, AppFailure>> program(String medreseId) async =>
      Ok(taskProgram);

  @override
  Future<Result<void, AppFailure>> start(
    String medreseId,
    DateTime today,
  ) async {
    calls.add('start');
    taskProgram = TaskProgram(startDate: today, active: true);
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> setPaused(
    String medreseId, {
    required bool paused,
  }) async {
    calls.add(paused ? 'pause' : 'resume');
    taskProgram = TaskProgram(
      startDate: taskProgram!.startDate,
      active: true,
      paused: paused,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> finish(String medreseId) async {
    calls.add('finish');
    taskProgram = TaskProgram(startDate: taskProgram!.startDate, active: false);
    return const Ok(null);
  }

  @override
  Future<Result<List<TaskEntry>, AppFailure>> entries({
    required String medreseId,
    required DateTime periodStart,
  }) async => Ok(List.of(entryList));

  @override
  Future<Result<void, AppFailure>> setEntry({
    required String medreseId,
    required String studentId,
    required String taskId,
    required DateTime day,
    required int item,
    required num? value,
  }) async {
    calls.add('$taskId ${day.day} $item $value');
    entryList.removeWhere(
      (e) =>
          e.studentId == studentId &&
          e.taskId == taskId &&
          e.day == day &&
          e.item == item,
    );
    if (value != null) {
      entryList.add(
        TaskEntry(
          studentId: studentId,
          taskId: taskId,
          day: day,
          item: item,
          value: value,
        ),
      );
    }
    return const Ok(null);
  }
}

class FakeNotificationRepository implements NotificationRepository {
  final list = <AppNotification>[];
  final calls = <String>[];

  @override
  Future<Result<List<AppNotification>, AppFailure>> notifications() async =>
      Ok(List.of(list));

  @override
  Future<Result<int, AppFailure>> unreadCount() async =>
      Ok(list.where((n) => !n.read).length);

  @override
  Future<Result<void, AppFailure>> markAllRead() async {
    calls.add('markAllRead');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> registerToken(String token) async =>
      const Ok(null);

  @override
  Future<Result<void, AppFailure>> deleteToken(String token) async =>
      const Ok(null);
}

class FakeConsentRepository implements ConsentRepository {
  FakeConsentRepository({this.given = true});

  bool given;
  final calls = <String>[];

  @override
  Future<Result<bool, AppFailure>> hasTaskConsent() async => Ok(given);

  @override
  Future<Result<void, AppFailure>> giveTaskConsent() async {
    calls.add('give');
    given = true;
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> revokeTaskConsent() async {
    calls.add('revoke');
    given = false;
    return const Ok(null);
  }
}

/// Firebase'e dokunmayan push servisi.
class FakePushService implements PushService {
  final calls = <String>[];

  /// Telefondaki bildirime dokunmayı taklit eder.
  final taps = StreamController<AppNotification>.broadcast();

  @override
  Future<void> register() async => calls.add('register');

  @override
  Future<void> unregister() async => calls.add('unregister');

  @override
  Stream<void> get received => const Stream.empty();

  @override
  Stream<AppNotification> get opened => taps.stream;
}

/// Ana ekranı açan testler için bildirim ve rıza sağlayıcıları.
List<Override> pushOverrides({
  FakeNotificationRepository? notifications,
  FakePushService? push,
  FakeConsentRepository? consent,
  FakeRewardRepository? rewards,
  FakeCourseRepository? courses,
}) => [
  rewardRepositoryProvider.overrideWithValue(rewards ?? FakeRewardRepository()),
  courseRepositoryProvider.overrideWithValue(courses ?? FakeCourseRepository()),
  // Testler GitHub'a sürüm sormasın.
  updateRequiredProvider.overrideWith((ref) async => false),
  consentRepositoryProvider.overrideWithValue(
    consent ?? FakeConsentRepository(),
  ),
  pushServiceProvider.overrideWithValue(push ?? FakePushService()),
  notificationRepositoryProvider.overrideWithValue(
    notifications ?? FakeNotificationRepository(),
  ),
];

class FakeRewardRepository implements RewardRepository {
  final rewardList = <Reward>[];
  final claimList = <RewardClaim>[];
  RewardGoal? myGoal;

  @override
  Future<Result<List<RewardClaim>, AppFailure>> claims(
    String medreseId,
  ) async => Ok(List.of(claimList));

  @override
  Future<Result<void, AppFailure>> requestReward(String rewardId) async {
    final r = rewardList.firstWhere((r) => r.id == rewardId);
    claimList.add(
      RewardClaim(
        id: 'c${claimList.length + 1}',
        rewardId: r.id,
        studentId: 'u1',
        studentName: 'Ali',
        title: r.title,
        points: r.points,
        requestedAt: DateTime(2026, 11, 4),
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deliver(String claimId) async {
    final i = claimList.indexWhere((c) => c.id == claimId);
    final c = claimList[i];
    claimList[i] = RewardClaim(
      id: c.id,
      rewardId: c.rewardId,
      studentId: c.studentId,
      studentName: c.studentName,
      title: c.title,
      points: c.points,
      requestedAt: c.requestedAt,
      deliveredAt: DateTime(2026, 11, 5),
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> reject(String claimId, String reason) async {
    final i = claimList.indexWhere((c) => c.id == claimId);
    final c = claimList[i];
    claimList[i] = RewardClaim(
      id: c.id,
      rewardId: c.rewardId,
      studentId: c.studentId,
      studentName: c.studentName,
      title: c.title,
      points: c.points,
      requestedAt: c.requestedAt,
      rejectedAt: DateTime(2026, 11, 5),
      rejectReason: reason.trim(),
    );
    return const Ok(null);
  }

  @override
  Future<Result<List<Reward>, AppFailure>> rewards(String medreseId) async =>
      Ok(List.of(rewardList));

  @override
  Future<Result<void, AppFailure>> addReward({
    required String medreseId,
    required String title,
    required String description,
    required num points,
  }) async {
    rewardList.add(
      Reward(
        id: 'r${rewardList.length + 1}',
        title: title,
        description: description,
        points: points,
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteReward(String id) async {
    rewardList.removeWhere((r) => r.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<RewardGoal?, AppFailure>> goal(String medreseId) async =>
      Ok(myGoal);

  @override
  Future<Result<void, AppFailure>> setGoal({
    required String medreseId,
    required String rewardId,
    required DateTime deadline,
  }) async {
    myGoal = RewardGoal(rewardId: rewardId, deadline: deadline);
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> clearGoal(String medreseId) async {
    myGoal = null;
    return const Ok(null);
  }
}

class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository({this.consent = true});

  final courseList = <Course>[];
  final progressMap = <String, LessonProgress>{};
  bool consent;
  final calls = <String>[];

  @override
  Future<Result<List<Course>, AppFailure>> courses() async =>
      Ok(List.of(courseList));

  @override
  Future<Result<Map<String, LessonProgress>, AppFailure>> progress() async =>
      Ok(Map.of(progressMap));

  @override
  Future<Result<bool, AppFailure>> saveProgress({
    required String lessonId,
    required int positionSeconds,
    required int watchedSeconds,
    required bool completed,
  }) async {
    calls.add('save $lessonId $positionSeconds $watchedSeconds $completed');
    return Ok(completed);
  }

  final assignmentList = <CourseAssignment>[];
  final studentProgress = <StudentCourseProgress>[];
  final noteList = <LessonNote>[];

  @override
  Future<Result<List<CourseAssignment>, AppFailure>> assignments() async =>
      Ok(List.of(assignmentList));

  @override
  Future<Result<void, AppFailure>> assign({
    required String medreseId,
    required String courseId,
    required DateTime? dueOn,
  }) async {
    calls.add('assign $medreseId $courseId $dueOn');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> unassign({
    required String medreseId,
    required String courseId,
  }) async {
    calls.add('unassign $medreseId $courseId');
    return const Ok(null);
  }

  @override
  Future<Result<List<StudentCourseProgress>, AppFailure>> assignmentProgress({
    required String medreseId,
    required String courseId,
  }) async => Ok(List.of(studentProgress));

  @override
  Future<Result<List<LessonNote>, AppFailure>> notes(String lessonId) async =>
      Ok(noteList.where((n) => n.lessonId == lessonId).toList());

  @override
  Future<Result<void, AppFailure>> addNote({
    required String lessonId,
    required int seconds,
    required String body,
  }) async {
    calls.add('note $lessonId $seconds $body');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteNote(String id) async {
    calls.add('delete note $id');
    return const Ok(null);
  }

  @override
  Future<Result<bool, AppFailure>> hasConsent() async => Ok(consent);

  @override
  Future<Result<void, AppFailure>> giveConsent() async {
    calls.add('give');
    consent = true;
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> revokeConsent() async {
    calls.add('revoke');
    consent = false;
    progressMap.clear();
    return const Ok(null);
  }

  bool admin = false;
  String? title;

  @override
  Future<Result<List<Course>, AppFailure>> allCourses() async =>
      Ok(List.of(courseList));

  @override
  Future<Result<bool, AppFailure>> isAdmin() async => Ok(admin);

  @override
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
  }) async {
    calls.add(
      [
        'course $id $title ${category.name} $published',
        ?level?.name,
        if (outcomes.isNotEmpty) outcomes,
      ].join(' '),
    );
    final newId = id ?? 'new';
    courseList
      ..removeWhere((c) => c.id == newId)
      ..add(
        Course(
          id: newId,
          title: title,
          subtitle: subtitle,
          description: description,
          teacher: teacher,
          category: category,
          coverUrl: '',
          lessons: const [],
          published: published,
        ),
      );
    return Ok(newId);
  }

  @override
  Future<Result<void, AppFailure>> deleteCourse(String id) async {
    calls.add('delete course $id');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> saveLesson({
    required String? id,
    required String courseId,
    required int position,
    required String section,
    required String title,
    required String description,
    required String youtubeId,
    required int durationSeconds,
  }) async {
    calls.add(
      'lesson $id $courseId $position $title $youtubeId '
      '$durationSeconds',
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> reorderLessons(
    String courseId,
    List<String> lessonIds,
  ) async {
    calls.add('reorder ${lessonIds.join(',')}');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteLesson(String id) async {
    calls.add('delete lesson $id');
    return const Ok(null);
  }

  @override
  Future<String?> videoTitle(String youtubeId) async => title;

  final questionResultMap = <String, bool>{};

  @override
  Future<Result<QuestionResults, AppFailure>> questionResults() async =>
      Ok(Map.of(questionResultMap));

  @override
  Future<Result<void, AppFailure>> answerQuestion({
    required String questionId,
    required int choice,
  }) async {
    calls.add('answer $questionId $choice');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> saveQuestion({
    required String? id,
    required String lessonId,
    required int position,
    required String question,
    required List<String> options,
    required int answer,
    required String explanation,
  }) async {
    calls.add(
      'question $id $lessonId $position $question '
      '${options.join('|')} $answer $explanation',
    );
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteQuestion(String id) async {
    calls.add('delete question $id');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> addResource({
    required String lessonId,
    required int position,
    required String title,
    required String url,
  }) async {
    calls.add('resource $lessonId $position $title $url');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteResource(String id) async {
    calls.add('delete resource $id');
    return const Ok(null);
  }

  final commentList = <LessonComment>[];

  @override
  Future<Result<List<LessonComment>, AppFailure>> lessonComments({
    required String medreseId,
    required String lessonId,
  }) async => Ok(commentList.where((c) => c.lessonId == lessonId).toList());

  @override
  Future<Result<List<LessonComment>, AppFailure>> courseComments({
    required String medreseId,
    required List<String> lessonIds,
  }) async =>
      Ok(commentList.where((c) => lessonIds.contains(c.lessonId)).toList());

  @override
  Future<Result<void, AppFailure>> addLessonComment({
    required String medreseId,
    required String lessonId,
    required String body,
    int? seconds,
  }) async {
    calls.add('comment $medreseId $lessonId $seconds $body');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteLessonComment(String id) async {
    calls.add('delete comment $id');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> report({
    required ReportReason reason,
    required String note,
    String? lessonCommentId,
    String? reviewId,
  }) async {
    calls.add('report $lessonCommentId $reviewId ${reason.name}');
    return const Ok(null);
  }

  final icazetList = <IcazetRequest>[];

  @override
  Future<Result<List<IcazetRequest>, AppFailure>> icazetRequests() async =>
      Ok(List.of(icazetList));

  @override
  Future<Result<void, AppFailure>> requestIcazet({
    required String medreseId,
    required String courseId,
  }) async {
    calls.add('icazet $medreseId $courseId');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> decideIcazet({
    required String id,
    required bool approve,
    required String note,
  }) async {
    calls.add('decide $id $approve $note');
    return const Ok(null);
  }

  final ratingMap = <String, CourseRating>{};
  final reviewList = <CourseReview>[];

  @override
  Future<Result<Map<String, CourseRating>, AppFailure>> ratings() async =>
      Ok(Map.of(ratingMap));

  @override
  Future<Result<List<CourseReview>, AppFailure>> reviews(
    String courseId,
  ) async => Ok(List.of(reviewList));

  @override
  Future<Result<void, AppFailure>> saveReview({
    required String courseId,
    required int rating,
    required String body,
  }) async {
    calls.add('review $courseId $rating $body');
    return const Ok(null);
  }

  @override
  Future<Result<void, AppFailure>> deleteReview(String id) async {
    calls.add('delete review $id');
    return const Ok(null);
  }
}
