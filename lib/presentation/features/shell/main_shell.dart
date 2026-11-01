import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/presentation/features/courses/online_medrese_page.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:e_medrese/presentation/features/notifications/notifications_page.dart';
import 'package:e_medrese/presentation/features/notifications/open_notification.dart';
import 'package:e_medrese/presentation/features/profile/profile_page.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana sekmeler.
enum MainTab {
  /// Medreselerim (ana ekran).
  medreses,

  /// Online Medrese (kurslar).
  online,

  /// Bildirimler.
  notifications,

  /// Profil.
  profile,
}

/// Seçili ana sekme; bildirimler de değiştirir (bkz. openNotification).
/// Kullanıcı değişince Medreselerim'e döner.
final mainTabProvider = StateProvider<MainTab>((ref) {
  ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
  return MainTab.medreses;
});

/// Giriş yapılmışken açılan iskelet: sekmeler ve altta havada duran menü.
///
/// Yalnızca giriş yapılmışken durduğu için push kaydını ve gelen
/// bildirimleri de burası dinler.
class MainShell extends ConsumerStatefulWidget {
  /// İskelet.
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final List<StreamSubscription<Object?>> _subscriptions;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushServiceProvider);
    unawaited(push.register());
    _subscriptions = [
      push.received.listen((_) {
        ref
          ..invalidate(unreadCountProvider)
          ..invalidate(notificationsProvider);
      }),
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

  Future<void> _select(MainTab tab) async {
    ref.read(mainTabProvider.notifier).state = tab;
    if (tab != MainTab.notifications) return;
    // Önce liste yenilenir ki yeni gelenler bu açılışta kalın görünsün.
    ref.invalidate(notificationsProvider);
    await ref.read(notificationsProvider.future);
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(mainTabProvider);
    final unread = switch (ref.watch(unreadCountProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => 0,
    };
    final theme = Theme.of(context);

    return Scaffold(
      // İçerik menünün arkasından akar.
      extendBody: true,
      body: IndexedStack(
        index: tab.index,
        children: const [
          HomePage(),
          OnlineMedresePage(),
          NotificationsPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: NavigationBar(
              height: 68,
              elevation: 0,
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              selectedIndex: tab.index,
              onDestinationSelected: (i) => _select(MainTab.values[i]),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.mosque_outlined),
                  selectedIcon: Icon(Icons.mosque),
                  label: 'Medreselerim',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: Icon(Icons.school),
                  label: 'Online Medrese',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: const Icon(Icons.notifications),
                  label: 'Bildirimler',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
