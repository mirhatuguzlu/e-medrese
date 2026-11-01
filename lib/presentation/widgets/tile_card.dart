import 'package:e_medrese/core/core.dart';
import 'package:flutter/material.dart';

/// Kartları ekran genişliğine göre dizer: telefonda 2, genişledikçe 3–4
/// sütun. Kaydırılan bir listenin içinde kullanılır.
class TileGrid extends StatelessWidget {
  /// Kart ızgarası.
  const TileGrid({required this.children, super.key});

  /// Kartlar.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: (constraints.maxWidth / 180).floor().clamp(2, 4),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// Büyük simge, altında başlık ve kısa açıklama olan kart.
class TileCard extends StatelessWidget {
  /// Kart; [onTap] dokununca açılır.
  const TileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  /// [page]'i açan kart.
  TileCard.page({
    required this.icon,
    required this.title,
    required this.subtitle,
    required Widget page,
    super.key,
  }) : onTap = ((context) => context.push(page));

  /// Büyük simge (ör. Icon ya da CircleAvatar).
  final Widget icon;

  /// Başlık.
  final String title;

  /// Kısa açıklama.
  final String subtitle;

  /// Dokununca.
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(size: 44, color: theme.colorScheme.primary),
                child: icon,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
