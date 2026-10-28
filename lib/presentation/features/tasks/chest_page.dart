import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Biten dönemin sandığı: öğrenci dokuna dokuna açar, görev puanları tek tek
/// çıkar, sonunda toplam sayılır.
class ChestPage extends ConsumerStatefulWidget {
  /// [periodStart] döneminin sandığı.
  const ChestPage({
    required this.medrese,
    required this.periodStart,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Biten dönemin ilk günü.
  final DateTime periodStart;

  @override
  ConsumerState<ChestPage> createState() => _ChestPageState();
}

class _ChestPageState extends ConsumerState<ChestPage> {
  static const _tapsToOpen = 3;

  int _taps = 0;
  bool _opening = false;
  WeeklyScore? _score;

  Future<void> _tap() async {
    if (_opening || _score != null) return;
    setState(() => _taps++);
    if (_taps < _tapsToOpen) return;

    setState(() => _opening = true);
    final result = await ref
        .read(taskRepositoryProvider)
        .openChest(
          medreseId: widget.medrese.id,
          periodStart: widget.periodStart,
        );
    if (!mounted) return;
    ref.invalidate(weeklyScoresProvider(widget.medrese.id));
    switch (result) {
      case Ok(:final value):
        setState(() => _score = value);
      case Err(:final error):
        setState(() {
          _opening = false;
          _taps = 0;
        });
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = _score;
    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık sandık')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: score == null ? _closed(theme) : _opened(theme, score),
        ),
      ),
    );
  }

  Widget _closed(ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(periodLabel(widget.periodStart), style: theme.textTheme.titleMedium),
      const SizedBox(height: 32),
      GestureDetector(
        onTap: _tap,
        child:
            Icon(
                  Icons.redeem,
                  size: 160 + 16.0 * _taps,
                  color: theme.colorScheme.tertiary,
                )
                // Her dokunuşta yeniden sallanır.
                .animate(key: ValueKey(_taps))
                .shake(hz: 6, duration: 400.ms)
                .scaleXY(begin: 0.95, end: 1, duration: 200.ms),
      ),
      const SizedBox(height: 32),
      if (_opening)
        const CircularProgressIndicator()
      else
        Text(
          'Açmak için ${_tapsToOpen - _taps} kez dokun',
          style: theme.textTheme.titleMedium,
        ),
    ],
  );

  Widget _opened(ThemeData theme, WeeklyScore score) {
    final tasks = switch (ref.watch(taskDefinitionsProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <TaskDefinition>[],
    };
    const step = Duration(milliseconds: 500);
    return ListView(
      shrinkWrap: true,
      children: [
        Icon(
          Icons.auto_awesome,
          size: 96,
          color: theme.colorScheme.tertiary,
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        for (final (i, t) in tasks.indexed)
          ListTile(
                leading: Icon(taskIcon(t.id)),
                title: Text(t.title),
                trailing: Text(
                  '+${formatPoints(score.details[t.id] ?? 0)}',
                  style: theme.textTheme.titleMedium,
                ),
              )
              .animate(delay: step * (i + 1))
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.3),
        const Divider(),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score.total.toDouble()),
          duration: step * (tasks.length + 2),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            '${formatPoints(value)} puan',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Puanın geçmişine kaydedildi.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ).animate(delay: step * (tasks.length + 2)).fadeIn(),
      ],
    );
  }
}
