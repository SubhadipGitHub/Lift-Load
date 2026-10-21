/// The lift cabin's interior and its sliding doors. Pure decoration: nothing
/// here depends on who is riding or how heavy they are.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Brushed-steel walls, a warm light strip, a handrail and the floor.
class CabinInteriorPainter extends CustomPainter {
  const CabinInteriorPainter({this.alarm = false});

  /// Crash: the interior light turns red.
  final bool alarm;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9ECF1), LL.steel, Color(0xFFC3C8D0)],
        ).createShader(rect),
    );
    // Brushed grain: faint vertical lines.
    final grain = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var x = 3.0; x < w; x += 6) {
      canvas.drawLine(Offset(x, h * 0.08), Offset(x, h * 0.92), grain);
    }
    // Back-wall panel seams.
    final seam = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.2;
    canvas
      ..drawLine(Offset(w / 3, h * 0.1), Offset(w / 3, h * 0.92), seam)
      ..drawLine(Offset(w * 2 / 3, h * 0.1), Offset(w * 2 / 3, h * 0.92), seam);
    // Ceiling light strip and its glow.
    final light = alarm ? const Color(0xFFFF6B6B) : const Color(0xFFFFF3C4);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.32),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light.withValues(alpha: 0.55), light.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.32)),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.18, h * 0.015, w * 0.82, h * 0.045, const Radius.circular(3)),
      Paint()..color = light,
    );
    // Handrail at hip height.
    final railY = h * 0.6;
    canvas
      ..drawLine(
        Offset(w * 0.06, railY),
        Offset(w * 0.94, railY),
        Paint()
          ..color = const Color(0xFF8E96A3)
          ..strokeWidth = h * 0.022
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        Offset(w * 0.06, railY - h * 0.006),
        Offset(w * 0.94, railY - h * 0.006),
        Paint()
          ..color = const Color(0x88FFFFFF)
          ..strokeWidth = h * 0.006
          ..strokeCap = StrokeCap.round,
      );
    // Floor with a tread pattern.
    final floorTop = h * 0.9;
    canvas.drawRect(Rect.fromLTRB(0, floorTop, w, h), Paint()..color = LL.steelFloor);
    final tread = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;
    for (var x = 4.0; x < w; x += 8) {
      canvas.drawLine(Offset(x, floorTop + 2), Offset(x + 4, h - 2), tread);
    }
  }

  @override
  bool shouldRepaint(CabinInteriorPainter old) => old.alarm != alarm;
}

/// Two steel door leaves. [open] is 0 (closed) to 1 (fully open).
class CabinDoorsPainter extends CustomPainter {
  const CabinDoorsPainter({required this.open});

  final double open;

  @override
  void paint(Canvas canvas, Size size) {
    if (open >= 1) return;
    final w = size.width, h = size.height;
    final leaf = w / 2 * (1 - open.clamp(0.0, 1.0));
    if (leaf <= 0.5) return;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB7BEC9), Color(0xFFDDE1E7), Color(0xFFA9B0BC)],
        stops: [0, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, 0, w / 2, h));
    final edge = Paint()
      ..color = const Color(0xFF6B7380)
      ..strokeWidth = 1.5;
    for (final left in [true, false]) {
      final r = left ? Rect.fromLTWH(0, 0, leaf, h) : Rect.fromLTWH(w - leaf, 0, leaf, h);
      canvas.drawRect(r, paint);
      final x = left ? r.right : r.left;
      canvas.drawLine(Offset(x, 0), Offset(x, h), edge);
      // A narrow vision panel in each leaf.
      final pw = leaf * 0.22, px = left ? r.right - leaf * 0.45 : r.left + leaf * 0.23;
      if (pw > 2) {
        canvas.drawRRect(
          RRect.fromLTRBR(px, h * 0.16, px + pw, h * 0.5, const Radius.circular(2)),
          Paint()..color = const Color(0x553A4A5E),
        );
      }
    }
  }

  @override
  bool shouldRepaint(CabinDoorsPainter old) => old.open != open;
}
