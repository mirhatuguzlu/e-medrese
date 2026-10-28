import 'package:flutter/material.dart';

/// [BuildContext] kısayolları.
extension BuildContextX on BuildContext {
  /// Önceki mesajı kapatıp alt tarafta [message] gösterir.
  void showMessage(String message) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// [page]'i yeni sayfa olarak açar.
  Future<void> push(Widget page) =>
      Navigator.of(this).push(MaterialPageRoute<void>(builder: (_) => page));
}
