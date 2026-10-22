/// Venue backgrounds: the lobby floor pattern under the lanes (or the
/// venue's painted floor), and one prop in the shaft corner. Kept faint so
/// residents always read on top.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A venue's painted lobby floor, cover-fitted and centred on the area it
/// fills. The image keeps the lane text's contrast on its own.
class LobbyFloorPainter extends CustomPainter {
  const LobbyFloorPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Size(image.width.toDouble(), image.height.toDouble());
    final fit = applyBoxFit(BoxFit.cover, src, size);
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fit.source, Offset.zero & src),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(LobbyFloorPainter old) => old.image != image;
}

class FloorPatternPainter extends CustomPainter {
  const FloorPatternPainter(this.style);

  final VenueStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = style.floorLine
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    switch (style.pattern) {
      case FloorPattern.tiles:
        for (var x = 0.0; x < size.width; x += 34) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
        }
        for (var y = 0.0; y < size.height; y += 34) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
      case FloorPattern.stone:
        var row = 0;
        for (var y = 0.0; y < size.height; y += 26, row++) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
          for (var x = row.isEven ? 0.0 : 30.0; x < size.width; x += 60) {
            canvas.drawLine(Offset(x, y), Offset(x, y + 26), line);
          }
        }
      case FloorPattern.stripes:
        final band = Paint()..color = style.floorLine;
        for (var y = 12.0; y < size.height; y += 44) {
          canvas.drawRect(Rect.fromLTWH(0, y, size.width, 6), band);
        }
      case FloorPattern.marble:
        for (var x = -size.height; x < size.width; x += 46) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
        }
      case FloorPattern.carpet:
        final dot = Paint()..color = style.floorLine;
        var row = 0;
        for (var y = 14.0; y < size.height; y += 28, row++) {
          for (var x = row.isEven ? 14.0 : 28.0; x < size.width; x += 28) {
            canvas.drawPath(
              Path()
                ..moveTo(x, y - 5)
                ..lineTo(x + 5, y)
                ..lineTo(x, y + 5)
                ..lineTo(x - 5, y)
                ..close(),
              dot,
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(FloorPatternPainter old) => old.style != style;
}

/// A small venue prop drawn in a 40 × 56 box.
class VenuePropPainter extends CustomPainter {
  const VenuePropPainter(this.style);

  final VenueStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 40, size.height / 56);
    final fill = Paint();
    switch (style.prop) {
      case VenueProp.plant:
        fill.color = const Color(0xFF3F8F5A);
        for (final (x, y, r) in [(20.0, 18.0, 9.0), (12.0, 24.0, 7.0), (28.0, 24.0, 7.0), (20.0, 28.0, 7.0)]) {
          canvas.drawCircle(Offset(x, y), r, fill);
        }
        fill.color = const Color(0xFFC0703A);
        canvas.drawPath(
            Path()..addPolygon(const [Offset(10, 34), Offset(30, 34), Offset(27, 54), Offset(13, 54)], true), fill);
      case VenueProp.cooler:
        fill.color = const Color(0xFF9FD3F0);
        canvas.drawRRect(RRect.fromLTRBR(13, 4, 27, 22, const Radius.circular(4)), fill);
        fill.color = const Color(0xFFDDE3EA);
        canvas.drawRRect(RRect.fromLTRBR(10, 22, 30, 54, const Radius.circular(3)), fill);
        fill.color = const Color(0xFF4F5B6B);
        canvas.drawRect(const Rect.fromLTWH(18, 28, 4, 3), fill);
      case VenueProp.medicalSign:
        fill.color = Colors.white;
        canvas.drawRRect(RRect.fromLTRBR(6, 6, 34, 34, const Radius.circular(6)), fill);
        fill.color = style.accent.withValues(alpha: 1);
        canvas
          ..drawRect(const Rect.fromLTWH(17, 11, 6, 18), fill)
          ..drawRect(const Rect.fromLTWH(11, 17, 18, 6), fill);
        fill.color = const Color(0xFF9FB3AD);
        canvas.drawRect(const Rect.fromLTWH(19, 34, 2, 20), fill);
      case VenueProp.shoppingBag:
        fill.color = style.accent;
        canvas.drawRRect(RRect.fromLTRBR(8, 22, 32, 54, const Radius.circular(3)), fill);
        canvas.drawArc(
          const Rect.fromLTWH(13, 12, 14, 18),
          3.14,
          3.14,
          false,
          Paint()
            ..color = style.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      case VenueProp.bell:
        fill.color = style.accent;
        canvas
          ..drawPath(
            Path()
              ..moveTo(6, 44)
              ..quadraticBezierTo(6, 24, 20, 24)
              ..quadraticBezierTo(34, 24, 34, 44)
              ..close(),
            fill,
          )
          ..drawCircle(const Offset(20, 21), 2.5, fill);
        fill.color = const Color(0xFF8A6A2A);
        canvas.drawRRect(RRect.fromLTRBR(3, 44, 37, 48, const Radius.circular(2)), fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(VenuePropPainter old) => old.style != style;
}
