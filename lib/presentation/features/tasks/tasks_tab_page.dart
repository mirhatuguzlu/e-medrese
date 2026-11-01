import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/features/tasks/task_tracking_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Görev takibi sekmesi (ana sayfa): öğrencisi olunan medreselerin görev
/// kartları, hocası olunanların görev takibi. Yalnız bir medresede hocaysa
/// ve öğrencisi olduğu medrese yoksa o medresenin görev takibi doğrudan açılır.
class TasksTabPage extends ConsumerWidget {
  /// Görev takibi sekmesi.
  const TasksTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(myMedresesProvider);
    if (value case AsyncData(
      value: Ok(value: [final m]),
    ) when m.myRole.isStaff) {
      return TaskTrackingPage(medrese: m);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Görev takibi')),
      body: ResultListView<Medrese>(
        value: value,
        onRefresh: () {
          ref
            ..invalidate(taskProgramProvider)
            ..invalidate(periodEntriesProvider);
          return ref.refresh(myMedresesProvider.future);
        },
        separated: false,
        emptyIcon: Icons.task_alt,
        emptyText:
            'Henüz bir medresen yok.\n'
            'Medreselerim sekmesinden hocandan aldığın kodla katıl.',
        itemBuilder: (context, m) => m.myRole.isStaff
            ? Card(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(m.name),
                  subtitle: const Text('Görevleri başlat, öğrencileri izle'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(TaskTrackingPage(medrese: m)),
                ),
              )
            : StudentTasksSection(medrese: m),
      ),
    );
  }
}
