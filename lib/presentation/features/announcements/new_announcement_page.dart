import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Duyuru yazma sayfası (hocalar için).
class NewAnnouncementPage extends ConsumerStatefulWidget {
  /// [medrese]'ye duyuru yaz.
  const NewAnnouncementPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  ConsumerState<NewAnnouncementPage> createState() =>
      _NewAnnouncementPageState();
}

class _NewAnnouncementPageState extends ConsumerState<NewAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(feedRepositoryProvider)
        .createAnnouncement(
          medreseId: widget.medrese.id,
          title: _title.text,
          body: _body.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case Ok():
        ref.invalidate(announcementsProvider(widget.medrese.id));
        Navigator.of(context).pop();
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duyuru yaz')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Başlık'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Bir başlık yaz.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(
                labelText: 'Ayrıntı (isteğe bağlı)',
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 4,
              maxLines: 10,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: 'Yayınla',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
