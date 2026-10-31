import 'dart:async';
import 'dart:math' as math;

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/star_view.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Sandığın açılış animasyonu bitti; puanlar gösterilir.
  bool _revealed = false;

  Future<void> _tap() async {
    if (_opening || _score != null) return;
    unawaited(HapticFeedback.mediumImpact());
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
        unawaited(HapticFeedback.heavyImpact());
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
      appBar: AppBar(title: const Text('Haftalık puan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: score != null && _revealed
              ? _opened(theme, score)
              : _closed(theme),
        ),
      ),
    );
  }

  Widget _closed(ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(periodLabel(widget.periodStart), style: theme.textTheme.titleMedium),
      const SizedBox(height: 64),
      GestureDetector(
        onTap: _tap,
        child: StarView(
          taps: _taps,
          open: _score != null,
          onOpened: () => setState(() => _revealed = true),
        ),
      ),
      const SizedBox(height: 48),
      if (_score != null)
        const SizedBox(height: 36)
      else if (_opening)
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
    final tally = _ScoreTally.duration(tasks.length);
    return ListView(
      shrinkWrap: true,
      children: [
        Icon(
          Icons.auto_awesome,
          size: 96,
          color: theme.colorScheme.tertiary,
        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        _ScoreTally(tasks: tasks, score: score),
        const SizedBox(height: 8),
        Text(
          'Puanın geçmişine kaydedildi.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ).animate(delay: tally).fadeIn(),
        if (score.note.isNotEmpty)
          _TeacherNote(
            points: score.details['uyum'] ?? 0,
            note: score.note,
          ).animate(delay: tally + 300.ms).fadeIn().slideY(begin: 0.2),
      ],
    );
  }
}

/// Görev puanları sırayla sayılarak artar; sonra her puan bir yıldız olup
/// aşağı kayar ve toplamın içine düşerek onu büyütür.
class _ScoreTally extends StatefulWidget {
  const _ScoreTally({required this.tasks, required this.score});

  final List<TaskDefinition> tasks;
  final WeeklyScore score;

  static const _rowHeight = 60.0;
  static const _totalHeight = 72.0;

  // Zamanlama (ms).
  static const _rowGap = 450;
  static const _count = 700;
  static const _pause = 300;
  static const _flyGap = 350;
  static const _fly = 700;
  static const _land = 300;

  static int _flyStart(int n) => math.max(n - 1, 0) * _rowGap + _count + _pause;

  /// [n] görevlik animasyonun toplam süresi.
  static Duration duration(int n) => Duration(
    milliseconds: _flyStart(n) + math.max(n - 1, 0) * _flyGap + _fly + _land,
  );

  @override
  State<_ScoreTally> createState() => _ScoreTallyState();
}

class _ScoreTallyState extends State<_ScoreTally>
    with SingleTickerProviderStateMixin {
  late final int _n = widget.tasks.length;
  late final _c = AnimationController(
    vsync: this,
    duration: _ScoreTally.duration(_n),
  );
  int _landed = 0;

  num _points(int i) => widget.score.details[widget.tasks[i].id] ?? 0;

  int _arrival(int i) =>
      _ScoreTally._flyStart(_n) + i * _ScoreTally._flyGap + _ScoreTally._fly;

  @override
  void initState() {
    super.initState();
    // Her yıldız toplama düştüğünde telefon hafifçe titrer.
    _c.addListener(() {
      final ms = _c.value * _c.duration!.inMilliseconds;
      final landed = [
        for (var i = 0; i < _n; i++)
          if (_points(i) > 0 && ms >= _arrival(i)) i,
      ].length;
      if (landed > _landed) {
        _landed = landed;
        unawaited(HapticFeedback.lightImpact());
      }
    });
    unawaited(_c.forward());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const rowH = _ScoreTally._rowHeight;
    final totalTop = _n * rowH + 16;
    return SizedBox(
      height: totalTop + _ScoreTally._totalHeight,
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final w = box.maxWidth;
            final ms = _c.value * _c.duration!.inMilliseconds;
            double phase(num start, int length) =>
                ((ms - start) / length).clamp(0, 1).toDouble();

            final rows = <Widget>[];
            final stars = <Widget>[];
            num landedSum = 0;
            var bump = 0.0;
            for (var i = 0; i < _n; i++) {
              final t = widget.tasks[i];
              final v = _points(i);
              final appear = phase(i * _ScoreTally._rowGap, 300);
              final count = Curves.easeOutCubic.transform(
                phase(i * _ScoreTally._rowGap, _ScoreTally._count),
              );
              final fly = phase(
                _arrival(i) - _ScoreTally._fly,
                _ScoreTally._fly,
              );
              final land = phase(_arrival(i), _ScoreTally._land);
              landedSum += v * land;
              bump = math.max(bump, math.sin(math.pi * land));

              rows.add(
                Positioned(
                  top: i * rowH,
                  left: 0,
                  right: 0,
                  height: rowH,
                  child: Opacity(
                    opacity: appear,
                    child: Transform.translate(
                      offset: Offset(40 * (1 - appear), 0),
                      child: Row(
                        children: [
                          Icon(taskIcon(t.id)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title),
                                if (t.kind == TaskKind.teacher)
                                  Text(
                                    'Hocan verdi',
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          // Yıldız uçunca puan söner.
                          Opacity(
                            opacity: v > 0 ? 1 - 0.6 * fly : 1,
                            child: Text(
                              '+${formatPoints(v * count)}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              if (v > 0 && fly > 0 && land < 1) {
                final p0 = Offset(w - 20, i * rowH + rowH / 2);
                final p2 = Offset(
                  w / 2,
                  totalTop + _ScoreTally._totalHeight / 2,
                );
                final p1 = Offset(w, p2.dy - 24);
                final s = Curves.easeInOut.transform(fly);
                final pos =
                    p0 * ((1 - s) * (1 - s)) +
                    p1 * (2 * (1 - s) * s) +
                    p2 * (s * s);
                final size = 28 + 16 * math.sin(math.pi * s);
                stars.add(
                  Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    child: Opacity(
                      opacity: 1 - land,
                      child: Icon(
                        Icons.star_rounded,
                        size: size,
                        color: const Color(0xFFFFC83D),
                        shadows: const [
                          Shadow(color: Color(0xFFFFE7A3), blurRadius: 16),
                        ],
                      ),
                    ),
                  ),
                );
              }
            }

            final shown = _c.isCompleted ? widget.score.total : landedSum;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ...rows,
                Positioned(
                  top: totalTop - 12,
                  left: 0,
                  right: 0,
                  child: const Divider(),
                ),
                Positioned(
                  top: totalTop,
                  left: 0,
                  right: 0,
                  height: _ScoreTally._totalHeight,
                  child: Center(
                    child: Transform.scale(
                      scale: 1 + 0.2 * bump,
                      child: Text(
                        '${formatPoints(shown)} puan',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Color.lerp(
                            theme.colorScheme.onSurface,
                            const Color(0xFFE8B931),
                            bump,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ...stars,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Hocanın uyum puanı ve notu: mektup gibi bir kart.
class _TeacherNote extends StatelessWidget {
  const _TeacherNote({required this.points, required this.note});

  final num points;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 24),
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake_outlined, color: colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hocanın notu',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${formatPoints(points)} / ${UyumGrade.max}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Hocan bu hafta sana ${formatPoints(points)} uyum puanı verdi.',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Icon(Icons.format_quote, color: colors.secondary),
            Text(
              note,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: colors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
