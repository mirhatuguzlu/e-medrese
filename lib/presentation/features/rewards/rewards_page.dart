import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/presentation/features/rewards/goal_page.dart';
import 'package:e_medrese/presentation/features/rewards/new_reward_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın koyduğu ödüller. Hoca ekler ve siler; öğrenci birikmiş puanını
/// görür ve bir ödülü hedef seçer.
class RewardsPage extends ConsumerWidget {
  /// [medrese]'nin ödülleri.
  const RewardsPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  Future<void> _delete(BuildContext context, WidgetRef ref, Reward r) async {
    if (!await confirm(
      context,
      title: 'Ödülü sil',
      message:
          '"${r.title}" silinsin mi? Bunu hedef seçenlerin hedefi de silinir.',
      action: 'Sil',
    )) {
      return;
    }
    final result = await ref.read(rewardRepositoryProvider).deleteReward(r.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(rewardsProvider(medrese.id));
        context.showMessage('Ödül silindi.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final staff = medrese.myRole.isStaff;
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    final total = staff
        ? null
        : switch (ref.watch(weeklyScoresProvider(medrese.id))) {
            AsyncData(value: Ok(:final value)) => totalScore(value, myId),
            _ => null,
          };
    final goal = staff
        ? null
        : switch (ref.watch(myGoalProvider(medrese.id))) {
            AsyncData(value: Ok(:final value)) => value,
            _ => null,
          };

    return Scaffold(
      appBar: AppBar(title: const Text('Ödüller')),
      body: ResultListView<Reward>(
        value: ref.watch(rewardsProvider(medrese.id)),
        onRefresh: () => ref.refresh(rewardsProvider(medrese.id).future),
        emptyIcon: Icons.card_giftcard,
        emptyText: staff
            ? 'Henüz ödül yok.\nÖğrencilerin hedef seçmesi için ödül ekle.'
            : 'Hocan henüz ödül koymadı.',
        header: total == null
            ? null
            : (_) => ListTile(
                leading: const Icon(Icons.stars_outlined),
                title: Text('Birikmiş puanın: ${formatPoints(total)}'),
                subtitle: const Text('Biten haftaların puanları toplanır.'),
              ),
        itemBuilder: (context, r) {
          final isGoal = goal?.rewardId == r.id;
          final left = total == null ? null : r.points - total;
          return ListTile(
            leading: Icon(
              isGoal ? Icons.flag : Icons.card_giftcard,
              color: isGoal ? theme.colorScheme.primary : null,
            ),
            title: Text(r.title),
            subtitle: Text(
              [
                '${formatPoints(r.points)} puan',
                if (left != null)
                  left <= 0 ? 'Ulaştın!' : '${formatPoints(left)} puan kaldı',
                if (isGoal) 'Hedefin: ${formatShortDate(goal!.deadline)}',
                if (r.description.isNotEmpty) r.description,
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: staff
                ? IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, r),
                  )
                : const Icon(Icons.chevron_right),
            onTap: staff
                ? null
                : () => context.push(
                    GoalPage(
                      medrese: medrese,
                      reward: r,
                      current: isGoal ? goal : null,
                    ),
                  ),
          );
        },
      ),
      floatingActionButton: staff
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Ödül ekle'),
              onPressed: () => context.push(NewRewardPage(medrese: medrese)),
            )
          : null,
    );
  }
}
