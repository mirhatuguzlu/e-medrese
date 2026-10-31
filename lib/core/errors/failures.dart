/// Uygulama genelindeki hataların base sınıfı.
///
/// Tüm özel hata tipleri bu sınıftan türetilmelidir.
/// Exception throw etmek yerine Result.Err içinde kullanın.
sealed class AppFailure {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Genel ağ hatası.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// Sunucu kaynaklı hata (5xx).
final class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {required this.statusCode});

  final int statusCode;
}

/// Bağlantı yok.
final class ConnectionFailure extends AppFailure {
  const ConnectionFailure() : super('İnternet bağlantısı yok.');
}

/// İstek zaman aşımı.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure() : super('İstek zaman aşımına uğradı.');
}

/// Oturum açılmamış.
final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure() : super('Oturum açmanız gerekiyor.');
}

/// Yetkisiz erişim.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure() : super('Bu işlem için yetkiniz yok.');
}

/// Kayıt bulunamadı.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// Geçersiz veri / parse hatası.
final class ParseFailure extends AppFailure {
  const ParseFailure(super.message);
}

/// Önbellekte veri yok.
final class CacheFailure extends AppFailure {
  const CacheFailure(super.message);
}

/// Form / girdi doğrulama hatası.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.field});

  /// Hangi alana ait olduğu (opsiyonel).
  final String? field;
}

/// Hiçbir kategoriye girmeyen beklenmeyen hata.
/// Üretim kodunda bu tipin oluşmaması hedeflenmelidir.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(super.message, {this.stackTrace});

  final StackTrace? stackTrace;
}
