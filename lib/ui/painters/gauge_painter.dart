import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../theme.dart';

/// The lift's load dial. Zones only, never numbers.
///
/// The dial spans 0 → 1.15 of capacity over a half circle: grey to 75%,
/// green to 100%, red past it. [fraction] is the needle; [ghost] is the
/// dashed Scale-booster preview.
class GaugePainter extends CustomPainter {
  const GaugePainter({required this.fraction, this.ghost});

  final double fraction;
  final double? ghost;

  static const double span = 1.15;

  @override
  void paint(Canvas canvas, Size size) {
    // Design box 120 × 72, pivot at (60, 64), radius 46.
    final s = math.min(size.width / 120, size.height / 72);
    canvas
      ..save()
      ..translate((size.width - 120 * s) / 2, (size.height - 72 * s) / 2)
      ..scale(s);
    const center = Offset(60, 64);
    final rect = Rect.fromCircle(center: center, radius: 46);
    double angle(double f) => math.pi + math.pi * (f.clamp(0, span) / span);
    void arc(double f0, double f1, Color c) => canvas.drawArc(
          rect,
          angle(f0),
          angle(f1) - angle(f0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 13
            ..color = c,
        );
    arc(0, Formulas.greenFraction, LL.rule);
    arc(Formulas.greenFraction, 1, LL.mint);
    arc(1, span, LL.alarm);

    Offset tip(double f, double r) {
      final a = angle(f);
      return center + Offset(math.cos(a) * r, math.sin(a) * r);
    }

    final g = ghost;
    if (g != null) {
      final dash = Paint()
        ..color = LL.brass
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final end = tip(g, 42);
      const segments = 6;
      for (var i = 0; i < segments; i++) {
        final t0 = i / segments, t1 = (i + 0.55) / segments;
        canvas.drawLine(Offset.lerp(center, end, t0)!, Offset.lerp(center, end, t1)!, dash);
      }
    }

    canvas.drawLine(
      center,
      tip(fraction, 44),
      Paint()
        ..color = LL.cream
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 7, Paint()..color = LL.cream);
    canvas.drawCircle(center, 3, Paint()..color = LL.facade);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GaugePainter old) => old.fraction != fraction || old.ghost != ghost;
}
