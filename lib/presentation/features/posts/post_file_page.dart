import 'package:cached_network_image/cached_network_image.dart';
import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/services/download_service.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Paylaşımdaki bir dosyayı gösterir; sağ üstten indirilir.
class PostFilePage extends ConsumerStatefulWidget {
  /// [file]'ı göster.
  const PostFilePage({required this.file, super.key});

  /// Dosya.
  final PostFile file;

  @override
  ConsumerState<PostFilePage> createState() => _PostFilePageState();
}

class _PostFilePageState extends ConsumerState<PostFilePage> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    final repo = ref.read(feedRepositoryProvider);
    final f = widget.file;
    try {
      await ref
          .read(downloadServiceProvider)
          .download(repo.fileUrl(f), name: f.name, headers: repo.fileHeaders);
    } on Exception {
      if (mounted) {
        setState(() => _downloading = false);
        context.showMessage('Dosya indirilemedi.');
      }
      return;
    }
    // Kayıt olmasa da dosya telefonda; paylaşana bildirim gitmez yalnız.
    await repo.recordDownload(f);
    await ref
        .read(pushServiceProvider)
        .showLocal('İndirildi', '${f.name} İndirilenler/e-Medrese klasöründe.');
    if (!mounted) return;
    setState(() => _downloading = false);
    context.showMessage('İndirildi: İndirilenler/e-Medrese');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(feedRepositoryProvider);
    final f = widget.file;
    final url = repo.fileUrl(f);
    final headers = repo.fileHeaders;
    return Scaffold(
      appBar: AppBar(
        title: Text(f.name),
        actions: [
          if (_downloading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'İndir',
              icon: const Icon(Icons.download),
              onPressed: _download,
            ),
        ],
      ),
      body: switch (f.kind) {
        PostFileKind.image => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: url,
              cacheKey: f.path,
              httpHeaders: headers,
              errorWidget: (_, _, _) => const Text('Fotoğraf açılamadı.'),
            ),
          ),
        ),
        PostFileKind.pdf => SfPdfViewer.network(url, headers: headers),
      },
    );
  }
}
