/// Kullanıcıya gelen bildirim.
final class AppNotification {
  /// Bildirim.
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  /// `notifications` satırından oluşturur.
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        read: json['read_at'] != null,
      );

  /// Kimlik.
  final String id;

  /// Başlık.
  final String title;

  /// Metin.
  final String body;

  /// Oluşturulma zamanı.
  final DateTime createdAt;

  /// Okundu mu.
  final bool read;
}
