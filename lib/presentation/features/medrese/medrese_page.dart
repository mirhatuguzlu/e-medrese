import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/announcements/announcements_page.dart';
import 'package:e_medrese/presentation/features/medrese/invite_code_page.dart';
import 'package:e_medrese/presentation/features/members/members_page.dart';
import 'package:e_medrese/presentation/features/posts/posts_page.dart';
import 'package:e_medrese/presentation/features/tasks/ranking_page.dart';
import 'package:e_medrese/presentation/features/tasks/score_history_page.dart';
import 'package:e_medrese/presentation/features/tasks/task_tracking_page.dart';
import 'package:flutter/material.dart';

/// Medresenin kapısı: her bölüm kendi sayfasında açılır.
class MedresePage extends StatelessWidget {
  /// [medrese] sayfası.
  const MedresePage({required this.medrese, super.key});

  /// Açılan medrese.
  final Medrese medrese;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(medrese.name)),
      body: ListView(
        children: [
          if (medrese.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                medrese.description,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Rolün: ${medrese.myRole.label}',
              style: theme.textTheme.labelLarge,
            ),
          ),
          const Divider(height: 1),
          _Entry(
            icon: Icons.campaign_outlined,
            title: 'Duyurular',
            subtitle: 'Hocaların duyuruları',
            page: AnnouncementsPage(medrese: medrese),
          ),
          _Entry(
            icon: Icons.forum_outlined,
            title: 'Paylaşımlar',
            subtitle: 'Medresedeki herkesin paylaşımları',
            page: PostsPage(medrese: medrese),
          ),
          _Entry(
            icon: Icons.groups_outlined,
            title: 'Üyeler',
            subtitle: 'Hocalar ve öğrenciler',
            page: MembersPage(medrese: medrese),
          ),
          _Entry(
            icon: Icons.emoji_events_outlined,
            title: 'Haftalık sıralama',
            subtitle: 'Biten dönemlerin görev puanları',
            page: RankingPage(medrese: medrese),
          ),
          if (!medrese.myRole.isStaff)
            _Entry(
              icon: Icons.history,
              title: 'Puan geçmişim',
              subtitle: 'Haftalık görev puanların',
              page: ScoreHistoryPage(medrese: medrese),
            ),
          if (medrese.myRole.isStaff)
            _Entry(
              icon: Icons.task_alt,
              title: 'Görev takibi',
              subtitle: 'Görevleri başlat, öğrenci geçmişleri',
              page: TaskTrackingPage(medrese: medrese),
            ),
          if (medrese.myRole.isStaff)
            _Entry(
              icon: Icons.vpn_key_outlined,
              title: 'Davet kodu',
              subtitle: 'Öğrencilerin katılması için',
              page: InviteCodePage(medrese: medrese),
            ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(page),
    );
  }
}
