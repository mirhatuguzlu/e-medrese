import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/admin_courses_page.dart';
import 'package:e_medrese/presentation/features/courses/course_consent_page.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/features/courses/course_page.dart';
import 'package:e_medrese/presentation/features/courses/course_reviews_page.dart';
import 'package:e_medrese/presentation/features/courses/course_search_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_page.dart';
import 'package:e_medrese/presentation/features/courses/my_courses_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Online Medrese akışı: kaldığın yerden devam kartı, kategoriler ve kurslar.
class OnlineMedresePage extends ConsumerStatefulWidget {
  /// Online Medrese sayfası.
  const OnlineMedresePage({super.key});

  @override
  ConsumerState<OnlineMedresePage> createState() => _OnlineMedresePageState();
}

class _OnlineMedresePageState extends ConsumerState<OnlineMedresePage> {
  CourseCategory? _category;

  Future<void> _refresh() async {
    ref
      ..invalidate(coursesProvider)
      ..invalidate(lessonProgressProvider)
      ..invalidate(assignmentsProvider)
      ..invalidate(courseRatingsProvider);
    await ref.read(coursesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final progress = switch (ref.watch(lessonProgressProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String, LessonProgress>{},
    };
    final courses = ref.watch(coursesProvider);
    // Hocanın verdiği kurslar; aynı kurs birkaç medreseye verildiyse son
    // günü en yakın olan.
    final assigned = <String, CourseAssignment>{};
    if (ref.watch(assignmentsProvider) case AsyncData(
      value: Ok(:final value),
    )) {
      for (final a in value) {
        final old = assigned[a.courseId];
        if (old == null ||
            (a.dueOn != null && (old.dueOn?.isAfter(a.dueOn!) ?? true))) {
          assigned[a.courseId] = a;
        }
      }
    }
    // Verilen ve bitmemiş kurslar başta.
    bool first(Course c) =>
        assigned.containsKey(c.id) && !CourseProgress(c, progress).finished;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Medrese'),
        actions: [
          IconButton(
            tooltip: 'Kurs ara',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(const CourseSearchPage()),
          ),
          IconButton(
            tooltip: 'Kurslarım',
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => context.push(const MyCoursesPage()),
          ),
          if (ref.watch(courseAdminProvider) case AsyncData(
            value: Ok(value: true),
          ))
            IconButton(
              tooltip: 'Kurs yönetimi',
              icon: const Icon(Icons.video_settings_outlined),
              onPressed: () => context.push(const AdminCoursesPage()),
            ),
        ],
      ),
      body: ResultListView<Course>(
        value: switch (courses) {
          AsyncData(value: Ok(:final value)) => AsyncData(
            Ok([
              for (final pass in [true, false])
                ...value.where(
                  (c) =>
                      first(c) == pass &&
                      (_category == null || c.category == _category),
                ),
            ]),
          ),
          _ => courses,
        },
        onRefresh: _refresh,
        emptyIcon: Icons.school_outlined,
        emptyText: _category == null
            ? 'Henüz yayında kurs yok. Yakında burada olacak.'
            : 'Bu kategoride henüz kurs yok.',
        separated: false,
        header: (_) => _Header(
          all: switch (courses) {
            AsyncData(value: Ok(:final value)) => value,
            _ => const [],
          },
          progress: progress,
          category: _category,
          onCategory: (c) => setState(() => _category = c),
        ),
        itemBuilder: (context, course) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: CourseCard(
            progress: CourseProgress(course, progress),
            assignment: assigned[course.id],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.all,
    required this.progress,
    required this.category,
    required this.onCategory,
  });

  final List<Course> all;
  final Map<String, LessonProgress> progress;
  final CourseCategory? category;
  final ValueChanged<CourseCategory?> onCategory;

  @override
  Widget build(BuildContext context) {
    final resume =
        [
            for (final c in all) CourseProgress(c, progress),
          ].where((p) => p.started && !p.finished && p.next != null).toList()
          ..sort((a, b) => b.lastWatched!.compareTo(a.lastWatched!));
    final categories = CourseCategory.values
        .where((c) => all.any((course) => course.category == c))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resume.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _ResumeCard(progress: resume.first),
          ),
        if (categories.length > 1)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final c in <CourseCategory?>[null, ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c?.label ?? 'Tümü'),
                      selected: c == category,
                      onSelected: (_) => onCategory(c),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// En son izlenen, bitmemiş kursun sıradaki dersi; dokununca ders açılır.
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.progress});

  final CourseProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lesson = progress.next!;
    final course = progress.course;
    final index = course.lessons.indexOf(lesson) + 1;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () async {
          if (!await ensureCourseConsent(context, ref) || !context.mounted) {
            return;
          }
          await context.push(
            LessonPage(courseId: course.id, lessonId: lesson.id),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CourseCover(url: lesson.thumbnail, radius: 0),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.play_arrow_rounded, size: 40),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Text(
                    'Kaldığın yerden devam et',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ders $index · ${lesson.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProgressLine(progress: progress),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Katalogdaki kurs kartı: kapak, başlık, hoca, ders sayısı ve ilerleme.
class CourseCard extends ConsumerWidget {
  /// [progress] kursunun kartı.
  const CourseCard({required this.progress, this.assignment, super.key});

  /// Kurs ve ilerlemesi.
  final CourseProgress progress;

  /// Hoca bu kursu verdiyse.
  final CourseAssignment? assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final course = progress.course;
    final duration = course.durationSeconds;
    final rating = switch (ref.watch(courseRatingsProvider)) {
      AsyncData(value: Ok(:final value)) => value[course.id],
      _ => null,
    };
    final meta = [
      if (course.teacher.isNotEmpty) course.teacher,
      if (course.level case final l?) l.label,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(CoursePage(courseId: course.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CourseCover(url: course.cover),
              Positioned(
                left: 8,
                top: 8,
                child: CoverBadge(label: course.category.label),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: CoverBadge(
                  icon: Icons.play_circle_outline,
                  label: [
                    '${course.lessons.length} ders',
                    if (duration > 0) formatLength(duration),
                  ].join(' · '),
                ),
              ),
              if (progress.finished)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: CoverBadge(icon: Icons.verified, label: 'Tamamlandı'),
                )
              else if (assignment case final a?)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CoverBadge(
                    icon: Icons.assignment_outlined,
                    label: a.dueOn == null
                        ? 'Hocan verdi'
                        : 'Hocan verdi · son gün ${formatShortDate(a.dueOn!)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (meta.isNotEmpty) Text(meta, style: theme.textTheme.bodyMedium),
          if (rating != null)
            Row(
              children: [
                Text(
                  rating.average.toStringAsFixed(1),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                RatingStars(rating: rating.average, size: 14),
                const SizedBox(width: 4),
                Text('(${rating.count})', style: theme.textTheme.bodySmall),
              ],
            ),
          if (course.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                course.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (progress.started && !progress.finished) ...[
            const SizedBox(height: 8),
            _ProgressLine(progress: progress),
          ],
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final CourseProgress progress;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 6,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        '${progress.done}/${progress.course.lessons.length} ders',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ],
  );
}
