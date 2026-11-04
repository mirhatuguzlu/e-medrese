import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/course_discussions_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın gördüğü, öğrencilerin verilen kurstaki ilerlemesi.
class AssignmentProgressPage extends ConsumerWidget {
  /// [medrese] öğrencilerinin [course] ilerlemesi.
  const AssignmentProgressPage({
    required this.medrese,
    required this.course,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Verilen kurs.
  final Course course;

  Future<void> _unassign(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Kurs geri alınsın mı?',
      message:
          'Kurs öğrencilerin listesinden "Hocan verdi" olarak kalkar. '
          'Öğrencilerin izlediği dersler silinmez.',
      action: 'Geri al',
    );
    if (!ok || !context.mounted) return;
    final result = await ref
        .read(courseRepositoryProvider)
        .unassign(medreseId: medrese.id, courseId: course.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(assignmentsProvider);
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (medreseId: medrese.id, courseId: course.id);
    final theme = Theme.of(context);
    final total = course.lessons.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
        actions: [
          IconButton(
            tooltip: 'Ders tartışmaları',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.push(
              CourseDiscussionsPage(medrese: medrese, course: course),
            ),
          ),
          IconButton(
            tooltip: 'Kursu geri al',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _unassign(context, ref),
          ),
        ],
      ),
      body: ResultListView<StudentCourseProgress>(
        value: ref.watch(assignmentProgressProvider(key)),
        onRefresh: () async {
          ref.invalidate(assignmentProgressProvider(key));
          await ref.read(assignmentProgressProvider(key).future);
        },
        emptyIcon: Icons.groups_outlined,
        emptyText: 'Bu medresede henüz öğrenci yok.',
        header: (students) {
          final finished = students
              .where((s) => s.consent && total > 0 && s.done >= total)
              .length;
          final started = students
              .where((s) => s.consent && s.lastWatched != null)
              .length;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Stat(value: '${students.length}', label: 'öğrenci'),
                _Stat(value: '$started', label: 'başladı'),
                _Stat(value: '$finished', label: 'bitirdi'),
              ],
            ),
          );
        },
        itemBuilder: (context, s) => ListTile(
          title: Text(displayName(s.name)),
          subtitle: !s.consent
              ? const Text('İlerlemesini paylaşmaya rıza vermedi.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : s.done / total,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${s.done}/$total ders',
                        if (s.lastWatched != null)
                          'son izleme ${formatDateTime(s.lastWatched!)}'
                        else
                          'henüz başlamadı',
                        if (s.answered > 0)
                          'sorular ${s.correct}/${s.answered} doğru',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
          trailing: s.consent && total > 0 && s.done >= total
              ? Icon(Icons.verified, color: theme.colorScheme.primary)
              : null,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
