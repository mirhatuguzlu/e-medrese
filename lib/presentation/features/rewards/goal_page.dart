import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Öğrencinin bir ödülü bitiş günüyle hedef seçtiği sayfa.
class GoalPage extends ConsumerStatefulWidget {
  /// [reward]'ı hedef seç; [current] bu ödül zaten hedefse dolu.
  const GoalPage({
    required this.medrese,
    required this.reward,
    this.current,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Hedef seçilen ödül.
  final Reward reward;

  /// Bu ödüldeki mevcut hedef.
  final RewardGoal? current;

  @override
  ConsumerState<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends ConsumerState<GoalPage> {
  late DateTime? _deadline = widget.current?.deadline;
  bool _loading = false;

  /// Süren dönemin ilk günü; program yoksa bugün.
  DateTime get _periodStart {
    final today = ref.read(todayProvider);
    return switch (ref.read(taskProgramProvider(widget.medrese.id))) {
      AsyncData(value: Ok(:final value?)) => value.periodStart(today),
      _ => today,
    };
  }

  Future<void> _pick() async {
    // En erken süren dönemin son günü: puan dönem bitince eklenir.
    final first = _periodStart.add(const Duration(days: 6));
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? first.add(const Duration(days: 28)),
      firstDate: first,
      lastDate: first.add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _deadline = dateOnly(picked));
  }

  Future<void> _save() async {
    final deadline = _deadline;
    if (deadline == null) {
      context.showMessage('Bir bitiş günü seç.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(rewardRepositoryProvider)
        .setGoal(
          medreseId: widget.medrese.id,
          rewardId: widget.reward.id,
          deadline: deadline,
        );
    _done(result, 'Hedefin kaydedildi.');
  }

  Future<void> _clear() async {
    setState(() => _loading = true);
    final result = await ref
        .read(rewardRepositoryProvider)
        .clearGoal(widget.medrese.id);
    _done(result, 'Hedefin kaldırıldı.');
  }

  void _done(Result<void, AppFailure> result, String message) {
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(myGoalProvider(widget.medrese.id));
        context.showMessage(message);
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seçiciyi açarken okunabilsin diye dinlenir.
    ref.watch(taskProgramProvider(widget.medrese.id));
    final theme = Theme.of(context);
    final deadline = _deadline;
    final r = widget.reward;

    return Scaffold(
      appBar: AppBar(title: const Text('Hedef seç')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(r.title, style: theme.textTheme.titleLarge),
          Text('${formatPoints(r.points)} birikmiş puan'),
          if (r.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.description),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(
              deadline == null
                  ? 'Bitiş günü seç'
                  : 'Bitiş: ${formatDay(deadline)}',
            ),
            onPressed: _loading ? null : _pick,
          ),
          if (deadline != null) ...[
            const SizedBox(height: 8),
            Text(
              '${weeksUntil(_periodStart, deadline)} hafta. '
              'Puanlar hafta bitince eklendiği için yarım hafta sayılmaz.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          LoadingButton(
            label: widget.current == null ? 'Hedef yap' : 'Kaydet',
            loading: _loading,
            onPressed: _save,
          ),
          if (widget.current != null)
            TextButton(
              onPressed: _loading ? null : _clear,
              child: const Text('Hedefi kaldır'),
            ),
        ],
      ),
    );
  }
}
