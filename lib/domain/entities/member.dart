import 'package:e_medrese/domain/entities/medrese.dart';

/// Medrese üyesi.
final class Member {
  /// Üye.
  const Member({
    required this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
  });

  /// `medrese_members` satırından (`profiles(full_name)` ile) oluşturur.
  factory Member.fromJson(Map<String, dynamic> json) => Member(
    userId: json['user_id'] as String,
    name:
        (json['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
        '',
    role: MemberRole.values.byName(json['role'] as String),
    joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
  );

  /// Kullanıcı kimliği.
  final String userId;

  /// Ad soyad (boş olabilir).
  final String name;

  /// Rol.
  final MemberRole role;

  /// Medreseye katılma zamanı.
  final DateTime joinedAt;
}
