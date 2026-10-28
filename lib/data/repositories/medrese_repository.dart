import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Uygulama genelindeki [MedreseRepository].
final medreseRepositoryProvider = Provider<MedreseRepository>(
  (ref) => MedreseRepository(Supabase.instance.client),
);

/// Giriş yapan kullanıcının medreseleri; kullanıcı değişince yenilenir.
final myMedresesProvider = FutureProvider<Result<List<Medrese>, AppFailure>>((
  ref,
) {
  final userId = ref.watch(sessionProvider).valueOrNull?.user.id;
  if (userId == null) return const Ok([]);
  return ref.watch(medreseRepositoryProvider).myMedreses(userId);
});

/// Medrese listeleme, kurma ve koda katılma.
class MedreseRepository {
  /// Supabase istemcisiyle oluşturur.
  MedreseRepository(this._client);

  final SupabaseClient _client;

  /// [userId]'nin üyesi olduğu medreseler, ada göre sıralı.
  Future<Result<List<Medrese>, AppFailure>> myMedreses(String userId) => _guard(
    () async {
      final rows = await _client
          .from('medrese_members')
          .select('role, medreses(id, name, description, invite_code)')
          .eq('user_id', userId);
      return rows
          .map(
            (r) => Medrese.fromJson(
              r['medreses'] as Map<String, dynamic>,
              r['role'] as String,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    },
  );

  /// Yeni medrese kurar; kuran kişi sahibi olur.
  Future<Result<Medrese, AppFailure>> create({
    required String name,
    required String description,
  }) => _guard(() async {
    // `insert().select()` kullanılamaz: sahiplik satırı AFTER trigger'da
    // eklendiği için RETURNING anında SELECT politikası henüz geçmiyor.
    final id = const Uuid().v4();
    await _client.from('medreses').insert({
      'id': id,
      'name': name.trim(),
      'description': description.trim(),
    });
    final row = await _client
        .from('medreses')
        .select('id, name, description, invite_code')
        .eq('id', id)
        .single();
    return Medrese.fromJson(row, MemberRole.owner.name);
  });

  /// Davet koduyla öğrenci olarak katılır; medrese kimliğini döner.
  Future<Result<String, AppFailure>> join(String code) => _guard(() async {
    final id = await _client.rpc<String>(
      'join_medrese',
      params: {'code': code.trim()},
    );
    return id;
  });

  Future<Result<T, AppFailure>> _guard<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on PostgrestException catch (e) {
      return Err(switch (e.message) {
        'invalid invite code' => const ValidationFailure(
          'Bu kodla bir medrese bulunamadı.',
          field: 'code',
        ),
        _ => UnexpectedFailure(e.message),
      });
    } on Exception catch (e, st) {
      return Err(ExceptionMapper.fromException(e, st));
    }
  }
}
