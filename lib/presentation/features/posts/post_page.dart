import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/posts/posts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir paylaşım ve yorumları; altta yorum yazma alanı.
class PostPage extends ConsumerStatefulWidget {
  /// [post] sayfası.
  const PostPage({required this.medrese, required this.post, super.key});

  /// Paylaşımın medresesi (akışı yenilemek için).
  final Medrese medrese;

  /// Paylaşım.
  final Post post;

  @override
  ConsumerState<PostPage> createState() => _PostPageState();
}

class _PostPageState extends ConsumerState<PostPage> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_comment.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final result = await ref
        .read(feedRepositoryProvider)
        .createComment(postId: widget.post.id, body: _comment.text);
    if (!mounted) return;
    setState(() => _sending = false);

    switch (result) {
      case Ok():
        _comment.clear();
        ref
          ..invalidate(commentsProvider(widget.post.id))
          // Akıştaki yorum sayısı güncellensin.
          ..invalidate(postsProvider(widget.medrese.id));
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = ref.watch(commentsProvider(widget.post.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Paylaşım')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(commentsProvider(widget.post.id).future),
              child: ListView(
                children: [
                  PostContent(post: widget.post),
                  const Divider(height: 1),
                  ...switch (comments) {
                    AsyncData(value: Ok(value: final list)) when list.isEmpty =>
                      [
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Henüz yorum yok.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    AsyncData(value: Ok(value: final list)) => [
                      for (final c in list)
                        ListTile(
                          title: Text(
                            displayName(c.authorName),
                            style: theme.textTheme.titleSmall,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.body, style: theme.textTheme.bodyMedium),
                              Text(
                                formatDateTime(c.createdAt),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                    AsyncData(value: Err(:final error)) => [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error.message, textAlign: TextAlign.center),
                      ),
                    ],
                    AsyncError(:final error) => [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('$error', textAlign: TextAlign.center),
                      ),
                    ],
                    _ => [
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  },
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _comment,
                      decoration: const InputDecoration(
                        hintText: 'Yorum yaz',
                        border: InputBorder.none,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gönder',
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
