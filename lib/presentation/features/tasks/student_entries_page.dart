import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/task_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın bir öğrencinin süren dönemdeki işaretlerini düzelttiği görev
/// listesi; göreve dokununca o görevin günleri açılır.
class StudentEntriesPage extends ConsumerWidget {
  /// [studentName]'in görevleri.
  const StudentEntriesPage({
    required this.medrese,
    required this.program,
    required this.studentId,
    required this.studentName,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Medresenin programı.
  final TaskProgram program;

  /// Öğrencinin kimliği.
  final String studentId;

  /// Öğrencinin adı.
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(displayName(studentName))),
      body: ResultListView<TaskDefinition>(
        value: ref
            .watch(taskDefinitionsProvider)
            .whenData(
              (r) => r.map(
                // Uyum puanı ayrı sayfada verilir.
                (list) =>
                    list.where((t) => t.kind != TaskKind.teacher).toList(),
              ),
            ),
        onRefresh: () => ref.refresh(taskDefinitionsProvider.future),
        emptyIcon: Icons.task_alt,
        emptyText: 'Görev yok.',
        itemBuilder: (context, t) => ListTile(
          title: Text(t.title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            TaskPage(
              medrese: medrese,
              task: t,
              program: program,
              studentId: studentId,
            ),
          ),
        ),
      ),
    );
  }
}
