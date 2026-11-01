import 'dart:async';

import 'package:e_medrese/data/repositories/notification_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uygulama genelindeki [PushService].
final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref.watch(notificationRepositoryProvider)),
);

/// Firebase push bildirimleri: izin, cihaz adresi ve gelen mesajlar.
///
/// Push alınamazsa (izin yok, ağ yok) hata yutulur; bildirimler yine
/// Bildirimler sayfasında görünür.
class PushService {
  /// Bildirim deposuyla oluşturur.
  PushService(this._repo);

  final NotificationRepository _repo;
  StreamSubscription<String>? _tokenRefresh;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// İzin ister ve cihaz adresini giriş yapan kullanıcıya kaydeder.
  /// Adres yenilenince yeniden kaydeder.
  Future<void> register() async {
    try {
      await _messaging.requestPermission();
      _tokenRefresh ??= _messaging.onTokenRefresh.listen(_repo.registerToken);
      final token = await _messaging.getToken();
      if (token != null) await _repo.registerToken(token);
    } on Exception catch (_) {}
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
  Stream<void> get opened async* {
    if (await _messaging.getInitialMessage() != null) yield null;
    yield* FirebaseMessaging.onMessageOpenedApp;
  }
}
