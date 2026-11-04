import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/data/repositories/saved_courses_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/certificate_page.dart';
import 'package:e_medrese/presentation/features/courses/course_consent_page.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/features/courses/course_reviews_page.dart';
import 'package:e_medrese/presentation/features/courses/icazet_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kursun tanıtımı ve ders listesi; alttaki düğme sıradaki dersi açar.
class CoursePage extends ConsumerWidget {
  /// [courseId] kursunun sayfası.
  const CoursePage({required this.courseId, super.key});

  /// Kurs.
  final String courseId;

  Future<void> _open(BuildContext context, WidgetRef ref, Lesson lesson) async {
    if (!await ensureCourseConsent(context, ref) || !context.mounted) return;
    await context.push(LessonPage(courseId: courseId, lessonId: lesson.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = switch (ref.watch(coursesProvider)) {
      AsyncData(value: Ok(:final value)) =>
        value.where((c) => c.id == courseId).firstOrNull,
      _ => null,
    };
    if (course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: ref.watch(coursesProvider).isLoading
              ? const CircularProgressIndicator()
              : const Text('Bu kurs artık yayında değil.'),
        ),
      );
    }
    final progress = switch (ref.watch(lessonProgressProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String, LessonProgress>{},
    };
    final summary = CourseProgress(course, progress);
    final next = summary.next;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.sizeOf(context).width * 9 / 16,
            actions: [
              if (ref.watch(savedCoursesProvider).contains(course.id))
                IconButton(
                  tooltip: 'Kayıtlılardan çıkar',
                  icon: const Icon(Icons.bookmark),
                  onPressed: () =>
                      ref.read(savedCoursesProvider.notifier).toggle(course.id),
                )
              else
                IconButton(
                  tooltip: 'Kursu kaydet',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: () {
                    ref.read(savedCoursesProvider.notifier).toggle(course.id);
                    context.showMessage(
                      'Kaydedildi. Kurslarım sayfasında bulursun.',
                    );
                  },
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CourseCover(url: course.cover, radius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverList.list(
              children: [
                Text(
                  upperTr(
                    [
                      course.category.label,
                      if (course.level case final l?) l.label,
                    ].join(' · '),
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  course.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (course.teacher.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(course.teacher, style: theme.textTheme.titleSmall),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                _RatingRow(summary: summary),
                const SizedBox(height: 8),
                _Stats(summary: summary),
                if (summary.finished) ...[
                  const SizedBox(height: 16),
                  Card(
                    margin: EdgeInsets.zero,
                    color: theme.colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.emoji_events_outlined),
                      title: const Text('Kursu bitirdin'),
                      subtitle: const Text('Tamamlama belgeni gör'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push(CertificatePage(progress: summary)),
                    ),
                  ),
                ],
                if (assignedMedreses(
                  ref,
                  course.id,
                  studentOnly: true,
                ).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _IcazetTile(summary: summary),
                ],
                if (course.outcomeList.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Bu kursta öğreneceklerin',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final o in course.outcomeList)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(o, style: theme.textTheme.bodyLarge),
                          ),
                        ],
                      ),
                    ),
                ],
                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(course.description, style: theme.textTheme.bodyLarge),
                ] else if (course.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(course.subtitle, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 24),
                Text(
                  'Dersler',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: course.lessons.length,
            itemBuilder: (context, i) {
              final lesson = course.lessons[i];
              final newSection =
                  lesson.section.isNotEmpty &&
                  (i == 0 || course.lessons[i - 1].section != lesson.section);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (newSection)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        lesson.section,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  _LessonTile(
                    number: i + 1,
                    lesson: lesson,
                    progress: progress[lesson.id],
                    isNext: summary.started && lesson == next,
                    onTap: () => _open(context, ref, lesson),
                  ),
                ],
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: next == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _open(context, ref, next),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    summary.finished
                        ? 'Baştan izle'
                        : summary.started
                        ? 'Devam et: Ders ${course.lessons.indexOf(next) + 1}'
                        : 'Kursa başla',
                  ),
                ),
              ),
            ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.summary});

  final CourseProgress summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final course = summary.course;
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            stat(
              Icons.video_library_outlined,
              '${course.lessons.length}',
              'ders',
            ),
            if (course.durationSeconds > 0)
              stat(
                Icons.schedule,
                formatLength(course.durationSeconds),
                'toplam',
              ),
            stat(
              summary.finished ? Icons.verified : Icons.trending_up,
              '%${(summary.fraction * 100).round()}',
              'tamamlandı',
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.number,
    required this.lesson,
    required this.progress,
    required this.isNext,
    required this.onTap,
  });

  final int number;
  final Lesson lesson;
  final LessonProgress? progress;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = progress?.completed ?? false;
    final watched = progress?.watchedSeconds ?? 0;
    final partial = !done && lesson.durationSeconds > 0 && watched > 0
        ? (watched / lesson.durationSeconds).clamp(0.0, 1.0)
        : null;
    return ListTile(
      onTap: onTap,
      selected: isNext,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: SizedBox.square(
        dimension: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (partial != null)
              CircularProgressIndicator(
                value: partial,
                strokeWidth: 3,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            CircleAvatar(
              radius: partial == null ? 20 : 15,
              backgroundColor: done
                  ? scheme.primary
                  : isNext
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              child: done
                  ? Icon(Icons.check, color: scheme.onPrimary, size: 20)
                  : isNext
                  ? Icon(Icons.play_arrow_rounded, color: scheme.primary)
                  : Text(
                      '$number',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
      title: Text(
        lesson.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: isNext ? FontWeight.bold : null),
      ),
      subtitle: Text(
        [
          'Ders $number',
          if (lesson.durationSeconds > 0) formatLength(lesson.durationSeconds),
          if (lesson.questions.isNotEmpty) '${lesson.questions.length} soru',
          if (done) 'Tamamlandı',
        ].join(' · '),
      ),
    );
  }
}

/// Ortalama puan ve değerlendirme sayısı; dokununca değerlendirmeler açılır.
class _RatingRow extends ConsumerWidget {
  const _RatingRow({required this.summary});

  final CourseProgress summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rating = switch (ref.watch(courseRatingsProvider)) {
      AsyncData(value: Ok(:final value)) => value[summary.course.id],
      _ => null,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(CourseReviewsPage(progress: summary)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (rating != null) ...[
              Text(
                rating.average.toStringAsFixed(1),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              RatingStars(rating: rating.average, size: 18),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                rating == null
                    ? 'Henüz değerlendirme yok'
                    : '${rating.count} değerlendirme',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// Hocanın verdiği kursta icazetin durumu; dokununca icazet sayfası.
class _IcazetTile extends ConsumerWidget {
  const _IcazetTile({required this.summary});

  final CourseProgress summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = summary.course;
    final statuses = [
      for (final m in assignedMedreses(ref, course.id, studentOnly: true))
        myIcazet(ref, m.id, course.id)?.status,
    ];
    final text = statuses.contains(IcazetStatus.approved)
        ? 'Hocan icazetini onayladı'
        : statuses.contains(IcazetStatus.pending)
        ? 'Hocanın onayını bekliyor'
        : statuses.contains(IcazetStatus.rejected)
        ? 'Hocan geri çevirdi; notunu gör'
        : summary.finished
        ? 'Hocandan icazet iste'
        : 'Kursu bitirince hocandan icazet isteyebilirsin';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          statuses.contains(IcazetStatus.approved)
              ? Icons.workspace_premium
              : Icons.workspace_premium_outlined,
        ),
        title: const Text('İcazet'),
        subtitle: Text(text),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(IcazetPage(progress: summary)),
      ),
    );
  }
}
