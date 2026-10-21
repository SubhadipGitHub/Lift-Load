/// The shaft panel's back wall: a venue-tinted gradient, a faint venue motif,
/// and the guide rails either side of the cabin's column.
library;

import 'package:flutter/material.dart';

import '../theme.dart';

class ShaftPainter extends CustomPainter {
  const ShaftPainter({required this.style, required this.railLeft, required this.railRight});

  final VenueStyle style;

  /// X positions of the cabin column's edges, where the rails run.
  final double railLeft;
  final double railRight;

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
          colors: [style.wallTop, style.wall, style.wallBottom],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    _motif(canvas, size);

    // The shaft itself: a darker channel behind the cabin.
    final shaft = Rect.fromLTRB(railLeft - 6, 0, railRight + 6, h);
    canvas.drawRect(shaft, Paint()..color = const Color(0x33000000));
    final rail = Paint()
      ..color = const Color(0xFF8F8AC4).withValues(alpha: 0.55)
      ..strokeWidth = 3;
    final shine = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 1;
    for (final x in [railLeft - 3, railRight + 3]) {
      canvas
        ..drawLine(Offset(x, 0), Offset(x, h), rail)
        ..drawLine(Offset(x - 1, 0), Offset(x - 1, h), shine);
      // Rail brackets.
      for (var y = 18.0; y < h; y += 46) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 9, height: 3), rail);
      }
    }
    // Soft vignette at the bottom so the panel sits on the lobby.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x33000000)],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );
  }

  void _motif(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final faint = Paint()..color = style.accent.withValues(alpha: 0.10);
    final line = Paint()
      ..color = style.accent.withValues(alpha: 0.10)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    switch (style.motif) {
      case WallMotif.windows:
        // A grid of lit and unlit flat windows.
        for (var y = 14.0; y < h - 20; y += 34) {
          for (var x = 10.0; x < w - 10; x += 30) {
            final lit = ((x * 7 + y * 3) ~/ 10).isEven;
            canvas.drawRRect(
              RRect.fromLTRBR(x, y, x + 16, y + 20, const Radius.circular(2)),
              Paint()..color = (lit ? const Color(0xFFFFD98A) : style.accent).withValues(alpha: lit ? 0.13 : 0.05),
            );
          }
        }
      case WallMotif.mullions:
        for (var x = 0.0; x < w; x += 26) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), line);
        }
        canvas.drawLine(Offset(0, h * 0.35), Offset(w, h * 0.35), line);
      case WallMotif.signStripe:
        canvas.drawRect(Rect.fromLTWH(0, h * 0.18, w, h * 0.05), faint);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.26, w, h * 0.012), faint);
        for (var x = 16.0; x < w; x += 64) {
          canvas.drawPath(
            Path()
              ..moveTo(x, h * 0.205)
              ..lineTo(x + 10, h * 0.205)
              ..lineTo(x + 10, h * 0.19)
              ..lineTo(x + 18, h * 0.205)
              ..lineTo(x + 10, h * 0.22)
              ..lineTo(x + 10, h * 0.205),
            Paint()..color = style.accent.withValues(alpha: 0.22),
          );
        }
      case WallMotif.awnings:
        for (var x = 0.0; x < w; x += 40) {
          final awning = Path()
            ..moveTo(x, h * 0.1)
            ..lineTo(x + 36, h * 0.1)
            ..lineTo(x + 32, h * 0.17)
            ..quadraticBezierTo(x + 18, h * 0.21, x + 4, h * 0.17)
            ..close();
          canvas.drawPath(awning, Paint()..color = style.accent.withValues(alpha: ((x ~/ 40).isEven) ? 0.14 : 0.07));
        }
      case WallMotif.wallpaper:
        var row = 0;
        for (var y = 10.0; y < h; y += 22, row++) {
          for (var x = row.isEven ? 8.0 : 19.0; x < w; x += 22) {
            canvas.drawCircle(Offset(x, y), 2.2, faint);
          }
        }
        // Wall sconces.
        for (final x in [w * 0.12, w * 0.88]) {
          canvas.drawCircle(
            Offset(x, h * 0.22),
            14,
            Paint()
              ..color = const Color(0x33FFD98A)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }
    }
  }

  @override
  bool shouldRepaint(ShaftPainter old) => old.style != style || old.railLeft != railLeft || old.railRight != railRight;
}
