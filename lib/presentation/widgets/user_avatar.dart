import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Giriş yapmış kullanıcının adı (yoksa boş). Profilde değiştirilen ad
/// önce gelir; profil yüklenmediyse Google hesabındaki ad.
String currentUserName(WidgetRef ref) {
  final profileName = ref.watch(myProfileProvider).valueOrNull?.name.trim();
  if (profileName != null && profileName.isNotEmpty) return profileName;
  final user = ref.watch(sessionProvider).valueOrNull?.user;
  return (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
}

/// Giriş yapmış kullanıcının e-postası (yoksa boş).
String currentUserEmail(WidgetRef ref) =>
    ref.watch(sessionProvider).valueOrNull?.user.email ?? '';

/// Giriş yapmış kullanıcının fotoğrafı ya da baş harfli avatarı.
class UserAvatar extends ConsumerWidget {
  /// [radius] boyutunda avatar.
  const UserAvatar({this.radius = 16, super.key});

  /// Yarıçap.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = currentUserName(ref);
    return ProfilePhoto(
      name: name.isNotEmpty ? name : currentUserEmail(ref),
      photoPath: ref.watch(myProfileProvider).valueOrNull?.photoPath,
      radius: radius,
    );
  }
}

/// Bir kullanıcının fotoğrafı; yoksa adının baş harfi.
class ProfilePhoto extends ConsumerWidget {
  /// [name] ve isteğe bağlı [photoPath] ile.
  const ProfilePhoto({
    required this.name,
    required this.photoPath,
    this.radius = 20,
    super.key,
  });

  /// Ad (baş harfi için).
  final String name;

  /// "avatars" kovasındaki yol; yoksa `null`.
  final String? photoPath;

  /// Yarıçap.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photoPath;
    return CircleAvatar(
      radius: radius,
      foregroundImage: path == null
          ? null
          : ref.watch(profileRepositoryProvider).photo(path),
      child: Text(
        displayName(name).characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.9),
      ),
    );
  }
}

/// Medresedeki bir kişinin fotoğrafı; yol üye listesinden bulunur.
///
/// Medreseden ayrıldıysa ya da liste yüklenmediyse baş harf görünür.
class MemberPhoto extends ConsumerWidget {
  /// [medreseId]'deki [userId]'nin fotoğrafı.
  const MemberPhoto({
    required this.medreseId,
    required this.userId,
    required this.name,
    this.radius = 20,
    super.key,
  });

  /// Medrese.
  final String medreseId;

  /// Kullanıcı.
  final String userId;

  /// Ad (baş harfi için).
  final String name;

  /// Yarıçap.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kendi fotoğrafın değişince hemen görünsün.
    if (userId == ref.watch(sessionProvider).valueOrNull?.user.id) {
      return UserAvatar(radius: radius);
    }
    final path = switch (ref.watch(membersProvider(medreseId))) {
      AsyncData(value: Ok(:final value)) =>
        value.where((m) => m.userId == userId).firstOrNull?.photoPath,
      _ => null,
    };
    return ProfilePhoto(name: name, photoPath: path, radius: radius);
  }
}
