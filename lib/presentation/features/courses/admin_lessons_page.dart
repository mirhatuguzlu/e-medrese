import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/admin_questions_page.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/features/courses/course_form_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir kursun derslerini yönetme: ekle, düzenle, sürükleyip sırala.
class AdminLessonsPage extends ConsumerStatefulWidget {
  /// [courseId] kursunun dersleri.
  const AdminLessonsPage({required this.courseId, super.key});

  /// Kurs.
  final String courseId;

  @override
  ConsumerState<AdminLessonsPage> createState() => _AdminLessonsPageState();
}

class _AdminLessonsPageState extends ConsumerState<AdminLessonsPage> {
  // Sıralama sunucuya yazılırken listenin geri zıplamaması için.
  List<Lesson>? _pending;

  Future<void> _reorder(List<Lesson> lessons, int from, int to) async {
    final order = List.of(lessons);
    order.insert(to, order.removeAt(from));
    setState(() => _pending = order);
    final result = await ref.read(courseRepositoryProvider).reorderLessons(
      widget.courseId,
      [for (final l in order) l.id],
    );
    if (result case Err(:final error) when mounted) {
      context.showMessage(error.message);
    }
    ref
      ..invalidate(adminCoursesProvider)
      ..invalidate(coursesProvider);
    await ref.read(adminCoursesProvider.future);
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _editCourse(Course course) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CourseFormPage(course: course)),
    );
    if ((deleted ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(adminCoursesProvider);
    final course = switch (courses) {
      AsyncData(value: Ok(:final value)) =>
        value.where((c) => c.id == widget.courseId).firstOrNull,
      _ => null,
    };
    if (course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: courses.isLoading
              ? const CircularProgressIndicator()
              : const Text('Kurs bulunamadı.'),
        ),
      );
    }
    final lessons = _pending ?? course.lessons;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
        actions: [
          IconButton(
            tooltip: 'Kurs bilgisi',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editCourse(course),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(LessonFormPage(course: course)),
        icon: const Icon(Icons.add),
        label: const Text('Ders ekle'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Card(
                color: course.published
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: Icon(
                    course.published
                        ? Icons.public
                        : Icons.visibility_off_outlined,
                  ),
                  title: Text(course.published ? 'Yayında' : 'Taslak'),
                  subtitle: Text(
                    course.published
                        ? 'Öğrenciler bu kursu katalogda görüyor.'
                        : lessons.isEmpty
                        ? 'Ders ekle, sonra kurs bilgisinden yayına al.'
                        : 'Öğrenciler görmüyor. Kurs bilgisinden yayına al.',
                  ),
                  onTap: () => _editCourse(course),
                ),
              ),
            ),
          ),
          if (lessons.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Henüz ders yok. YouTube linkiyle ilk dersi ekle.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Sırayı değiştirmek için dersi basılı tutup sürükle.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            SliverReorderableList(
              itemCount: lessons.length,
              onReorderItem: (from, to) => _reorder(lessons, from, to),
              itemBuilder: (context, i) {
                final lesson = lessons[i];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(lesson.id),
                  index: i,
                  child: Material(
                    child: ListTile(
                      leading: SizedBox(
                        width: 96,
                        child: CourseCover(url: lesson.thumbnail, radius: 8),
                      ),
                      title: Text(
                        '${i + 1}. ${lesson.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (lesson.section.isNotEmpty) lesson.section,
                          if (lesson.durationSeconds > 0)
                            formatClock(lesson.durationSeconds),
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Tekrar soruları',
                            icon: Badge.count(
                              count: lesson.questions.length,
                              isLabelVisible: lesson.questions.isNotEmpty,
                              child: const Icon(Icons.quiz_outlined),
                            ),
                            onPressed: () => context.push(
                              AdminQuestionsPage(
                                courseId: course.id,
                                lessonId: lesson.id,
                              ),
                            ),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                      onTap: () => context.push(
                        LessonFormPage(course: course, lesson: lesson),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ],
      ),
    );
  }
}
