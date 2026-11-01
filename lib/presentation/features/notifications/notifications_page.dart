import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:e_medrese/presentation/features/notifications/open_notification.dart';
import 'package:e_medrese/presentation/widgets/result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gelen bildirimler. Sekme açılınca hepsi okundu sayılır (MainShell); bu
/// açılışta yeni olanlar kalın gösterilir. Dokununca ilgili sayfa açılır.
class NotificationsPage extends ConsumerWidget {
  /// Bildirimler sayfası.
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onTap: () => openNotification(context, ref, n),
        ),
      ),
    );
  }
}
