import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
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
        authorName: 'Hoca',
        createdAt: DateTime(2026),
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
        authorName: 'Ali',
        createdAt: DateTime(2026),
        commentCount: 0,
      ),
    );
    return const Ok(null);
  }

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
        authorName: 'Ali',
        createdAt: DateTime(2026),
      ),
    );
    return const Ok(null);
  }
}
