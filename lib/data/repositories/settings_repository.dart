import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `main`'de açılışta yüklenip verilir (ilk karede doğru tema görünsün).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main içinde override edilir'),
);

/// Telefonda tutulan görünüm ayarları.
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// Görünüm ayarları.
@immutable
final class AppSettings {
  /// Ayarlar.
  const AppSettings({this.themeMode = ThemeMode.system, this.textScale = 1});

  /// Açık, koyu ya da telefona uyan tema.
  final ThemeMode themeMode;

  /// Yazı büyüklüğü çarpanı; telefonun yazı boyutuyla çarpılır.
  final double textScale;
}

/// Ayarları okur ve kaydeder.
class SettingsNotifier extends Notifier<AppSettings> {
  static const _themeKey = 'theme_mode';
  static const _textScaleKey = 'text_scale';

  /// Seçilebilen yazı büyüklükleri.
  static const textScales = [0.85, 1.0, 1.15, 1.3];

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      themeMode:
          ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system,
      textScale: prefs.getDouble(_textScaleKey) ?? 1,
    );
  }

  /// Temayı değiştirir.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = AppSettings(themeMode: mode, textScale: state.textScale);
    await _prefs.setString(_themeKey, mode.name);
  }

  /// Yazı büyüklüğünü değiştirir.
  Future<void> setTextScale(double scale) async {
    state = AppSettings(themeMode: state.themeMode, textScale: scale);
    await _prefs.setDouble(_textScaleKey, scale);
  }
}
