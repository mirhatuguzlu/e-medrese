import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/feed_repository.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:e_medrese/presentation/features/posts/post_page.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gelen bildirimler. Açılınca hepsi okundu sayılır; bu açılışta yeni
/// olanlar kalın gösterilir. Yorum bildirimine dokununca paylaşım açılır.
class NotificationsPage extends ConsumerStatefulWidget {
  /// Bildirimler sayfası.
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future(() async {
        await ref.read(notificationRepositoryProvider).markAllRead();
        ref.invalidate(unreadCountProvider);
      }),
    );
  }

  Future<void> _openPost(String medreseId, String postId) async {
    final medrese = switch (await ref.read(myMedresesProvider.future)) {
      Ok(:final value) => value.where((m) => m.id == medreseId).firstOrNull,
      Err() => null,
    };
    final post = await ref.read(feedRepositoryProvider).post(postId);
    if (!mounted) return;
    switch (post) {
      case Ok(:final value?) when medrese != null:
        await context.push(PostPage(medrese: medrese, post: value));
      case Ok():
        context.showMessage('Bu paylaşım silinmiş.');
      case Err(:final error):
        context.showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ResultListView<AppNotification>(
        value: ref.watch(notificationsProvider),
        onRefresh: () => ref.refresh(notificationsProvider.future),
        emptyIcon: Icons.notifications_none,
        emptyText: 'Henüz bildirim yok.',
        itemBuilder: (context, n) => ListTile(
          leading: Icon(
            n.read ? Icons.notifications_none : Icons.notifications_active,
          ),
          title: Text(
            n.title,
            style: n.read ? null : const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            [
              if (n.body.isNotEmpty) n.body,
              formatDateTime(n.createdAt),
            ].join('\n'),
          ),
          isThreeLine: n.body.isNotEmpty,
          onTap: switch ((n.medreseId, n.postId)) {
            (final m?, final p?) => () => _openPost(m, p),
            _ => null,
          },
        ),
      ),
    );
  }
}
