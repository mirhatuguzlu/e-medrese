import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/widgets/loading_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Paylaşım yapma ya da [editing] verilirse düzenleme (yazan) sayfası.
///
/// Yeni paylaşıma fotoğraf, video, ses ve PDF eklenebilir. Düzenlemede
/// yalnız yazı değişir; yeni metinle kapanır.
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
  final _files = <PostFileDraft>[];
  bool _loading = false;

  /// Paylaşım başına dosya sayısı ve dosya boyutu sınırı (sunucu da uygular).
  static const int _maxFiles = 5;
  static const int _maxBytes = 50 * 1024 * 1024;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: PostFileKind.allExtensions,
    );
    final skipped = <String>[];
    for (final f in picked) {
      final path = f.path;
      final size = await f.xFile.length();
      if (path == null ||
          PostFileKind.of(f.name) == null ||
          size == 0 ||
          size > _maxBytes ||
          _files.length >= _maxFiles) {
        skipped.add(f.name);
        continue;
      }
      _files.add((path: path, name: f.name, size: size));
    }
    if (!mounted) return;
    setState(() {});
    if (skipped.isNotEmpty) {
      context.showMessage(
        'Eklenmedi: ${skipped.join(', ')}. En çok $_maxFiles dosya, her biri '
        'en çok 50 MB olabilir.',
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(feedRepositoryProvider);
    final editing = widget.editing;
    final result = editing == null
        ? await repo.createPost(
            medreseId: widget.medrese.id,
            body: _body.text,
            files: _files,
          )
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
    final isNew = widget.editing == null;
    // Dosyası olan paylaşımın yazısı boş olabilir.
    final needsText = !isNew ? widget.editing!.files.isEmpty : _files.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Paylaş' : 'Paylaşımı düzenle')),
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
              validator: (v) => needsText && (v ?? '').trim().isEmpty
                  ? 'Bir şeyler yaz ya da dosya ekle.'
                  : null,
            ),
            if (isNew) ...[
              for (final f in _files)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(switch (PostFileKind.of(f.name)) {
                    PostFileKind.image => Icons.image_outlined,
                    PostFileKind.video => Icons.movie_outlined,
                    PostFileKind.audio => Icons.audiotrack_outlined,
                    _ => Icons.picture_as_pdf_outlined,
                  }),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(formatBytes(f.size)),
                  trailing: IconButton(
                    tooltip: 'Dosyayı çıkar',
                    icon: const Icon(Icons.close),
                    onPressed: _loading
                        ? null
                        : () => setState(() => _files.remove(f)),
                  ),
                ),
              if (_files.length < _maxFiles)
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Dosya ekle'),
                  onPressed: _loading ? null : _pick,
                ),
              const SizedBox(height: 4),
              Text(
                'Fotoğraf, video, ses ya da PDF; en çok $_maxFiles dosya, her '
                'biri en çok 50 MB. Medresendeki üyeler görür ve indirebilir; '
                'indirince sana bildirim gelir. Telif hakkı sahibinin izin '
                'verdiği dosyaları paylaş.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(
              label: isNew ? 'Paylaş' : 'Kaydet',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
