import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
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

  /// Bütün görevler tam yapılsa ödüle ulaşılan en erken gün; veri
  /// yüklenmediyse `null`.
  DateTime? _earliest() {
    final id = widget.medrese.id;
    final today = ref.watch(todayProvider);
    final periodStart = _periodStart;
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    // Program yoksa bu hafta yapılan da yok.
    final entries = switch (ref.watch(taskProgramProvider(id))) {
      AsyncData(value: Ok(value: _?)) => switch (ref.watch(
        periodEntriesProvider((medreseId: id, periodStart: periodStart)),
      )) {
        AsyncData(value: Ok(:final value)) => value,
        _ => null,
      },
      AsyncData(value: Ok()) => const <TaskEntry>[],
      _ => null,
    };
    final data = (
      ref.watch(taskDefinitionsProvider),
      ref.watch(weeklyScoresProvider(id)),
      ref.watch(rewardClaimsProvider(id)),
    );
    if (data case (
      AsyncData(value: Ok(value: final tasks)),
      AsyncData(value: Ok(value: final scores)),
      AsyncData(value: Ok(value: final claims)),
    ) when entries != null) {
      return earliestDeadline(
        tasks: tasks,
        entries: entries,
        student: myId,
        // Bu ödülün bekleyen isteği varsa puanı ayrılmış sayılmasın.
        total: rewardBalance(scores, [
          for (final c in claims)
            if (!(c.pending && c.rewardId == widget.reward.id)) c,
        ], myId),
        threshold: widget.reward.points,
        periodStart: periodStart,
        today: today,
      );
    }
    return null;
  }

  Future<void> _pick(DateTime first) async {
    final deadline = _deadline;
    final picked = await showDatePicker(
      context: context,
      initialDate: deadline == null || deadline.isBefore(first)
          ? first
          : deadline,
      firstDate: first,
      lastDate: first.add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _deadline = dateOnly(picked));
  }

  Future<void> _save(DateTime? first) async {
    final deadline = _deadline;
    if (first == null) return;
    if (deadline == null || deadline.isBefore(first)) {
      context.showMessage(
        'Bir bitiş günü seç; en erken ${formatShortDate(first)}.',
      );
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
    final first = _earliest();
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
            onPressed: _loading || first == null ? null : () => _pick(first),
          ),
          if (first != null) ...[
            const SizedBox(height: 8),
            Text(
              'En erken ${formatDay(first)}: bütün görevleri tam yapsan '
              'bile daha önce ulaşamazsın. Uyum puanı hesaba katılmadı.',
              style: theme.textTheme.bodySmall,
            ),
          ],
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
            onPressed: () => _save(first),
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
