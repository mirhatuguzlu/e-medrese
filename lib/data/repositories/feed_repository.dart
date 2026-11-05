import 'dart:io';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Paylaşıma eklenecek, telefondan seçilmiş dosya.
typedef PostFileDraft = ({String path, String name, int size});

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

  static const _files = 'post-files';

  static const _fileColumns =
      'post_files(id, position, kind, name, path, size)';

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
              'comments(count), $_fileColumns',
            )
            .eq('medrese_id', medreseId)
            .order('created_at', ascending: false)
            .limit(_limit);
        return rows.map(Post.fromJson).toList();
      });

  /// Tek paylaşım; silinmişse `null`.
  Future<Result<Post?, AppFailure>> post(String id) => guardSupabase(() async {
    final row = await _client
        .from('posts')
        .select(
          'id, body, author_id, created_at, edited_at, '
          'author:profiles(full_name), '
          'comments(count), $_fileColumns',
        )
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Post.fromJson(row);
  });

  /// [body] yazısı ve [files] dosyalarıyla paylaşım yapar. Bir dosya
  /// yüklenemezse paylaşım ve yüklenenler silinir.
  Future<Result<void, AppFailure>> createPost({
    required String medreseId,
    required String body,
    List<PostFileDraft> files = const [],
  }) => guardSupabase(() async {
    final post = await _client
        .from('posts')
        .insert({'medrese_id': medreseId, 'body': body.trim()})
        .select('id')
        .single();
    final uploaded = <String>[];
    try {
      final rows = <Map<String, dynamic>>[];
      for (final (i, f) in files.indexed) {
        final ext = f.name.split('.').last.toLowerCase();
        final path = '$medreseId/${const Uuid().v4()}.$ext';
        await _client.storage
            .from(_files)
            .upload(
              path,
              File(f.path),
              fileOptions: FileOptions(
                contentType: PostFileKind.mimeOf(f.name),
              ),
            );
        uploaded.add(path);
        rows.add({
          'post_id': post['id'],
          'position': i + 1,
          'kind': PostFileKind.of(f.name)!.name,
          'name': f.name,
          'path': path,
          'size': f.size,
        });
      }
      if (rows.isNotEmpty) await _client.from('post_files').insert(rows);
    } on Object {
      await _client.from('posts').delete().eq('id', post['id'] as String);
      if (uploaded.isNotEmpty) {
        await _client.storage.from(_files).remove(uploaded);
      }
      rethrow;
    }
  });

  /// Paylaşımı düzenler (yalnızca yazan).
  Future<Result<void, AppFailure>> updatePost({
    required String id,
    required String body,
  }) => _changeOne(_client.from('posts').update({'body': body.trim()}), id);

  /// Paylaşımı ve dosyalarını siler (yazan ya da hocalar).
  Future<Result<void, AppFailure>> deletePost(String id) =>
      guardSupabase(() async {
        final files = await _client
            .from('post_files')
            .select('path')
            .eq('post_id', id);
        final rows = await _client
            .from('posts')
            .delete()
            .eq('id', id)
            .select('id');
        if (rows.isEmpty) {
          throw const PostgrestException(message: 'not allowed');
        }
        final paths = [for (final f in files) f['path'] as String];
        if (paths.isNotEmpty) await _client.storage.from(_files).remove(paths);
      });

  /// Dosyanın adresi; [fileHeaders] ile açılır (kova özel).
  String fileUrl(PostFile f) =>
      '${_client.storage.url}/object/authenticated/$_files/${f.path}';

  /// [fileUrl]'i açmak için oturum belirteci.
  Map<String, String> get fileHeaders => {
    'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken}',
  };

  /// İndirmeyi kaydeder; ilk indirişte paylaşana bildirim gider.
  Future<Result<void, AppFailure>> recordDownload(PostFile f) => guardSupabase(
    () => _client.rpc<void>('record_post_download', params: {'f': f.id}),
  );

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

  /// Yorumu siler (yazan ya da medresenin kurucusu/hocaları).
  Future<Result<void, AppFailure>> deleteComment(String id) =>
      _changeOne(_client.from('comments').delete(), id);

  /// Paylaşımı ([postId]) ya da yorumu ([commentId]) şikayet eder.
  Future<Result<void, AppFailure>> report({
    required ReportReason reason,
    required String note,
    String? postId,
    String? commentId,
  }) => guardSupabase(
    () => _client.rpc<void>(
      'report_content',
      params: {
        'p': postId,
        'c': commentId,
        'reason': reason.name,
        'note': note.trim(),
      },
    ),
  );

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
