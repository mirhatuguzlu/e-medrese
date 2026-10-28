import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/announcements/new_announcement_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Duyuru akışı; hocalar yeni duyuru yazabilir.
class AnnouncementsPage extends ConsumerWidget {
  /// [medrese]'nin duyuruları.
  const AnnouncementsPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Duyurular')),
      body: ResultListView<Announcement>(
        value: ref.watch(announcementsProvider(medrese.id)),
        onRefresh: () => ref.refresh(announcementsProvider(medrese.id).future),
        emptyIcon: Icons.campaign_outlined,
        emptyText: 'Henüz duyuru yok.',
        separated: false,
        itemBuilder: (context, a) => Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: theme.textTheme.titleMedium),
                if (a.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(a.body),
                ],
                const SizedBox(height: 12),
                Text(
                  '${displayName(a.authorName)} · '
                  '${formatDateTime(a.createdAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: medrese.myRole.isStaff
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Duyuru yaz'),
              onPressed: () =>
                  context.push(NewAnnouncementPage(medrese: medrese)),
            )
          : null,
    );
  }
}
