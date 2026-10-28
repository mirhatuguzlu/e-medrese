import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Paylaşım yapma ya da [editing] verilirse düzenleme (yazan) sayfası.
///
/// Düzenlemede yeni metinle kapanır.
class NewPostPage extends ConsumerStatefulWidget {
  /// [medrese]'de paylaş.
  const NewPostPage({required this.medrese, this.editing, super.key});

  /// Medrese.
  final Medrese medrese;

  /// Düzenlenen paylaşım; `null` ise yeni paylaşım.
  final Post? editing;

  @override
  ConsumerState<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends ConsumerState<NewPostPage> {
  final _formKey = GlobalKey<FormState>();
  late final _body = TextEditingController(text: widget.editing?.body);
  bool _loading = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(feedRepositoryProvider);
    final editing = widget.editing;
    final result = editing == null
        ? await repo.createPost(medreseId: widget.medrese.id, body: _body.text)
        : await repo.updatePost(id: editing.id, body: _body.text);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Ok():
        ref.invalidate(postsProvider(widget.medrese.id));
        Navigator.of(context).pop(_body.text.trim());
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Paylaş' : 'Paylaşımı düzenle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _body,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Medresene ne söylemek istersin?',
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 5,
              maxLines: 12,
              maxLength: 5000,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Bir şeyler yaz.' : null,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: widget.editing == null ? 'Paylaş' : 'Kaydet',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
