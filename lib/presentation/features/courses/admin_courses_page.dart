import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/admin_lessons_page.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/features/courses/course_form_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kurs yönetimi (uygulama yöneticileri): taslaklar dahil bütün kurslar.
class AdminCoursesPage extends ConsumerWidget {
  /// Kurs yönetimi sayfası.
  const AdminCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Kurs yönetimi')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.push(const CourseFormPage()),
      icon: const Icon(Icons.add),
      label: const Text('Yeni kurs'),
    ),
    body: ResultListView<Course>(
      value: ref.watch(adminCoursesProvider),
      onRefresh: () async {
        ref.invalidate(adminCoursesProvider);
        await ref.read(adminCoursesProvider.future);
      },
      emptyIcon: Icons.video_library_outlined,
      emptyText: 'Henüz kurs yok. "Yeni kurs" ile ilkini aç.',
      itemBuilder: (context, course) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SizedBox(
          width: 96,
          child: CourseCover(url: course.cover, radius: 8),
        ),
        title: Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${course.published ? 'Yayında' : 'Taslak'} · '
          '${course.lessons.length} ders · ${course.category.label}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AdminLessonsPage(courseId: course.id)),
      ),
    ),
  );
}
