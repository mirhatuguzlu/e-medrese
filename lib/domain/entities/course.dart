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

/// Kursun seviyesi; `courses.level` değerleri.
enum CourseLevel {
  /// Başlangıç.
  baslangic('Başlangıç'),

  /// Orta.
  orta('Orta'),

  /// İleri.
  ileri('İleri');

  const CourseLevel(this.label);

  /// Görünen ad.
  final String label;
}

/// Dersin sonundaki çoktan seçmeli tekrar sorusu.
final class LessonQuestion {
  /// Soru.
  const LessonQuestion({
    required this.id,
    required this.lessonId,
    required this.position,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  /// `lesson_questions` satırından oluşturur.
  factory LessonQuestion.fromJson(Map<String, dynamic> json) => LessonQuestion(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    position: json['position'] as int? ?? 0,
    question: json['question'] as String,
    options: (json['options'] as List<dynamic>).cast<String>(),
    answer: json['answer'] as int,
    explanation: json['explanation'] as String? ?? '',
  );

  /// Kimlik.
  final String id;

  /// Ders.
  final String lessonId;

  /// Dersteki sırası.
  final int position;

  /// Soru metni.
  final String question;

  /// Şıklar (2–5).
  final List<String> options;

  /// Doğru şıkkın sırası (0'dan).
  final int answer;

  /// Cevaptan sonra gösterilen açıklama (boş olabilir).
  final String explanation;
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
    this.questions = const [],
    this.resources = const [],
  });

  /// `lessons` satırından (`lesson_questions(*)` ile) oluşturur.
  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    position: json['position'] as int,
    section: json['section'] as String? ?? '',
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    youtubeId: json['youtube_id'] as String,
    durationSeconds: json['duration_seconds'] as int? ?? 0,
    questions: [
      for (final q in json['lesson_questions'] as List<dynamic>? ?? const [])
        LessonQuestion.fromJson(q as Map<String, dynamic>),
    ]..sort((a, b) => a.position.compareTo(b.position)),
    resources: [
      for (final r in json['lesson_resources'] as List<dynamic>? ?? const [])
        LessonResource.fromJson(r as Map<String, dynamic>),
    ]..sort((a, b) => a.position.compareTo(b.position)),
  );

  /// Tekrar soruları, sırasıyla.
  final List<LessonQuestion> questions;

  /// Ders kaynakları (PDF, web linki), sırasıyla.
  final List<LessonResource> resources;

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
    this.published = true,
    this.level,
    this.outcomes = '',
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
    published: json['published'] as bool? ?? true,
    level: switch (json['level']) {
      final String l => CourseLevel.values.asNameMap()[l],
      _ => null,
    },
    outcomes: json['outcomes'] as String? ?? '',
  );

  /// Seviye; girilmediyse `null`.
  final CourseLevel? level;

  /// Kazanımlar, satır satır (boş olabilir).
  final String outcomes;

  /// Boş olmayan kazanım satırları.
  List<String> get outcomeList => [
    for (final line in outcomes.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  /// Bütün tekrar soruları.
  int get questionCount =>
      lessons.fold(0, (sum, l) => sum + l.questions.length);

  /// Kimlik.
  final String id;

  /// Başlık.
  final String title;

  /// Öğrencilere görünüyor; değilse taslak.
  final bool published;

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
      lastCompleted = course.lessons
          .map((l) => progress[l.id]?.completedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
      next = _next(course, progress);

  /// Son tamamlanan dersin zamanı; kurs bittiyse bitirme tarihi.
  final DateTime? lastCompleted;

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

/// YouTube linkinden (watch, youtu.be, shorts, embed, live) ya da çıplak
/// kimlikten 11 karakterlik video kimliği; bulunamazsa `null`.
String? parseYoutubeId(String input) {
  final text = input.trim();
  final id = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (id.hasMatch(text)) return text;
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null) return null;
  final host = uri.host.replaceFirst(RegExp(r'^(www\.|m\.)'), '');
  final candidate = switch (host) {
    'youtu.be' => uri.pathSegments.firstOrNull,
    'youtube.com' || 'youtube-nocookie.com' || 'music.youtube.com' =>
      uri.pathSegments.firstOrNull == 'watch'
          ? uri.queryParameters['v']
          : uri.pathSegments.length > 1 &&
                const {
                  'shorts',
                  'embed',
                  'live',
                  'v',
                }.contains(uri.pathSegments.first)
          ? uri.pathSegments[1]
          : null,
    _ => null,
  };
  return candidate != null && id.hasMatch(candidate) ? candidate : null;
}

/// "12:34", "1:02:03" ya da dakika ("45") biçimindeki süreyi saniyeye
/// çevirir; geçersizse `null`.
int? parseDuration(String input) {
  final parts = input.trim().split(':');
  if (parts.length > 3) return null;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null || n < 0)) return null;
  if (numbers.length == 1) return numbers.first! * 60;
  if (numbers.skip(1).any((n) => n! > 59)) return null;
  return numbers.fold<int>(0, (sum, n) => sum * 60 + n!);
}

/// Hocanın bir medreseye verdiği kurs.
final class CourseAssignment {
  /// Verilen kurs.
  const CourseAssignment({
    required this.medreseId,
    required this.medreseName,
    required this.courseId,
    required this.createdAt,
    this.dueOn,
  });

  /// `course_assignments` satırından (`medreses(name)` ile) oluşturur.
  factory CourseAssignment.fromJson(Map<String, dynamic> json) =>
      CourseAssignment(
        medreseId: json['medrese_id'] as String,
        medreseName:
            (json['medreses'] as Map<String, dynamic>?)?['name'] as String? ??
            '',
        courseId: json['course_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        dueOn: switch (json['due_on']) {
          final String d => DateTime.parse(d),
          _ => null,
        },
      );

  /// Medrese.
  final String medreseId;

  /// Medresenin adı.
  final String medreseName;

  /// Kurs.
  final String courseId;

  /// Verildiği zaman.
  final DateTime createdAt;

  /// Bitirme tarihi; yoksa `null`.
  final DateTime? dueOn;
}

/// Hocanın gördüğü, öğrencinin verilen kurstaki ilerlemesi.
final class StudentCourseProgress {
  /// İlerleme.
  const StudentCourseProgress({
    required this.userId,
    required this.name,
    required this.consent,
    required this.done,
    this.lastWatched,
    this.answered = 0,
    this.correct = 0,
  });

  /// `assignment_progress` satırından oluşturur.
  factory StudentCourseProgress.fromJson(Map<String, dynamic> json) =>
      StudentCourseProgress(
        userId: json['user_id'] as String,
        name: json['full_name'] as String? ?? '',
        consent: json['consent'] as bool? ?? false,
        done: json['done'] as int? ?? 0,
        lastWatched: switch (json['last_watched']) {
          final String at => DateTime.parse(at).toLocal(),
          _ => null,
        },
        answered: json['answered'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
      );

  /// Cevapladığı tekrar sorusu (ilk cevaplar).
  final int answered;

  /// İlk cevabı doğru olan soru sayısı.
  final int correct;

  /// Öğrenci.
  final String userId;

  /// Ad soyad.
  final String name;

  /// Öğrenci ilerlemesini hocalarla paylaşmaya rıza verdi.
  final bool consent;

  /// Tamamladığı ders sayısı.
  final int done;

  /// Son izleme; hiç izlemediyse `null`.
  final DateTime? lastWatched;
}

/// Öğrencinin dersin bir anına yazdığı not.
final class LessonNote {
  /// Not.
  const LessonNote({
    required this.id,
    required this.lessonId,
    required this.seconds,
    required this.body,
    required this.createdAt,
  });

  /// `lesson_notes` satırından oluşturur.
  factory LessonNote.fromJson(Map<String, dynamic> json) => LessonNote(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    seconds: json['seconds'] as int,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  /// Kimlik.
  final String id;

  /// Ders.
  final String lessonId;

  /// Videonun kaçıncı saniyesi.
  final int seconds;

  /// Not.
  final String body;

  /// Yazıldığı zaman.
  final DateTime createdAt;
}

/// Medresenin bir ders hakkındaki tartışmasında yazılan.
final class LessonComment {
  /// Yazı.
  const LessonComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.seconds,
    this.lessonId = '',
  });

  /// `lesson_comments` satırından (`author:profiles(full_name)` ile).
  factory LessonComment.fromJson(Map<String, dynamic> json) => LessonComment(
    id: json['id'] as String,
    authorId: json['author_id'] as String,
    authorName:
        (json['author'] as Map<String, dynamic>?)?['full_name'] as String? ??
        '',
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    seconds: json['seconds'] as int?,
    lessonId: json['lesson_id'] as String? ?? '',
  );

  /// Ders.
  final String lessonId;

  /// Kimlik.
  final String id;

  /// Yazan.
  final String authorId;

  /// Yazanın adı.
  final String authorName;

  /// Metin.
  final String body;

  /// Yazıldığı zaman.
  final DateTime createdAt;

  /// Bağlandığı video anı; yoksa `null`.
  final int? seconds;
}

/// İcazet isteğinin durumu.
enum IcazetStatus {
  /// Hoca henüz karar vermedi.
  pending,

  /// Hoca onayladı.
  approved,

  /// Hoca geri çevirdi; yeniden istenebilir.
  rejected,
}

/// Öğrencinin, hocanın verdiği kursu bitirince istediği icazet.
final class IcazetRequest {
  /// İstek.
  const IcazetRequest({
    required this.id,
    required this.medreseId,
    required this.courseId,
    required this.userId,
    required this.studentName,
    required this.status,
    required this.note,
    required this.decidedByName,
    required this.createdAt,
    this.decidedAt,
  });

  /// `icazet_requests` satırından (`student:profiles(full_name)` ile).
  factory IcazetRequest.fromJson(Map<String, dynamic> json) => IcazetRequest(
    id: json['id'] as String,
    medreseId: json['medrese_id'] as String,
    courseId: json['course_id'] as String,
    userId: json['user_id'] as String,
    studentName:
        (json['student'] as Map<String, dynamic>?)?['full_name'] as String? ??
        '',
    status: IcazetStatus.values.byName(json['status'] as String),
    note: json['note'] as String? ?? '',
    decidedByName: json['decided_by_name'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    decidedAt: switch (json['decided_at']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
  );

  /// Kimlik.
  final String id;

  /// Medrese.
  final String medreseId;

  /// Kurs.
  final String courseId;

  /// İsteyen öğrenci.
  final String userId;

  /// Öğrencinin adı.
  final String studentName;

  /// Durum.
  final IcazetStatus status;

  /// Hocanın notu (boş olabilir).
  final String note;

  /// Karar veren hocanın adı.
  final String decidedByName;

  /// İstenme zamanı.
  final DateTime createdAt;

  /// Karar zamanı.
  final DateTime? decidedAt;
}

/// Kursa verilen isimsiz değerlendirme.
final class CourseReview {
  /// Değerlendirme.
  const CourseReview({
    required this.id,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  /// `course_reviews_of` satırından oluşturur.
  factory CourseReview.fromJson(Map<String, dynamic> json) => CourseReview(
    id: json['id'] as String,
    rating: json['rating'] as int,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    mine: json['mine'] as bool? ?? false,
  );

  /// Kimlik.
  final String id;

  /// 1–5 yıldız.
  final int rating;

  /// Yorum (boş olabilir).
  final String body;

  /// Son yazıldığı zaman.
  final DateTime createdAt;

  /// Giriş yapan kullanıcının değerlendirmesi.
  final bool mine;
}

/// Kursun ortalama puanı.
typedef CourseRating = ({double average, int count});

/// [course] başlığında, hocasında, açıklamasında, kategorisinde ya da ders
/// adlarında [query]'nin bütün kelimeleri geçiyor mu (Türkçe büyük/küçük
/// harf ve şapka farkı gözetmez).
bool courseMatches(Course course, String query) {
  final words = foldTurkish(query).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return true;
  final text = foldTurkish(
    [
      course.title,
      course.subtitle,
      course.teacher,
      course.category.label,
      course.description,
      for (final l in course.lessons) l.title,
    ].join(' '),
  );
  return words.every(text.contains);
}

/// Aramada karşılaştırma için: küçük harf, şapkasız; İ, I ve ı hep "i"
/// (klavyede hangisi yazılırsa yazılsın bulunsun).
String foldTurkish(String s) {
  const from = 'İIıÂÎÛâîû';
  const to = 'iiiaiuaiu';
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().toLowerCase();
}

/// Tekrar sorularında ilk cevaplar: soru kimliği -> doğru mu.
typedef QuestionResults = Map<String, bool>;

/// Yöneticinin derse eklediği kaynak: PDF ya da web sayfası linki.
final class LessonResource {
  /// Kaynak.
  const LessonResource({
    required this.id,
    required this.position,
    required this.title,
    required this.url,
  });

  /// `lesson_resources` satırından oluşturur.
  factory LessonResource.fromJson(Map<String, dynamic> json) => LessonResource(
    id: json['id'] as String,
    position: json['position'] as int? ?? 0,
    title: json['title'] as String,
    url: json['url'] as String,
  );

  /// Kimlik.
  final String id;

  /// Dersteki sırası.
  final int position;

  /// Görünen ad.
  final String title;

  /// https linki.
  final String url;

  /// Link PDF dosyası mı.
  bool get isPdf =>
      Uri.tryParse(url)?.path.toLowerCase().endsWith('.pdf') ?? false;
}

/// Kaynak linki geçerliyse temizlenmiş hali: yalnız https ve alan adı olan
/// linkler (sunucu da aynı kuralı uygular); geçersizse `null`. Şemasız
/// yazılana https eklenir.
String? normalizeResourceUrl(String input) {
  final text = input.trim();
  if (text.isEmpty || text.contains(RegExp(r'\s')) || text.length > 2000) {
    return null;
  }
  final url = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || !uri.host.contains('.')) {
    return null;
  }
  return url;
}
