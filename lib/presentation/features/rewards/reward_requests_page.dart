import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
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
          final delivered = c.deliveredAt;
          final when = delivered == null
              ? 'istedi: ${formatDateTime(c.requestedAt)}'
              : 'teslim: ${formatDateTime(delivered)}';
          return ListTile(
            leading: Icon(
              delivered == null ? Icons.redeem : Icons.check_circle_outline,
            ),
            title: Text('${displayName(c.studentName)} · ${c.title}'),
            subtitle: Text('${formatPoints(c.points)} puan · $when'),
            trailing: delivered == null
                ? FilledButton(
                    onPressed: () => _deliver(context, ref, c),
                    child: const Text('Teslim edildi'),
                  )
                : null,
          );
        },
      ),
    );
  }
}
