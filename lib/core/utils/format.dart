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
