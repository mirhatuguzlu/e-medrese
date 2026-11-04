import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/assign_course_page.dart';
import 'package:e_medrese/presentation/features/courses/assignment_progress_page.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/features/courses/online_medrese_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocaların medreseye verdiği Online Medrese kursları. Öğrenci kendi
/// ilerlemesini, hoca öğrencilerin ilerlemesini açar.
class MedreseCoursesPage extends ConsumerWidget {
  /// [medrese]'nin kursları.
  const MedreseCoursesPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = medrese.myRole.isStaff;
    final assignments = ref.watch(assignmentsProvider);
    final courses = ref.watch(coursesProvider);
    final progress = switch (ref.watch(lessonProgressProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String, LessonProgress>{},
    };
    final byId = switch (courses) {
      AsyncData(value: Ok(:final value)) => {for (final c in value) c.id: c},
      _ => const <String, Course>{},
    };
    final value = switch ((assignments, courses)) {
      (AsyncData(value: Ok(:final value)), AsyncData(value: Ok())) =>
        AsyncData<Result<List<CourseAssignment>, AppFailure>>(
          Ok(
            value
                .where(
                  (a) => a.medreseId == medrese.id && byId[a.courseId] != null,
                )
                .toList(),
          ),
        ),
      (AsyncData(value: Err(:final error)), _) ||
      (
        _,
        AsyncData(value: Err(:final error)),
      ) => AsyncData<Result<List<CourseAssignment>, AppFailure>>(Err(error)),
      _ => const AsyncLoading<Result<List<CourseAssignment>, AppFailure>>(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Online kurslar')),
      floatingActionButton: staff
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AssignCoursePage(medrese: medrese)),
              icon: const Icon(Icons.add),
              label: const Text('Kurs ver'),
            )
          : null,
      body: ResultListView<CourseAssignment>(
        value: value,
        onRefresh: () async {
          ref
            ..invalidate(assignmentsProvider)
            ..invalidate(coursesProvider)
            ..invalidate(lessonProgressProvider);
          await ref.read(assignmentsProvider.future);
        },
        emptyIcon: Icons.school_outlined,
        emptyText: staff
            ? 'Henüz kurs vermedin. "Kurs ver" ile Online Medrese\'den bir '
                  'kursu öğrencilerine ver; ilerlemelerini buradan izle.'
            : 'Hocaların henüz bir kurs vermedi.',
        separated: false,
        header: staff
            ? null
            : (_) => const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  'Hocalarının verdiği kurslar. İlerlemen hocalarına '
                  'gösterilir.',
                ),
              ),
        itemBuilder: (context, a) {
          final course = byId[a.courseId]!;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: staff
                ? _StaffTile(medrese: medrese, course: course, assignment: a)
                : CourseCard(
                    progress: CourseProgress(course, progress),
                    assignment: a,
                  ),
          );
        },
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.medrese,
    required this.course,
    required this.assignment,
  });

  final Medrese medrese;
  final Course course;
  final CourseAssignment assignment;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: SizedBox(
        width: 96,
        child: CourseCover(url: course.cover, radius: 8),
      ),
      title: Text(course.title),
      subtitle: Text(
        [
          '${course.lessons.length} ders',
          if (assignment.dueOn != null)
            'son gün ${formatShortDate(assignment.dueOn!)}',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.insights_outlined),
      onTap: () => context.push(
        AssignmentProgressPage(medrese: medrese, course: course),
      ),
    ),
  );
}
