import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/profile_repository.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ad soyadı değiştirme sayfası.
class EditNamePage extends ConsumerStatefulWidget {
  /// Ad soyad.
  const EditNamePage({super.key});

  /// En fazla uzunluk (sunucudaki kısıtla aynı).
  static const maxLength = 80;

  @override
  ConsumerState<EditNamePage> createState() => _EditNamePageState();
}

class _EditNamePageState extends ConsumerState<EditNamePage> {
  late final _controller = TextEditingController(text: currentUserName(ref));
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(profileRepositoryProvider)
        .updateName(_controller.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(myProfileProvider);
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ad soyad')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _controller,
            autofocus: true,
            maxLength: EditNamePage.maxLength,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ad soyad',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Adını yaz.' : null,
            onFieldSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adın medresendeki üyelere, paylaşımlarında ve icazet '
            'belgelerinde görünür.',
          ),
          const SizedBox(height: 24),
          LoadingButton(label: 'Kaydet', loading: _loading, onPressed: _save),
        ],
      ),
    ),
  );
}
