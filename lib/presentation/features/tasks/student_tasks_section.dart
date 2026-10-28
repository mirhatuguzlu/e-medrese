import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/chest_page.dart';
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
String periodLabel(DateTime periodStart) =>
    '${formatShortDate(periodStart)} – '
    '${formatShortDate(periodStart.add(const Duration(days: 6)))}';

/// Öğrencinin bir medresedeki bu dönem görevleri: 2'li kare kartlar.
/// Puanlar dönem bitince sandıkta açıklanır; burada gösterilmez.
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
    final periodStart = program.periodStart(today);
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    final entries = switch (ref.watch(
      periodEntriesProvider((medreseId: medrese.id, periodStart: periodStart)),
    )) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <TaskEntry>[],
    };
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(medrese.name, style: theme.textTheme.titleMedium),
          Text(
            'Bu dönem: ${periodLabel(periodStart)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Dönem dün bittiyse sandık bugün açılır.
          if (today == periodStart && periodStart != program.startDate)
            _ChestCard(
              medrese: medrese,
              periodStart: periodStart.subtract(const Duration(days: 7)),
            ),
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
                  markedToday: entries.any(
                    (e) =>
                        e.taskId == t.id &&
                        e.studentId == myId &&
                        e.day == today,
                  ),
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

/// Biten dönemin sandığı açılmadıysa gösterilen kart.
class _ChestCard extends ConsumerWidget {
  const _ChestCard({required this.medrese, required this.periodStart});

  final Medrese medrese;
  final DateTime periodStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id;
    final unopened = switch (ref.watch(weeklyScoresProvider(medrese.id))) {
      AsyncData(value: Ok(:final value)) => value.any(
        (s) => s.studentId == myId && s.periodStart == periodStart && !s.opened,
      ),
      _ => false,
    };
    if (!unopened) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: theme.colorScheme.tertiaryContainer,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(
            ChestPage(medrese: medrese, periodStart: periodStart),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.redeem,
                  size: 48,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haftalık sandığın hazır!',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${periodLabel(periodStart)} dönemi. Bugün aç; '
                        'açmazsan puanın yine kaydedilir.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.markedToday,
    required this.onTap,
  });

  final TaskDefinition task;
  final bool markedToday;
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
              Row(
                children: [
                  Icon(
                    markedToday ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: markedToday
                        ? theme.colorScheme.primary
                        : theme.hintColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      markedToday ? 'Bugün yapıldı' : 'Bugün bekliyor',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
