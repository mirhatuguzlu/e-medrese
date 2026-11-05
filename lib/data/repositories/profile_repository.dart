import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:e_medrese/data/repositories/supabase_guard.dart';
import 'package:e_medrese/domain/entities/profile.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uygulama genelindeki [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(Supabase.instance.client),
);

/// Giriş yapmış kullanıcının profili; kullanıcı değişince yeniden okunur.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final id = ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
  if (id == null) return null;
  return switch (await ref.watch(profileRepositoryProvider).profile(id)) {
    Ok(:final value) => value,
    // AppFailure Exception değil; hata zinciri Exception bekliyor.
    Err(:final error) => throw Exception(error.message),
  };
});

/// Ad soyad ve profil fotoğrafı.
class ProfileRepository {
  /// Supabase istemcisiyle oluşturur.
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'avatars';

  String get _me => _client.auth.currentUser!.id;

  /// [userId]'nin profili.
  Future<Result<Profile, AppFailure>> profile(String userId) =>
      guardSupabase(() async {
        final row = await _client
            .from('profiles')
            .select('full_name, avatar_url, created_at')
            .eq('id', userId)
            .single();
        return Profile.fromJson(row);
      });

  /// Adı değiştirir. Google girişte hesap verisini yeniden yazdığı için ad
  /// `profiles`'tan okunur; hesap verisi de aynı kalsın diye güncellenir.
  Future<Result<void, AppFailure>> updateName(String name) => guardSupabase(
    () async {
      await _client.from('profiles').update({'full_name': name}).eq('id', _me);
      await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
    },
  );

  /// [bytes]'ı ([extension]: jpg, png ya da webp) yeni fotoğraf yapar,
  /// eskisini siler.
  Future<Result<void, AppFailure>> uploadPhoto(
    Uint8List bytes, {
    required String extension,
  }) => guardSupabase(() async {
    // Her yüklemede yeni ad: önbellekteki eski fotoğraf gösterilmesin.
    final path = '$_me/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: extension == 'jpg' ? 'image/jpeg' : 'image/$extension',
          ),
        );
    await _client.from('profiles').update({'avatar_url': path}).eq('id', _me);
    await _removeFiles(except: path);
  });

  /// Fotoğrafı kaldırır.
  Future<Result<void, AppFailure>> removePhoto() => guardSupabase(() async {
    await _client.from('profiles').update({'avatar_url': null}).eq('id', _me);
    await _removeFiles();
  });

  Future<void> _removeFiles({String? except}) async {
    final files = await _client.storage.from(_bucket).list(path: _me);
    final paths = [
      for (final f in files)
        if ('$_me/${f.name}' != except) '$_me/${f.name}',
    ];
    if (paths.isNotEmpty) await _client.storage.from(_bucket).remove(paths);
  }

  /// [path]'teki fotoğraf; oturum belirteciyle indirilir (kova özel).
  ImageProvider photo(String path) => CachedNetworkImageProvider(
    '${_client.storage.url}/object/authenticated/$_bucket/$path',
    // Belirteç değişse de aynı fotoğraf önbellekten gelsin.
    cacheKey: path,
    headers: {
      'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken}',
    },
  );
}
