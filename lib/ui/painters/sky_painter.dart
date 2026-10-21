/// The home-screen sky behind the skyline: a venue-tinted gradient, a moon,
/// a scatter of stars and a few clouds. [drift] (0–1, wrapping) slides the
/// clouds; [twinkle] (0–1) pulses the stars. Both stay 0 under reduce-motion.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class SkyPainter extends CustomPainter {
  const SkyPainter({required this.style, this.drift = 0, this.twinkle = 0});

  final VenueStyle style;
  final double drift;
  final double twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.skyTop, style.skyBottom, LL.night],
          stops: const [0, 0.62, 1],
        ).createShader(rect),
    );
    // Stars: a fixed scatter so every frame matches.
    final rng = math.Random(17);
    for (var i = 0; i < 40; i++) {
      final x = rng.nextDouble() * w, y = rng.nextDouble() * h * 0.55;
      final r = 0.6 + rng.nextDouble() * 1.2;
      final pulse = 0.35 + 0.45 * (0.5 + 0.5 * math.sin((twinkle + i / 40) * 2 * math.pi));
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: pulse));
    }
    // Moon with a soft halo.
    // Left of centre and below the title, so it never sits behind the text.
    final moon = Offset(w * 0.14, h * 0.3);
    final mr = math.min(w, h) * 0.035 + 8;
    canvas
      ..drawCircle(
        moon,
        mr * 2.2,
        Paint()
          ..color = const Color(0x22FFF4E2)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, mr),
      )
      ..drawCircle(moon, mr, Paint()..color = const Color(0xFFFFF1CF))
      ..drawCircle(
          moon + Offset(mr * 0.35, -mr * 0.2), mr * 0.78, Paint()..color = style.skyTop.withValues(alpha: 0.55));
    // Clouds drift right and wrap around.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (final (i, (y, scale)) in [(0.18, 1.0), (0.32, 0.7), (0.08, 0.55)].indexed) {
      final x = ((drift + i * 0.37) % 1.0) * (w + 160) - 80;
      final cy = h * y;
      final s = scale * math.min(w, 600) / 6;
      canvas
        ..drawOval(Rect.fromCenter(center: Offset(x, cy), width: s * 1.6, height: s * 0.5), cloud)
        ..drawOval(Rect.fromCenter(center: Offset(x + s * 0.3, cy - s * 0.15), width: s, height: s * 0.5), cloud);
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.style != style || old.drift != drift || old.twinkle != twinkle;
}
