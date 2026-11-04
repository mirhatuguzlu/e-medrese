import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// 2.9'da kaydedilen kurslar telefonda kaldı; sunucuya bir kez taşınır.
final legacySavedCoursesProvider = Provider<LegacySavedCourses>(
  (ref) => LegacySavedCourses(),
);

/// 2.9'un `saved_courses` Hive kutusu: anahtar `<kullanıcı>:<kurs>`, değer
/// kaydetme zamanı (ms).
class LegacySavedCourses {
  static const _box = 'saved_courses';

  /// [user]ın telefondaki kayıtları: kurs → kaydetme zamanı.
  Future<Map<String, DateTime>> read(String user) async {
    if (!await Hive.boxExists(_box)) return const {};
    final box = await Hive.openBox<int>(_box);
    return {
      for (final key in box.keys.whereType<String>())
        if (key.startsWith('$user:'))
          key.substring(user.length + 1): DateTime.fromMillisecondsSinceEpoch(
            box.get(key) ?? 0,
          ),
    };
  }

  /// [user]ın kayıtlarını siler; kutu boşalınca dosyası da silinir.
  Future<void> remove(String user) async {
    if (!await Hive.boxExists(_box)) return;
    final box = await Hive.openBox<int>(_box);
    await box.deleteAll(
      box.keys.whereType<String>().where((k) => k.startsWith('$user:')),
    );
    if (box.isEmpty) await box.deleteFromDisk();
  }
}
