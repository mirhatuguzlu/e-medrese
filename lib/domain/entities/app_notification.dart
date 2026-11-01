/// Kullanıcıya gelen bildirim.
final class AppNotification {
  /// Bildirim.
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.medreseId,
    this.postId,
  });

  /// `notifications` satırından oluşturur.
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        read: json['read_at'] != null,
        medreseId: json['medrese_id'] as String?,
        postId: json['post_id'] as String?,
      );

  /// Push mesajının verisinden (send-push) oluşturur; yalnız yönlendirme
  /// alanları dolu, boş metin `null` demektir.
  factory AppNotification.fromPush(Map<String, dynamic> data) {
    String? text(String key) => switch (data[key]) {
      final String s when s.isNotEmpty => s,
      _ => null,
    };
    return AppNotification(
      id: '',
      kind: text('kind') ?? '',
      title: '',
      body: '',
      createdAt:
          DateTime.tryParse(text('created_at') ?? '')?.toLocal() ??
          DateTime.now(),
      read: true,
      medreseId: text('medrese_id'),
      postId: text('post_id'),
    );
  }

  /// Kimlik.
  final String id;

  /// Tür: task_started, task_paused, task_resumed, task_finished,
  /// announcement, period_ready, reminder, comment.
  final String kind;

  /// Başlık.
  final String title;

  /// Metin.
  final String body;

  /// Oluşturulma zamanı.
  final DateTime createdAt;

  /// Okundu mu.
  final bool read;

  /// İlgili medrese.
  final String? medreseId;

  /// Yorum bildiriminde paylaşım.
  final String? postId;
}
