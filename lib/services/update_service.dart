import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Yeni sürümün indirildiği adres.
const latestApkUrl =
    'https://github.com/mirhatuguzlu/e-medrese/releases/latest/download/e-medrese.apk';

const _latestReleaseApi =
    'https://api.github.com/repos/mirhatuguzlu/e-medrese/releases/latest';

/// GitHub'da bu uygulamadan yeni bir sürüm varsa `true`. Kontrol
/// yapılamazsa (ağ yok, GitHub yanıt vermedi) `false`: kullanıcı çevrimdışı
/// diye kilitlenmez.
final updateRequiredProvider = FutureProvider<bool>((ref) async {
  try {
    final res = await http
        .get(Uri.parse(_latestReleaseApi))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return false;
    final release = jsonDecode(res.body) as Map<String, dynamic>;
    // APK henüz yüklenmediyse indirme adresi 404 verir; zorlanmaz.
    final hasApk = (release['assets'] as List<dynamic>).any(
      (a) => (a as Map<String, dynamic>)['name'] == 'e-medrese.apk',
    );
    final installed = (await PackageInfo.fromPlatform()).version;
    return hasApk && isNewerVersion(release['tag_name'] as String, installed);
  } on Exception {
    return false;
  }
});

/// [latest] (`v2.4.0` ya da `2.4.0`) [installed]'dan yeni mi.
bool isNewerVersion(String latest, String installed) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp('^v'), '')
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final a = parts(latest);
  final b = parts(installed);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
