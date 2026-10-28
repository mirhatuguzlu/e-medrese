import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/medrese.dart';
import 'package:e_medrese/domain/entities/member.dart';
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

/// Bir medresenin üyeleri.
final AutoDisposeFutureProviderFamily<Result<List<Member>, AppFailure>, String>
membersProvider = FutureProvider.autoDispose.family(
  (ref, medreseId) => ref.watch(medreseRepositoryProvider).members(medreseId),
);

/// Medrese listeleme, kurma, katılma ve üye yönetimi.
class MedreseRepository {
  /// Supabase istemcisiyle oluşturur.
  MedreseRepository(this._client);

  final SupabaseClient _client;

  /// [userId]'nin üyesi olduğu medreseler, ada göre sıralı.
  Future<Result<List<Medrese>, AppFailure>> myMedreses(String userId) =>
      guardSupabase(() async {
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
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
      });

  /// Yeni medrese kurar; kuran kişi sahibi olur.
  Future<Result<Medrese, AppFailure>> create({
    required String name,
    required String description,
  }) => guardSupabase(() async {
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
  Future<Result<String, AppFailure>> join(String code) => guardSupabase(
    () => _client.rpc<String>('join_medrese', params: {'code': code.trim()}),
  );

  /// Üyeler: önce kurucu ve hocalar, sonra ada göre.
  Future<Result<List<Member>, AppFailure>> members(String medreseId) =>
      guardSupabase(() async {
        final rows = await _client
            .from('medrese_members')
            .select('user_id, role, profiles(full_name)')
            .eq('medrese_id', medreseId);
        return rows.map(Member.fromJson).toList()..sort(
          (a, b) => a.role != b.role
              ? a.role.index.compareTo(b.role.index)
              : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      });

  /// Kayıtlı bir kullanıcıyı e-postasıyla medreseye ekler.
  Future<Result<void, AppFailure>> addMemberByEmail({
    required String medreseId,
    required String email,
    required MemberRole role,
  }) => guardSupabase(
    () => _client.rpc<void>(
      'add_member_by_email',
      params: {'m': medreseId, 'email': email.trim(), 'r': role.name},
    ),
  );

  /// Üyeyi medreseden çıkarır.
  Future<Result<void, AppFailure>> removeMember({
    required String medreseId,
    required String userId,
  }) => guardSupabase(() async {
    // RLS izin vermezse silme hata vermez, 0 satır döner.
    final deleted = await _client
        .from('medrese_members')
        .delete()
        .eq('medrese_id', medreseId)
        .eq('user_id', userId)
        .select('user_id');
    if (deleted.isEmpty) throw const PostgrestException(message: 'not allowed');
  });
}
