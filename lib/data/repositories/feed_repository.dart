import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(Supabase.instance.client),
);

/// Bir medresenin duyuruları.
final AutoDisposeFutureProviderFamily<
  Result<List<Announcement>, AppFailure>,
  String
>
announcementsProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) =>
      ref.watch(feedRepositoryProvider).announcements(medreseId),
);

/// Bir medresenin paylaşımları.
final AutoDisposeFutureProviderFamily<Result<List<Post>, AppFailure>, String>
postsProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(feedRepositoryProvider).posts(medreseId),
);

/// Bir paylaşımın yorumları.
final AutoDisposeFutureProviderFamily<Result<List<Comment>, AppFailure>, String>
commentsProvider = FutureProvider.autoDispose.family(
  (ref, postId) => ref.watch(feedRepositoryProvider).comments(postId),
);

/// Bir üyenin bir medresedeki paylaşım sayısı.
final AutoDisposeFutureProviderFamily<
  Result<int, AppFailure>,
  ({String medreseId, String userId})
>
postCountProvider = FutureProvider.autoDispose.family(
  (ref, key) => ref
      .watch(feedRepositoryProvider)
      .postCount(medreseId: key.medreseId, userId: key.userId),
);

/// Duyurular, paylaşımlar ve yorumlar.
class FeedRepository {
  /// Supabase istemcisiyle oluşturur.
  FeedRepository(this._client);

  final SupabaseClient _client;

  // shortcut: son 50 kayıt, sayfalama yok; akış uzayınca range() ile sayfala.
  static const _limit = 50;

  /// En yeni duyurular.
  Future<Result<List<Announcement>, AppFailure>> announcements(
    String medreseId,
  ) => guardSupabase(() async {
    final rows = await _client
        .from('announcements')
        .select(
          'id, title, body, author_id, created_at, edited_at, '
          'author:profiles(full_name)',
        )
        .eq('medrese_id', medreseId)
        .order('created_at', ascending: false)
        .limit(_limit);
    return rows.map(Announcement.fromJson).toList();
  });

  /// Duyuru yazar (yalnızca hocalar).
  Future<Result<void, AppFailure>> createAnnouncement({
    required String medreseId,
    required String title,
    required String body,
  }) => guardSupabase(
    () => _client.from('announcements').insert({
      'medrese_id': medreseId,
      'title': title.trim(),
      'body': body.trim(),
    }),
  );

  /// Duyuruyu düzenler (yalnızca yazan).
  Future<Result<void, AppFailure>> updateAnnouncement({
    required String id,
    required String title,
    required String body,
  }) => _changeOne(
    _client.from('announcements').update({
      'title': title.trim(),
      'body': body.trim(),
    }),
    id,
  );

  /// Duyuruyu siler (yazan ya da kurucu).
  Future<Result<void, AppFailure>> deleteAnnouncement(String id) =>
      _changeOne(_client.from('announcements').delete(), id);

  /// En yeni paylaşımlar, yorum sayılarıyla.
  Future<Result<List<Post>, AppFailure>> posts(String medreseId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('posts')
            .select(
              'id, body, author_id, created_at, edited_at, '
              'author:profiles(full_name), '
              'comments(count)',
            )
            .eq('medrese_id', medreseId)
            .order('created_at', ascending: false)
            .limit(_limit);
        return rows.map(Post.fromJson).toList();
      });

  /// Paylaşım yapar.
  Future<Result<void, AppFailure>> createPost({
    required String medreseId,
    required String body,
  }) => guardSupabase(
    () => _client.from('posts').insert({
      'medrese_id': medreseId,
      'body': body.trim(),
    }),
  );

  /// Paylaşımı düzenler (yalnızca yazan).
  Future<Result<void, AppFailure>> updatePost({
    required String id,
    required String body,
  }) => _changeOne(_client.from('posts').update({'body': body.trim()}), id);

  /// Paylaşımı siler (yazan ya da hocalar).
  Future<Result<void, AppFailure>> deletePost(String id) =>
      _changeOne(_client.from('posts').delete(), id);

  /// [userId]'nin bu medresedeki paylaşım sayısı.
  Future<Result<int, AppFailure>> postCount({
    required String medreseId,
    required String userId,
  }) => guardSupabase(() async {
    final response = await _client
        .from('posts')
        .select('id')
        .eq('medrese_id', medreseId)
        .eq('author_id', userId)
        .count();
    return response.count;
  });

  /// [id]'li tek satırı günceller/siler. RLS izin vermezse Supabase hata
  /// vermez, 0 satır döner; bunu yetkisizlik olarak bildirir.
  Future<Result<void, AppFailure>> _changeOne(
    PostgrestFilterBuilder<dynamic> query,
    String id,
  ) => guardSupabase(() async {
    final rows = await query.eq('id', id).select('id');
    if (rows.isEmpty) throw const PostgrestException(message: 'not allowed');
  });

  /// Yorumlar, eskiden yeniye.
  Future<Result<List<Comment>, AppFailure>> comments(String postId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('comments')
            .select(
              'id, body, author_id, created_at, author:profiles(full_name)',
            )
            .eq('post_id', postId)
            .order('created_at');
        return rows.map(Comment.fromJson).toList();
      });

  /// Yorum yapar.
  Future<Result<void, AppFailure>> createComment({
    required String postId,
    required String body,
  }) => guardSupabase(
    () => _client.from('comments').insert({
      'post_id': postId,
      'body': body.trim(),
    }),
  );
}
