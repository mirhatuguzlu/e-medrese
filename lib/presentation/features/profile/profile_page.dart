import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/presentation/features/courses/course_consent_page.dart';
import 'package:e_medrese/presentation/features/legal/legal_text_page.dart';
import 'package:e_medrese/presentation/features/legal/task_consent_page.dart';
import 'package:e_medrese/presentation/features/profile/delete_account_page.dart';
import 'package:e_medrese/presentation/widgets/user_avatar.dart';
import 'package:e_medrese/services/push_service.dart';
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
        // Alttaki havada duran menünün altında kalmasın.
        padding: EdgeInsets.only(
          top: 32,
          bottom: 32 + MediaQuery.paddingOf(context).bottom,
        ),
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
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Aydınlatma metni'),
            onTap: () => context.push(
              const LegalTextPage(
                title: 'Aydınlatma metni',
                asset: privacyNoticeAsset,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Görev takibi rızası'),
            onTap: () => context.push(const TaskConsentPage()),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Online Medrese rızası'),
            onTap: () => context.push(const CourseConsentPage()),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Künye ve iletişim'),
            onTap: () => context.push(
              const LegalTextPage(
                title: 'Künye ve iletişim',
                asset: imprintAsset,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Hesabı sil'),
            onTap: () => context.push(const DeleteAccountPage()),
          ),
          const Divider(),
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
