import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:flutter/material.dart';

/// Bir öğrencinin bu dönem görev görev dökümü (hocalar için).
class StudentReportPage extends StatelessWidget {
  /// [student] dökümü.
  const StudentReportPage({
    required this.student,
    required this.tasks,
    required this.entries,
    required this.days,
    super.key,
  });

  /// Öğrenci.
  final Member student;

  /// Görevler.
  final List<TaskDefinition> tasks;

  /// Dönemin bütün girdileri.
  final List<TaskEntry> entries;

  /// Dönemin günleri.
  final List<DateTime> days;

  /// Görev toplamının ekranda okunuşu.
  String _amount(TaskDefinition t, num total) => switch (t.kind) {
    TaskKind.checks when t.items.length > 1 => '$total işaret',
    TaskKind.checks => '$total gün',
    TaskKind.pages => '$total sayfa',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = {
      for (final t in tasks) t: taskTotal(t, student.userId, entries),
    };
    final total = scores.entries.fold<double>(
      0,
      (sum, e) => sum + e.key.score(e.value),
    );

    return Scaffold(
      appBar: AppBar(title: Text(displayName(student.name))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dönem: ${periodLabel(days)}'),
                const SizedBox(height: 4),
                Text(
                  'Toplam: ${formatPoints(total)} puan',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final MapEntry(key: t, value: amount) in scores.entries)
            ListTile(
              leading: Icon(taskIcon(t.id)),
              title: Text(t.title),
              subtitle: Text(_amount(t, amount)),
              trailing: Text(
                '${formatPoints(t.score(amount))} puan',
                style: theme.textTheme.titleSmall,
              ),
            ),
        ],
      ),
    );
  }
}
