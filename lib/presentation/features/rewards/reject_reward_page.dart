import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın ödül isteğini nedeniyle reddettiği sayfa. Neden öğrenciye
/// bildirilir, ayrılan puan öğrenciye döner.
class RejectRewardPage extends ConsumerStatefulWidget {
  /// [claim]'i reddet.
  const RejectRewardPage({
    required this.medrese,
    required this.claim,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Bekleyen istek.
  final RewardClaim claim;

  @override
  ConsumerState<RejectRewardPage> createState() => _RejectRewardPageState();
}

class _RejectRewardPageState extends ConsumerState<RejectRewardPage> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(rewardRepositoryProvider)
        .reject(widget.claim.id, _reason.text);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(rewardClaimsProvider(widget.medrese.id));
        context.showMessage('İstek reddedildi; öğrenciye bildirildi.');
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.claim;
    return Scaffold(
      appBar: AppBar(title: const Text('İsteği reddet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${displayName(c.studentName)} · ${c.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Neden öğrenciye bildirilir; ayrılan puan öğrenciye döner.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Reddetme nedeni'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 500,
              minLines: 2,
              maxLines: 6,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Reddetme nedenini yaz.' : null,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: 'Reddet',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
