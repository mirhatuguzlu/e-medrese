import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/presentation/features/medrese/invite_code_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yeni medrese kurma sayfası.
class CreateMedresePage extends ConsumerStatefulWidget {
  /// Medrese kur.
  const CreateMedresePage({super.key});

  @override
  ConsumerState<CreateMedresePage> createState() => _CreateMedresePageState();
}

class _CreateMedresePageState extends ConsumerState<CreateMedresePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(medreseRepositoryProvider)
        .create(name: _name.text, description: _description.text);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Ok(:final value):
        ref.invalidate(myMedresesProvider);
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => InviteCodePage(medrese: value),
          ),
        );
      case Err(:final error):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medrese kur')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Medrese adı'),
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Medreseye bir ad ver.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kur'),
            ),
          ],
        ),
      ),
    );
  }
}
