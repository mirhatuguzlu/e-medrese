import 'package:e_medrese/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `FutureProvider<Result<List<T>, AppFailure>>` için yükleniyor / hata / boş /
/// liste görünümü. Liste aşağı çekilince [onRefresh] çağrılır.
class ResultListView<T> extends StatelessWidget {
  /// Liste görünümü.
  const ResultListView({
    required this.value,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyText,
    required this.itemBuilder,
    this.separated = true,
    this.header,
    super.key,
  });

  /// Sağlayıcının değeri.
  final AsyncValue<Result<List<T>, AppFailure>> value;

  /// Yeniden yükler.
  final Future<void> Function() onRefresh;

  /// Liste boşken gösterilen ikon.
  final IconData emptyIcon;

  /// Liste boşken gösterilen metin.
  final String emptyText;

  /// Satır.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Satırlar arasında çizgi olsun mu.
  final bool separated;

  /// Liste doluyken satırlardan önce çizilen içerik.
  final Widget Function(List<T> items)? header;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(value: Ok(value: final items)) when items.isNotEmpty =>
        RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length + (header == null ? 0 : 1),
            separatorBuilder: (_, i) => separated && (header == null || i > 0)
                ? const Divider(height: 1)
                : const SizedBox.shrink(),
            itemBuilder: (context, i) => header == null
                ? itemBuilder(context, items[i])
                : i == 0
                ? header!(items)
                : itemBuilder(context, items[i - 1]),
          ),
        ),
      AsyncData(value: Ok()) => _Message(
        icon: emptyIcon,
        text: emptyText,
        onRefresh: onRefresh,
      ),
      AsyncData(value: Err(:final error)) => _Message(
        icon: Icons.error_outline,
        text: error.message,
        onRefresh: onRefresh,
        retry: true,
      ),
      AsyncError(:final error) => _Message(
        icon: Icons.error_outline,
        text: error.toString(),
        onRefresh: onRefresh,
        retry: true,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.onRefresh,
    this.retry = false,
  });

  final IconData icon;
  final String text;
  final Future<void> Function() onRefresh;
  final bool retry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (retry) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Tekrar dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
