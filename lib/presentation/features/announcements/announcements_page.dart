import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/domain/entities/feed.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/presentation/features/announcements/new_announcement_page.dart';
import 'package:e_medrese/presentation/widgets/author_label.dart';
import 'package:e_medrese/presentation/widgets/confirm_dialog.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Duyuru akışı; hocalar yeni duyuru yazabilir.
class AnnouncementsPage extends ConsumerWidget {
  /// [medrese]'nin duyuruları.
  const AnnouncementsPage({required this.medrese, super.key});

  /// Medrese.
  final Medrese medrese;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Announcement a,
  ) async {
    if (!await confirm(
      context,
      title: 'Duyuruyu sil',
      message: '"${a.title}" silinsin mi?',
      action: 'Sil',
    )) {
      return;
    }
    final result = await ref
        .read(feedRepositoryProvider)
        .deleteAnnouncement(a.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(announcementsProvider(medrese.id));
        context.showMessage('Duyuru silindi.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = ref.watch(sessionProvider).valueOrNull?.user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Duyurular')),
      body: ResultListView<Announcement>(
        value: ref.watch(announcementsProvider(medrese.id)),
        onRefresh: () => ref.refresh(announcementsProvider(medrese.id).future),
        emptyIcon: Icons.campaign_outlined,
        emptyText: 'Henüz duyuru yok.',
        separated: false,
        itemBuilder: (context, a) {
          final isAuthor = a.authorId == myId;
          // Veritabanı kuralı: yazan düzenler, yazan ya da kurucu siler.
          final canDelete = isAuthor || medrese.myRole == MemberRole.owner;
          final author = authorLabel(
            ref,
            medreseId: medrese.id,
            authorId: a.authorId,
            name: a.authorName,
          );
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(a.title, style: theme.textTheme.titleMedium),
                  ),
                  if (a.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(a.body),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$author · ${formatDateTime(a.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (isAuthor)
                        IconButton(
                          tooltip: 'Düzenle',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => context.push(
                            NewAnnouncementPage(medrese: medrese, editing: a),
                          ),
                        ),
                      if (canDelete)
                        IconButton(
                          tooltip: 'Sil',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, a),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
