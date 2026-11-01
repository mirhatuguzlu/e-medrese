import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [NotificationRepository].
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(Supabase.instance.client),
);

/// Giriş yapan kullanıcının bildirimleri.
final AutoDisposeFutureProvider<Result<List<AppNotification>, AppFailure>>
notificationsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(notificationRepositoryProvider).notifications(),
);

/// Okunmamış bildirim sayısı.
final AutoDisposeFutureProvider<Result<int, AppFailure>> unreadCountProvider =
    FutureProvider.autoDispose(
      (ref) => ref.watch(notificationRepositoryProvider).unreadCount(),
    );

/// Bildirimler ve cihaz bildirim adresleri.
class NotificationRepository {
  /// Supabase istemcisiyle oluşturur.
  NotificationRepository(this._client);

  final SupabaseClient _client;

  /// En yeni bildirimler. RLS yalnızca kendi bildirimlerini döndürür.
  Future<Result<List<AppNotification>, AppFailure>> notifications() =>
      guardSupabase(() async {
        final rows = await _client
            .from('notifications')
            .select('id, title, body, created_at, read_at')
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map(AppNotification.fromJson).toList();
      });

  /// Okunmamış bildirim sayısı.
  Future<Result<int, AppFailure>> unreadCount() => guardSupabase(() async {
    final response = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null)
        .count();
    return response.count;
  });

  /// Bütün bildirimleri okundu işaretler.
  Future<Result<void, AppFailure>> markAllRead() => guardSupabase(
    () => _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .isFilter('read_at', null),
  );

  /// Bu cihazın bildirim adresini giriş yapan kullanıcıya bağlar.
  Future<Result<void, AppFailure>> registerToken(String token) => guardSupabase(
    () => _client.rpc<void>('register_push_token', params: {'t': token}),
  );

  /// Bu cihazın bildirim adresini siler (çıkış yapmadan önce).
  Future<Result<void, AppFailure>> deleteToken(String token) => guardSupabase(
    () => _client.from('push_tokens').delete().eq('token', token),
  );
}
