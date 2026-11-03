import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/reward_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ödül ekleme sayfası (hocalar).
class NewRewardPage extends ConsumerStatefulWidget {
  /// [medrese]'ye ödül ekle.
  const NewRewardPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  ConsumerState<NewRewardPage> createState() => _NewRewardPageState();
}

class _NewRewardPageState extends ConsumerState<NewRewardPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _points = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(rewardRepositoryProvider)
        .addReward(
          medreseId: widget.medrese.id,
          title: _title.text,
          description: _description.text,
          points: int.parse(_points.text.trim()),
        );
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case Ok():
        ref.invalidate(rewardsProvider(widget.medrese.id));
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ödül ekle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Ödül',
                hintText: 'ör. Bir kitap hediyesi',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Ödülü yaz.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _points,
              decoration: const InputDecoration(
                labelText: 'Gereken birikmiş puan',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) > 0
                  ? null
                  : 'Sıfırdan büyük bir sayı yaz.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Ayrıntı (isteğe bağlı)',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 2000,
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 24),
            LoadingButton(label: 'Ekle', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
