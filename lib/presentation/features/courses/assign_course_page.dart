import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hocanın medreseye Online Medrese'den kurs vermesi (isteğe bağlı son gün).
class AssignCoursePage extends ConsumerStatefulWidget {
  /// [medrese]'ye kurs ver.
  const AssignCoursePage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  ConsumerState<AssignCoursePage> createState() => _AssignCoursePageState();
}

class _AssignCoursePageState extends ConsumerState<AssignCoursePage> {
  String? _courseId;
  DateTime? _dueOn;
  bool _loading = false;

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueOn ?? now.add(const Duration(days: 14)),
      helpText: 'Son gün',
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _submit() async {
    final courseId = _courseId;
    if (courseId == null) {
      context.showMessage('Vereceğin kursu seç.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .assign(
          medreseId: widget.medrese.id,
          courseId: courseId,
          dueOn: _dueOn,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(assignmentsProvider);
        context.showMessage('Kurs verildi; öğrencilere bildirim gitti.');
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final given = switch (ref.watch(assignmentsProvider)) {
      AsyncData(value: Ok(:final value)) => {
        for (final a in value)
          if (a.medreseId == widget.medrese.id) a.courseId,
      },
      _ => const <String>{},
    };
    final courses = switch (ref.watch(coursesProvider)) {
      AsyncData(value: Ok(:final value)) =>
        value.where((c) => !given.contains(c.id)).toList(),
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Kurs ver')),
      body: courses == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Öğrenciler kursu Online Medrese\'de "Hocan verdi" '
                  'etiketiyle en üstte görür. Rıza veren öğrencilerin '
                  'ilerlemesini bu medresenin hocaları izler.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (courses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Verilecek kurs kalmadı; yayındaki bütün kursları '
                      'bu medreseye verdin.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                RadioGroup<String>(
                  groupValue: _courseId,
                  onChanged: (id) => setState(() => _courseId = id),
                  child: Column(
                    children: [
                      for (final c in courses)
                        RadioListTile<String>(
                          value: c.id,
                          contentPadding: EdgeInsets.zero,
                          secondary: SizedBox(
                            width: 88,
                            child: CourseCover(url: c.cover, radius: 8),
                          ),
                          title: Text(c.title),
                          subtitle: Text(
                            [
                              c.category.label,
                              '${c.lessons.length} ders',
                              if (c.durationSeconds > 0)
                                formatLength(c.durationSeconds),
                            ].join(' · '),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    _dueOn == null
                        ? 'Son gün yok'
                        : 'Son gün: ${formatDay(_dueOn!)}',
                  ),
                  subtitle: const Text('İsteğe bağlı'),
                  trailing: _dueOn == null
                      ? null
                      : IconButton(
                          tooltip: 'Son günü kaldır',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _dueOn = null),
                        ),
                  onTap: _pickDue,
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  label: 'Kursu ver',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
    );
  }
}
