import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Davet koduyla medreseye katılma sayfası.
class JoinMedresePage extends ConsumerStatefulWidget {
  /// Koda katıl.
  const JoinMedresePage({super.key});

  @override
  ConsumerState<JoinMedresePage> createState() => _JoinMedresePageState();
}

class _JoinMedresePageState extends ConsumerState<JoinMedresePage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref.read(medreseRepositoryProvider).join(_code.text);
    if (!mounted) return;
    setState(() => _loading = false);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    switch (result) {
      case Ok():
        ref.invalidate(myMedresesProvider);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Medreseye katıldın.')),
        );
      case Err(:final error):
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Koda katıl')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Hocandan aldığın 8 haneli davet kodunu yaz.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _code,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 4),
              decoration: const InputDecoration(hintText: 'ABCD1234'),
              onFieldSubmitted: (_) => _loading ? null : _submit(),
              validator: (v) => (v ?? '').trim().length == 8
                  ? null
                  : 'Kod 8 karakter olmalı.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Katıl'),
            ),
          ],
        ),
      ),
    );
  }
}
