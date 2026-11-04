import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/lesson_discussion_page.dart';
import 'package:e_medrese/presentation/widgets/author_label.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medresede bir kursun bütün derslerinde son yazılanlar; hoca soruları
/// buradan görür, dokununca o dersin tartışması açılır.
class CourseDiscussionsPage extends ConsumerWidget {
  /// [medrese]'de [course] tartışmaları.
  const CourseDiscussionsPage({
    required this.medrese,
    required this.course,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Verilen kurs.
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = (medreseId: medrese.id, course: course);
    final lessons = {for (final l in course.lessons) l.id: l};
    return Scaffold(
      appBar: AppBar(title: const Text('Ders tartışmaları')),
      body: ResultListView<LessonComment>(
        value: ref.watch(courseCommentsProvider(key)),
        onRefresh: () async {
          ref.invalidate(courseCommentsProvider(key));
          await ref.read(courseCommentsProvider(key).future);
        },
        emptyIcon: Icons.forum_outlined,
        emptyText:
            'Bu kursun derslerinde henüz kimse yazmadı. Öğrencilerin ders '
            'izlerken sorularını buraya yazabilir.',
        itemBuilder: (context, c) {
          final lesson = lessons[c.lessonId];
          return ListTile(
            title: Text(
              authorLabel(
                ref,
                medreseId: medrese.id,
                authorId: c.authorId,
                name: c.authorName,
              ),
              style: theme.textTheme.titleSmall,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                Text(
                  [
                    if (lesson != null)
                      'Ders ${course.lessons.indexOf(lesson) + 1}',
                    if (c.seconds case final s?) formatClock(s),
                    formatDateTime(c.createdAt),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: lesson == null
                ? null
                : () async {
                    await context.push(
                      LessonDiscussionPage(medrese: medrese, lesson: lesson),
                    );
                    if (context.mounted) {
                      ref.invalidate(courseCommentsProvider(key));
                    }
                  },
          );
        },
      ),
    );
  }
}
