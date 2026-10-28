import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Biten bir dönemin puan sıralaması; dönem üstten seçilir.
class RankingPage extends ConsumerStatefulWidget {
  /// [medrese] sıralaması.
  const RankingPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage> {
  /// Seçili dönem; `null` ise en yenisi.
  DateTime? _period;

  static const _medals = [
    Color(0xFFD4AF37), // altın
    Color(0xFFA8A9AD), // gümüş
    Color(0xFFB87333), // bronz
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id;
    final scores = ref.watch(weeklyScoresProvider(widget.medrese.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık sıralama')),
      body: switch (scores) {
        AsyncData(value: Ok(value: final all)) when all.isNotEmpty => () {
          // Sunucu en yeni dönem önce, dönem içinde puana göre sıralı verir.
          final periods = {for (final s in all) s.periodStart}.toList();
          final period = _period ?? periods.first;
          final ranked = all.where((s) => s.periodStart == period).toList();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final p in periods)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(periodLabel(p)),
                          selected: p == period,
                          onSelected: (_) => setState(() => _period = p),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    for (final (i, s) in ranked.indexed)
                      ListTile(
                        selected: s.studentId == myId,
                        leading: CircleAvatar(
                          backgroundColor: i < _medals.length
                              ? _medals[i]
                              : null,
                          child: Text('${i + 1}'),
                        ),
                        title: Text(
                          s.studentId == myId
                              ? '${displayName(s.studentName)} (sen)'
                              : displayName(s.studentName),
                        ),
                        trailing: Text(
                          '${formatPoints(s.total)} puan',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }(),
        AsyncData(value: Ok()) => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Henüz biten bir dönem yok. Sıralama ilk dönem bitince çıkar.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AsyncData(value: Err(:final error)) => Center(
          child: Text(error.message),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
