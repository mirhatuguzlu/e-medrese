import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/reward.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [RewardRepository].
final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(Supabase.instance.client),
);

/// Medresenin ödülleri, puanı az olan önce.
final AutoDisposeFutureProviderFamily<Result<List<Reward>, AppFailure>, String>
rewardsProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(rewardRepositoryProvider).rewards(medreseId),
);

/// Giriş yapan öğrencinin medresedeki hedefi; yoksa `null`.
final AutoDisposeFutureProviderFamily<Result<RewardGoal?, AppFailure>, String>
myGoalProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(rewardRepositoryProvider).goal(medreseId),
);

/// Ödül istekleri: hocaya medresenin bütün istekleri, öğrenciye kendi
/// istekleri (RLS); bekleyenler önce, en yeni önce.
final AutoDisposeFutureProviderFamily<
  Result<List<RewardClaim>, AppFailure>,
  String
>
rewardClaimsProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(rewardRepositoryProvider).claims(medreseId),
);

/// Ödüller ve öğrenci hedefleri.
class RewardRepository {
  /// Supabase istemcisiyle oluşturur.
  RewardRepository(this._client);

  final SupabaseClient _client;

  static final _day = DateFormat('yyyy-MM-dd');

  /// Medresenin ödülleri.
  Future<Result<List<Reward>, AppFailure>> rewards(String medreseId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('rewards')
            .select('id, title, description, points')
            .eq('medrese_id', medreseId)
            .order('points');
        return rows.map(Reward.fromJson).toList();
      });

  /// Ödül ekler (yalnızca hocalar).
  Future<Result<void, AppFailure>> addReward({
    required String medreseId,
    required String title,
    required String description,
    required num points,
  }) => guardSupabase(
    () => _client.from('rewards').insert({
      'medrese_id': medreseId,
      'title': title.trim(),
      'description': description.trim(),
      'points': points,
    }),
  );

  /// Ödülü siler; onu seçen hedefler de silinir.
  Future<Result<void, AppFailure>> deleteReward(String id) =>
      guardSupabase(() => _client.from('rewards').delete().eq('id', id));

  /// Öğrencinin hedefi (RLS yalnız kendi satırını döner).
  Future<Result<RewardGoal?, AppFailure>> goal(String medreseId) =>
      guardSupabase(() async {
        final row = await _client
            .from('reward_goals')
            .select('reward_id, deadline')
            .eq('medrese_id', medreseId)
            .maybeSingle();
        return row == null ? null : RewardGoal.fromJson(row);
      });

  /// Hedefi kaydeder; önceki hedefin yerine geçer.
  Future<Result<void, AppFailure>> setGoal({
    required String medreseId,
    required String rewardId,
    required DateTime deadline,
  }) => guardSupabase(
    () => _client.from('reward_goals').upsert({
      'medrese_id': medreseId,
      'reward_id': rewardId,
      'deadline': _day.format(deadline),
    }),
  );

  /// Ödül istekleri.
  Future<Result<List<RewardClaim>, AppFailure>> claims(String medreseId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('reward_claims')
            .select(
              'id, reward_id, student_id, title, points, requested_at, '
              'delivered_at, rejected_at, reject_reason, '
              'student:profiles!reward_claims_student_id_fkey(full_name)',
            )
            .eq('medrese_id', medreseId)
            .order('rejected_at', nullsFirst: true)
            .order('delivered_at', nullsFirst: true)
            .order('requested_at', ascending: false);
        return rows.map(RewardClaim.fromJson).toList();
      });

  /// Öğrenci ödülü ister; puanı yetmiyorsa sunucu reddeder. Hocalara
  /// bildirim gider, ama istek bildirimden bağımsız kaydedilir.
  Future<Result<void, AppFailure>> requestReward(String rewardId) =>
      guardSupabase(
        () => _client.rpc<void>('request_reward', params: {'r': rewardId}),
      );

  /// Hoca istenmiş ödülü teslim edildi işaretler; puanı düşülür.
  Future<Result<void, AppFailure>> deliver(String claimId) => guardSupabase(
    () => _client.rpc<void>('deliver_reward', params: {'c': claimId}),
  );

  /// Hoca bekleyen isteği [reason] ile reddeder; puan öğrenciye döner,
  /// öğrenciye neden bildirilir.
  Future<Result<void, AppFailure>> reject(String claimId, String reason) =>
      guardSupabase(
        () => _client.rpc<void>(
          'reject_reward',
          params: {'c': claimId, 'reason': reason.trim()},
        ),
      );

  /// Hedefi kaldırır.
  Future<Result<void, AppFailure>> clearGoal(String medreseId) => guardSupabase(
    () => _client.from('reward_goals').delete().eq('medrese_id', medreseId),
  );
}
