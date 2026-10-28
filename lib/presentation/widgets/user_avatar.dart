import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Giriş yapmış kullanıcının adı (yoksa boş).
String currentUserName(WidgetRef ref) {
  final user = ref.watch(sessionProvider).valueOrNull?.user;
  return (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
}

/// Giriş yapmış kullanıcının e-postası (yoksa boş).
String currentUserEmail(WidgetRef ref) =>
    ref.watch(sessionProvider).valueOrNull?.user.email ?? '';

/// Giriş yapmış kullanıcının baş harfli avatarı.
class UserAvatar extends ConsumerWidget {
  /// [radius] boyutunda avatar.
  const UserAvatar({this.radius = 16, super.key});

  /// Yarıçap.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = currentUserName(ref);
    final initial =
        (name.isNotEmpty ? name : currentUserEmail(ref)).characters.firstOrNull;
    return CircleAvatar(
      radius: radius,
      child: Text(
        initial?.toUpperCase() ?? '?',
        style: TextStyle(fontSize: radius * 0.9),
      ),
    );
  }
}
