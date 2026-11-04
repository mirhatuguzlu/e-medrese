import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/report/report_page.dart';
import 'package:e_medrese/presentation/widgets/author_label.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın verdiği kursun bir dersi hakkında medrese içi soru ve cevaplar.
/// Yalnız o medresenin üyeleri görür. Yazı videonun bir anına bağlanabilir;
/// o ana dokununca sayfa saniyesiyle kapanır.
class LessonDiscussionPage extends ConsumerStatefulWidget {
  /// [medrese]'nin [lesson] tartışması; [seconds] videonun şimdiki anı.
  const LessonDiscussionPage({
    required this.medrese,
    required this.lesson,
    this.seconds,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Ders.
  final Lesson lesson;

  /// Oynatıcının bulunduğu an; verilirse yazı bu ana bağlanabilir.
  final int? seconds;

  @override
  ConsumerState<LessonDiscussionPage> createState() =>
      _LessonDiscussionPageState();
}

class _LessonDiscussionPageState extends ConsumerState<LessonDiscussionPage> {
  final _body = TextEditingController();
  late bool _attach = widget.seconds != null;
  bool _sending = false;

  ({String medreseId, String lessonId}) get _key =>
      (medreseId: widget.medrese.id, lessonId: widget.lesson.id);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .addLessonComment(
          medreseId: widget.medrese.id,
          lessonId: widget.lesson.id,
          body: _body.text,
          seconds: _attach ? widget.seconds : null,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case Ok():
        _body.clear();
        setState(() => _attach = false);
        ref.invalidate(lessonCommentsProvider(_key));
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  Future<void> _delete(LessonComment c) async {
    if (!await confirm(
      context,
      title: 'Yazı silinsin mi?',
      message: c.body,
      action: 'Sil',
    )) {
      return;
    }
    final result = await ref
        .read(courseRepositoryProvider)
        .deleteLessonComment(c.id);
    if (!mounted) return;
    if (result case Err(:final error)) context.showMessage(error.message);
    ref.invalidate(lessonCommentsProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id;
    final staff = widget.medrese.myRole.isStaff;
    final seconds = widget.seconds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ders tartışması'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.medrese.name} · ${widget.lesson.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ResultListView<LessonComment>(
              value: ref.watch(lessonCommentsProvider(_key)),
              onRefresh: () async {
                ref.invalidate(lessonCommentsProvider(_key));
                await ref.read(lessonCommentsProvider(_key).future);
              },
              emptyIcon: Icons.forum_outlined,
              emptyText:
                  'Bu ders hakkında henüz kimse yazmadı. Anlamadığın yeri sor; '
                  'yalnız medresendekiler görür.',
              itemBuilder: (context, c) {
                final role = authorRole(
                  ref,
                  medreseId: widget.medrese.id,
                  authorId: c.authorId,
                );
                final name = authorLabel(
                  ref,
                  medreseId: widget.medrese.id,
                  authorId: c.authorId,
                  name: c.authorName,
                );
                return ListTile(
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(name, style: theme.textTheme.titleSmall),
                      ),
                      if (role?.isStaff ?? false) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Hoca',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.seconds case final s?)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: Text(formatClock(s)),
                            // Oynatıcıdan açıldıysa o ana dönülür.
                            onPressed: seconds == null
                                ? null
                                : () => Navigator.of(context).pop(s),
                          ),
                        ),
                      Text(c.body, style: theme.textTheme.bodyMedium),
                      Text(
                        formatDateTime(c.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  // Veritabanı kuralı: yazan ya da kurucu/hoca siler.
                  trailing: c.authorId == myId || staff
                      ? IconButton(
                          tooltip: 'Yazıyı sil',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(c),
                        )
                      : IconButton(
                          tooltip: 'Yazıyı şikayet et',
                          icon: const Icon(Icons.flag_outlined),
                          onPressed: () =>
                              context.push(ReportPage(lessonCommentId: c.id)),
                        ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (seconds != null)
                    FilterChip(
                      selected: _attach,
                      onSelected: (v) => setState(() => _attach = v),
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        'Videonun ${formatClock(seconds)} anına bağla',
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _body,
                          decoration: InputDecoration(
                            hintText: staff
                                ? 'Cevap yaz'
                                : 'Soru ya da yorum yaz',
                            border: InputBorder.none,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 2000,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => null,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
