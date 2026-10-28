import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Duyuru yazma (hocalar) ya da [editing] verilirse düzenleme (yazan) sayfası.
class NewAnnouncementPage extends ConsumerStatefulWidget {
  /// [medrese]'ye duyuru yaz.
  const NewAnnouncementPage({required this.medrese, this.editing, super.key});

  /// Medrese.
  final Medrese medrese;

  /// Düzenlenen duyuru; `null` ise yeni duyuru.
  final Announcement? editing;

  @override
  ConsumerState<NewAnnouncementPage> createState() =>
      _NewAnnouncementPageState();
}

class _NewAnnouncementPageState extends ConsumerState<NewAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.editing?.title);
  late final _body = TextEditingController(text: widget.editing?.body);
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
    final repo = ref.read(feedRepositoryProvider);
    final editing = widget.editing;
    final result = editing == null
        ? await repo.createAnnouncement(
            medreseId: widget.medrese.id,
            title: _title.text,
            body: _body.text,
          )
        : await repo.updateAnnouncement(
            id: editing.id,
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
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Duyuru yaz' : 'Duyuruyu düzenle'),
      ),
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
              label: widget.editing == null ? 'Yayınla' : 'Kaydet',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
