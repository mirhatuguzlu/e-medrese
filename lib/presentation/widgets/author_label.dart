import 'package:e_medrese/core/core.dart';
import 'package:e_medrese/data/repositories/medrese_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// İçeriği yazanın adı; medreseden ayrıldıysa bunu da belirtir.
///
/// Üye listesi henüz yüklenmediyse yalnızca adı döner.
String authorLabel(
  WidgetRef ref, {
  required String medreseId,
  required String authorId,
  required String name,
}) {
  final isFormer = switch (ref.watch(membersProvider(medreseId))) {
    AsyncData(value: Ok(:final value)) => !value.any(
      (m) => m.userId == authorId,
    ),
    _ => false,
  };
  return isFormer
      ? '${displayName(name)} (artık bu medresede değil)'
      : displayName(name);
}
