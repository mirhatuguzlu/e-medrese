import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AppBar'larda kullanılan profil butonu.
///
/// Ayarlar gibi hesapla ilgili her şey bu menüye eklenir.
class ProfileButton extends ConsumerWidget {
  /// Profil butonu.
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull?.user;
    final name = (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final email = user?.email ?? '';
    final initial = (name.isNotEmpty ? name : email).characters.firstOrNull;

    return PopupMenuButton<VoidCallback>(
      tooltip: 'Profil',
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name.isNotEmpty ? name : email),
            subtitle: name.isNotEmpty ? Text(email) : null,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: () => ref.read(authRepositoryProvider).signOut(),
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Çıkış yap'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          radius: 16,
          child: Text(initial?.toUpperCase() ?? '?'),
        ),
      ),
    );
  }
}
