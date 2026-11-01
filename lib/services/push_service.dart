import 'dart:async';
import 'dart:convert';

import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulama genelindeki [PushService].
final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref.watch(notificationRepositoryProvider)),
);

/// Sesli, üstten açılan bildirim kanalı. Kimliği AndroidManifest'te de var.
const _channel = AndroidNotificationChannel(
  'bildirimler',
  'Bildirimler',
  importance: Importance.high,
);

/// Firebase push bildirimleri: izin, cihaz adresi ve gelen mesajlar.
///
/// Push alınamazsa (izin yok, ağ yok) hata yutulur; bildirimler yine
/// Bildirimler sayfasında görünür.
class PushService {
  /// Bildirim deposuyla oluşturur.
  PushService(this._repo);

  final NotificationRepository _repo;
  final _local = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<AppNotification>.broadcast();
  StreamSubscription<String>? _tokenRefresh;
  bool _started = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// İzin ister ve cihaz adresini giriş yapan kullanıcıya kaydeder.
  /// Adres yenilenince yeniden kaydeder.
  Future<void> register() async {
    try {
      await _start();
      await _messaging.requestPermission();
      _tokenRefresh ??= _messaging.onTokenRefresh.listen(_repo.registerToken);
      final token = await _messaging.getToken();
      if (token != null) await _repo.registerToken(token);
    } on Exception catch (_) {}
  }

  /// Kanalı kurar, dokunulan bildirimleri [opened]'a aktarır.
  Future<void> _start() async {
    if (_started) return;
    _started = true;
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // Uygulama açıkken gösterilenin yükü mesaj verisidir (_show).
      onDidReceiveNotificationResponse: (r) => _taps.add(
        AppNotification.fromPush(
          jsonDecode(r.payload ?? '{}') as Map<String, dynamic>,
        ),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    FirebaseMessaging.onMessage.listen(_show);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _taps.add(AppNotification.fromPush(m.data)),
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _taps.add(AppNotification.fromPush(initial.data));
  }

  /// Uygulama açıkken Android bildirimi kendisi göstermez; biz gösteririz.
  Future<void> _show(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Çıkıştan önce: bu cihaza artık bildirim gelmesin.
  Future<void> unregister() async {
    try {
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
      final token = await _messaging.getToken();
      if (token != null) await _repo.deleteToken(token);
    } on Exception catch (_) {}
  }

  /// Uygulama açıkken gelen bildirimler.
  Stream<void> get received => FirebaseMessaging.onMessage;

  /// Kullanıcının dokunduğu bildirimler; uygulamayı başlatan dahil.
  Stream<AppNotification> get opened => _taps.stream;
}
