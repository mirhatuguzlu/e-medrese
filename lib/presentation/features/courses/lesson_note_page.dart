import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dersin bir anına not yazma.
class LessonNotePage extends ConsumerStatefulWidget {
  /// [lessonId] dersinin [seconds]. saniyesine not.
  const LessonNotePage({
    required this.lessonId,
    required this.seconds,
    super.key,
  });

  /// Ders.
  final String lessonId;

  /// Videonun anı.
  final int seconds;

  @override
  ConsumerState<LessonNotePage> createState() => _LessonNotePageState();
}

class _LessonNotePageState extends ConsumerState<LessonNotePage> {
  final _formKey = GlobalKey<FormState>();
  final _body = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(courseRepositoryProvider)
        .addNote(
          lessonId: widget.lessonId,
          seconds: widget.seconds,
          body: _body.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(lessonNotesProvider(widget.lessonId));
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Not · ${formatClock(widget.seconds)}')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _body,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Notun',
              hintText: 'Bu anda aklında kalmasını istediğin şey',
              helperText: 'Notlarını yalnız sen görürsün.',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 2000,
            minLines: 4,
            maxLines: 12,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Notunu yaz.' : null,
          ),
          const SizedBox(height: 24),
          LoadingButton(label: 'Kaydet', loading: _loading, onPressed: _submit),
        ],
      ),
    ),
  );
}
