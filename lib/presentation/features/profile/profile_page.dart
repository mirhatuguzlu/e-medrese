import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profil sayfası. Ayarlar gibi hesap sayfalarına buradan gidilir.
class ProfilePage extends ConsumerWidget {
  /// Profil sayfası.
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = currentUserName(ref);
    final email = currentUserEmail(ref);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: [
          const Center(child: UserAvatar(radius: 48)),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : email,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (name.isNotEmpty)
            Text(
              email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Çıkış yap',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
