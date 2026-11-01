import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/announcements/announcements_page.dart';
import 'package:e_medrese/presentation/features/medrese/invite_code_page.dart';
import 'package:e_medrese/presentation/features/members/members_page.dart';
import 'package:e_medrese/presentation/features/posts/posts_page.dart';
import 'package:e_medrese/presentation/features/tasks/ranking_page.dart';
import 'package:e_medrese/presentation/features/tasks/score_history_page.dart';
import 'package:e_medrese/presentation/features/tasks/task_tracking_page.dart';
import 'package:e_medrese/presentation/widgets/tile_card.dart';
import 'package:flutter/material.dart';

/// Medresenin kapısı: her bölüm kendi sayfasında açılır.
class MedresePage extends StatelessWidget {
  /// [medrese] sayfası.
  const MedresePage({required this.medrese, this.actions, super.key});

  /// Açılan medrese.
  final Medrese medrese;

  /// Üst çubuk düğmeleri (Medreselerim sekmesinde koda katıl, medrese kur).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(medrese.name), actions: actions),
      body: ListView(
        // Alttaki menünün arkasında kalmasın.
        padding: const EdgeInsets.only(bottom: 96),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TileGrid(
              children: [
                TileCard.page(
                  icon: const Icon(Icons.campaign_outlined),
                  title: 'Duyurular',
                  subtitle: 'Hocaların duyuruları',
                  page: AnnouncementsPage(medrese: medrese),
                ),
                TileCard.page(
                  icon: const Icon(Icons.forum_outlined),
                  title: 'Paylaşımlar',
                  subtitle: 'Medresedeki herkesin paylaşımları',
                  page: PostsPage(medrese: medrese),
                ),
                TileCard.page(
                  icon: const Icon(Icons.groups_outlined),
                  title: 'Üyeler',
                  subtitle: 'Hocalar ve öğrenciler',
                  page: MembersPage(medrese: medrese),
                ),
                TileCard.page(
                  icon: const Icon(Icons.emoji_events_outlined),
                  title: 'Haftalık sıralama',
                  subtitle: 'Biten dönemlerin görev puanları',
                  page: RankingPage(medrese: medrese),
                ),
                if (!medrese.myRole.isStaff)
                  TileCard.page(
                    icon: const Icon(Icons.history),
                    title: 'Puan geçmişim',
                    subtitle: 'Haftalık görev puanların',
                    page: ScoreHistoryPage(medrese: medrese),
                  ),
                if (medrese.myRole.isStaff)
                  TileCard.page(
                    icon: const Icon(Icons.task_alt),
                    title: 'Görev takibi',
                    subtitle: 'Görevleri başlat, öğrenci geçmişleri',
                    page: TaskTrackingPage(medrese: medrese),
                  ),
                if (medrese.myRole.isStaff)
                  TileCard.page(
                    icon: const Icon(Icons.vpn_key_outlined),
                    title: 'Davet kodu',
                    subtitle: 'Öğrencilerin katılması için',
                    page: InviteCodePage(medrese: medrese),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
