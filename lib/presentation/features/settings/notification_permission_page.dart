import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Telefon bildirimi izninin durumu; kapalıysa açtırır.
class NotificationPermissionPage extends StatefulWidget {
  /// Bildirim izni.
  const NotificationPermissionPage({super.key});

  @override
  State<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState
    extends State<NotificationPermissionPage> {
  late final AppLifecycleListener _lifecycle;
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    // Telefon ayarlarından dönünce yeni durum görünsün.
    _lifecycle = AppLifecycleListener(onResume: _load);
    unawaited(_load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _enable() async {
    final status = await Permission.notification.request();
    // Kalıcı reddedildiyse uygulama yeniden soramaz; telefon ayarları açılır.
    if (!status.isGranted) await openAppSettings();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final granted = status?.isGranted ?? false;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim izni')),
      body: status == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  granted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 72,
                  color: granted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  granted ? 'Bildirimler açık' : 'Bildirimler kapalı',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  granted
                      ? 'Duyuru, yorum, görev ve ders bildirimleri telefonuna '
                            'gelir. Kapatmak için telefonun ayarlarını aç.'
                      : 'Telefonuna bildirim gelmez; yine de Bildirimler '
                            'sekmesinde görünürler.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (granted)
                  const OutlinedButton(
                    onPressed: openAppSettings,
                    child: Text('Telefon ayarlarını aç'),
                  )
                else
                  FilledButton(
                    onPressed: _enable,
                    child: const Text('Bildirimleri aç'),
                  ),
              ],
            ),
    );
  }
}
