import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/student_report_page.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocaların görev takibi: programı başlatır/durdurur, öğrencilerin bu
/// dönemki puanlarını görür.
class TaskTrackingPage extends ConsumerStatefulWidget {
  /// [medrese]'nin görev takibi.
  const TaskTrackingPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  ConsumerState<TaskTrackingPage> createState() => _TaskTrackingPageState();
}

class _TaskTrackingPageState extends ConsumerState<TaskTrackingPage> {
  bool _loading = false;

  Future<void> _setActive({required bool active}) async {
    if (!await confirm(
      context,
      title: active ? 'Görevleri başlat' : 'Görevleri durdur',
      message: active
          ? 'Görevler bugünden itibaren 7 günlük dönemlerle her hafta '
                'öğrencilere açılır.'
          : 'Öğrenciler görev işaretleyemez. Girilen puanlar silinmez.',
      action: active ? 'Başlat' : 'Durdur',
    )) {
      return;
    }
    setState(() => _loading = true);
    final repo = ref.read(taskRepositoryProvider);
    final result = active
        ? await repo.start(widget.medrese.id, ref.read(todayProvider))
        : await repo.stop(widget.medrese.id);
    if (!mounted) return;
    setState(() => _loading = false);
    ref.invalidate(taskProgramProvider(widget.medrese.id));
    if (result case Err(:final error)) context.showMessage(error.message);
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(taskProgramProvider(widget.medrese.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev takibi'),
        actions: [
          if (program case AsyncData(
            value: Ok(value: TaskProgram(active: true)),
          ))
            IconButton(
              tooltip: 'Görevleri durdur',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => _setActive(active: false),
            ),
        ],
      ),
      body: switch (program) {
        AsyncData(value: Ok(:final value?)) when value.active => _Scores(
          medrese: widget.medrese,
          program: value,
        ),
        AsyncData(value: Ok()) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.task_alt, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Haftalık görevler (namaz, Risale-i Nur, ders, cüz, kitap) '
                  'başlatıldığı günden itibaren 7 günlük dönemlerle '
                  'öğrencilere açılır.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  label: 'Görevleri başlat',
                  loading: _loading,
                  onPressed: () => _setActive(active: true),
                ),
              ],
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

/// Öğrencilerin bu dönemki toplam puanları, yüksekten düşüğe.
class _Scores extends ConsumerWidget {
  const _Scores({required this.medrese, required this.program});

  final Medrese medrese;
  final TaskProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = program.periodDays(ref.watch(todayProvider));
    final key = (medreseId: medrese.id, periodStart: days.first);
    final data = (
      ref.watch(membersProvider(medrese.id)),
      ref.watch(taskDefinitionsProvider),
      ref.watch(periodEntriesProvider(key)),
    );
    if (data case (
      AsyncData(value: Ok(value: final members)),
      AsyncData(value: Ok(value: final tasks)),
      AsyncData(value: Ok(value: final entries)),
    )) {
      double total(Member m) => tasks.fold(
        0,
        (sum, t) => sum + t.score(taskTotal(t, m.userId, entries)),
      );
      final students =
          members.where((m) => m.role == MemberRole.student).toList()
            ..sort((a, b) => total(b).compareTo(total(a)));

      return RefreshIndicator(
        onRefresh: () => ref.refresh(periodEntriesProvider(key).future),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Bu dönem: ${periodLabel(days)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Medresede henüz öğrenci yok.'),
              ),
            for (final s in students)
              ListTile(
                leading: CircleAvatar(
                  child: Text(displayName(s.name).characters.first),
                ),
                title: Text(displayName(s.name)),
                trailing: Text(
                  '${formatPoints(total(s))} puan',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                onTap: () => context.push(
                  StudentReportPage(
                    student: s,
                    tasks: tasks,
                    entries: entries,
                    days: days,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return switch (data) {
      (AsyncData(value: Err(:final error)), _, _) ||
      (_, AsyncData(value: Err(:final error)), _) ||
      (
        _,
        _,
        AsyncData(value: Err(:final error)),
      ) => Center(child: Text(error.message)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
