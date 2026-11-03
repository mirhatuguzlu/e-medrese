import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/presentation/features/rewards/reject_reward_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Öğrencilerin ödül istekleri (hocalar). Yalnız istenmiş ödül teslim edildi
/// işaretlenir; istek, bildirim gitmese de burada görünür.
class RewardRequestsPage extends ConsumerWidget {
  /// [medrese]'nin ödül istekleri.
  const RewardRequestsPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  Future<void> _deliver(
    BuildContext context,
    WidgetRef ref,
    RewardClaim c,
  ) async {
    if (!await confirm(
      context,
      title: 'Teslim edildi',
      message:
          '"${c.title}" ödülü ${displayName(c.studentName)} adlı öğrenciye '
          'teslim edildi mi? ${formatPoints(c.points)} puan birikmiş '
          'puanından düşülür.',
      action: 'Teslim edildi',
    )) {
      return;
    }
    final result = await ref.read(rewardRepositoryProvider).deliver(c.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(rewardClaimsProvider(medrese.id));
        context.showMessage('Teslim edildi olarak işaretlendi.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödül istekleri')),
      body: ResultListView<RewardClaim>(
        value: ref.watch(rewardClaimsProvider(medrese.id)),
        onRefresh: () => ref.refresh(rewardClaimsProvider(medrese.id).future),
        emptyIcon: Icons.redeem,
        emptyText: 'Henüz ödül isteyen öğrenci yok.',
        itemBuilder: (context, c) {
          final when = switch ((c.deliveredAt, c.rejectedAt)) {
            (final at?, _) => 'teslim: ${formatDateTime(at)}',
            (_, final at?) =>
              'reddedildi: ${formatDateTime(at)}\nNeden: ${c.rejectReason}',
            _ => 'istedi: ${formatDateTime(c.requestedAt)}',
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ListTile(
                leading: Icon(switch (c) {
                  RewardClaim(pending: true) => Icons.redeem,
                  RewardClaim(deliveredAt: _?) => Icons.check_circle_outline,
                  _ => Icons.block,
                }),
                title: Text('${displayName(c.studentName)} · ${c.title}'),
                subtitle: Text('${formatPoints(c.points)} puan · $when'),
              ),
              if (c.pending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => context.push(
                          RejectRewardPage(medrese: medrese, claim: c),
                        ),
                        child: const Text('Reddet'),
                      ),
                      FilledButton(
                        onPressed: () => _deliver(context, ref, c),
                        child: const Text('Teslim edildi'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
