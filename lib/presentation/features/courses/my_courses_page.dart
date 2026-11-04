import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/data/repositories/saved_courses_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/online_medrese_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kullanıcının başladığı kurslar: devam edenler (son izlenen başta) ve
/// bitirdikleri.
class MyCoursesPage extends ConsumerWidget {
  /// Kurslarım sayfası.
  const MyCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final courses = switch (ref.watch(coursesProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <Course>[],
    };
    final progress = switch (ref.watch(lessonProgressProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String, LessonProgress>{},
    };
    final started =
        [
            for (final c in courses) CourseProgress(c, progress),
          ].where((p) => p.started).toList()
          ..sort((a, b) => b.lastWatched!.compareTo(a.lastWatched!));
    final going = started.where((p) => !p.finished).toList();
    final done = started.where((p) => p.finished).toList();
    // Kaydedilip henüz başlanmayanlar; başlanınca "Devam edenler"e geçer.
    final byId = {for (final c in courses) c.id: c};
    final saved = [
      for (final id in ref.watch(savedCoursesProvider))
        if (byId[id] case final c? when !CourseProgress(c, progress).started) c,
    ];
    final lessonsDone = progress.values.where((p) => p.completed).length;
    final watchedSeconds = progress.values.fold<int>(
      0,
      (s, p) => s + p.watchedSeconds,
    );

    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Kurslarım')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(coursesProvider)
            ..invalidate(lessonProgressProvider);
          await ref.read(lessonProgressProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (started.isEmpty && saved.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Henüz bir kursa başlamadın. Online Medrese akışından '
                  'bir kurs seç; sonra izlemek istediklerini kurs '
                  'sayfasındaki yer imiyle kaydedebilirsin.',
                  textAlign: TextAlign.center,
                ),
              )
            else if (started.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        _Stat(value: '${going.length}', label: 'devam eden'),
                        _Stat(value: '${done.length}', label: 'biten'),
                        _Stat(value: '$lessonsDone', label: 'ders'),
                        _Stat(
                          value: formatLength(watchedSeconds),
                          label: 'izleme',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (going.isNotEmpty) title('Devam edenler'),
            for (final p in going)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: CourseCard(progress: p),
              ),
            if (saved.isNotEmpty) title('Kaydettiklerin'),
            for (final c in saved)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: CourseCard(progress: CourseProgress(c, progress)),
              ),
            if (done.isNotEmpty) title('Bitirdiklerin'),
            for (final p in done)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: CourseCard(progress: p),
              ),
          ],
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
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
