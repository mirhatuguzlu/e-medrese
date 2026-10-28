import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
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
  ])
    TaskDefinition.fromJson(json),
];

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({this.taskProgram});

  TaskProgram? taskProgram;
  final entryList = <TaskEntry>[];
  final calls = <String>[];

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
  Future<Result<void, AppFailure>> stop(String medreseId) async {
    calls.add('stop');
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
