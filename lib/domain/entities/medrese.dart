/// Medresedeki rol.
enum MemberRole {
  /// Medreseyi kuran hoca.
  owner('Kurucu'),

  /// Hoca.
  teacher('Hoca'),

  /// Öğrenci.
  student('Öğrenci');

  const MemberRole(this.label);

  /// Ekranda gösterilecek ad.
  final String label;

  /// Hoca yetkisi (sahip dahil).
  bool get isStaff => this != student;
}

/// Kullanıcının üyesi olduğu bir medrese.
final class Medrese {
  /// Medrese.
  const Medrese({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.myRole,
  });

  /// `medreses` satırından ve kullanıcının rolünden oluşturur.
  factory Medrese.fromJson(Map<String, dynamic> json, String role) => Medrese(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    inviteCode: json['invite_code'] as String,
    myRole: MemberRole.values.byName(role),
  );

  /// Kimlik.
  final String id;

  /// Ad.
  final String name;

  /// Açıklama.
  final String description;

  /// Katılım kodu.
  final String inviteCode;

  /// Giriş yapan kullanıcının rolü.
  final MemberRole myRole;
}
