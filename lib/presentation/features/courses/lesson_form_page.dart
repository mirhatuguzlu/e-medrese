import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/features/courses/course_cover.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// YouTube linkiyle ders ekleme ya da dersi düzenleme (uygulama yöneticileri).
class LessonFormPage extends ConsumerStatefulWidget {
  /// [course]'a ders ekler; [lesson] verilirse onu düzenler.
  const LessonFormPage({required this.course, this.lesson, super.key});

  /// Kurs.
  final Course course;

  /// Düzenlenen ders.
  final Lesson? lesson;

  @override
  ConsumerState<LessonFormPage> createState() => _LessonFormPageState();
}

class _LessonFormPageState extends ConsumerState<LessonFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _link = TextEditingController(
    text: widget.lesson == null
        ? ''
        : 'https://youtu.be/${widget.lesson!.youtubeId}',
  );
  late final _title = TextEditingController(text: widget.lesson?.title);
  // Yeni ders, önceki dersin bölümünde başlar.
  late final _section = TextEditingController(
    text: widget.lesson?.section ?? widget.course.lessons.lastOrNull?.section,
  );
  late final _duration = TextEditingController(
    text: switch (widget.lesson?.durationSeconds) {
      final int s when s > 0 => formatClock(s),
      _ => '',
    },
  );
  late final _description = TextEditingController(
    text: widget.lesson?.description,
  );
  late String? _videoId = widget.lesson?.youtubeId;
  bool _loading = false;

  @override
  void dispose() {
    _link.dispose();
    _title.dispose();
    _section.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _onLink(String text) async {
    final id = parseYoutubeId(text);
    if (id == _videoId) return;
    setState(() => _videoId = id);
    if (id == null || _title.text.trim().isNotEmpty) return;
    final title = await ref.read(courseRepositoryProvider).videoTitle(id);
    if (mounted && title != null && _videoId == id && _title.text.isEmpty) {
      _title.text = title;
    }
  }

  void _refresh() => ref
    ..invalidate(adminCoursesProvider)
    ..invalidate(coursesProvider);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final lessons = widget.course.lessons;
    final result = await ref
        .read(courseRepositoryProvider)
        .saveLesson(
          id: widget.lesson?.id,
          courseId: widget.course.id,
          position: lessons.isEmpty ? 1 : lessons.last.position + 1,
          section: _section.text,
          title: _title.text,
          description: _description.text,
          youtubeId: _videoId!,
          durationSeconds: parseDuration(_duration.text)!,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        _refresh();
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Ders silinsin mi?',
      message: 'Öğrencilerin bu dersteki ilerlemesi de silinir; geri alınamaz.',
      action: 'Sil',
    );
    if (!ok || !mounted) return;
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .deleteLesson(widget.lesson!.id);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        _refresh();
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.lesson != null;
    final videoId = _videoId;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Dersi düzenle' : 'Ders ekle'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Dersi sil',
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
              controller: _link,
              autofocus: !editing,
              decoration: const InputDecoration(
                labelText: 'YouTube linki',
                hintText: 'https://youtu.be/...',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              onChanged: (v) => unawaited(_onLink(v)),
              validator: (v) => parseYoutubeId(v ?? '') == null
                  ? 'Geçerli bir YouTube video linki yapıştır.'
                  : null,
            ),
            if (videoId != null) ...[
              const SizedBox(height: 12),
              CourseCover(
                url: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                radius: 12,
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Ders başlığı',
                helperText: 'Link yapıştırınca YouTube başlığı gelir.',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Ders başlığını yaz.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _duration,
              decoration: const InputDecoration(
                labelText: 'Süre',
                hintText: 'ör. 12:34',
                helperText:
                    "YouTube'daki süreyi yaz; ders tamamlanması buna göre "
                    'doğrulanır.',
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.datetime,
              validator: (v) => (parseDuration(v ?? '') ?? 0) > 0
                  ? null
                  : 'Süreyi dakika:saniye olarak yaz (ör. 12:34).',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _section,
              decoration: const InputDecoration(
                labelText: 'Bölüm (isteğe bağlı)',
                hintText: 'ör. Giriş',
                helperText:
                    'Aynı bölümdeki ardışık dersler birlikte listelenir.',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Ders notu (isteğe bağlı)',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 5000,
              minLines: 2,
              maxLines: 8,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: editing ? 'Kaydet' : 'Dersi ekle',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
