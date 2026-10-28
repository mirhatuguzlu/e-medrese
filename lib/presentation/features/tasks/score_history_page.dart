import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir öğrencinin biten dönemlerdeki puanları, en yeni önce.
class ScoreHistoryPage extends ConsumerWidget {
  /// [studentId] `null` ise giriş yapan kullanıcının geçmişi.
  const ScoreHistoryPage({
    required this.medrese,
    this.studentId,
    this.studentName,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Öğrenci; `null` ise kendisi.
  final String? studentId;

  /// Başlıkta gösterilecek ad.
  final String? studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id =
        studentId ?? ref.watch(sessionProvider).valueOrNull?.user.id ?? '';
    final tasks = switch (ref.watch(taskDefinitionsProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <TaskDefinition>[],
    };
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          studentName == null
              ? 'Puan geçmişim'
              : '${displayName(studentName!)} · geçmiş',
        ),
      ),
      body: ResultListView<WeeklyScore>(
        value: ref
            .watch(weeklyScoresProvider(medrese.id))
            .whenData(
              (r) => r.map(
                (list) => list.where((s) => s.studentId == id).toList(),
              ),
            ),
        onRefresh: () => ref.refresh(weeklyScoresProvider(medrese.id).future),
        emptyIcon: Icons.history,
        emptyText: 'Henüz biten bir dönem yok.',
        itemBuilder: (context, s) => ListTile(
          title: Text(periodLabel(s.periodStart)),
          subtitle: Text(
            [
              for (final t in tasks)
                '${t.title}: ${formatPoints(s.details[t.id] ?? 0)}',
              if (!s.opened) 'Sandık açılmadı, puan otomatik aktarıldı.',
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: Text(
            '${formatPoints(s.total)} puan',
            style: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
