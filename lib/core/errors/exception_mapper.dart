import 'package:e_medrese/core/errors/failures.dart';

/// Dio / http exception'larını [AppFailure]'a dönüştüren yardımcı.
///
/// Repository implementasyonlarında try-catch içinde kullanın:
/// ```dart
/// Future<Result<User, AppFailure>> getUser(String id) async {
///   try {
///     final response = await _dio.get('/users/$id');
///     return Ok(User.fromJson(response.data as Map<String, dynamic>));
///   } on Exception catch (e, st) {
///     return Err(ExceptionMapper.fromException(e, st));
///   }
/// }
/// ```
abstract final class ExceptionMapper {
  ExceptionMapper._();

  /// [Object] hatasını [AppFailure]'a çevirir.
  static AppFailure fromException(Object error, [StackTrace? stackTrace]) {
    return UnexpectedFailure(
      error.toString(),
      stackTrace: stackTrace,
    );
  }

  /// Bilinmeyen / beklenmeyen hatalar için.
  static AppFailure fromUnknown(Object error, StackTrace stackTrace) {
    return UnexpectedFailure(error.toString(), stackTrace: stackTrace);
  }
}
