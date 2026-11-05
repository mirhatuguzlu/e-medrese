import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/presentation/features/courses/course_consent_page.dart';
import 'package:e_medrese/presentation/features/legal/legal_text_page.dart';
import 'package:e_medrese/presentation/features/legal/task_consent_page.dart';
import 'package:e_medrese/presentation/features/profile/delete_account_page.dart';
import 'package:e_medrese/presentation/features/settings/about_page.dart';
import 'package:e_medrese/presentation/features/settings/cache_page.dart';
import 'package:e_medrese/presentation/features/settings/notification_permission_page.dart';
import 'package:e_medrese/presentation/features/settings/text_size_page.dart';
import 'package:e_medrese/presentation/features/settings/theme_page.dart';
import 'package:flutter/material.dart';

/// Ayarlar listesi; her ayar kendi sayfasında açılır.
class SettingsPage extends StatelessWidget {
  /// Ayarlar.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, Widget page) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(page),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _Header('Görünüm'),
          item(Icons.dark_mode_outlined, 'Tema', const ThemePage()),
          item(Icons.format_size, 'Yazı boyutu', const TextSizePage()),
          const _Header('Bildirimler'),
          item(
            Icons.notifications_outlined,
            'Bildirim izni',
            const NotificationPermissionPage(),
          ),
          const _Header('Depolama'),
          item(Icons.cleaning_services_outlined, 'Önbellek', const CachePage()),
          const _Header('Gizlilik ve hukuk'),
          item(
            Icons.privacy_tip_outlined,
            'Aydınlatma metni',
            const LegalTextPage(
              title: 'Aydınlatma metni',
              asset: privacyNoticeAsset,
            ),
          ),
          item(
            Icons.fact_check_outlined,
            'Görev takibi rızası',
            const TaskConsentPage(),
          ),
          item(
            Icons.school_outlined,
            'Online Medrese rızası',
            const CourseConsentPage(),
          ),
          item(
            Icons.info_outline,
            'Künye ve iletişim',
            const LegalTextPage(
              title: 'Künye ve iletişim',
              asset: imprintAsset,
            ),
          ),
          const _Header('Hesap'),
          item(
            Icons.person_remove_outlined,
            'Hesabı sil',
            const DeleteAccountPage(),
          ),
          const _Header('Uygulama'),
          item(
            Icons.system_update_outlined,
            'Uygulama hakkında',
            const AboutPage(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
