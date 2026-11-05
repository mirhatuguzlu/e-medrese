import 'dart:io';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir dersin kaynaklarını yönetme (uygulama yöneticileri): telefondan PDF
/// seçilip eklenir, silinir.
class AdminResourcesPage extends ConsumerStatefulWidget {
  /// [courseId] kursunun [lessonId] dersinin kaynakları.
  const AdminResourcesPage({
    required this.courseId,
    required this.lessonId,
    super.key,
  });

  /// Kurs.
  final String courseId;

  /// Ders.
  final String lessonId;

  @override
  ConsumerState<AdminResourcesPage> createState() => _AdminResourcesPageState();
}

class _AdminResourcesPageState extends ConsumerState<AdminResourcesPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  PlatformFile? _file;
  bool _loading = false;

  /// Kovanın sınırı (50 MB).
  static const int _maxBytes = 50 * 1024 * 1024;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _refresh() => ref
    ..invalidate(adminCoursesProvider)
    ..invalidate(coursesProvider);

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return;
    final size = await file.xFile.length();
    if (!mounted) return;
    if (size > _maxBytes) {
      context.showMessage('PDF en çok 50 MB olabilir.');
      return;
    }
    setState(() => _file = file);
    if (_title.text.trim().isEmpty) {
      _title.text = file.name.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
    }
  }

  Future<void> _add(Lesson lesson) async {
    if (!_formKey.currentState!.validate()) return;
    final path = _file?.path;
    if (path == null) {
      context.showMessage('Önce bir PDF seç.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .addResource(
          lessonId: lesson.id,
          position: (lesson.resources.lastOrNull?.position ?? 0) + 1,
          title: _title.text,
          file: File(path),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        _title.clear();
        setState(() => _file = null);
        _refresh();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  Future<void> _delete(LessonResource r) async {
    final ok = await confirm(
      context,
      title: 'Kaynak silinsin mi?',
      message: r.title,
      action: 'Sil',
    );
    if (!ok || !mounted) return;
    final result = await ref.read(courseRepositoryProvider).deleteResource(r);
    if (!mounted) return;
    if (result case Err(:final error)) context.showMessage(error.message);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = switch (ref.watch(adminCoursesProvider)) {
      AsyncData(value: Ok(:final value)) =>
        value
            .where((c) => c.id == widget.courseId)
            .firstOrNull
            ?.lessons
            .where((l) => l.id == widget.lessonId)
            .firstOrNull,
      _ => null,
    };
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Ders bulunamadı.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Kaynaklar · ${lesson.title}')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (lesson.resources.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Bu derste kaynak yok. Ders notu PDF'ini telefonundan seç; "
                'öğrenciler ders sayfasında uygulama içinde açar.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final r in lesson.resources)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(r.title),
              trailing: IconButton(
                tooltip: 'Kaynağı sil',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(r),
              ),
            ),
          const Divider(),
          Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'PDF ekle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(_file?.name ?? 'PDF seç'),
                    onPressed: _loading ? null : _pick,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'En çok 50 MB. Telif hakkı sahibinin izin verdiği '
                    'dosyaları ekle.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Kaynağın adı',
                      hintText: 'ör. Ders notu',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 200,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Kaynağın adını yaz.' : null,
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: 'Kaynağı ekle',
                    loading: _loading,
                    onPressed: () => _add(lesson),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
