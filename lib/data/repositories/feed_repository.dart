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
        .select('id, title, body, created_at, author:profiles(full_name)')
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

  /// En yeni paylaşımlar, yorum sayılarıyla.
  Future<Result<List<Post>, AppFailure>> posts(String medreseId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('posts')
            .select(
              'id, body, created_at, author:profiles(full_name), '
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

  /// Yorumlar, eskiden yeniye.
  Future<Result<List<Comment>, AppFailure>> comments(String postId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('comments')
            .select('id, body, created_at, author:profiles(full_name)')
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
