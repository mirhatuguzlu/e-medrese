import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/profile_repository.dart';
import 'package:e_medrese/presentation/features/profile/edit_name_page.dart';
import 'package:e_medrese/presentation/features/profile/profile_photo_page.dart';
import 'package:e_medrese/presentation/features/settings/settings_page.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Profil sayfası: kişisel bilgiler. Ayarlar sağ üstteki düğmeyle açılır.
class ProfilePage extends ConsumerWidget {
  /// Profil sayfası.
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = currentUserName(ref);
    final email = currentUserEmail(ref);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final medreses = switch (ref.watch(myMedresesProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(const SettingsPage()),
          ),
        ],
      ),
      body: ListView(
        // Alttaki havada duran menünün altında kalmasın.
        padding: EdgeInsets.only(
          top: 32,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => context.push(const ProfilePhotoPage()),
              child: const UserAvatar(radius: 48),
            ),
          ),
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
          const SizedBox(height: 24),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Ad soyad'),
                  subtitle: Text(displayName(name)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(const EditNamePage()),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Profil fotoğrafı'),
                  subtitle: Text(
                    profile?.photoPath == null ? 'Eklenmedi' : 'Eklendi',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(const ProfilePhotoPage()),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('E-posta'),
                  subtitle: Text('$email · Google ile giriş'),
                ),
                if (medreses != null && medreses.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.mosque_outlined),
                    title: const Text('Medreselerim'),
                    subtitle: Text(
                      medreses
                          .map((m) => '${m.name} (${m.myRole.label})')
                          .join(', '),
                    ),
                  ),
                if (profile != null)
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Üyelik tarihi'),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy').format(profile.createdAt),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              'Çıkış yap',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () async {
              // Çıkıştan önce: token silmek için oturum gerekiyor.
              await ref.read(pushServiceProvider).unregister();
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}
