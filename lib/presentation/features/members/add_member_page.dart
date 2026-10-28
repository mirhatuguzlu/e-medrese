import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kayıtlı bir kullanıcıyı e-postasıyla ekleme sayfası (hocalar için).
class AddMemberPage extends ConsumerStatefulWidget {
  /// [medrese]'ye üye ekle.
  const AddMemberPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  ConsumerState<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends ConsumerState<AddMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  MemberRole _role = MemberRole.student;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(medreseRepositoryProvider)
        .addMemberByEmail(
          medreseId: widget.medrese.id,
          email: _email.text,
          role: _role,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Ok():
        ref.invalidate(membersProvider(widget.medrese.id));
        Navigator.of(context).pop();
        context.showMessage('${_role.label} eklendi.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.medrese.myRole == MemberRole.owner;
    return Scaffold(
      appBar: AppBar(title: const Text('Üye ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Uygulamaya kayıtlı birinin e-postasını yaz. '
              'Kayıtlı değilse davet koduyla katılabilir.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _email,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'E-posta'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Geçerli bir e-posta yaz.',
            ),
            // Hoca eklemeyi yalnızca kurucu yapabilir (veritabanı kuralı).
            if (isOwner) ...[
              const SizedBox(height: 24),
              SegmentedButton<MemberRole>(
                segments: [
                  for (final r in [MemberRole.student, MemberRole.teacher])
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(label: 'Ekle', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
