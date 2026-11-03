import 'dart:math';

import 'package:e_medrese/domain/entities/task.dart';

/// Hocanın koyduğu ödül: birikmiş puan [points]'e gelen alır.
final class Reward {
  /// Ödül.
  const Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
  });

  /// `rewards` satırından oluşturur.
  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    points: json['points'] as num,
  );

  /// Kimlik.
  final String id;

  /// Başlık.
  final String title;

  /// Ayrıntı (boş olabilir).
  final String description;

  /// Gereken birikmiş puan.
  final num points;
}

/// Öğrencinin seçtiği ödül ve bitiş günü.
final class RewardGoal {
  /// Hedef.
  const RewardGoal({required this.rewardId, required this.deadline});

  /// `reward_goals` satırından oluşturur.
  factory RewardGoal.fromJson(Map<String, dynamic> json) => RewardGoal(
    rewardId: json['reward_id'] as String,
    deadline: dateOnly(DateTime.parse(json['deadline'] as String)),
  );

  /// Ödül.
  final String rewardId;

  /// Bitiş günü.
  final DateTime deadline;
}

/// Bir görevden haftada en az yapılması gereken.
final class TaskNeed {
  /// İhtiyaç.
  const TaskNeed({
    required this.task,
    required this.perWeek,
    required this.perDay,
  });

  /// Görev.
  final TaskDefinition task;

  /// Haftada en az birim (vakit, sayfa, kez).
  final int perWeek;

  /// Her gün yapılan görevde günde en az birim; değilse `null`.
  final int? perDay;
}

/// Hedef için haftalık öneri.
final class GoalPlan {
  /// Öneri.
  const GoalPlan({
    required this.remaining,
    required this.weeks,
    required this.needs,
    required this.reachable,
  });

  /// Ödüle kalan puan; 0 ise ödüle ulaşıldı.
  final num remaining;

  /// Bitiş gününe kadar biten dönem sayısı.
  final int weeks;

  /// Görev başına ihtiyaç; namaz her zaman tam.
  final List<TaskNeed> needs;

  /// Görevlerin en yüksek puanıyla yetişiyor mu.
  final bool reachable;
}

/// Öğrencinin ödül isteği; hoca teslim edince [deliveredAt], reddedince
/// [rejectedAt] dolar.
final class RewardClaim {
  /// İstek.
  const RewardClaim({
    required this.id,
    required this.rewardId,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.points,
    required this.requestedAt,
    this.deliveredAt,
    this.rejectedAt,
    this.rejectReason = '',
  });

  /// `reward_claims` satırından (`student:profiles(full_name)` ile) oluşturur.
  factory RewardClaim.fromJson(Map<String, dynamic> json) => RewardClaim(
    id: json['id'] as String,
    rewardId: json['reward_id'] as String?,
    studentId: json['student_id'] as String,
    studentName:
        (json['student'] as Map<String, dynamic>?)?['full_name'] as String? ??
        '',
    title: json['title'] as String,
    points: json['points'] as num,
    requestedAt: DateTime.parse(json['requested_at'] as String).toLocal(),
    deliveredAt: switch (json['delivered_at']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
    rejectedAt: switch (json['rejected_at']) {
      final String at => DateTime.parse(at).toLocal(),
      _ => null,
    },
    rejectReason: json['reject_reason'] as String? ?? '',
  );

  /// Kimlik.
  final String id;

  /// Ödül; ödül sonradan silindiyse `null`.
  final String? rewardId;

  /// Öğrenci.
  final String studentId;

  /// Öğrencinin adı (boş olabilir).
  final String studentName;

  /// İstek anındaki ödül adı.
  final String title;

  /// Birikmiş puandan düşülen puan.
  final num points;

  /// İstek zamanı.
  final DateTime requestedAt;

  /// Teslim zamanı; teslim edilmediyse `null`.
  final DateTime? deliveredAt;

  /// Ret zamanı; reddedilmediyse `null`.
  final DateTime? rejectedAt;

  /// Hocanın ret nedeni.
  final String rejectReason;

  /// Hoca henüz teslim etmedi ve reddetmedi.
  bool get pending => deliveredAt == null && rejectedAt == null;
}

/// [student]'in istenebilir puanı: biten dönemler toplamından istenen ve
/// teslim edilen ödüllerin puanı düşülür; reddedilenler düşülmez (sunucudaki
/// `reward_balance`).
num rewardBalance(
  List<WeeklyScore> scores,
  List<RewardClaim> claims,
  String student,
) =>
    scores
        .where((s) => s.studentId == student)
        .fold<num>(0, (sum, s) => sum + s.total) -
    claims
        .where((c) => c.studentId == student && c.rejectedAt == null)
        .fold<num>(0, (sum, c) => sum + c.points);

/// Süren dönemde [need] için kalan: haftalık en azdan bu hafta yapılan
/// [done] düşülür; her gün yapılan görevde kalan [daysLeft] güne (bugün
/// dahil) bölünür.
({int left, int? perDay}) leftThisWeek(TaskNeed need, num done, int daysLeft) {
  final left = max<num>(0, need.perWeek - done).ceil();
  return (
    left: left,
    perDay: need.perDay == null ? null : (left / daysLeft - 1e-9).ceil(),
  );
}

/// Bütün görevler en yüksek puanla yapılsa ödüle en erken ulaşılan gün (bir
/// dönemin son günü). Süren dönemde yalnız bugünden sonra kalan günler ve
/// [entries]'teki yapılanlar sayılır; hocanın verdiği puan sayılmaz.
DateTime earliestDeadline({
  required List<TaskDefinition> tasks,
  required List<TaskEntry> entries,
  required String student,
  required num total,
  required num threshold,
  required DateTime periodStart,
  required DateTime today,
}) {
  final own = [
    for (final t in tasks)
      if (t.kind != TaskKind.teacher) t,
  ];
  final daysLeft = [
    for (var i = 0; i < 7; i++) periodStart.add(Duration(days: i)),
  ].where((d) => !d.isBefore(today));
  double thisWeek(TaskDefinition t) {
    // Sayfa ve haftalık görevde kalan gün sınır değil; tek günde cap'e varılır.
    final room = t.kind == TaskKind.checks
        ? t.items.length * daysLeft.where(t.isOn).length
        : t.cap;
    return t.score(taskTotal(t, student, entries) + room);
  }

  final perWeek = own.fold<double>(0, (s, t) => s + t.maxScore);
  final rest =
      threshold - total - own.fold<double>(0, (s, t) => s + thisWeek(t));
  final weeks = rest <= 0 || perWeek == 0
      ? 1
      : 1 + (rest / perWeek - 1e-9).ceil();
  return periodStart.add(Duration(days: 7 * weeks - 1));
}

/// [deadline]'e kadar bitecek dönem sayısı; [periodStart] süren dönemin ilk
/// günü. Puan dönem bitince eklendiği için yarım dönem sayılmaz.
int weeksUntil(DateTime periodStart, DateTime deadline) =>
    max(0, (deadline.difference(periodStart).inDays + 1) ~/ 7);

/// Ödüle kalan puanı [weeks] döneme böler. Namaz kısılmaz: hep tam istenir.
/// Kalanı diğer görevlere en yüksek puanlarına oranla dağıtır. Hocanın verdiği
/// puan ([TaskKind.teacher]) hesaba katılmaz.
GoalPlan planGoal({
  required List<TaskDefinition> tasks,
  required num total,
  required num threshold,
  required int weeks,
}) {
  final remaining = max<num>(0, threshold - total);
  final namaz = tasks.where((t) => t.id == 'namaz').toList();
  final others = [
    for (final t in tasks)
      if (t.id != 'namaz' && t.kind != TaskKind.teacher) t,
  ];
  final othersMax = others.fold<double>(0, (s, t) => s + t.maxScore);
  final namazMax = namaz.fold<double>(0, (s, t) => s + t.maxScore);
  final perWeek = weeks == 0 ? double.infinity : remaining / weeks;
  final rest = max<double>(0, perWeek - namazMax);
  final share = othersMax == 0 ? 0.0 : min<double>(1, rest / othersMax);

  TaskNeed need(TaskDefinition t, double f) {
    // Küçük kayan nokta artığı bir birim fazla istemesin.
    final week = (t.cap * f - 1e-9).ceil();
    final daily =
        t.weekdays == null &&
        (t.kind == TaskKind.checks || t.kind == TaskKind.pages);
    return TaskNeed(
      task: t,
      perWeek: week,
      perDay: daily ? (week / 7 - 1e-9).ceil() : null,
    );
  }

  return GoalPlan(
    remaining: remaining,
    weeks: weeks,
    needs: remaining == 0
        ? const []
        : [
            for (final t in namaz) need(t, 1),
            for (final t in others)
              if (share > 0) need(t, share),
          ],
    reachable: weeks > 0 && perWeek <= namazMax + othersMax + 1e-9,
  );
}
