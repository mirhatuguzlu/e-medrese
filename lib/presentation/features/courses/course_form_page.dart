import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/admin_lessons_page.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kurs açma ya da kurs bilgisini düzenleme (uygulama yöneticileri).
/// Silinirse `true` ile kapanır.
class CourseFormPage extends ConsumerStatefulWidget {
  /// [course] verilirse düzenler, yoksa yeni kurs açar.
  const CourseFormPage({this.course, super.key});

  /// Düzenlenen kurs.
  final Course? course;

  @override
  ConsumerState<CourseFormPage> createState() => _CourseFormPageState();
}

class _CourseFormPageState extends ConsumerState<CourseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.course?.title);
  late final _subtitle = TextEditingController(text: widget.course?.subtitle);
  late final _teacher = TextEditingController(text: widget.course?.teacher);
  late final _description = TextEditingController(
    text: widget.course?.description,
  );
  late final _outcomes = TextEditingController(text: widget.course?.outcomes);
  late CourseCategory? _category = widget.course?.category;
  late CourseLevel? _level = widget.course?.level;
  late bool _published = widget.course?.published ?? false;
  bool _loading = false;

  bool get _hasLessons => widget.course?.lessons.isNotEmpty ?? false;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _teacher.dispose();
    _description.dispose();
    _outcomes.dispose();
    super.dispose();
  }

  void _refresh() => ref
    ..invalidate(adminCoursesProvider)
    ..invalidate(coursesProvider);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .saveCourse(
          id: widget.course?.id,
          title: _title.text,
          subtitle: _subtitle.text,
          description: _description.text,
          teacher: _teacher.text,
          category: _category!,
          published: _published && _hasLessons,
          level: _level,
          outcomes: _outcomes.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok(:final value):
        _refresh();
        if (widget.course == null) {
          // Yeni kursa hemen ders eklensin.
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => AdminLessonsPage(courseId: value),
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  Future<void> _delete() async {
    final course = widget.course!;
    final ok = await confirm(
      context,
      title: 'Kurs silinsin mi?',
      message:
          '"${course.title}" ve ${course.lessons.length} dersi silinir. '
          'Öğrencilerin bu kurstaki ilerlemesi de silinir; geri alınamaz.',
      action: 'Sil',
    );
    if (!ok || !mounted) return;
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .deleteCourse(course.id);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        _refresh();
        Navigator.of(context).pop(true);
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.course != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Kurs bilgisi' : 'Yeni kurs'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Kursu sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _loading ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _title,
              autofocus: !editing,
              decoration: const InputDecoration(
                labelText: 'Kurs adı',
                hintText: 'ör. Temel Akaid',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Kurs adını yaz.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subtitle,
              decoration: const InputDecoration(
                labelText: 'Kısa açıklama (isteğe bağlı)',
                hintText: 'ör. İmanın altı esası, sade bir anlatımla',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 300,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _teacher,
              decoration: const InputDecoration(
                labelText: 'Dersi veren hoca (isteğe bağlı)',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<CourseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final c in CourseCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c),
              validator: (c) => c == null ? 'Kategori seç.' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CourseLevel?>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Seviye'),
              items: [
                const DropdownMenuItem(child: Text('Belirtilmedi')),
                for (final l in CourseLevel.values)
                  DropdownMenuItem(value: l, child: Text(l.label)),
              ],
              onChanged: (l) => setState(() => _level = l),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _outcomes,
              decoration: const InputDecoration(
                labelText: 'Bu kursta öğrenecekleri (isteğe bağlı)',
                helperText: 'Her satıra bir kazanım yaz.',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 3000,
              minLines: 3,
              maxLines: 8,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Kurs hakkında (isteğe bağlı)',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 5000,
              minLines: 3,
              maxLines: 10,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yayında'),
              subtitle: Text(
                _hasLessons
                    ? 'Kapalıyken öğrenciler kursu görmez.'
                    : 'Yayına almak için önce ders ekle.',
              ),
              value: _published && _hasLessons,
              onChanged: _hasLessons
                  ? (v) => setState(() => _published = v)
                  : null,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: editing ? 'Kaydet' : 'Kursu aç',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
