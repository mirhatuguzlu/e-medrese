import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/services/download_service.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:video_player/video_player.dart';

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
        PostFileKind.video => _VideoView(url: url, headers: headers),
        PostFileKind.audio => _AudioView(url: url, headers: headers),
        PostFileKind.pdf => SfPdfViewer.network(url, headers: headers),
      },
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final _video = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
    httpHeaders: widget.headers,
  );
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _video.initialize();
    } on Object {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    setState(
      () => _chewie = ChewieController(
        videoPlayerController: _video,
        autoPlay: true,
      ),
    );
  }

  @override
  void dispose() {
    _chewie?.dispose();
    unawaited(_video.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: switch (_chewie) {
      final c? => Chewie(controller: c),
      null when _failed => const Text('Video açılamadı.'),
      null => const CircularProgressIndicator(),
    },
  );
}

class _AudioView extends StatefulWidget {
  const _AudioView({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView> {
  final _player = AudioPlayer();
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(widget.url), headers: widget.headers),
      );
    } on Object {
      if (mounted) setState(() => _failed = true);
      return;
    }
    await _player.play();
  }

  Future<void> _play() async {
    // Bitince baştan çalsın.
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const Center(child: Text('Ses açılamadı.'));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.graphic_eq, size: 96),
          const SizedBox(height: 24),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snap) {
              final total = _player.duration ?? Duration.zero;
              final pos = snap.data ?? Duration.zero;
              return Column(
                children: [
                  Slider(
                    max: total.inMilliseconds.toDouble(),
                    value: pos.inMilliseconds
                        .clamp(0, total.inMilliseconds)
                        .toDouble(),
                    onChanged: total == Duration.zero
                        ? null
                        : (v) =>
                              _player.seek(Duration(milliseconds: v.round())),
                  ),
                  Text(
                    '${formatClock(pos.inSeconds)} / '
                    '${formatClock(total.inSeconds)}',
                  ),
                ],
              );
            },
          ),
          StreamBuilder<bool>(
            stream: _player.playingStream,
            builder: (context, snap) => IconButton.filled(
              iconSize: 48,
              tooltip: (snap.data ?? false) ? 'Duraklat' : 'Oynat',
              icon: Icon((snap.data ?? false) ? Icons.pause : Icons.play_arrow),
              onPressed: (snap.data ?? false) ? _player.pause : _play,
            ),
          ),
        ],
      ),
    );
  }
}
