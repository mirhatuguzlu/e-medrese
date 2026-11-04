import 'package:intl/intl.dart';

final _format = DateFormat('dd.MM.yyyy HH:mm');

/// Akışlarda gösterilen tarih: `28.10.2026 14:05`.
String formatDateTime(DateTime value) => _format.format(value);

/// Ad boşsa gösterilen yedek.
String displayName(String name) => name.isEmpty ? 'İsimsiz' : name;

const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// Kısa tarih: `28.10`.
String formatShortDate(DateTime day) => DateFormat('dd.MM').format(day);

/// Görev günleri: `28.10 Salı`.
String formatDay(DateTime day) =>
    '${formatShortDate(day)} ${_weekdays[day.weekday - 1]}';

/// Puan: tam sayıysa küsuratsız (`25`), değilse virgülden sonra 2 basamak
/// (`7,14`).
String formatPoints(num value) {
  final hundredths = (value * 100).round();
  if (hundredths % 100 == 0) return '${hundredths ~/ 100}';
  return (hundredths / 100).toStringAsFixed(2).replaceAll('.', ',');
}

/// Toplam süre: "1 sa 20 dk", "12 dk"; bir dakikadan kısaysa "1 dk".
String formatLength(int seconds) {
  final minutes = (seconds / 60).ceil();
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m == 0 ? 1 : m} dk';
  return m == 0 ? '$h sa' : '$h sa $m dk';
}

/// Oynatıcı saati: "3:07", "1:03:07".
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h == 0 ? '$m:$s' : '$h:${m.toString().padLeft(2, '0')}:$s';
}
