import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/task_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Görevin kartta gösterilen ikonu.
IconData taskIcon(String taskId) => switch (taskId) {
  'namaz' => Icons.access_time,
  'risale' => Icons.menu_book_outlined,
  'ders' => Icons.school_outlined,
  'cuz' => Icons.auto_stories_outlined,
  'kitap' => Icons.library_books_outlined,
  _ => Icons.task_alt,
};

/// Dönemin gün aralığı: `27.10 – 02.11`.
String periodLabel(List<DateTime> days) =>
    '${formatShortDate(days.first)} – ${formatShortDate(days.last)}';

/// Öğrencinin bir medresedeki bu dönem görevleri: 2'li kare kartlar.
///
/// Program başlamadıysa ya da durdurulduysa hiçbir şey çizmez.
class StudentTasksSection extends ConsumerWidget {
  /// [medrese] için görevler.
  const StudentTasksSection({required this.medrese, super.key});

  /// Öğrencisi olunan medrese.
  final Medrese medrese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = switch (ref.watch(taskProgramProvider(medrese.id))) {
      AsyncData(value: Ok(:final value?)) when value.active => value,
      _ => null,
    };
    final tasks = switch (ref.watch(taskDefinitionsProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    if (program == null || tasks == null) return const SizedBox.shrink();

    final today = ref.watch(todayProvider);
    final days = program.periodDays(today);
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    final entries = switch (ref.watch(
      periodEntriesProvider((medreseId: medrese.id, periodStart: days.first)),
    )) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <TaskEntry>[],
    };
    final total = tasks.fold<double>(
      0,
      (sum, t) => sum + t.score(taskTotal(t, myId, entries)),
    );
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(medrese.name, style: theme.textTheme.titleMedium),
          Text(
            'Bu dönem (${periodLabel(days)}): ${formatPoints(total)} puan',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final t in tasks)
                _TaskTile(
                  task: t,
                  score: t.score(taskTotal(t, myId, entries)),
                  onTap: () => context.push(
                    TaskPage(medrese: medrese, task: t, program: program),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.score,
    required this.onTap,
  });

  final TaskDefinition task;
  final double score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                taskIcon(task.id),
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const Spacer(),
              Text(
                task.title,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${formatPoints(score)} / ${formatPoints(task.points)} puan',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (score / task.points).clamp(0, 1).toDouble(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
