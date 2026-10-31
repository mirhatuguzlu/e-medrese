import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _goldLight = Color(0xFFFFF3C4);
const _goldMid = Color(0xFFF2C94C);
const _goldDeep = Color(0xFFB8860B);
const _goldDark = Color(0xFF7A5208);
const _light = Color(0xFFFFE7A3);

/// Haftalık ödülün yıldızı.
///
/// [taps] arttıkça büyür, sallanır ve parlar. [open] olunca ışık saçarak
/// iyice büyür, kıvılcımlar dağılır, sonra söner; bitince [onOpened] çağrılır.
class StarView extends StatefulWidget {
  /// Yıldız.
  const StarView({
    required this.taps,
    required this.open,
    this.onOpened,
    super.key,
  });

  /// Şimdiye kadarki dokunuş sayısı.
  final int taps;

  /// Açılış animasyonu oynasın mı.
  final bool open;

  /// Açılış animasyonu bitince.
  final VoidCallback? onOpened;

  @override
  State<StarView> createState() => _StarViewState();
}

class _StarViewState extends State<StarView>
    with SingleTickerProviderStateMixin {
  static const _size = 220.0;

  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didUpdateWidget(StarView old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      unawaited(_c.forward().then((_) => widget.onOpened?.call()));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taps = widget.taps;
    return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final grow = Curves.easeOutBack.transform(
              const Interval(0, 0.5).transform(t),
            );
            final fade = const Interval(0.8, 1).transform(t);
            return SizedBox.square(
              dimension: _size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GlowPainter(
                        (0.15 + 0.2 * taps + 0.6 * t).clamp(0, 1) * (1 - fade),
                      ),
                    ),
                  ),
                  if (t > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RaysPainter(
                          const Interval(0.1, 0.9).transform(t),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 1 - fade,
                      child: Transform.scale(
                        scale: 1 + 0.12 * taps + 0.6 * grow,
                        child: const CustomPaint(painter: _StarPainter()),
                      ),
                    ),
                  ),
                  if (t > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SparksPainter(
                          const Interval(0.25, 1).transform(t),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        )
        // Her dokunuşta yeniden, öncekinden sert sallanır.
        .animate(key: ValueKey(taps))
        .shake(
          hz: 5 + 2.0 * taps,
          rotation: 0.03 + 0.02 * taps,
          duration: 400.ms,
        )
        .scaleXY(begin: 0.92, end: 1, duration: 200.ms);
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.glow);

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _light.withValues(alpha: glow * 0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.glow != glow;
}

/// Beş köşeli, köşeleri kabartmalı altın yıldız.
class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width * 0.36;
    final inner = outer * 0.45;
    final points = [
      for (var k = 0; k < 10; k++)
        c +
            Offset.fromDirection(
              -math.pi / 2 + k * math.pi / 5,
              k.isEven ? outer : inner,
            ),
    ];
    final star = Path()..addPolygon(points, true);

    canvas.drawShadow(star, _goldDark, 8, false);
    // Her kolun bir yarısı aydınlık, öbür yarısı gölgede: kabartma etkisi.
    for (var k = 0; k < 10; k++) {
      final facet = Path()
        ..addPolygon([c, points[k], points[(k + 1) % 10]], true);
      canvas.drawPath(
        facet,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: k.isEven
                ? const [_goldLight, _goldMid]
                : const [_goldMid, _goldDeep],
          ).createShader(facet.getBounds()),
      );
    }
    canvas
      ..drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = _goldDark,
      )
      ..drawCircle(
        c.translate(-outer * 0.2, -outer * 0.25),
        outer * 0.12,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

/// Açılışta dönerek uzayan ışık huzmeleri.
class _RaysPainter extends CustomPainter {
  const _RaysPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    if (p <= 0 || p >= 1) return;
    final c = size.center(Offset.zero);
    final length = size.width * (0.4 + 1.2 * Curves.easeOut.transform(p));
    final alpha = math.sin(math.pi * p);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          _light.withValues(alpha: alpha),
          _light.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: length));
    for (var k = 0; k < 12; k++) {
      final a = k * math.pi / 6 + p * 0.8;
      canvas.drawPath(
        Path()..addPolygon([
          c + Offset.fromDirection(a - 0.08, 20),
          c + Offset.fromDirection(a, length),
          c + Offset.fromDirection(a + 0.08, 20),
        ], true),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.progress != progress;
}

class _SparksPainter extends CustomPainter {
  const _SparksPainter(this.progress);

  final double progress;

  static final List<({double angle, double speed, double size, bool white})>
  _sparks = () {
    final r = math.Random(7);
    return [
      for (var i = 0; i < 36; i++)
        (
          angle: r.nextDouble() * 2 * math.pi,
          speed: 120 + r.nextDouble() * 160,
          size: 2 + r.nextDouble() * 3,
          white: r.nextBool(),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress;
    if (p <= 0 || p >= 1) return;
    final origin = size.center(Offset.zero);
    for (final s in _sparks) {
      final pos =
          origin +
          Offset.fromDirection(s.angle, s.speed * Curves.easeOut.transform(p));
      final paint = Paint()
        ..color = (s.white ? Colors.white : _light).withValues(alpha: 1 - p)
        ..strokeWidth = 1.5;
      final r = s.size * (1 - p * 0.5);
      canvas.drawCircle(pos, r, paint);
      // Büyük kıvılcımlar yıldız gibi parlar.
      if (s.size > 4) {
        canvas
          ..drawLine(
            pos.translate(-r * 2.5, 0),
            pos.translate(r * 2.5, 0),
            paint,
          )
          ..drawLine(
            pos.translate(0, -r * 2.5),
            pos.translate(0, r * 2.5),
            paint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => old.progress != progress;
}
