import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/rewards/rewards_page.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
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
    required this.today,
    required this.entries,
    super.key,
  });

  /// Öğrencisi olunan medrese.
  final Medrese medrese;

  /// Görev tanımları.
  final List<TaskDefinition> tasks;

  /// Süren dönemin ilk günü.
  final DateTime periodStart;

  /// Bugün.
  final DateTime today;

  /// Süren dönemin girdileri.
  final List<TaskEntry> entries;

  static String _unit(TaskDefinition t) => switch (t.kind) {
    TaskKind.pages => 'sayfa',
    TaskKind.checks when t.items.length > 1 => 'vakit',
    _ => 'kez',
  };

  /// Satırda görünen kısa yazı: bugünden itibaren ne yapılacak.
  static String _short(TaskNeed n, ({int left, int? perDay}) week) {
    final unit = _unit(n.task);
    if (n.task.id == 'namaz') return 'Her gün ${n.task.items.length} vakit';
    if (week.left == 0) return 'Bu haftalık tamam';
    final perDay = week.perDay;
    return perDay != null
        ? 'Her gün $perDay $unit'
        : 'Bu hafta ${week.left} $unit daha';
  }

  /// Satıra dokununca açılan açıklama.
  static String _detail(
    TaskNeed n,
    num done,
    ({int left, int? perDay}) week,
    int daysLeft,
  ) {
    final unit = _unit(n.task);
    return [
      if (n.task.id == 'namaz')
        'Namaz kısılmaz: her gün ${n.task.items.length} vaktin hepsini kıl.'
      else
        'Hedefine yetişmek için her hafta en az ${n.perWeek} $unit.',
      'Bu hafta ${formatPoints(done)} $unit yaptın.',
      if (n.task.id != 'namaz')
        switch (week) {
          (left: 0, perDay: _) => 'Bu haftanın payı tamam.',
          (:final left, perDay: final perDay?) =>
            'Kalan $left $unit, haftanın kalan $daysLeft gününe bölünce '
                'her gün $perDay $unit.',
          (:final left, perDay: null) => 'Bu hafta $left $unit daha yap.',
        },
    ].join('\n');
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
    final claims = switch (ref.watch(rewardClaimsProvider(medrese.id))) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };
    final total = switch (ref.watch(weeklyScoresProvider(medrese.id))) {
      AsyncData(value: Ok(:final value)) when claims != null => rewardBalance(
        value,
        claims,
        myId,
      ),
      _ => null,
    };
    if (claims == null || total == null) return const SizedBox.shrink();
    final pending = claims.any((c) => c.rewardId == reward.id && c.pending);
    final daysLeft = 7 - today.difference(periodStart).inDays;
    final plan = planGoal(
      tasks: tasks,
      total: total,
      threshold: reward.points,
      weeks: weeksUntil(periodStart, goal.deadline),
    );
    final theme = Theme.of(context);

    final showPlan = !pending && plan.remaining > 0 && plan.weeks > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
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
                    '${formatPoints(total)} / ${formatPoints(reward.points)} '
                    'puan · bitiş ${formatShortDate(goal.deadline)}',
                  ),
                  const SizedBox(height: 8),
                  if (pending)
                    const Text('Ödülünü istedin; hocan teslim edecek.')
                  else if (plan.remaining == 0)
                    const Text('Ödüle ulaştın! Dokun ve ödülünü iste.')
                  else if (plan.weeks == 0)
                    const Text(
                      'Süre doldu. Ödüle dokunup yeni bir bitiş günü seç.',
                    )
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
                  ],
                ],
              ),
            ),
          ),
          if (showPlan) ...[
            for (final n in plan.needs)
              () {
                final done = taskTotal(n.task, myId, entries);
                final week = leftThisWeek(n, done, daysLeft);
                return ExpansionTile(
                  leading: Icon(taskIcon(n.task.id)),
                  title: Text(n.task.title),
                  subtitle: Text(_short(n, week)),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  expandedAlignment: Alignment.centerLeft,
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [Text(_detail(n, done, week, daysLeft))],
                );
              }(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'Uyum puanı hesaba katılmadı; ondan alacağın puan seni '
                'hedefe daha erken ulaştırır.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
