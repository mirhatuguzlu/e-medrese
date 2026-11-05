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
    this.files = const [],
  });

  /// `posts` satırından (`author:...`, `comments(count)`, `post_files(...)`
  /// ile) oluşturur.
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
    files:
        ((json['post_files'] as List<dynamic>?) ?? [])
            .map((f) => PostFile.fromJson(f as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
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

  /// Ekli dosyalar, sırasıyla.
  final List<PostFile> files;

  /// Metni değiştirilmiş kopya (düzenlemeden sonra).
  Post withBody(String body) => Post(
    id: id,
    body: body,
    authorId: authorId,
    authorName: authorName,
    createdAt: createdAt,
    edited: true,
    commentCount: commentCount,
    files: files,
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

/// Şikayet nedeni; adları `reports.reason` değerleridir.
enum ReportReason {
  /// Hakaret, taciz.
  insult('Hakaret ya da taciz'),

  /// Hukuka aykırı içerik.
  illegal('Hukuka aykırı içerik'),

  /// Telif hakkı ihlali (5846).
  copyright('Telif hakkı ihlali'),

  /// Kişisel verilerin ifşası.
  privacy('Kişisel verilerimin ifşası'),

  /// Spam.
  spam('Spam ya da reklam'),

  /// Diğer.
  other('Diğer');

  const ReportReason(this.label);

  /// Ekranda görünen ad.
  final String label;
}

/// Paylaşıma eklenebilen dosya türü.
enum PostFileKind {
  /// Fotoğraf.
  image(['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic']),

  /// Video.
  video(['mp4', 'mov', '3gp', 'webm']),

  /// Ses.
  audio(['mp3', 'm4a', 'aac', 'ogg', 'wav', 'opus', 'amr']),

  /// PDF.
  pdf(['pdf']);

  const PostFileKind(this.extensions);

  /// Bu türün dosya uzantıları (küçük harf).
  final List<String> extensions;

  /// Eklenebilen bütün uzantılar.
  static List<String> get allExtensions => [
    for (final k in values) ...k.extensions,
  ];

  /// [fileName]'in türü; eklenemiyorsa `null`.
  static PostFileKind? of(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return values.where((k) => k.extensions.contains(ext)).firstOrNull;
  }

  /// Sunucuya bildirilen içerik türü (kovanın izin listesinde olmalı).
  static String mimeOf(String fileName) =>
      switch (fileName.split('.').last.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'mov' => 'video/quicktime',
        '3gp' => 'video/3gpp',
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        'pdf' => 'application/pdf',
        final ext => '${of(fileName)?.name}/$ext',
      };
}

/// Paylaşıma eklenmiş dosya.
final class PostFile {
  /// Dosya.
  const PostFile({
    required this.id,
    required this.position,
    required this.kind,
    required this.name,
    required this.path,
    required this.size,
  });

  /// `post_files` satırından oluşturur.
  factory PostFile.fromJson(Map<String, dynamic> json) => PostFile(
    id: json['id'] as String,
    position: json['position'] as int,
    kind: PostFileKind.values.byName(json['kind'] as String),
    name: json['name'] as String,
    path: json['path'] as String,
    size: json['size'] as int,
  );

  /// Kimlik.
  final String id;

  /// Paylaşımdaki sırası (1–5).
  final int position;

  /// Tür.
  final PostFileKind kind;

  /// Asıl dosya adı.
  final String name;

  /// "post-files" kovasındaki yol.
  final String path;

  /// Bayt.
  final int size;
}
