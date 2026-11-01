import 'dart:async';

import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/presentation/features/courses/online_medrese_page.dart';
import 'package:e_medrese/presentation/features/home/home_page.dart';
import 'package:e_medrese/presentation/features/notifications/notifications_page.dart';
import 'package:e_medrese/presentation/features/notifications/open_notification.dart';
import 'package:e_medrese/presentation/features/profile/profile_page.dart';
import 'package:e_medrese/presentation/features/tasks/tasks_tab_page.dart';
import 'package:e_medrese/services/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ana sekmeler, menüdeki sırasıyla.
enum MainTab {
  /// Medreselerim.
  medreses,

  /// Online Medrese (kurslar).
  online,

  /// Görev takibi (ana sayfa, ortadaki büyük düğme).
  tasks,

  /// Bildirimler.
  notifications,

  /// Profil.
  profile,
}

/// Seçili ana sekme; bildirimler de değiştirir (bkz. openNotification).
/// Kullanıcı değişince Görev takibi'ne döner.
final mainTabProvider = StateProvider<MainTab>((ref) {
  ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
  return MainTab.tasks;
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
          TasksTabPage(),
          NotificationsPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          // Ortadaki düğme şeritten taşar; dokunulabilsin diye yükseklik
          // taşan kısmı da kapsar.
          child: SizedBox(
            height: _barHeight + _lift,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Material(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  child: SizedBox(
                    height: _barHeight,
                    child: Row(
                      children: [
                        _item(
                          MainTab.medreses,
                          Icons.mosque_outlined,
                          'Medreselerim',
                        ),
                        _item(MainTab.online, Icons.school_outlined, 'Online'),
                        _item(MainTab.tasks, null, 'Görev takibi'),
                        _item(
                          MainTab.notifications,
                          Icons.notifications_outlined,
                          'Bildirimler',
                          badge: unread,
                        ),
                        _item(MainTab.profile, Icons.person_outline, 'Profil'),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Material(
                    elevation: 6,
                    shape: const CircleBorder(),
                    color: theme.colorScheme.primary,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _select(MainTab.tasks),
                      child: SizedBox.square(
                        dimension: 64,
                        child: Icon(
                          tab == MainTab.tasks
                              ? Icons.task_alt
                              : Icons.task_alt_outlined,
                          size: 32,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _barHeight = 68;
  static const double _lift = 22;

  /// Menüdeki bir sekme: simge ve altında yazı, seçiliyse renkli.
  /// [icon] `null` ise ortadaki büyük düğmenin yeri; yalnız yazı çizilir.
  Widget _item(MainTab tab, IconData? icon, String label, {int badge = 0}) {
    final theme = Theme.of(context);
    final selected = ref.watch(mainTabProvider) == tab;
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => _select(tab),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (icon != null)
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  child: Icon(icon, color: color),
                ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
