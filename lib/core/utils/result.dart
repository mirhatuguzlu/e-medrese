/// Dart 3 sealed class ile tip-güvenli sonuç tipi.
///
/// Happy-path anti-pattern'ini engellemek için tüm repository
/// ve use-case metotları `Result` döndürmelidir.
///
/// Kullanım:
/// ```dart
/// Future<Result<User, AppFailure>> getUser(String id);
///
/// final result = await getUser('123');
/// switch (result) {
///   case Ok(:final value):
///     // Başarı durumu — derleyici burayı zorlar
///   case Err(:final error):
///     // Hata durumu — atlanamaz
/// }
/// ```
sealed class Result<T, E> {
  const Result();
}

/// Başarılı sonuç — [value] içerir.
final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Başarısız sonuç — [error] içerir.
final class Err<T, E> extends Result<T, E> {
  const Err(this.error);

  final E error;

  @override
  String toString() => 'Err($error)';
}

/// `Result` üzerinde kolay kullanım için extension.
extension ResultX<T, E> on Result<T, E> {
  /// Başarılı ise true döner.
  bool get isOk => this is Ok<T, E>;

  /// Başarısız ise true döner.
  bool get isErr => this is Err<T, E>;

  /// Başarılı ise `Ok.value`'yu döner, aksi halde null.
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// Başarısız ise `Err.error`'u döner, aksi halde null.
  E? get errorOrNull => switch (this) {
    Ok() => null,
    Err(:final error) => error,
  };

  /// Başarılı ise `Ok.value`'yu döner, aksi halde [orElse]'yi döner.
  T valueOr(T orElse) => switch (this) {
    Ok(:final value) => value,
    Err() => orElse,
  };

  /// `Result` üzerinde dönüşüm uygular.
  Result<U, E> map<U>(U Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final error) => Err(error),
  };

  /// Hata üzerinde dönüşüm uygular.
  Result<T, F> mapError<F>(F Function(E error) transform) => switch (this) {
    Ok(:final value) => Ok(value),
    Err(:final error) => Err(transform(error)),
  };

  /// Başarılı ise [onOk], başarısız ise [onErr] çalıştırır.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(E error) onErr,
  }) => switch (this) {
    Ok(:final value) => onOk(value),
    Err(:final error) => onErr(error),
  };
}
