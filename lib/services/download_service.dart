import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Uygulama genelindeki [DownloadService].
final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(Dio()),
);

/// Dosyayı telefonun İndirilenler klasörüne (Download/e-Medrese) indirir.
class DownloadService {
  /// [Dio] ile oluşturur.
  DownloadService(this._dio);

  final Dio _dio;

  // shortcut: Android'in ortak İndirilenler yolu sabit; Android dışına
  // çıkılırsa path_provider ile platforma göre seç.
  static const _folder = '/storage/emulated/0/Download/e-Medrese';

  /// [url]'deki dosyayı [name] adıyla indirir; kaydedilen yolu döner.
  /// Aynı adda dosya varsa adın sonuna (1), (2)… eklenir.
  Future<String> download(
    String url, {
    required String name,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _save(url, name, headers);
    } on FileSystemException {
      // Android 9 ve öncesi ortak klasöre yazmak için izin ister.
      if (!await Permission.storage.request().isGranted) rethrow;
      return _save(url, name, headers);
    }
  }

  Future<String> _save(
    String url,
    String name,
    Map<String, String> headers,
  ) async {
    await Directory(_folder).create(recursive: true);
    // Ad sunucudan gelir; klasör dışına yazılmasın.
    final safe = name.replaceAll(RegExp(r'[/\\]|^\.+'), '_');
    final path = uniquePath(safe, (p) => File('$_folder/$p').existsSync());
    await _dio.download(
      url,
      '$_folder/$path',
      options: Options(headers: headers),
    );
    return '$_folder/$path';
  }
}

/// [name] alınmışsa ([taken]) "ad (1).uzantı", "ad (2).uzantı"… döner.
String uniquePath(String name, bool Function(String) taken) {
  if (!taken(name)) return name;
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var i = 1; ; i++) {
    final candidate = '$base ($i)$ext';
    if (!taken(candidate)) return candidate;
  }
}
