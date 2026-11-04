import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir dersteki notların, videodaki sırasıyla. Nota dokununca o ana
/// dönülür (saniyesiyle kapanır).
class LessonNotesPage extends ConsumerWidget {
  /// [lesson] notları.
  const LessonNotesPage({required this.lesson, super.key});

  /// Ders.
  final Lesson lesson;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LessonNote note,
  ) async {
    final ok = await confirm(
      context,
      title: 'Not silinsin mi?',
      message: note.body,
      action: 'Sil',
    );
    if (!ok) return;
    final result = await ref.read(courseRepositoryProvider).deleteNote(note.id);
    if (result case Err(:final error) when context.mounted) {
      context.showMessage(error.message);
    }
    ref.invalidate(lessonNotesProvider(lesson.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notlarım')),
      body: ResultListView<LessonNote>(
        value: ref.watch(lessonNotesProvider(lesson.id)),
        onRefresh: () async {
          ref.invalidate(lessonNotesProvider(lesson.id));
          await ref.read(lessonNotesProvider(lesson.id).future);
        },
        emptyIcon: Icons.sticky_note_2_outlined,
        emptyText:
            'Bu derste henüz notun yok. İzlerken "Not al" ile o ana not '
            'düşebilirsin.',
        itemBuilder: (context, note) => ListTile(
          leading: ActionChip(
            avatar: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(formatClock(note.seconds)),
            onPressed: () => Navigator.of(context).pop(note.seconds),
          ),
          title: Text(note.body),
          subtitle: Text(
            formatDateTime(note.createdAt),
            style: theme.textTheme.bodySmall,
          ),
          trailing: IconButton(
            tooltip: 'Notu sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref, note),
          ),
          onTap: () => Navigator.of(context).pop(note.seconds),
        ),
      ),
    );
  }
}
