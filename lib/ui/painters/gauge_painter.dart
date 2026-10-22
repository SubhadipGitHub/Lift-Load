import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../theme.dart';

/// The lift's load dial. Zones only, never numbers.
///
/// The dial spans 0 → 1.15 of capacity over a half circle: grey to 75%,
/// green to 100%, red past it. [fraction] is the needle; [ghost] is the
/// dashed Scale-booster preview. Drawn to the style frame: a dark bed under
/// the arcs, a soft glow behind the zone the needle is in, a gloss line over
/// the arcs, and an outlined needle on a brass hub.
class GaugePainter extends CustomPainter {
  const GaugePainter({required this.fraction, this.ghost, this.glow = 0, this.glowColor = LL.mint, this.over = false});

  final double fraction;
  final double? ghost;

  /// 0–1: how strongly the zone under the needle glows. It follows the load
  /// already aboard (the caller passes the current zone), never the ghost and
  /// never a scale: the dial still has no ticks or numbers.
  final double glow;
  final Color glowColor;

  /// The load aboard is past the limit: the red zone glows, else the green.
  /// Taken from the engine's zone, not the springing needle, so an
  /// overshoot never flickers the glow into the next zone.
  final bool over;

  static const double span = 1.15;

  /// The arc that glows: the green zone, or the red one when [over].
  static (double, double) glowArc({required bool over}) => over ? (1.0, span) : (Formulas.greenFraction, 1.0);

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
    Paint stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = cap
      ..color = c;
    void arc(double f0, double f1, Paint p) => canvas.drawArc(rect, angle(f0), angle(f1) - angle(f0), false, p);

    // The dark bed the zones sit in.
    arc(0, span, stroke(LL.gaugeBed, 19, cap: StrokeCap.round));
    // The glow behind the needle's zone, under the zone colours.
    if (glow > 0) {
      final (f0, f1) = glowArc(over: over);
      arc(
        f0,
        f1,
        stroke(glowColor.withValues(alpha: 0.7 * glow.clamp(0, 1)), 22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    arc(0, Formulas.greenFraction, stroke(LL.gaugeGrey, 13));
    arc(Formulas.greenFraction, 1, stroke(LL.mint, 13));
    arc(1, span, stroke(LL.alarm, 13));
    // The gloss line along the top of the arcs.
    canvas.drawArc(Rect.fromCircle(center: center, radius: 49), math.pi, math.pi, false,
        stroke(LL.gaugeGloss, 2.5, cap: StrokeCap.round));

    Offset tip(double f, double r) {
      final a = angle(f);
      return center + Offset(math.cos(a) * r, math.sin(a) * r);
    }

    final g = ghost;
    if (g != null) {
      final dash = stroke(LL.brass, 3, cap: StrokeCap.round);
      final end = tip(g, 42);
      const segments = 6;
      for (var i = 0; i < segments; i++) {
        final t0 = i / segments, t1 = (i + 0.55) / segments;
        canvas.drawLine(Offset.lerp(center, end, t0)!, Offset.lerp(center, end, t1)!, dash);
      }
    }

    final needle = tip(fraction, 44);
    canvas
      ..drawLine(center, needle, stroke(LL.gaugeBed, 7.5, cap: StrokeCap.round))
      ..drawLine(center, needle, stroke(LL.creamHi, 4, cap: StrokeCap.round))
      ..drawCircle(center, 9, Paint()..color = LL.gaugeBed)
      ..drawCircle(center, 7, Paint()..color = LL.gaugeHub)
      ..drawCircle(center + const Offset(-2, -2), 2.4, Paint()..color = LL.creamHi)
      ..restore();
  }

  @override
  bool shouldRepaint(GaugePainter old) =>
      old.fraction != fraction ||
      old.ghost != ghost ||
      old.glow != glow ||
      old.glowColor != glowColor ||
      old.over != over;
}
