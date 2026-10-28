import 'dart:math';

/// Görev girişinin türü.
enum TaskKind {
  /// Günlük onay kutuları (ör. namaz vakitleri).
  checks,

  /// Günlük sayfa sayısı (hazır seçenekler ya da elle).
  pages,
}

/// Sayfa görevinde hazır seçenek (ör. "1 cüz" = 20 sayfa).
final class TaskPreset {
  /// Seçenek.
  const TaskPreset({required this.label, required this.pages});

  /// Yazı.
  final String label;

  /// Sayfa karşılığı.
  final int pages;
}

/// Görev tanımı. Puan = min(dönem toplamı, [cap]) * [points] / [target].
final class TaskDefinition {
  /// Görev tanımı.
  const TaskDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.target,
    required this.points,
    required this.cap,
    this.items = const [],
    this.weekdays,
    this.presets = const [],
  });

  /// `task_definitions` satırından oluşturur.
  factory TaskDefinition.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>;
    return TaskDefinition(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      kind: TaskKind.values.byName(config['kind'] as String),
      target: config['target'] as num,
      points: config['points'] as num,
      cap: config['cap'] as num,
      items: [...?(config['items'] as List<dynamic>?)?.cast<String>()],
      weekdays: (config['weekdays'] as List<dynamic>?)?.cast<int>(),
      presets: [
        for (final p in (config['presets'] as List<dynamic>?) ?? <dynamic>[])
          TaskPreset(
            label: (p as Map<String, dynamic>)['label'] as String,
            pages: p['pages'] as int,
          ),
      ],
    );
  }

  /// Kimlik (ör. `namaz`).
  final String id;

  /// Başlık.
  final String title;

  /// Öğrenciye açıklama.
  final String description;

  /// Giriş türü.
  final TaskKind kind;

  /// [points] puan için gereken dönem toplamı.
  final num target;

  /// [target]'a ulaşınca alınan puan.
  final num points;

  /// Puana sayılan en yüksek dönem toplamı.
  final num cap;

  /// [TaskKind.checks] için gündeki kutular.
  final List<String> items;

  /// Görevin olduğu haftanın günleri (1 = Pazartesi); `null` ise her gün.
  final List<int>? weekdays;

  /// [TaskKind.pages] için hazır seçenekler.
  final List<TaskPreset> presets;

  /// [day] bu görevin günü mü.
  bool isOn(DateTime day) => weekdays?.contains(day.weekday) ?? true;

  /// Dönem toplamının puanı.
  double score(num total) => min(total, cap) * points / target;

  /// Alınabilecek en yüksek puan.
  double get maxScore => score(cap);
}

/// Öğrencinin bir gündeki girdisi; işaretlenmeyen = girdi yok.
final class TaskEntry {
  /// Girdi.
  const TaskEntry({
    required this.studentId,
    required this.taskId,
    required this.day,
    required this.item,
    required this.value,
  });

  /// `task_entries` satırından oluşturur.
  factory TaskEntry.fromJson(Map<String, dynamic> json) => TaskEntry(
    studentId: json['student_id'] as String,
    taskId: json['task_id'] as String,
    day: dateOnly(DateTime.parse(json['day'] as String)),
    item: json['item'] as int,
    value: json['value'] as num,
  );

  /// Öğrenci.
  final String studentId;

  /// Görev.
  final String taskId;

  /// Gün.
  final DateTime day;

  /// Kutu sırası ([TaskKind.checks]); sayfa görevinde 0.
  final int item;

  /// İşaret için 1, sayfa görevinde sayfa sayısı.
  final num value;
}

/// Saat ve saat dilimi olmadan gün (gün farkları yaz saatinden etkilenmesin).
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Medresenin görev programı: [startDate]'ten itibaren 7 günlük dönemler.
final class TaskProgram {
  /// Program.
  const TaskProgram({required this.startDate, required this.active});

  /// `task_programs` satırından oluşturur.
  factory TaskProgram.fromJson(Map<String, dynamic> json) => TaskProgram(
    startDate: dateOnly(DateTime.parse(json['start_date'] as String)),
    active: json['active'] as bool,
  );

  /// Başlangıç günü.
  final DateTime startDate;

  /// Sürüyor mu.
  final bool active;

  /// [today]'in içinde bulunduğu dönemin ilk günü.
  DateTime periodStart(DateTime today) {
    final days = dateOnly(today).difference(startDate).inDays;
    return startDate.add(Duration(days: 7 * (days ~/ 7)));
  }

  /// [today]'in dönemindeki 7 gün.
  List<DateTime> periodDays(DateTime today) {
    final start = periodStart(today);
    return [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
  }
}

/// [entries] içinden [task] görevinin [student] için dönem toplamı.
num taskTotal(TaskDefinition task, String student, List<TaskEntry> entries) =>
    entries
        .where((e) => e.taskId == task.id && e.studentId == student)
        .fold<num>(0, (sum, e) => sum + e.value);

/// Öğrencinin biten bir dönemdeki puanı (sunucuda hesaplanır).
final class WeeklyScore {
  /// Haftalık puan.
  const WeeklyScore({
    required this.studentId,
    required this.studentName,
    required this.periodStart,
    required this.total,
    required this.details,
    required this.opened,
  });

  /// `weekly_scores` satırından (`student:profiles(full_name)` ile) oluşturur.
  factory WeeklyScore.fromJson(Map<String, dynamic> json) => WeeklyScore(
    studentId: json['student_id'] as String,
    studentName:
        (json['student'] as Map<String, dynamic>?)?['full_name'] as String? ??
        '',
    periodStart: dateOnly(DateTime.parse(json['period_start'] as String)),
    total: json['total'] as num,
    details: (json['details'] as Map<String, dynamic>).cast<String, num>(),
    opened: json['opened_at'] != null,
  );

  /// Öğrenci.
  final String studentId;

  /// Öğrencinin adı (boş olabilir).
  final String studentName;

  /// Dönemin ilk günü.
  final DateTime periodStart;

  /// Toplam puan.
  final num total;

  /// Görev kimliği -> puan.
  final Map<String, num> details;

  /// Öğrenci sandığı açtı mı; açmadıysa puan otomatik aktarılmıştır.
  final bool opened;
}
