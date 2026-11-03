import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/rewards/rewards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana sayfada öğrencinin hedef önerisi: hedefe yetişmek için görev başına
/// günlük/haftalık en az miktar. Hedef yoksa ödül varsa hedef seçtirir.
class GoalCard extends ConsumerWidget {
  /// [medrese]'deki hedef.
  const GoalCard({
    required this.medrese,
    required this.tasks,
    required this.periodStart,
    super.key,
  });

  /// Öğrencisi olunan medrese.
  final Medrese medrese;

  /// Görev tanımları.
  final List<TaskDefinition> tasks;

  /// Süren dönemin ilk günü.
  final DateTime periodStart;

  static String _unit(TaskDefinition t) => switch (t.kind) {
    TaskKind.pages => 'sayfa',
    TaskKind.checks when t.items.length > 1 => 'vakit',
    _ => 'kez',
  };

  static String _needText(TaskNeed n) {
    final unit = _unit(n.task);
    if (n.task.id == 'namaz') {
      return 'her gün ${n.task.items.length} vakit, hepsi kılınmalı';
    }
    final perDay = n.perDay;
    return perDay != null
        ? 'günde en az $perDay $unit'
        : 'haftada en az ${n.perWeek} $unit';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = switch (ref.watch(rewardsProvider(medrese.id))) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    final goal = switch (ref.watch(myGoalProvider(medrese.id))) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    if (rewards == null || rewards.isEmpty) return const SizedBox.shrink();
    void open() => context.push(RewardsPage(medrese: medrese));

    final reward = rewards.where((r) => r.id == goal?.rewardId).firstOrNull;
    if (goal == null || reward == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.card_giftcard),
          title: const Text('Bir ödülü hedef seç'),
          subtitle: const Text(
            'Hedefine göre her gün ne yapacağını gösteririz.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: open,
        ),
      );
    }

    final myId = ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    final total = switch (ref.watch(weeklyScoresProvider(medrese.id))) {
      AsyncData(value: Ok(:final value)) => totalScore(value, myId),
      _ => null,
    };
    if (total == null) return const SizedBox.shrink();
    final plan = planGoal(
      tasks: tasks,
      total: total,
      threshold: reward.points,
      weeks: weeksUntil(periodStart, goal.deadline),
    );
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hedef: ${reward.title}',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '${formatPoints(total)} / ${formatPoints(reward.points)} puan · '
                'bitiş ${formatShortDate(goal.deadline)}',
              ),
              const SizedBox(height: 8),
              if (plan.remaining == 0)
                const Text('Ödüle ulaştın! Hocana haber ver.')
              else if (plan.weeks == 0)
                const Text('Süre doldu. Ödüle dokunup yeni bir bitiş günü seç.')
              else ...[
                Text(
                  '${formatPoints(plan.remaining)} puan kaldı, '
                  '${plan.weeks} hafta: haftada en az '
                  '${formatPoints(plan.remaining / plan.weeks)} puan.',
                ),
                if (!plan.reachable)
                  Text(
                    'Bu sürede bütün görevleri tam yapsan da yetişmiyor; '
                    'bitiş gününü uzat.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: 8),
                for (final n in plan.needs)
                  Text('• ${n.task.title}: ${_needText(n)}'),
                const SizedBox(height: 8),
                Text(
                  'Uyum puanı hesaba katılmadı; ondan alacağın puan seni '
                  'hedefe daha erken ulaştırır.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
