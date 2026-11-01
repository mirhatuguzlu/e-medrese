import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/presentation/features/notifications/notifications_page.dart';
import 'package:e_medrese/presentation/features/notifications/open_notification.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Okunmamış sayısıyla bildirim zili; Bildirimler sayfasını açar.
///
/// Ana ekranda, yani yalnızca giriş yapılmışken durur; bu yüzden push
/// kaydını ve gelen bildirimleri de burası dinler.
class NotificationsButton extends ConsumerStatefulWidget {
  /// Bildirim zili.
  const NotificationsButton({super.key});

  @override
  ConsumerState<NotificationsButton> createState() =>
      _NotificationsButtonState();
}

class _NotificationsButtonState extends ConsumerState<NotificationsButton> {
  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);
    unawaited(push.register());
    _subscriptions = [
      push.received.listen((_) => ref.invalidate(unreadCountProvider)),
      // Telefondaki bildirime dokununca doğrudan ilgili sayfa açılır.
      push.opened.listen((n) {
        if (mounted) unawaited(openNotification(context, ref, n));
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  Future<void> _open() => context.push(const NotificationsPage());

  @override
  Widget build(BuildContext context) {
    final unread = switch (ref.watch(unreadCountProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => 0,
    };
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
