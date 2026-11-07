import 'package:cached_network_image/cached_network_image.dart';
import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/posts/new_post_page.dart';
import 'package:e_medrese/presentation/features/posts/post_file_page.dart';
import 'package:e_medrese/presentation/features/posts/post_page.dart';
import 'package:e_medrese/presentation/widgets/author_label.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Paylaşım akışı; her üye paylaşım yapabilir.
class PostsPage extends ConsumerWidget {
  /// [medrese]'nin paylaşımları.
  const PostsPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paylaşımlar')),
      body: ResultListView<Post>(
        value: ref.watch(postsProvider(medrese.id)),
        onRefresh: () => ref.refresh(postsProvider(medrese.id).future),
        emptyIcon: Icons.forum_outlined,
        emptyText: 'Henüz paylaşım yok. İlk paylaşımı sen yap.',
        separated: false,
        itemBuilder: (context, p) => Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(PostPage(medrese: medrese, post: p)),
            child: PostContent(
              medreseId: medrese.id,
              post: p,
              author: authorLabel(
                ref,
                medreseId: medrese.id,
                authorId: p.authorId,
                name: p.authorName,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Paylaş'),
        onPressed: () => context.push(NewPostPage(medrese: medrese)),
      ),
    );
  }
}

/// Paylaşım kartının içeriği; akışta ve paylaşım sayfasında kullanılır.
class PostContent extends ConsumerWidget {
  /// [post] içeriği.
  const PostContent({
    required this.medreseId,
    required this.post,
    required this.author,
    super.key,
  });

  /// Medrese.
  final String medreseId;

  /// Paylaşım.
  final Post post;

  /// Yazanın gösterilecek adı.
  final String author;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberPhoto(
                medreseId: medreseId,
                userId: post.authorId,
                name: post.authorName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author, style: theme.textTheme.titleSmall),
                    Text(
                      postedAt(post.createdAt, edited: post.edited),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(post.body),
          ],
          for (final f in post.files) _FileTile(file: f),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.mode_comment_outlined,
                size: 16,
                color: theme.hintColor,
              ),
              const SizedBox(width: 6),
              Text('${post.commentCount}', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Paylaşımdaki dosya satırı; dokununca dosya açılır.
class _FileTile extends ConsumerWidget {
  const _FileTile({required this.file});

  final PostFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(feedRepositoryProvider);
    return Card.outlined(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: switch (file.kind) {
          PostFileKind.image => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: repo.fileUrl(file),
              cacheKey: file.path,
              httpHeaders: repo.fileHeaders,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const Icon(Icons.image_outlined),
            ),
          ),
          PostFileKind.pdf => const Icon(Icons.picture_as_pdf_outlined),
        },
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatBytes(file.size)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(PostFilePage(file: file)),
      ),
    );
  }
}
