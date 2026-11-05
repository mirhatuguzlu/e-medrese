import 'dart:async';
import 'dart:math';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/course_repository.dart';
import 'package:e_medrese/domain/entities/course.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/courses/icazet_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_discussion_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_note_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_notes_page.dart';
import 'package:e_medrese/presentation/features/courses/lesson_quiz_page.dart';
import 'package:e_medrese/presentation/features/files/pdf_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Ders sayfası: YouTube oynatıcı kendi düğmelerimizle. İlk izleyişte
/// izlenmemiş kısma sarılamaz; hız her zaman değiştirilebilir.
class LessonPage extends ConsumerStatefulWidget {
  /// [courseId] kursunun [lessonId] dersi.
  const LessonPage({required this.courseId, required this.lessonId, super.key});

  /// Kurs.
  final String courseId;

  /// Ders.
  final String lessonId;

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

/// Oynatıcının anlık durumu; düğmeler (tam ekranda da) bunu dinler.
class _Playback extends ChangeNotifier {
  double position = 0;
  double watched = 0;
  double duration = 0;
  double rate = 1;
  bool playing = false;
  bool buffering = true;
  bool ended = false;
  bool completed = false;
  bool failed = false;
  bool captions = false;

  /// İlk izleyiş: izlenmemiş kısma sarma kapalı.
  bool get locked => !completed;

  void changed() => notifyListeners();
}

/// Hız düğmesine her dokunuşta sıradaki hız.
const _rates = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75];

/// Ardışık iki konum arasında bundan büyük ileri atlama sarma sayılır.
const _jumpTolerance = 2.0;

class _LessonPageState extends ConsumerState<LessonPage>
    with WidgetsBindingObserver {
  late final Course? _course;
  late final Lesson? _lesson;
  late final CourseRepository _repo;
  late final ProviderContainer _container;
  YoutubePlayerController? _player;
  final _playback = _Playback();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _saveTimer;

  // Sunucuya son yazılan değerler; değişmediyse yeniden yazılmaz.
  int _savedPosition = -1;
  int _savedWatched = -1;
  bool _savedCompleted = false;
  DateTime _lastLockWarning = DateTime(0);

  // Seçilen hız. YouTube bazen hızı kendiliğinden 1x'e döndürür ya da
  // değişikliği bildirmez; bu yüzden ekranda bu gösterilir ve gerekirse
  // yeniden uygulanır.
  double _rate = 1;
  DateTime _lastRateApply = DateTime(0);
  bool _fullscreen = false;
  bool _completionRejected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = ref.read(courseRepositoryProvider);
    _container = ProviderScope.containerOf(context, listen: false);
    final courses = switch (ref.read(coursesProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <Course>[],
    };
    _course = courses.where((c) => c.id == widget.courseId).firstOrNull;
    _lesson = _course?.lessons
        .where((l) => l.id == widget.lessonId)
        .firstOrNull;
    final lesson = _lesson;
    if (lesson == null) return;

    final saved = switch (ref.read(lessonProgressProvider)) {
      AsyncData(value: Ok(:final value)) => value[lesson.id],
      _ => null,
    };
    _playback
      ..duration = lesson.durationSeconds.toDouble()
      ..watched = (saved?.watchedSeconds ?? 0).toDouble()
      ..completed = saved?.completed ?? false;
    _savedCompleted = _playback.completed;
    var start = (saved?.positionSeconds ?? 0).toDouble();
    // Bitirilmiş dersin sonunda kaldıysa baştan açılır.
    if (_playback.completed && isWatched(start, lesson.durationSeconds)) {
      start = 0;
    }
    _playback.position = start;

    final player = YoutubePlayerController.fromVideoId(
      videoId: lesson.youtubeId,
      autoPlay: true,
      startSeconds: start,
      params: const YoutubePlayerParams(
        showControls: false,
        // Videoya dokunmak sarmaya yol açmasın; her şey bizim düğmelerde.
        pointerEvents: PointerEvents.none,
        enableCaption: false,
        captionLanguage: 'tr',
        interfaceLanguage: 'tr',
        strictRelatedVideos: true,
        showVideoAnnotations: false,
        videoStateUpdateInterval: 250,
      ),
    );
    _player = player;
    _subscriptions
      ..add(player.videoStateStream.listen(_onTick))
      ..add(player.listen(_onValue));
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_save());
      unawaited(_checkRate());
    });
  }

  void _onTick(YoutubeVideoState state) {
    final p = _playback;
    final pos = state.position.inMilliseconds / 1000;
    if (p.locked && pos > p.watched + _jumpTolerance * max(1, _rate)) {
      // Düğmeler dışından (ör. klavye) izlenmemiş kısma gidildi: geri al.
      unawaited(_player?.seekTo(seconds: p.watched, allowSeekAhead: true));
      _warnLocked();
      return;
    }
    p
      ..position = pos
      ..watched = max(p.watched, pos);
    if (p.locked && isWatched(p.watched, p.duration)) _complete();
    p.changed();
  }

  void _onValue(YoutubePlayerValue value) {
    final p = _playback;
    final wasPlaying = p.playing;
    final seconds = value.metaData.duration.inSeconds;
    if (seconds > 0) p.duration = seconds.toDouble();
    p
      ..rate = _rate
      ..playing = value.playerState == PlayerState.playing
      ..buffering =
          value.playerState == PlayerState.buffering ||
          value.playerState == PlayerState.unknown
      ..ended = value.playerState == PlayerState.ended
      ..failed = value.error != YoutubeError.none;
    if (p.ended) {
      p.watched = max(p.watched, p.duration);
      if (p.locked) _complete();
    }
    if (wasPlaying && !p.playing) unawaited(_save());
    if (!wasPlaying && p.playing) {
      _applyCaptions();
      if (value.playbackRate != _rate) _applyRate();
    }
    final fullscreen = value.fullScreenOption.enabled;
    if (fullscreen != _fullscreen) _setSystemFullscreen(fullscreen);
    // Oynarken ekran kararmasın.
    if (wasPlaying != p.playing) {
      unawaited(WakelockPlus.toggle(enable: p.playing));
    }
    p.changed();
  }

  void _complete() {
    _playback.completed = true;
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_save());
    if (mounted) {
      context.showMessage(
        'Ders tamamlandı. Artık bu derste serbestçe sarabilirsin.',
      );
    }
  }

  void _warnLocked() {
    final now = DateTime.now();
    if (now.difference(_lastLockWarning).inSeconds < 3 || !mounted) return;
    _lastLockWarning = now;
    context.showMessage('İlk izleyişte izlemediğin kısma geçilemez.');
  }

  Future<void> _save() async {
    final lesson = _lesson;
    if (lesson == null) return;
    final p = _playback;
    final position = p.position.floor();
    final watched = p.watched.floor();
    if (position == _savedPosition &&
        watched == _savedWatched &&
        p.completed == _savedCompleted) {
      return;
    }
    final completing = p.completed && !_savedCompleted;
    _savedPosition = position;
    _savedWatched = watched;
    _savedCompleted = p.completed;
    final result = await _repo.saveProgress(
      lessonId: lesson.id,
      positionSeconds: position,
      watchedSeconds: watched,
      completed: completing,
    );
    switch (result) {
      case Ok(:final value) when completing && !value:
        // Sunucu henüz kabul etmedi (izlenen süre gerçek zamanla sınırlı);
        // sonraki kayıtta yeniden denenir.
        _savedCompleted = false;
        if (!_completionRejected && mounted) {
          _completionRejected = true;
          context.showMessage(
            'Ders henüz tamamlanmış sayılmadı; izlemeye devam edince '
            'kaydedilir.',
          );
        }
      case Ok():
        break;
      case Err(:final error):
        // Yeniden denensin.
        _savedPosition = -1;
        if (completing) _savedCompleted = false;
        if (completing && mounted) context.showMessage(error.message);
    }
    _container.invalidate(lessonProgressProvider);
  }

  void _seek(double target) {
    final p = _playback;
    final to = allowedSeek(
      target: min(target, p.duration),
      watched: p.watched,
      completed: p.completed,
    );
    if (to < target - 0.5) _warnLocked();
    p
      ..position = to
      ..ended = false
      ..changed();
    unawaited(_player?.seekTo(seconds: to, allowSeekAhead: true));
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    if (_playback.ended) {
      _seek(0);
      unawaited(player.playVideo());
    } else if (_playback.playing) {
      unawaited(player.pauseVideo());
    } else {
      unawaited(player.playVideo());
    }
  }

  Future<void> _addNote() async {
    final lesson = _lesson;
    if (lesson == null) return;
    final seconds = _playback.position.floor();
    unawaited(_player?.pauseVideo());
    await context.push(LessonNotePage(lessonId: lesson.id, seconds: seconds));
  }

  Future<void> _openNotes() async {
    final lesson = _lesson;
    if (lesson == null) return;
    final seconds = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => LessonNotesPage(lesson: lesson)),
    );
    if (seconds == null) return;
    _seek(seconds.toDouble());
    unawaited(_player?.playVideo());
  }

  Future<void> _openResource(LessonResource r) async {
    unawaited(_player?.pauseVideo());
    final result = await ref.read(courseRepositoryProvider).resourceUrl(r);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        await context.push(PdfPage(title: r.title, url: value));
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  Future<void> _openQuiz() async {
    final lesson = _lesson;
    if (lesson == null) return;
    _player?.exitFullScreen();
    unawaited(_player?.pauseVideo());
    await context.push(LessonQuizPage(lesson: lesson));
  }

  Future<void> _openDiscussion(Medrese medrese) async {
    final lesson = _lesson;
    if (lesson == null) return;
    unawaited(_player?.pauseVideo());
    final seconds = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => LessonDiscussionPage(
          medrese: medrese,
          lesson: lesson,
          seconds: _playback.position.floor(),
        ),
      ),
    );
    if (seconds == null) return;
    _seek(seconds.toDouble());
    unawaited(_player?.playVideo());
  }

  void _nextRate() {
    _rate = _rates[(_rates.indexOf(_rate) + 1) % _rates.length];
    _playback
      ..rate = _rate
      ..changed();
    _applyRate();
  }

  void _applyRate() {
    final now = DateTime.now();
    // YouTube reddederse sonsuz döngüye girmesin.
    if (now.difference(_lastRateApply).inMilliseconds < 1500) return;
    _lastRateApply = now;
    unawaited(_player?.setPlaybackRate(_rate));
  }

  Future<void> _checkRate() async {
    final player = _player;
    if (player == null || !_playback.playing) return;
    try {
      if (await player.playbackRate != _rate) _applyRate();
    } on Exception {
      // Oynatıcı hazır değil; sonraki turda.
    }
  }

  void _toggleCaptions() {
    _playback
      ..captions = !_playback.captions
      ..changed();
    _applyCaptions();
  }

  // YouTube dil ayarına göre altyazıyı kendiliğinden açabiliyor; seçim her
  // oynatmada yeniden uygulanır.
  void _applyCaptions() {
    final js = _playback.captions
        ? "player.loadModule('captions');"
        : "player.unloadModule('captions');";
    unawaited(
      _player?.webViewController.runJavaScript(js).catchError((Object _) {}),
    );
  }

  // Paket tam ekranı yalnız oynatıcıyı büyüterek yapar; durum ve gezinme
  // çubuklarını gizlemek ve yatay döndürmek bizde.
  void _setSystemFullscreen(bool on) {
    _fullscreen = on;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(
        on
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            // Çıkınca dikey kalsın; yoksa telefon yanken hemen geri girer.
            : const [DeviceOrientation.portraitUp],
      ),
    );
  }

  Lesson? get _next {
    final lessons = _course?.lessons ?? const <Lesson>[];
    final i = lessons.indexWhere((l) => l.id == widget.lessonId);
    return i >= 0 && i + 1 < lessons.length ? lessons[i + 1] : null;
  }

  void _openNext() {
    final next = _next;
    if (next == null) return;
    _player?.exitFullScreen();
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              LessonPage(courseId: widget.courseId, lessonId: next.id),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_player?.pauseVideo());
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_save());
    unawaited(WakelockPlus.disable());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(const []));
    unawaited(_player?.close());
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    final lesson = _lesson;
    final player = _player;
    if (course == null || lesson == null || player == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Bu ders artık yayında değil.')),
      );
    }
    final theme = Theme.of(context);
    final number = course.lessons.indexOf(lesson) + 1;
    final next = _next;

    return Scaffold(
      appBar: AppBar(
        title: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          YoutubePlayer(
            controller: player,
            backgroundColor: Colors.black,
            enableFullScreenOnVerticalDrag: false,
            controlsBuilder: (context, fullscreen) => _Controls(
              playback: _playback,
              fullscreen: fullscreen,
              hasNext: next != null,
              onQuestions: lesson.questions.isEmpty ? null : _openQuiz,
              onPlayPause: _togglePlay,
              onSeek: _seek,
              onRate: _nextRate,
              onCaptions: _toggleCaptions,
              onFullscreen: player.toggleFullScreen,
              onNext: _openNext,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'Ders $number / ${course.lessons.length}',
                    if (lesson.section.isNotEmpty) lesson.section,
                  ].join(' · '),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lesson.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: _playback,
                  builder: (context, _) => _StatusBanner(playback: _playback),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addNote,
                        icon: const Icon(Icons.edit_note),
                        label: ListenableBuilder(
                          listenable: _playback,
                          builder: (context, _) => Text(
                            'Not al · '
                            '${formatClock(_playback.position.floor())}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openNotes,
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        label: Text(switch (ref.watch(
                          lessonNotesProvider(lesson.id),
                        )) {
                          AsyncData(value: Ok(:final value))
                              when value.isNotEmpty =>
                            'Notlarım (${value.length})',
                          _ => 'Notlarım',
                        }),
                      ),
                    ),
                  ],
                ),
                if (lesson.questions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: _playback,
                    builder: (context, _) => _QuizButton(
                      lesson: lesson,
                      completed: _playback.completed,
                      onPressed: _openQuiz,
                    ),
                  ),
                ],
                for (final m in assignedMedreses(ref, course.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => _openDiscussion(m),
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(
                        'Ders tartışması · ${m.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (lesson.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(lesson.description, style: theme.textTheme.bodyLarge),
                ],
                if (lesson.resources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Ders kaynakları',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (final r in lesson.resources)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(r.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openResource(r),
                    ),
                ],
                const SizedBox(height: 24),
                if (next != null)
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _openNext,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: Text(
                      'Sonraki ders: ${next.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Kursa dön'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dersin durumu: tamamlandı ya da ileri sarma kilidi.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.playback});

  final _Playback playback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, color) = playback.completed
        ? (
            Icons.verified,
            'Ders tamamlandı. İstediğin yere sarabilirsin.',
            scheme.primaryContainer,
          )
        : (
            Icons.lock_clock_outlined,
            'İlk izleyişte ileri sarma kapalı; geri sarabilir, hızı '
                'değiştirebilirsin. Dersin %${(completeFraction * 100).round()}'
                "'ını izleyince tamamlanır.",
            scheme.surfaceContainerHighest,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

/// Oynatıcının üstündeki düğmeler: dokununca görünür, oynarken 3 sn sonra
/// gizlenir. İki kez dokunmak 10 sn geri/ileri sarar (ileri, kilide uyar).
class _Controls extends StatefulWidget {
  const _Controls({
    required this.playback,
    required this.fullscreen,
    required this.hasNext,
    required this.onPlayPause,
    required this.onSeek,
    required this.onRate,
    required this.onCaptions,
    required this.onFullscreen,
    required this.onNext,
    this.onQuestions,
  });

  final _Playback playback;
  final bool fullscreen;
  final bool hasNext;

  /// Dersin tekrar soruları varsa açar; varsa sonraki derse kendiliğinden
  /// geçilmez.
  final VoidCallback? onQuestions;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onRate;
  final VoidCallback onCaptions;
  final VoidCallback onFullscreen;
  final VoidCallback onNext;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _visible = true;
  double? _drag;
  Timer? _hide;
  Timer? _tick;
  int? _countdown;

  /// "Burada kal" dendi; video yeniden oynayana kadar sayılmaz.
  bool _stayed = false;

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_onPlayback);
  }

  void _show() {
    setState(() => _visible = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.playback.playing && _drag == null) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onPlayback);
    _hide?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.playback,
    builder: (context, _) {
      final p = widget.playback;
      final visible = _visible || !p.playing || p.ended;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            visible && p.playing ? setState(() => _visible = false) : _show(),
        onDoubleTapDown: (d) {
          final width = context.size?.width ?? 1;
          widget.onSeek(
            p.position + (d.localPosition.dx < width / 2 ? -10 : 10),
          );
          _show();
        },
        onDoubleTap: () {},
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !visible,
            child: p.ended
                ? _ended(p)
                : p.failed
                ? const _Failed()
                : _bar(context, p),
          ),
        ),
      );
    },
  );

  Widget _bar(BuildContext context, _Playback p) {
    final duration = max(p.duration, 1).toDouble();
    final value = (_drag ?? p.position).clamp(0, duration).toDouble();
    const white = Colors.white;
    return ColoredBox(
      // Duraklayınca YouTube'un önerdiği videolar görünmesin.
      color: p.playing ? Colors.black38 : Colors.black87,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    widget.onRate();
                    _show();
                  },
                  style: TextButton.styleFrom(foregroundColor: white),
                  child: Text(
                    '${formatRate(p.rate)}x',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: p.captions ? 'Altyazıyı kapat' : 'Altyazıyı aç',
                  color: white,
                  onPressed: () {
                    widget.onCaptions();
                    _show();
                  },
                  icon: Icon(
                    p.captions
                        ? Icons.closed_caption
                        : Icons.closed_caption_off_outlined,
                  ),
                ),
                IconButton(
                  tooltip: widget.fullscreen ? 'Tam ekrandan çık' : 'Tam ekran',
                  color: white,
                  onPressed: widget.onFullscreen,
                  icon: Icon(
                    widget.fullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '10 sn geri',
                  iconSize: 36,
                  color: white,
                  onPressed: () {
                    widget.onSeek(p.position - 10);
                    _show();
                  },
                  icon: const Icon(Icons.replay_10_rounded),
                ),
                const SizedBox(width: 24),
                if (p.buffering && !p.playing)
                  const SizedBox.square(
                    dimension: 56,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: white),
                    ),
                  )
                else
                  IconButton(
                    tooltip: p.playing ? 'Duraklat' : 'Oynat',
                    iconSize: 56,
                    color: white,
                    onPressed: () {
                      widget.onPlayPause();
                      _show();
                    },
                    icon: Icon(
                      p.playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                    ),
                  ),
                const SizedBox(width: 24),
                IconButton(
                  tooltip: p.locked
                      ? 'İzlediğin yere kadar ileri'
                      : '10 sn ileri',
                  iconSize: 36,
                  color: white,
                  disabledColor: Colors.white38,
                  onPressed: p.locked && p.position >= p.watched - 0.5
                      ? null
                      : () {
                          widget.onSeek(p.position + 10);
                          _show();
                        },
                  icon: const Icon(Icons.forward_10_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (p.locked) ...[
                      const Icon(Icons.lock_outline, size: 14, color: white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${formatClock(value.floor())} / '
                      '${formatClock(p.duration.floor())}',
                      style: const TextStyle(color: white, fontSize: 12),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    inactiveTrackColor: Colors.white24,
                    secondaryActiveTrackColor: Colors.white60,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Slider(
                      max: duration,
                      value: value,
                      // Kilitliyken açık renkli kısım sarılabilecek yerdir.
                      secondaryTrackValue: p.locked
                          ? p.watched.clamp(0, duration).toDouble()
                          : null,
                      onChanged: (v) {
                        _hide?.cancel();
                        setState(
                          () => _drag = allowedSeek(
                            target: v,
                            watched: p.watched,
                            completed: p.completed,
                          ),
                        );
                      },
                      onChangeEnd: (v) {
                        widget.onSeek(v);
                        setState(() => _drag = null);
                        _show();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ended(_Playback p) => ColoredBox(
    color: Colors.black87,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          const Text(
            'Ders tamamlandı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: widget.onPlayPause,
                icon: const Icon(Icons.replay),
                label: const Text('Tekrar izle'),
              ),
              if (widget.onQuestions case final onQuestions?) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onQuestions,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Soruları çöz'),
                ),
              ] else if (widget.hasNext) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.skip_next_rounded),
                  label: Text(
                    _countdown == null
                        ? 'Sonraki ders'
                        : 'Sonraki ders ($_countdown)',
                  ),
                ),
              ],
            ],
          ),
          if (_countdown != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: _cancelCountdown,
              child: const Text('Burada kal'),
            ),
        ],
      ),
    ),
  );

  // Sorusu olmayan ders bitince sıradaki ders 5 sn sonra kendiliğinden açılır.
  void _onPlayback() {
    final p = widget.playback;
    final auto = p.ended && widget.hasNext && widget.onQuestions == null;
    if (auto && _countdown == null && !_stayed) {
      setState(() => _countdown = _autoNextSeconds);
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        if (_countdown! <= 1) {
          t.cancel();
          setState(() => _countdown = null);
          widget.onNext();
        } else {
          setState(() => _countdown = _countdown! - 1);
        }
      });
    } else if (!p.ended) {
      _stayed = false;
      if (_countdown != null) _cancelCountdown();
    }
  }

  void _cancelCountdown() {
    _tick?.cancel();
    setState(() {
      _countdown = null;
      _stayed = true;
    });
  }
}

const _autoNextSeconds = 5;

class _Failed extends StatelessWidget {
  const _Failed();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black87,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Video oynatılamadı. İnternet bağlantını kontrol edip sayfayı '
          'yeniden aç.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}

/// Hız: "1", "1.25", "0.75".
String formatRate(double rate) =>
    rate == rate.roundToDouble() ? '${rate.round()}' : '$rate';

/// Tekrar soruları düğmesi: ders bitince açılır; ilk cevapların sonucunu
/// gösterir.
class _QuizButton extends ConsumerWidget {
  const _QuizButton({
    required this.lesson,
    required this.completed,
    required this.onPressed,
  });

  final Lesson lesson;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = lesson.questions.length;
    final results = switch (ref.watch(questionResultsProvider)) {
      AsyncData(value: Ok(:final value)) => [
        for (final q in lesson.questions) ?value[q.id],
      ],
      _ => const <bool>[],
    };
    final label = !completed
        ? 'Tekrar soruları ($total) · dersi bitirince açılır'
        : results.length == total
        ? 'Tekrar soruları · ${results.where((c) => c).length}/$total doğru'
        : 'Tekrar sorularını çöz ($total)';
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: completed ? onPressed : null,
      icon: Icon(completed ? Icons.quiz_outlined : Icons.lock_outline),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
