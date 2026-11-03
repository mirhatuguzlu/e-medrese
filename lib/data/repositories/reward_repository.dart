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

  /// Hedefi kaldırır.
  Future<Result<void, AppFailure>> clearGoal(String medreseId) => guardSupabase(
    () => _client.from('reward_goals').delete().eq('medrese_id', medreseId),
  );
}
