import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/posts/new_post_page.dart';
import 'package:e_medrese/presentation/features/posts/posts_page.dart';
import 'package:e_medrese/presentation/widgets/author_label.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
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
  late Post _post = widget.post;
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

  Future<void> _edit() async {
    final body = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NewPostPage(medrese: widget.medrese, editing: _post),
      ),
    );
    if (body != null && mounted) setState(() => _post = _post.withBody(body));
  }

  Future<void> _delete() async {
    if (!await confirm(
      context,
      title: 'Paylaşımı sil',
      message: 'Paylaşım ve yorumları silinsin mi?',
      action: 'Sil',
    )) {
      return;
    }
    final result = await ref.read(feedRepositoryProvider).deletePost(_post.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(postsProvider(widget.medrese.id));
        Navigator.of(context).pop();
        context.showMessage('Paylaşım silindi.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  String _author(String authorId, String name) => authorLabel(
    ref,
    medreseId: widget.medrese.id,
    authorId: authorId,
    name: name,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = ref.watch(commentsProvider(widget.post.id));
    final isAuthor =
        _post.authorId == ref.watch(sessionProvider).valueOrNull?.user.id;
    // Veritabanı kuralı: yazan, kurucu ya da (öğrenci/ayrılmış üyenin
    // paylaşımında) hoca siler.
    final canDelete =
        isAuthor ||
        switch (widget.medrese.myRole) {
          MemberRole.owner => true,
          MemberRole.teacher =>
            (authorRole(
                      ref,
                      medreseId: widget.medrese.id,
                      authorId: _post.authorId,
                    ) ??
                    MemberRole.student) ==
                MemberRole.student,
          MemberRole.student => false,
        };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paylaşım'),
        actions: [
          if (isAuthor)
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(commentsProvider(widget.post.id).future),
              child: ListView(
                children: [
                  PostContent(
                    post: _post,
                    author: _author(_post.authorId, _post.authorName),
                  ),
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
                            _author(c.authorId, c.authorName),
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
