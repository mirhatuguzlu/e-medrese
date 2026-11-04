import 'dart:math';

/// Kurs kategorisi; `courses.category` değerleri.
enum CourseCategory {
  /// Kur'an-ı Kerim.
  kuran("Kur'an"),

  /// Akaid.
  akaid('Akaid'),

  /// Fıkıh.
  fikih('Fıkıh'),

  /// Hadis.
  hadis('Hadis'),

  /// Siyer.
  siyer('Siyer'),

  /// Risale-i Nur.
  risale('Risale-i Nur'),

  /// Arapça.
  arapca('Arapça'),

  /// Ahlak.
  ahlak('Ahlak');

  const CourseCategory(this.label);

  /// Görünen ad.
  final String label;
}

/// YouTube'dan oynatılan tek ders.
final class Lesson {
  /// Ders.
  const Lesson({
    required this.id,
    required this.position,
    required this.section,
    required this.title,
    required this.description,
    required this.youtubeId,
    required this.durationSeconds,
  });

  /// `lessons` satırından oluşturur.
  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    position: json['position'] as int,
    section: json['section'] as String? ?? '',
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    youtubeId: json['youtube_id'] as String,
    durationSeconds: json['duration_seconds'] as int? ?? 0,
  );

  /// Kimlik.
  final String id;

  /// Kurstaki sırası.
  final int position;

  /// Bölüm başlığı (boş olabilir).
  final String section;

  /// Başlık.
  final String title;

  /// Açıklama (boş olabilir).
  final String description;

  /// YouTube video kimliği.
  final String youtubeId;

  /// Süre; bilinmiyorsa 0.
  final int durationSeconds;

  /// YouTube kapak görseli.
  String get thumbnail => 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';
}

/// Kurs ve sıralı dersleri.
final class Course {
  /// Kurs.
  const Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.teacher,
    required this.category,
    required this.coverUrl,
    required this.lessons,
  });

  /// `courses` satırından (`lessons(*)` ile) oluşturur.
  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    description: json['description'] as String? ?? '',
    teacher: json['teacher'] as String? ?? '',
    category: CourseCategory.values.byName(json['category'] as String),
    coverUrl: json['cover_url'] as String? ?? '',
    lessons: [
      for (final l in json['lessons'] as List<dynamic>? ?? const [])
        Lesson.fromJson(l as Map<String, dynamic>),
    ]..sort((a, b) => a.position.compareTo(b.position)),
  );

  /// Kimlik.
  final String id;

  /// Başlık.
  final String title;

  /// Kısa açıklama (boş olabilir).
  final String subtitle;

  /// Uzun açıklama (boş olabilir).
  final String description;

  /// Dersi veren hoca (boş olabilir).
  final String teacher;

  /// Kategori.
  final CourseCategory category;

  /// Kapak görseli; boşsa ilk dersin kapağı.
  final String coverUrl;

  /// Dersler, sırasıyla.
  final List<Lesson> lessons;

  /// Gösterilecek kapak; ders yoksa boş.
  String get cover => coverUrl.isNotEmpty
      ? coverUrl
      : lessons.isEmpty
      ? ''
      : lessons.first.thumbnail;

  /// Bilinen derslerin toplam süresi.
  int get durationSeconds =>
      lessons.fold(0, (sum, l) => sum + l.durationSeconds);
}

/// Kullanıcının bir dersteki ilerlemesi.
final class LessonProgress {
  /// İlerleme.
  const LessonProgress({
    required this.lessonId,
    required this.positionSeconds,
    required this.watchedSeconds,
    required this.updatedAt,
    this.completedAt,
  });

  /// `lesson_progress` satırından oluşturur.
  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
    lessonId: json['lesson_id'] as String,
    positionSeconds: json['position_seconds'] as int,
    watchedSeconds: json['watched_seconds'] as int,
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    completedAt: switch (json['completed_at']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
  );

  /// Ders.
  final String lessonId;

  /// Kaldığı saniye.
  final int positionSeconds;

  /// İzlediği en ileri saniye.
  final int watchedSeconds;

  /// Son izleme.
  final DateTime updatedAt;

  /// Tamamlanma; tamamlanmadıysa `null`.
  final DateTime? completedAt;

  /// Ders tamamlandı.
  bool get completed => completedAt != null;
}

/// Videonun bu oranı izlenince ders tamamlanmış sayılır.
const completeFraction = 0.9;

/// [watched] saniye izlenmiş, [duration] saniyelik video tamamlandı mı.
bool isWatched(num watched, num duration) =>
    duration > 0 && watched >= duration * completeFraction;

/// İlk izleyişte (ders tamamlanmadıysa) izlenmemiş kısma atlanamaz: [target]
/// izlenen en ileri saniyeyi ([watched]) geçiyorsa oraya çekilir. Geri sarmak
/// her zaman serbesttir.
double allowedSeek({
  required double target,
  required double watched,
  required bool completed,
}) => completed ? max(0, target) : max(0, min(target, watched));

/// Bir kursta ne kadar ilerlendi.
final class CourseProgress {
  /// [course]'un [progress] (ders kimliğine göre) üzerinden ilerlemesi.
  CourseProgress(this.course, Map<String, LessonProgress> progress)
    : done = course.lessons
          .where((l) => progress[l.id]?.completed ?? false)
          .length,
      started = course.lessons.any((l) => progress.containsKey(l.id)),
      lastWatched = course.lessons
          .map((l) => progress[l.id]?.updatedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
      next = _next(course, progress);

  /// Kurs.
  final Course course;

  /// Tamamlanan ders sayısı.
  final int done;

  /// En az bir ders açıldı.
  final bool started;

  /// Son izleme; hiç izlenmediyse `null`.
  final DateTime? lastWatched;

  /// Devam edilecek ders: son izlenen ders yarım kaldıysa o; bittiyse ondan
  /// sonraki ilk tamamlanmamış ders, yoksa baştan ilk tamamlanmamış ders;
  /// hepsi bittiyse ilk ders. Ders yoksa `null`.
  final Lesson? next;

  /// Bütün dersler tamamlandı.
  bool get finished =>
      course.lessons.isNotEmpty && done == course.lessons.length;

  /// 0–1 arası.
  double get fraction =>
      course.lessons.isEmpty ? 0 : done / course.lessons.length;

  static Lesson? _next(Course course, Map<String, LessonProgress> progress) {
    final lessons = course.lessons;
    if (lessons.isEmpty) return null;
    bool open(Lesson l) => !(progress[l.id]?.completed ?? false);
    var last = -1;
    for (var i = 0; i < lessons.length; i++) {
      final p = progress[lessons[i].id];
      if (p == null) continue;
      if (last < 0 ||
          p.updatedAt.isAfter(progress[lessons[last].id]!.updatedAt)) {
        last = i;
      }
    }
    if (last >= 0 && open(lessons[last])) return lessons[last];
    return lessons.skip(last + 1).where(open).firstOrNull ??
        lessons.where(open).firstOrNull ??
        lessons.first;
  }
}
