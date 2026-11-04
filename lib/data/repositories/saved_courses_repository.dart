import 'dart:async';

import 'package:e_medrese/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Kaydedilen kursların Hive kutusu; `main` açar.
const savedCoursesBox = 'saved_courses';

/// Kullanıcının kaydettiği kurslar, en son kaydedilen başta.
final savedCoursesProvider =
    NotifierProvider<SavedCoursesNotifier, List<String>>(
      SavedCoursesNotifier.new,
    );

/// Kaydedilen kurslar yalnız bu cihazda saklanır, sunucuya gitmez (hangi
/// dini kursla ilgilendiği özel nitelikli veri olabilir). Anahtar
/// `<kullanıcı>:<kurs>`, değer kaydetme zamanı (ms). Kutu açık değilse (ör.
/// testler) yalnız bellekte tutulur.
class SavedCoursesNotifier extends Notifier<List<String>> {
  String? _user;

  static Box<int>? get _box =>
      Hive.isBoxOpen(savedCoursesBox) ? Hive.box<int>(savedCoursesBox) : null;

  @override
  List<String> build() {
    _user = ref.watch(sessionProvider.select((s) => s.valueOrNull?.user.id));
    final box = _box;
    final user = _user;
    if (box == null || user == null) return const [];
    final prefix = '$user:';
    final entries = [
      for (final key in box.keys.whereType<String>())
        if (key.startsWith(prefix))
          MapEntry(key.substring(prefix.length), box.get(key) ?? 0),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in entries) e.key];
  }

  /// [courseId] kaydedilmişse çıkarır, değilse kaydeder.
  void toggle(String courseId) {
    final user = _user;
    if (user == null) return;
    final key = '$user:$courseId';
    if (state.contains(courseId)) {
      state = [...state]..remove(courseId);
      unawaited(_box?.delete(key));
    } else {
      state = [courseId, ...state];
      unawaited(_box?.put(key, DateTime.now().millisecondsSinceEpoch));
    }
  }

  /// [user]ın bu cihazdaki kayıtlarını siler (hesap silinince).
  static Future<void> clearUser(String user) async {
    final box = _box;
    if (box == null) return;
    await box.deleteAll(
      box.keys.whereType<String>().where((k) => k.startsWith('$user:')),
    );
  }
}
