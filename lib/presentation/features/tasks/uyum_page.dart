import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/task_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/task.dart';
import 'package:e_medrese/presentation/features/tasks/student_tasks_section.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın süren dönemde bir öğrenciye uyum puanı ve not verdiği sayfa.
/// Öğrenci dönem bitince sandıkta görür.
class UyumPage extends ConsumerStatefulWidget {
  /// [studentId] için uyum sayfası; [grade] daha önce verilen puan.
  const UyumPage({
    required this.medrese,
    required this.periodStart,
    required this.studentId,
    required this.studentName,
    this.grade,
    super.key,
  });

  /// Medrese.
  final Medrese medrese;

  /// Süren dönemin ilk günü.
  final DateTime periodStart;

  /// Öğrenci.
  final String studentId;

  /// Öğrencinin adı.
  final String studentName;

  /// Bu dönem daha önce verilen puan.
  final UyumGrade? grade;

  @override
  ConsumerState<UyumPage> createState() => _UyumPageState();
}

class _UyumPageState extends ConsumerState<UyumPage> {
  late double _points = (widget.grade?.points ?? 0).toDouble();
  late final _note = TextEditingController(text: widget.grade?.note);
  bool _loading = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final result = await ref
        .read(taskRepositoryProvider)
        .setUyum(
          medreseId: widget.medrese.id,
          studentId: widget.studentId,
          points: _points.round(),
          note: _note.text.trim(),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    ref.invalidate(
      uyumGradesProvider((
        medreseId: widget.medrese.id,
        periodStart: widget.periodStart,
      )),
    );
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${displayName(widget.studentName)} · uyum')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Bu dönem: ${periodLabel(widget.periodStart)}\n'
            'Öğrenci puanı ve notunu dönem bitince sandıkta görür.',
          ),
          const SizedBox(height: 24),
          Text(
            '${_points.round()} / ${UyumGrade.max}',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
          Slider(
            value: _points,
            max: UyumGrade.max.toDouble(),
            divisions: UyumGrade.max,
            label: '${_points.round()}',
            onChanged: (v) => setState(() => _points = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 1000,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Öğrenciye not',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          LoadingButton(label: 'Kaydet', loading: _loading, onPressed: _save),
        ],
      ),
    );
  }
}
