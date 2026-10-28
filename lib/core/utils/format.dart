import 'package:intl/intl.dart';

final _format = DateFormat('dd.MM.yyyy HH:mm');

/// Akışlarda gösterilen tarih: `28.10.2026 14:05`.
String formatDateTime(DateTime value) => _format.format(value);

/// Ad boşsa gösterilen yedek.
String displayName(String name) => name.isEmpty ? 'İsimsiz' : name;
