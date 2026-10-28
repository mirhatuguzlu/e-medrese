import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/score_history_page.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocaların görev takibi: programı başlatır/durdurur; öğrenciye dokununca
/// puan geçmişi açılır. Süren dönemin puanları gösterilmez.
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
          : 'Öğrenciler görev işaretleyemez. Kaydedilen puanlar silinmez.',
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
        AsyncData(value: Ok(:final value?)) when value.active => _Students(
          medrese: widget.medrese,
          periodStart: value.periodStart(ref.watch(todayProvider)),
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

class _Students extends ConsumerWidget {
  const _Students({required this.medrese, required this.periodStart});

  final Medrese medrese;
  final DateTime periodStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Bu dönem: ${periodLabel(periodStart)}\n'
            'Puanlar dönem bitince açıklanır. Geçmiş için öğrenciye dokun.',
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ResultListView<Member>(
            value: ref
                .watch(membersProvider(medrese.id))
                .whenData(
                  (r) => r.map(
                    (list) => list
                        .where((m) => m.role == MemberRole.student)
                        .toList(),
                  ),
                ),
            onRefresh: () => ref.refresh(membersProvider(medrese.id).future),
            emptyIcon: Icons.groups_outlined,
            emptyText: 'Medresede henüz öğrenci yok.',
            itemBuilder: (context, s) => ListTile(
              leading: CircleAvatar(
                child: Text(displayName(s.name).characters.first),
              ),
              title: Text(displayName(s.name)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                ScoreHistoryPage(
                  medrese: medrese,
                  studentId: s.userId,
                  studentName: s.name,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
