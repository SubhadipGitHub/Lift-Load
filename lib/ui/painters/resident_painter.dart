/// Parametric resident bodies, ported from the concept canvas (Assets
/// artboard). Every type is one body drawn from a [ResidentLook]: height,
/// shoulders, hips, belly, clothing, hair and one accessory. Weight is never
/// drawn as a number; the silhouette carries it.
///
/// Design space: 60 × 120, feet on y = 116.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';

enum Bottom { pants, shorts, skirt, saree }

enum Sleeves { long, short, none }

enum Hair { short, messy, long, bun, bald, fade, helmet }

enum Accessory { backpack, phone, laptopLeft, tie, shoppingBags, stick, mustache, duffel, parcel }

class ResidentLook {
  const ResidentLook({
    required this.height,
    required this.shoulders,
    required this.hips,
    this.belly = 0,
    required this.top,
    required this.bottomColor,
    required this.bottom,
    required this.sleeves,
    this.longTop = false,
    required this.hair,
    required this.hairColor,
    required this.skin,
    required this.shoe,
    required this.accessory,
  });

  final double height, shoulders, hips, belly;
  final Color top, bottomColor, hairColor, skin, shoe;
  final Bottom bottom;
  final Sleeves sleeves;
  final bool longTop;
  final Hair hair;
  final Accessory accessory;

  static ResidentLook of(ResidentType t) => switch (t) {
        ResidentType.kid => const ResidentLook(height: 66, shoulders: 7, hips: 6.5, top: Color(0xFFF2F4F8), bottomColor: Color(0xFF2C3A63), bottom: Bottom.shorts, sleeves: Sleeves.short, hair: Hair.short, hairColor: Color(0xFF2B2140), skin: Color(0xFFC98E66), shoe: Color(0xFF1E1E24), accessory: Accessory.backpack),
        ResidentType.student => const ResidentLook(height: 92, shoulders: 9, hips: 8, top: Color(0xFFE46D3A), bottomColor: Color(0xFF3B5B8C), bottom: Bottom.pants, sleeves: Sleeves.short, hair: Hair.messy, hairColor: Color(0xFF1F1A17), skin: Color(0xFF8D5A3B), shoe: Color(0xFFF2F2F2), accessory: Accessory.phone),
        ResidentType.officeW => const ResidentLook(height: 96, shoulders: 8.5, hips: 8.5, top: Color(0xFF8E7CC3), bottomColor: Color(0xFF2D2D3A), bottom: Bottom.skirt, sleeves: Sleeves.long, hair: Hair.long, hairColor: Color(0xFF2A1B14), skin: Color(0xFFE0AC85), shoe: Color(0xFF5A2E2E), accessory: Accessory.laptopLeft),
        ResidentType.officeM => const ResidentLook(height: 102, shoulders: 10.5, hips: 9, belly: 1, top: Color(0xFFDCE7F5), bottomColor: Color(0xFF4A4A55), bottom: Bottom.pants, sleeves: Sleeves.long, hair: Hair.short, hairColor: Color(0xFF1F1A17), skin: Color(0xFFB07A55), shoe: Color(0xFF3A2A20), accessory: Accessory.tie),
        ResidentType.aunty => const ResidentLook(height: 92, shoulders: 10.5, hips: 11.5, belly: 3, top: Color(0xFFF4B400), bottomColor: Color(0xFFC2185B), bottom: Bottom.saree, sleeves: Sleeves.short, hair: Hair.bun, hairColor: Color(0xFF1F1A17), skin: Color(0xFFA86F4C), shoe: Color(0xFF8A5A2B), accessory: Accessory.shoppingBags),
        ResidentType.grandpa => const ResidentLook(height: 94, shoulders: 9, hips: 8.5, belly: 1, top: Color(0xFFEFE6D2), bottomColor: Color(0xFFF7F3EA), bottom: Bottom.pants, sleeves: Sleeves.long, longTop: true, hair: Hair.bald, hairColor: Color(0xFFD8D4CC), skin: Color(0xFFC08A63), shoe: Color(0xFF5C4033), accessory: Accessory.stick),
        ResidentType.uncle => const ResidentLook(height: 100, shoulders: 12, hips: 13, belly: 7, top: Color(0xFF5D7D4E), bottomColor: Color(0xFF3D3A36), bottom: Bottom.pants, sleeves: Sleeves.long, longTop: true, hair: Hair.short, hairColor: Color(0xFF2B2140), skin: Color(0xFF9C6644), shoe: Color(0xFF2A211B), accessory: Accessory.mustache),
        ResidentType.gym => const ResidentLook(height: 104, shoulders: 14, hips: 9, top: Color(0xFF24252C), bottomColor: Color(0xFF6B6F78), bottom: Bottom.shorts, sleeves: Sleeves.none, hair: Hair.fade, hairColor: Color(0xFF1A1512), skin: Color(0xFF7A4A2C), shoe: Color(0xFFE8E8EC), accessory: Accessory.duffel),
        ResidentType.rider => const ResidentLook(height: 100, shoulders: 11, hips: 10, belly: 1, top: Color(0xFFD9A21B), bottomColor: Color(0xFF2B2B30), bottom: Bottom.pants, sleeves: Sleeves.long, hair: Hair.helmet, hairColor: Color(0xFFD9A21B), skin: Color(0xFFB88360), shoe: Color(0xFF1E1E24), accessory: Accessory.parcel),
      };
}

/// A filled or stroked layer of the figure.
class _Layer {
  const _Layer(this.path, this.color, {this.stroke = 0});
  final Path path;
  final Color color;

  /// 0 = filled, otherwise stroke width with round caps.
  final double stroke;
}

/// Builds the ordered layers for one look. Cached per type.
class _Figure {
  _Figure(ResidentLook l) {
    final h = l.height;
    final kid = h < 75;
    final t0 = 116 - h;
    final headH = kid ? h * 0.21 : h * 0.145;
    final rx = headH * 0.4, ry = headH * 0.5;
    final hy = t0 + ry;
    final neckTop = hy + ry * 0.8;
    final s = t0 + headH + h * 0.035;
    final p = t0 + h * (kid ? 0.55 : 0.53);
    final c = p + h * 0.05;
    final k = p + (113 - p) * 0.5;
    final tb = l.longTop ? p + (k - p) * 0.85 : p + 1.5;
    final sh = l.shoulders, hp = l.hips, bb = l.belly;
    final bx = math.max(sh, hp) + bb;
    final hpT = l.longTop ? hp + 2 : hp;
    final cy = s + (tb - s) * 0.6;
    final a = math.max(2.0, hp * 0.3);
    const lg = 0.9;

    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);
    Path circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

    shadowRx = math.max(sh, hp) + 4;

    // Back layer: backpack or long hair / bun.
    if (l.accessory == Accessory.backpack) {
      layers.add(_Layer(
        Path()
          ..addRRect(RRect.fromLTRBAndCorners(30 - sh - 1.6, s + 1.5, 30 + sh + 1.6, s + 1.5 + h * 0.3 + 2.5,
              bottomLeft: const Radius.circular(2.5), bottomRight: const Radius.circular(2.5))),
        const Color(0xFFD64545),
      ));
    }
    if (l.hair == Hair.long) {
      layers.add(_Layer(
        Path()
          ..moveTo(30 - rx - 0.9, hy - ry * 0.2)
          ..quadraticBezierTo(30 - rx - 1.9, hy + ry * 1.6, 30 - rx + 0.4, s + 6)
          ..lineTo(30 + rx - 0.4, s + 6)
          ..quadraticBezierTo(30 + rx + 1.9, hy + ry * 1.6, 30 + rx + 0.9, hy - ry * 0.2)
          ..close(),
        l.hairColor,
      ));
    }
    if (l.hair == Hair.bun) layers.add(_Layer(circle(30, hy - ry * 1.02, rx * 0.5), l.hairColor));

    // Legs in skin, then the bottom garment over them.
    final legs = poly([
      Offset(30 - hp, p),
      Offset(30 + hp, p),
      Offset(30 + lg + 2 * a, 113),
      Offset(30 + lg, 113),
      Offset(30, c),
      Offset(30 - lg, 113),
      Offset(30 - lg - 2 * a, 113),
    ]);
    layers.add(_Layer(legs, l.skin));

    double xo(double y) => hp + (lg + 2 * a - hp) * (y - p) / (113 - p);
    final Path bottom;
    switch (l.bottom) {
      case Bottom.pants:
        bottom = legs;
      case Bottom.shorts:
        final ky = k + 2;
        bottom = poly([
          Offset(30 - hp, p),
          Offset(30 + hp, p),
          Offset(30 + xo(ky) + 0.6, ky),
          Offset(30.4, ky),
          Offset(30, c),
          Offset(29.6, ky),
          Offset(30 - xo(ky) - 0.6, ky),
        ]);
      case Bottom.skirt:
        bottom = poly([Offset(30 - hp, p), Offset(30 + hp, p), Offset(30 + hp + 2.5, k + 4), Offset(30 - hp - 2.5, k + 4)]);
      case Bottom.saree:
        bottom = Path()
          ..moveTo(30 - hp, p)
          ..lineTo(30 + hp, p)
          ..quadraticBezierTo(30 + hp + 4, 100, 30 + hp + 4.5, 114.5)
          ..lineTo(30 - hp - 4.5, 114.5)
          ..quadraticBezierTo(30 - hp - 4, 100, 30 - hp, p)
          ..close();
    }
    layers.add(_Layer(bottom, l.bottomColor));

    // Shoes.
    final sw = 2 * a + 1.2;
    final rx0 = 30 + lg - 0.3, lx0 = 30 - lg + 0.3;
    final shoes = Path()
      ..moveTo(rx0, 112.6)
      ..lineTo(rx0 + sw, 112.6)
      ..quadraticBezierTo(rx0 + sw + 1.4, 112.6, rx0 + sw + 1.4, 114.2)
      ..lineTo(rx0 + sw + 1.4, 116)
      ..lineTo(rx0, 116)
      ..close()
      ..moveTo(lx0, 112.6)
      ..lineTo(lx0 - sw, 112.6)
      ..quadraticBezierTo(lx0 - sw - 1.4, 112.6, lx0 - sw - 1.4, 114.2)
      ..lineTo(lx0 - sw - 1.4, 116)
      ..lineTo(lx0, 116)
      ..close();
    layers.add(_Layer(shoes, l.shoe));

    // Torso and its shaded right side.
    layers.add(_Layer(
      Path()
        ..moveTo(30 - sh, s + 3)
        ..quadraticBezierTo(30 - sh, s, 30 - sh + 4, s)
        ..lineTo(30 + sh - 4, s)
        ..quadraticBezierTo(30 + sh, s, 30 + sh, s + 3)
        ..quadraticBezierTo(30 + bx, cy, 30 + hpT, tb)
        ..lineTo(30 - hpT, tb)
        ..quadraticBezierTo(30 - bx, cy, 30 - sh, s + 3)
        ..close(),
      l.top,
    ));
    layers.add(_Layer(
      Path()
        ..moveTo(30 + sh * 0.25, s)
        ..lineTo(30 + sh - 4, s)
        ..quadraticBezierTo(30 + sh, s, 30 + sh, s + 3)
        ..quadraticBezierTo(30 + bx, cy, 30 + hpT, tb)
        ..lineTo(30 + hpT * 0.25, tb)
        ..close(),
      const Color(0x1F000000),
    ));

    // Arms, sleeves, hands.
    var hyH = p + h * 0.07;
    final reach = math.max(sh, hp + bb * 0.6) + 1.4;
    var hxL = 30 - reach, hxR = 30 + reach;
    if (l.accessory == Accessory.parcel) {
      hxL = 23;
      hxR = 37;
      hyH = p - 4;
    }
    final sxL = 30 - sh + 1.6, sxR = 30 + sh - 1.6, sy = s + 2.6;
    final aw = kid ? 2.8 : (sh >= 13 ? 4.8 : 3.6);
    final arms = Path()
      ..moveTo(sxL, sy)
      ..quadraticBezierTo(math.min(sxL, hxL) - 1.2, (sy + hyH) / 2, hxL, hyH)
      ..moveTo(sxR, sy)
      ..quadraticBezierTo(math.max(sxR, hxR) + 1.2, (sy + hyH) / 2, hxR, hyH);
    layers.add(_Layer(arms, l.sleeves == Sleeves.long ? l.top : l.skin, stroke: aw));
    if (l.sleeves == Sleeves.short) {
      layers.add(_Layer(
        Path()
          ..moveTo(sxL, sy)
          ..lineTo(sxL - 0.9, sy + h * 0.11)
          ..moveTo(sxR, sy)
          ..lineTo(sxR + 0.9, sy + h * 0.11),
        l.top,
        stroke: aw + 0.9,
      ));
    }
    layers.add(_Layer(circle(hxL, hyH, aw * 0.58)..addPath(circle(hxR, hyH, aw * 0.58), Offset.zero), l.skin));

    // Neck and head.
    final nw = headH * 0.34;
    layers.add(_Layer(Path()..addRect(Rect.fromLTWH(30 - nw / 2, neckTop, nw, s - neckTop + 1.5)), l.skin));
    layers.add(_Layer(Path()..addOval(Rect.fromCenter(center: Offset(30, hy), width: rx * 2, height: ry * 2)), l.skin));

    // Hair.
    final cap = Path()
      ..moveTo(30 - rx - 0.4, hy + ry * 0.05)
      ..quadraticBezierTo(30 - rx - 0.7, hy - ry * 1.2, 30, hy - ry * 1.12)
      ..quadraticBezierTo(30 + rx + 0.7, hy - ry * 1.2, 30 + rx + 0.4, hy + ry * 0.05)
      ..quadraticBezierTo(30 + rx * 0.75, hy - ry * 0.5, 30, hy - ry * 0.6)
      ..quadraticBezierTo(30 - rx * 0.75, hy - ry * 0.5, 30 - rx - 0.4, hy + ry * 0.05)
      ..close();
    switch (l.hair) {
      case Hair.short || Hair.fade || Hair.long || Hair.bun:
        layers.add(_Layer(cap, l.hairColor));
      case Hair.messy:
        final x0 = 30 - rx * 0.5, y0 = hy - ry * 1.05;
        layers.add(_Layer(
          cap
            ..addPolygon([
              Offset(x0, y0),
              Offset(x0 + 1.2, y0 - 1.8),
              Offset(x0 + 2.2, y0 - 0.3),
              Offset(x0 + 3.5, y0 - 2.0),
              Offset(x0 + 4.3, y0 - 0.1),
            ], true),
          l.hairColor,
        ));
      case Hair.bald:
        layers.add(_Layer(
          Path()
            ..moveTo(30 - rx - 0.3, hy + ry * 0.2)
            ..quadraticBezierTo(30 - rx - 0.5, hy - ry * 0.5, 30 - rx * 0.55, hy - ry * 0.78)
            ..lineTo(30 - rx * 0.4, hy - ry * 0.35)
            ..close()
            ..moveTo(30 + rx + 0.3, hy + ry * 0.2)
            ..quadraticBezierTo(30 + rx + 0.5, hy - ry * 0.5, 30 + rx * 0.55, hy - ry * 0.78)
            ..lineTo(30 + rx * 0.4, hy - ry * 0.35)
            ..close(),
          l.hairColor,
        ));
      case Hair.helmet:
        layers.add(_Layer(
          Path()
            ..moveTo(30 - rx - 1.6, hy + ry * 0.35)
            ..quadraticBezierTo(30 - rx - 1.9, hy - ry * 1.5, 30, hy - ry * 1.42)
            ..quadraticBezierTo(30 + rx + 1.9, hy - ry * 1.5, 30 + rx + 1.6, hy + ry * 0.35)
            ..close(),
          l.hairColor,
        ));
    }

    // Eyes.
    final eyeY = hy + ry * 0.08, er = math.max(0.45, rx * 0.12);
    layers.add(_Layer(circle(30 - rx * 0.38, eyeY, er)..addPath(circle(30 + rx * 0.38, eyeY, er), Offset.zero), const Color(0xFF1E1A24)));

    // Front accessories.
    Path rrect(double x, double y, double w, double hh, double r) =>
        Path()..addRRect(RRect.fromLTRBAndCorners(x, y, x + w, y + hh, bottomLeft: Radius.circular(r), bottomRight: Radius.circular(r)));
    switch (l.accessory) {
      case Accessory.backpack:
        layers.add(_Layer(
          Path()
            ..addRect(Rect.fromLTWH(30 - sh + 1.2, s, 1.8, h * 0.24))
            ..addRect(Rect.fromLTWH(30 + sh - 3, s, 1.8, h * 0.24)),
          const Color(0xFF8E2B2B),
        ));
      case Accessory.phone:
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(hxR - 1.5, hyH - 4.8, 3, 5)), const Color(0xFF22232B)));
      case Accessory.laptopLeft:
        layers.add(_Layer(rrect(hxL - 5.5, hyH - 0.5, 11, 9.6, 1.6), const Color(0xFF6B4A3A)));
        layers.add(_Layer(
          Path()
            ..moveTo(30 + sh - 3, s + 1)
            ..lineTo(hxL + 3, hyH - 0.5),
          const Color(0xFF4A3226),
          stroke: 1,
        ));
      case Accessory.tie:
        layers.add(_Layer(poly([Offset(30, s + 0.8), Offset(28.4, s + 3), Offset(30, s + 3 + h * 0.2), Offset(31.6, s + 3)]), const Color(0xFFB23A48)));
        layers.add(_Layer(rrect(hxR - 5.5, hyH - 0.5, 11, 9.6, 1.6), const Color(0xFF3A2A20)));
      case Accessory.shoppingBags:
        layers.add(_Layer(
          poly([Offset(30 + sh - 5.5, s), Offset(30 + sh - 0.5, s + 1.5), Offset(30 - hp + 5, p + 7), Offset(30 - hp - 0.5, p + 4)]),
          const Color(0xFF8E0F42),
        ));
        layers.add(_Layer(
          poly([Offset(hxL - 4, hyH), Offset(hxL + 4, hyH), Offset(hxL + 3, hyH + 9), Offset(hxL - 3, hyH + 9)])
            ..addPolygon([Offset(hxR - 4, hyH), Offset(hxR + 4, hyH), Offset(hxR + 3, hyH + 9), Offset(hxR - 3, hyH + 9)], true),
          const Color(0xFFE9D3A8),
        ));
      case Accessory.stick:
        layers.add(_Layer(
          Path()
            ..addRect(Rect.fromLTWH(hxR + 0.6, hyH - 1.5, 1.5, 116 - hyH + 1.5))
            ..addRect(Rect.fromLTWH(hxR - 1.5, hyH - 1.5, 3.6, 1.4)),
          const Color(0xFF7A4E26),
        ));
        layers.add(_Layer(
          circle(30 - rx * 0.38, eyeY, 1.5)..addPath(circle(30 + rx * 0.38, eyeY, 1.5), Offset.zero),
          const Color(0xFF2B2140),
          stroke: 0.5,
        ));
      case Accessory.mustache:
        layers.add(_Layer(
          Path()
            ..moveTo(30 - rx * 0.5, hy + ry * 0.45)
            ..quadraticBezierTo(30, hy + ry * 0.22, 30 + rx * 0.5, hy + ry * 0.45)
            ..quadraticBezierTo(30, hy + ry * 0.6, 30 - rx * 0.5, hy + ry * 0.45)
            ..close(),
          const Color(0xFF241A16),
        ));
      case Accessory.duffel:
        layers.add(_Layer(Path()..addRRect(RRect.fromLTRBR(hxL - 6, hyH, hxL + 8, hyH + 9, const Radius.circular(2))), const Color(0xFF3A3F4B)));
      case Accessory.parcel:
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(21.5, p - 11, 17, 13)), const Color(0xFFC69C6D)));
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(21.5, p - 6, 17, 2.2)), const Color(0xFFA87E50)));
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(30 - rx - 0.8, hy - ry * 0.25, 2 * rx + 1.6, ry * 0.62)), const Color(0xFF26262E)));
    }
  }

  final List<_Layer> layers = [];
  late final double shadowRx;
}

class ResidentPainter extends CustomPainter {
  ResidentPainter(this.type);

  final ResidentType type;

  static final Map<ResidentType, _Figure> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final fig = _cache.putIfAbsent(type, () => _Figure(ResidentLook.of(type)));
    final scale = size.height / 120;
    canvas
      ..save()
      ..translate((size.width - 60 * scale) / 2, 0)
      ..scale(scale);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(30, 116), width: fig.shadowRx * 2, height: 5.2),
      Paint()..color = const Color(0x2E000000),
    );
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final layer in fig.layers) {
      if (layer.stroke > 0) {
        canvas.drawPath(layer.path, stroke
          ..color = layer.color
          ..strokeWidth = layer.stroke);
      } else {
        canvas.drawPath(layer.path, fill..color = layer.color);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ResidentPainter old) => old.type != type;
}
