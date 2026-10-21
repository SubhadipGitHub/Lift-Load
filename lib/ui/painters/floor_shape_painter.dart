import 'package:flutter/material.dart';

import '../theme.dart';

/// Draws a floor's shape in a 12×12 design box, scaled to the paint size.
class FloorShapePainter extends CustomPainter {
  const FloorShapePainter(this.shape, this.color);

  final FloorShape shape;
  final Color color;

  static Path pathFor(FloorShape shape) {
    final p = Path();
    switch (shape) {
      case FloorShape.circle:
        p.addOval(Rect.fromCircle(center: const Offset(6, 6), radius: 5));
      case FloorShape.triangle:
        p
          ..moveTo(6, 1)
          ..lineTo(11, 11)
          ..lineTo(1, 11)
          ..close();
      case FloorShape.square:
        p.addRect(const Rect.fromLTWH(2, 2, 8, 8));
      case FloorShape.diamond:
        p
          ..moveTo(6, 0.5)
          ..lineTo(11.5, 6)
          ..lineTo(6, 11.5)
          ..lineTo(0.5, 6)
          ..close();
      case FloorShape.hexagon:
        p
          ..moveTo(3, 1)
          ..lineTo(9, 1)
          ..lineTo(12, 6)
          ..lineTo(9, 11)
          ..lineTo(3, 11)
          ..lineTo(0, 6)
          ..close();
      case FloorShape.plus:
        p
          ..moveTo(4, 0.5)
          ..lineTo(8, 0.5)
          ..lineTo(8, 4)
          ..lineTo(11.5, 4)
          ..lineTo(11.5, 8)
          ..lineTo(8, 8)
          ..lineTo(8, 11.5)
          ..lineTo(4, 11.5)
          ..lineTo(4, 8)
          ..lineTo(0.5, 8)
          ..lineTo(0.5, 4)
          ..lineTo(4, 4)
          ..close();
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 12;
    canvas
      ..save()
      ..translate((size.width - 12 * s) / 2, (size.height - 12 * s) / 2)
      ..scale(s);
    canvas.drawPath(pathFor(shape), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FloorShapePainter old) => old.shape != shape || old.color != color;
}
