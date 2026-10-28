import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/posts/new_post_page.dart';
import 'package:e_medrese/presentation/features/posts/post_page.dart';
import 'package:e_medrese/presentation/widgets/author_label.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
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
class PostContent extends StatelessWidget {
  /// [post] içeriği.
  const PostContent({required this.post, required this.author, super.key});

  /// Paylaşım.
  final Post post;

  /// Yazanın gösterilecek adı.
  final String author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author, style: theme.textTheme.titleSmall),
          Text(
            postedAt(post.createdAt, edited: post.edited),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(post.body),
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
