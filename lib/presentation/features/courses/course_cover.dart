import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 16:9 kurs ya da ders kapağı; görsel yoksa ya da yüklenemezse renkli
/// zemin ve simge.
class CourseCover extends StatelessWidget {
  /// [url] kapağı.
  const CourseCover({required this.url, this.radius = 16, super.key});

  /// Görsel adresi (boş olabilir).
  final String url;

  /// Köşe yuvarlaklığı.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: scheme.surfaceContainer),
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

/// Kapağın üstüne yazılan küçük etiket (kategori, süre).
class CoverBadge extends StatelessWidget {
  /// [label] etiketi; [icon] varsa önünde.
  const CoverBadge({required this.label, this.icon, super.key});

  /// Yazı.
  final String label;

  /// Simge.
  final IconData? icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
