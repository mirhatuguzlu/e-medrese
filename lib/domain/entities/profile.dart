/// Giriş yapmış kullanıcının profili.
final class Profile {
  /// Profil.
  const Profile({
    required this.name,
    required this.photoPath,
    required this.createdAt,
  });

  /// `profiles` satırından oluşturur.
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['full_name'] as String? ?? '',
    photoPath: json['avatar_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );

  /// Ad soyad (boş olabilir).
  final String name;

  /// Fotoğrafın "avatars" kovasındaki yolu; yoksa `null`.
  final String? photoPath;

  /// Hesabın açıldığı zaman.
  final DateTime createdAt;
}
