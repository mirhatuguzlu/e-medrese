import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/score_history_page.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/features/tasks/uyum_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocaların görev takibi: programı başlatır, durdurur, bitirir; öğrenciye
/// dokununca puan geçmişi açılır. Süren dönemin puanları gösterilmez.
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

  Future<void> _run({
    required String title,
    required String message,
    required String action,
    required Future<Result<void, AppFailure>> Function(TaskRepository) call,
  }) async {
    if (!await confirm(
      context,
      title: title,
      message: message,
      action: action,
    )) {
      return;
    }
    setState(() => _loading = true);
    final result = await call(ref.read(taskRepositoryProvider));
    if (!mounted) return;
    setState(() => _loading = false);
    ref
      ..invalidate(taskProgramProvider(widget.medrese.id))
      ..invalidate(weeklyScoresProvider(widget.medrese.id));
    if (result case Err(:final error)) context.showMessage(error.message);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.medrese.id;
    final program = ref.watch(taskProgramProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev takibi'),
        actions: [
          if (program case AsyncData(
            value: Ok(value: TaskProgram(active: true, :final paused)),
          )) ...[
            if (paused)
              IconButton(
                tooltip: 'Görevlere devam et',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () => _run(
                  title: 'Görevlere devam et',
                  message: 'Öğrenciler süren dönemde yeniden işaretleyebilir.',
                  action: 'Devam et',
                  call: (r) => r.setPaused(id, paused: false),
                ),
              )
            else
              IconButton(
                tooltip: 'Görevleri durdur',
                icon: const Icon(Icons.pause_circle_outline),
                onPressed: () => _run(
                  title: 'Görevleri durdur',
                  message:
                      'Öğrenciler devam edene kadar görev işaretleyemez. '
                      'Dönemler akmaya devam eder; kaydedilen puanlar '
                      'silinmez.',
                  action: 'Durdur',
                  call: (r) => r.setPaused(id, paused: true),
                ),
              ),
            IconButton(
              tooltip: 'Görevleri bitir',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: () => _run(
                title: 'Görevleri bitir',
                message:
                    'Süren dönem şimdiye kadarki girdilerle puanlanır ve '
                    'program kapanır. Yeniden başlatınca dönemler o günden '
                    'başlar.',
                action: 'Bitir',
                call: (r) => r.finish(id),
              ),
            ),
          ],
        ],
      ),
      body: switch (program) {
        AsyncData(value: Ok(:final value?)) when value.active => _Students(
          medrese: widget.medrese,
          periodStart: value.periodStart(ref.watch(todayProvider)),
          paused: value.paused,
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
                  'Haftalık görevler (namaz, Risale-i Nur, ders, cüz, kitap, '
                  'Cevşen, uyum) '
                  'başlatıldığı günden itibaren 7 günlük dönemlerle '
                  'öğrencilere açılır.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  label: 'Görevleri başlat',
                  loading: _loading,
                  onPressed: () => _run(
                    title: 'Görevleri başlat',
                    message:
                        'Görevler bugünden itibaren 7 günlük dönemlerle her '
                        'hafta öğrencilere açılır.',
                    action: 'Başlat',
                    call: (r) => r.start(id, ref.read(todayProvider)),
                  ),
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
  const _Students({
    required this.medrese,
    required this.periodStart,
    required this.paused,
  });

  final Medrese medrese;
  final DateTime periodStart;
  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = switch (ref.watch(
      uyumGradesProvider((medreseId: medrese.id, periodStart: periodStart)),
    )) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <String, UyumGrade>{},
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${paused ? 'Görevler durduruldu; öğrenciler '
                      'işaretleyemez.\n' : ''}'
            'Bu dönem: ${periodLabel(periodStart)}\n'
            'Puanlar dönem bitince açıklanır. Geçmiş için öğrenciye, '
            'uyum vermek için el sıkışma simgesine dokun.',
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
              subtitle: Text(switch (grades[s.userId]) {
                final g? => 'Uyum: ${formatPoints(g.points)}/${UyumGrade.max}',
                null => 'Uyum verilmedi',
              }),
              trailing: IconButton(
                tooltip: 'Uyum puanı ver',
                icon: const Icon(Icons.handshake_outlined),
                onPressed: () => context.push(
                  UyumPage(
                    medrese: medrese,
                    periodStart: periodStart,
                    studentId: s.userId,
                    studentName: s.name,
                    grade: grades[s.userId],
                  ),
                ),
              ),
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
