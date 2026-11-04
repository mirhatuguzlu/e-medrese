import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tekrar sorusu ekleme ya da düzenleme (uygulama yöneticileri): soru, 2–5
/// şık, doğru şık ve isteğe bağlı açıklama.
class QuestionFormPage extends ConsumerStatefulWidget {
  /// [lessonId] dersine soru; [question] verilirse düzenler.
  const QuestionFormPage({
    required this.lessonId,
    required this.position,
    this.question,
    super.key,
  });

  /// Ders.
  final String lessonId;

  /// Yeni sorunun sırası.
  final int position;

  /// Düzenlenen soru.
  final LessonQuestion? question;

  @override
  ConsumerState<QuestionFormPage> createState() => _QuestionFormPageState();
}

class _QuestionFormPageState extends ConsumerState<QuestionFormPage> {
  static const _maxOptions = 5;

  final _formKey = GlobalKey<FormState>();
  late final _question = TextEditingController(text: widget.question?.question);
  late final _explanation = TextEditingController(
    text: widget.question?.explanation,
  );
  late final List<TextEditingController> _options = [
    for (final o in widget.question?.options ?? const ['', ''])
      TextEditingController(text: o),
  ];
  late int _answer = widget.question?.answer ?? 0;
  bool _loading = false;

  @override
  void dispose() {
    _question.dispose();
    _explanation.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _refresh() => ref
    ..invalidate(adminCoursesProvider)
    ..invalidate(coursesProvider);

  void _removeOption(int i) => setState(() {
    _options.removeAt(i).dispose();
    if (_answer == i) {
      _answer = 0;
    } else if (_answer > i) {
      _answer--;
    }
  });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .saveQuestion(
          id: widget.question?.id,
          lessonId: widget.lessonId,
          position: widget.position,
          question: _question.text,
          options: [for (final o in _options) o.text],
          answer: _answer,
          explanation: _explanation.text,
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
      title: 'Soru silinsin mi?',
      message: 'Öğrencilerin bu soruya verdiği cevaplar da silinir.',
      action: 'Sil',
    );
    if (!ok || !mounted) return;
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .deleteQuestion(widget.question!.id);
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
    final editing = widget.question != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Soruyu düzenle' : 'Yeni soru'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Soruyu sil',
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
              controller: _question,
              autofocus: !editing,
              decoration: const InputDecoration(labelText: 'Soru'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 1000,
              minLines: 2,
              maxLines: 6,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Soruyu yaz.' : null,
            ),
            const SizedBox(height: 8),
            Text(
              'Şıklar · doğru olanı işaretle',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            RadioGroup<int>(
              groupValue: _answer,
              onChanged: (v) => setState(() => _answer = v ?? 0),
              child: Column(
                children: [
                  for (var i = 0; i < _options.length; i++)
                    Row(
                      children: [
                        Radio<int>(value: i),
                        Expanded(
                          child: TextFormField(
                            key: ObjectKey(_options[i]),
                            controller: _options[i],
                            decoration: InputDecoration(
                              labelText: '${String.fromCharCode(65 + i)} şıkkı',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 300,
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Şıkkı yaz.' : null,
                          ),
                        ),
                        if (_options.length > 2)
                          IconButton(
                            tooltip: 'Şıkkı kaldır',
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeOption(i),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (_options.length < _maxOptions)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _options.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Şık ekle'),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _explanation,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                helperText: 'Öğrenci cevapladıktan sonra görür.',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 2000,
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: editing ? 'Kaydet' : 'Soruyu ekle',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
