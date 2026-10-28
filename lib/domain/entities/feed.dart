String _authorName(Map<String, dynamic> json) =>
    (json['author'] as Map<String, dynamic>?)?['full_name'] as String? ?? '';

/// Hocaların medreseye yazdığı duyuru.
final class Announcement {
  /// Duyuru.
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.edited,
  });

  /// `announcements` satırından (`author:profiles(full_name)` ile) oluşturur.
  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    authorId: json['author_id'] as String,
    authorName: _authorName(json),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    edited: json['edited_at'] != null,
  );

  /// Kimlik.
  final String id;

  /// Başlık.
  final String title;

  /// Metin.
  final String body;

  /// Yazanın kimliği.
  final String authorId;

  /// Yazan.
  final String authorName;

  /// Yazılma zamanı.
  final DateTime createdAt;

  /// Yazıldıktan sonra düzenlendi mi.
  final bool edited;
}

/// Medrese üyesinin paylaşımı.
final class Post {
  /// Paylaşım.
  const Post({
    required this.id,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.edited,
    required this.commentCount,
  });

  /// `posts` satırından (`author:...`, `comments(count)` ile) oluşturur.
  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    body: json['body'] as String,
    authorId: json['author_id'] as String,
    authorName: _authorName(json),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    edited: json['edited_at'] != null,
    commentCount:
        ((json['comments'] as List<dynamic>?)?.firstOrNull
                as Map<String, dynamic>?)?['count']
            as int? ??
        0,
  );

  /// Kimlik.
  final String id;

  /// Metin.
  final String body;

  /// Paylaşanın kimliği.
  final String authorId;

  /// Paylaşan.
  final String authorName;

  /// Paylaşılma zamanı.
  final DateTime createdAt;

  /// Paylaşıldıktan sonra düzenlendi mi.
  final bool edited;

  /// Yorum sayısı.
  final int commentCount;

  /// Metni değiştirilmiş kopya (düzenlemeden sonra).
  Post withBody(String body) => Post(
    id: id,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    edited: true,
    commentCount: commentCount,
  );
}

/// Paylaşıma yapılan yorum.
final class Comment {
  /// Yorum.
  const Comment({
    required this.id,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  /// `comments` satırından (`author:profiles(full_name)` ile) oluşturur.
  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    body: json['body'] as String,
    authorId: json['author_id'] as String,
    authorName: _authorName(json),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  /// Kimlik.
  final String id;

  /// Metin.
  final String body;

  /// Yazanın kimliği.
  final String authorId;

  /// Yazan.
  final String authorName;

  /// Yazılma zamanı.
  final DateTime createdAt;
}
