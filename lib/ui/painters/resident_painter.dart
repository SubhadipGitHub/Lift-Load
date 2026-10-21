/// Parametric resident bodies, ported from the concept canvas (Assets
/// artboard). Every type is one body drawn from a [ResidentLook]: height,
/// shoulders, hips, belly, clothing, hair, one accessory and optionally a
/// vehicle (wheelchair, pram, trolley). Cargo is a separate prop drawn by
/// the feet. Weight is never drawn as a number; the silhouette carries it.
///
/// Design space: 60 × 120 for the person, feet on y = 116. A vehicle adds
/// [vehicleWidth] to the right, cargo adds [cargoWidth] to the right.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';

enum Bottom { pants, shorts, skirt, saree }

enum Sleeves { long, short, none }

enum Hair { short, messy, long, bun, bald, fade, helmet, cap, pillbox, hood }

enum Accessory { none, backpack, phone, laptopLeft, tie, shoppingBags, stick, mustache, duffel, parcel, baton, quilted, blanket, buttons }

enum Vehicle { none, wheelchair, pram, trolley }

const double personWidth = 60;
const double vehicleWidth = 30;
const double cargoWidth = 16;

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
    this.vehicle = Vehicle.none,
  });

  final double height, shoulders, hips, belly;
  final Color top, bottomColor, hairColor, skin, shoe;
  final Bottom bottom;
  final Sleeves sleeves;
  final bool longTop;
  final Hair hair;
  final Accessory accessory;
  final Vehicle vehicle;

  /// Width of the design box for this type with [cargo]. A dimmed (power
  /// cut) figure is always person-width so its outline gives nothing away.
  static double designWidth(ResidentType t, Cargo cargo, {bool dimmed = false}) {
    if (dimmed) return personWidth;
    final v = of(t).vehicle;
    return personWidth +
        (v == Vehicle.pram || v == Vehicle.trolley ? vehicleWidth : 0) +
        (cargo == Cargo.none ? 0 : cargoWidth);
  }

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
        ResidentType.guard => const ResidentLook(height: 102, shoulders: 12.5, hips: 11, belly: 3, top: Color(0xFF34466B), bottomColor: Color(0xFF243150), bottom: Bottom.pants, sleeves: Sleeves.long, hair: Hair.cap, hairColor: Color(0xFF1D2740), skin: Color(0xFF9C6644), shoe: Color(0xFF15151A), accessory: Accessory.baton),
        ResidentType.wheelchair => const ResidentLook(height: 94, shoulders: 10, hips: 10, belly: 2, top: Color(0xFFBFD8E6), bottomColor: Color(0xFF8FA9BC), bottom: Bottom.pants, sleeves: Sleeves.short, hair: Hair.short, hairColor: Color(0xFF6E6A66), skin: Color(0xFFC08A63), shoe: Color(0xFF5C4033), accessory: Accessory.blanket, vehicle: Vehicle.wheelchair),
        ResidentType.puffer => const ResidentLook(height: 96, shoulders: 14, hips: 13, belly: 4, top: Color(0xFFEF7D32), bottomColor: Color(0xFF26262E), bottom: Bottom.pants, sleeves: Sleeves.long, longTop: true, hair: Hair.hood, hairColor: Color(0xFF1F1A17), skin: Color(0xFFB07A55), shoe: Color(0xFFF2F2F2), accessory: Accessory.quilted),
        ResidentType.pram => const ResidentLook(height: 96, shoulders: 9.5, hips: 10, belly: 1, top: Color(0xFFD98BA8), bottomColor: Color(0xFF3B4A6B), bottom: Bottom.pants, sleeves: Sleeves.long, hair: Hair.long, hairColor: Color(0xFF3A2418), skin: Color(0xFFE0AC85), shoe: Color(0xFF5A2E2E), accessory: Accessory.none, vehicle: Vehicle.pram),
        ResidentType.bellhop => const ResidentLook(height: 100, shoulders: 11, hips: 10, belly: 1, top: Color(0xFF9E2B2B), bottomColor: Color(0xFF2B2B30), bottom: Bottom.pants, sleeves: Sleeves.long, hair: Hair.pillbox, hairColor: Color(0xFF9E2B2B), skin: Color(0xFF8D5A3B), shoe: Color(0xFF15151A), accessory: Accessory.buttons, vehicle: Vehicle.trolley),
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
    final seated = l.vehicle == Vehicle.wheelchair;
    // Seated figures keep standing proportions, lowered onto the seat.
    final t0 = 116 - h + (seated ? 24 : 0);
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

    // Back layer: vehicle frames, hood, backpack or long hair / bun.
    if (seated) {
      layers.add(_Layer(circle(25, 99, 15), const Color(0xFF4A4F5C), stroke: 3));
      layers.add(_Layer(
        Path()
          ..moveTo(25, 85)
          ..lineTo(25, 113)
          ..moveTo(11, 99)
          ..lineTo(39, 99),
        const Color(0xFF8A90A0),
        stroke: 1,
      ));
      layers.add(_Layer(
        Path()
          ..moveTo(30 - hp - 3, s + 4)
          ..lineTo(30 - hp - 3, p + 4)
          ..moveTo(30 - hp - 3, s + 4)
          ..lineTo(30 - hp - 7, s + 4),
        const Color(0xFF4A4F5C),
        stroke: 2.2,
      ));
    }
    if (l.hair == Hair.hood) {
      layers.add(_Layer(Path()..addOval(Rect.fromCenter(center: Offset(30, hy + ry * 0.1), width: rx * 2 + 6, height: ry * 2 + 6)), l.top));
    }
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

    // Legs in skin, then the bottom garment over them. Seated legs bend
    // forward at the knee (thigh across the seat, shin down to the footrest).
    if (seated) {
      final knee = 30 + hp + 9;
      final thighs = Path()..addRRect(RRect.fromLTRBR(30 - hp, p - 2, knee + 2, p + 7, const Radius.circular(3)));
      final shins = Path()..addRect(Rect.fromLTRB(knee - 4, p + 4, knee + 1.5, 112.6));
      layers.add(_Layer(thighs..addPath(shins, Offset.zero), l.bottomColor));
      layers.add(_Layer(Path()..addRRect(RRect.fromLTRBR(knee - 4.5, 112.4, knee + 5, 116, const Radius.circular(1.5))), l.shoe));
      layers.add(_Layer(
        Path()
          ..moveTo(30 - hp - 2, p + 8)
          ..lineTo(knee + 3, p + 8)
          ..moveTo(knee + 2, p + 8)
          ..lineTo(knee + 4, 110),
        const Color(0xFF4A4F5C),
        stroke: 2,
      ));
      layers.add(_Layer(circle(knee + 5, 112.5, 3), const Color(0xFF2E323C)));
    }
    final legs = poly([
      Offset(30 - hp, p),
      Offset(30 + hp, p),
      Offset(30 + lg + 2 * a, 113),
      Offset(30 + lg, 113),
      Offset(30, c),
      Offset(30 - lg, 113),
      Offset(30 - lg - 2 * a, 113),
    ]);
    if (!seated) layers.add(_Layer(legs, l.skin));

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
    if (!seated) layers.add(_Layer(bottom, l.bottomColor));

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
    if (!seated) layers.add(_Layer(shoes, l.shoe));

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
    if (l.vehicle == Vehicle.pram || l.vehicle == Vehicle.trolley) {
      hxR = 30 + reach + 4;
      hyH = p - 2;
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
      case Hair.cap:
        layers.add(_Layer(cap, l.hairColor));
        layers.add(_Layer(
          Path()
            ..moveTo(30 - rx - 0.8, hy - ry * 0.35)
            ..quadraticBezierTo(30 - rx - 1, hy - ry * 1.45, 30, hy - ry * 1.4)
            ..quadraticBezierTo(30 + rx + 1, hy - ry * 1.45, 30 + rx + 0.8, hy - ry * 0.35)
            ..close()
            ..addRect(Rect.fromLTWH(30 - rx - 1.5, hy - ry * 0.45, 2 * rx + 5, 1.8)),
          l.hairColor,
        ));
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(30 - 1.2, hy - ry * 1.05, 2.4, 2.2)), const Color(0xFFE8C547)));
      case Hair.pillbox:
        layers.add(_Layer(cap, const Color(0xFF1F1A17)));
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(30 - rx * 0.75, hy - ry * 1.55, rx * 1.5, ry * 0.62)), l.hairColor));
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(30 - rx * 0.75, hy - ry * 1.02, rx * 1.5, 0.9)), const Color(0xFFE8C547)));
      case Hair.hood:
        layers.add(_Layer(cap, l.hairColor));
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
      case Accessory.none:
        break;
      case Accessory.baton:
        layers.add(_Layer(
          Path()
            ..moveTo(hxR, hyH)
            ..lineTo(hxR + 2.5, hyH + 13),
          const Color(0xFF15151A),
          stroke: 2,
        ));
        layers.add(_Layer(circle(30 - sh * 0.5, s + 5, 1.5), const Color(0xFFE8C547)));
      case Accessory.quilted:
        final quilt = Path();
        for (var i = 1; i <= 3; i++) {
          final y = s + (tb - s) * i / 4;
          quilt
            ..moveTo(30 - bx + 1.5, y)
            ..lineTo(30 + bx - 1.5, y);
        }
        layers.add(_Layer(quilt, const Color(0x40000000), stroke: 1));
        layers.add(_Layer(Path()..addRect(Rect.fromLTWH(29.4, s + 1, 1.2, tb - s - 1)), const Color(0x40000000)));
      case Accessory.blanket:
        layers.add(_Layer(Path()..addRRect(RRect.fromLTRBR(30 - hp - 1, p - 3, 30 + hp + 8, p + 8, const Radius.circular(3))), const Color(0xFF6F8FB0)));
      case Accessory.buttons:
        layers.add(_Layer(
          circle(30, s + 4, 1)..addPath(circle(30, s + 9, 1), Offset.zero)..addPath(circle(30, s + 14, 1), Offset.zero),
          const Color(0xFFE8C547),
        ));
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

    // Vehicles to the right of the person (60..90).
    switch (l.vehicle) {
      case Vehicle.none || Vehicle.wheelchair:
        break;
      case Vehicle.pram:
        layers.add(_Layer(
          Path()
            ..moveTo(hxR, hyH)
            ..lineTo(64, 84),
          const Color(0xFF2E3A40),
          stroke: 1.6,
        ));
        layers.add(_Layer(
          Path()
            ..moveTo(62, 84)
            ..lineTo(87, 84)
            ..quadraticBezierTo(87, 102, 74, 102)
            ..quadraticBezierTo(62, 102, 62, 84)
            ..close(),
          const Color(0xFF5C7C8A),
        ));
        layers.add(_Layer(
          Path()
            ..moveTo(72, 84)
            ..quadraticBezierTo(72, 68, 87, 70)
            ..lineTo(87, 84)
            ..close(),
          const Color(0xFF3E5560),
        ));
        layers.add(_Layer(
          Path()
            ..moveTo(68, 102)
            ..lineTo(66, 110)
            ..moveTo(80, 102)
            ..lineTo(82, 110),
          const Color(0xFF2E3A40),
          stroke: 1.4,
        ));
        layers.add(_Layer(circle(66, 111, 4.5)..addPath(circle(82, 111, 4.5), Offset.zero), const Color(0xFF2E3A40)));
        layers.add(_Layer(circle(66, 111, 1.6)..addPath(circle(82, 111, 1.6), Offset.zero), const Color(0xFFB8C4CC)));
      case Vehicle.trolley:
        const brass = Color(0xFFC9A227);
        layers.add(_Layer(
          Path()
            ..moveTo(hxR, hyH)
            ..lineTo(62, 80),
          brass,
          stroke: 1.6,
        ));
        layers.add(_Layer(Path()..addRect(const Rect.fromLTRB(65, 94, 87, 110)), const Color(0xFF6B4A3A)));
        layers.add(_Layer(Path()..addRect(const Rect.fromLTRB(67, 80, 85, 94)), const Color(0xFF44546A)));
        layers.add(_Layer(Path()..addRect(const Rect.fromLTRB(68, 70, 82, 80)), const Color(0xFF8E2B2B)));
        layers.add(_Layer(
          Path()
            ..moveTo(62, 112)
            ..lineTo(62, 62)
            ..quadraticBezierTo(76, 54, 90, 62)
            ..lineTo(90, 112),
          brass,
          stroke: 2,
        ));
        layers.add(_Layer(Path()..addRect(const Rect.fromLTRB(60, 110, 92, 113)), brass));
        layers.add(_Layer(circle(64, 114.5, 2.4)..addPath(circle(88, 114.5, 2.4), Offset.zero), const Color(0xFF2E323C)));
    }
  }

  final List<_Layer> layers = [];
  late final double shadowRx;
}

/// Cargo props stand by the feet, in the [cargoWidth] strip right of the
/// person (x 58..74). Each is shaped unlike any type's own accessory.
List<_Layer> _cargoLayers(Cargo cargo) {
  const x = 58.0;
  switch (cargo) {
    case Cargo.none:
      return const [];
    case Cargo.waterCan:
      return [
        _Layer(Path()..addRRect(RRect.fromLTRBR(x + 1, 92, x + 15, 116, const Radius.circular(4))), const Color(0xCC8FD0EA)),
        _Layer(Path()..addRect(const Rect.fromLTRB(x + 1, 100, x + 15, 101.6)), const Color(0x664B9CC4)),
        _Layer(Path()..addRect(const Rect.fromLTRB(x + 5.5, 87.5, x + 10.5, 92)), const Color(0xFF2F6FB5)),
      ];
    case Cargo.suitcase:
      return [
        _Layer(
          Path()
            ..moveTo(x + 5, 92)
            ..lineTo(x + 5, 80)
            ..lineTo(x + 11, 80)
            ..lineTo(x + 11, 92),
          const Color(0xFF8A90A0),
          stroke: 1.4,
        ),
        _Layer(Path()..addRRect(RRect.fromLTRBR(x + 1, 91, x + 15, 113, const Radius.circular(2.5))), const Color(0xFF44546A)),
        _Layer(Path()..addRect(const Rect.fromLTRB(x + 1, 100, x + 15, 101.4)), const Color(0xFF2E3A4A)),
        _Layer(
          Path()
            ..addOval(Rect.fromCircle(center: const Offset(x + 4, 114.5), radius: 1.6))
            ..addOval(Rect.fromCircle(center: const Offset(x + 12, 114.5), radius: 1.6)),
          const Color(0xFF1E1E24),
        ),
      ];
    case Cargo.cylinder:
      return [
        _Layer(Path()..addRRect(RRect.fromLTRBR(x + 1, 86, x + 15, 116, const Radius.circular(5))), const Color(0xFFB3261E)),
        _Layer(Path()..addRect(const Rect.fromLTRB(x + 1, 108, x + 15, 110)), const Color(0xFF7E1A14)),
        _Layer(Path()..addRRect(RRect.fromLTRBR(x + 3.5, 79, x + 12.5, 86, const Radius.circular(2))), const Color(0xFF5B5F6B)),
        _Layer(Path()..addRect(const Rect.fromLTRB(x + 6.5, 76.5, x + 9.5, 79)), const Color(0xFF2E323C)),
      ];
  }
}

class ResidentPainter extends CustomPainter {
  ResidentPainter(this.type, {this.cargo = Cargo.none, this.dimmed = false});

  final ResidentType type;
  final Cargo cargo;

  /// Power cut: a generic shadow with no type, build or cargo showing.
  final bool dimmed;

  static final Map<ResidentType, _Figure> _cache = {};
  static final Map<Cargo, List<_Layer>> _cargoCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final width = ResidentLook.designWidth(type, cargo, dimmed: dimmed);
    final scale = size.height / 120;
    canvas
      ..save()
      ..translate((size.width - width * scale) / 2, 0)
      ..scale(scale);
    if (dimmed) {
      _paintShadow(canvas);
      canvas.restore();
      return;
    }
    final fig = _cache.putIfAbsent(type, () => _Figure(ResidentLook.of(type)));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(width == personWidth ? 30 : width / 2, 116),
        width: width == personWidth ? fig.shadowRx * 2 : width - 8,
        height: 5.2,
      ),
      Paint()..color = const Color(0x2E000000),
    );
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final layers in [fig.layers, _cargoCache.putIfAbsent(cargo, () => _cargoLayers(cargo))]) {
      for (final layer in layers) {
        if (layer.stroke > 0) {
          canvas.drawPath(layer.path, stroke
            ..color = layer.color
            ..strokeWidth = layer.stroke);
        } else {
          canvas.drawPath(layer.path, fill..color = layer.color);
        }
      }
    }
    canvas.restore();
  }

  void _paintShadow(Canvas canvas) {
    final paint = Paint()..color = const Color(0x8C3A3560);
    canvas
      ..drawOval(Rect.fromCenter(center: const Offset(30, 38), width: 16, height: 19), paint)
      ..drawRRect(RRect.fromLTRBR(18, 50, 42, 116, const Radius.circular(11)), paint);
  }

  @override
  bool shouldRepaint(ResidentPainter old) => old.type != type || old.cargo != cargo || old.dimmed != dimmed;
}
