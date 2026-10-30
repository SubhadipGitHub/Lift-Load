/// Sprite residents: the approved cut-outs drawn in the same 120-unit figure
/// box as [ResidentPainter], feet on [feetY], with a contact shadow painted
/// under each sprite. Cargo stands beside the person in the box's right-hand
/// strip, as the painter places it. A sprite never changes with load.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art_assets.dart';
import '../layout.dart';
import '../theme.dart';
import 'resident_painter.dart';

class SpriteFigurePainter extends CustomPainter {
  /// A resident: [person] centred in the person area, [cargo] (if any)
  /// right-aligned in the cargo strip. [designWidth] is the box width in
  /// design units, the same as the painter's.
  SpriteFigurePainter({required this.person, this.cargo, required this.designWidth}) : ghost = false;

  /// The unknown person: the one ghost sprite, glowing and translucent, in
  /// a person-width box. Nothing in it depends on who they are.
  SpriteFigurePainter.ghost(ui.Image image)
      : person = image,
        cargo = null,
        designWidth = personWidth,
        ghost = true;

  final ui.Image person;
  final ui.Image? cargo;
  final double designWidth;
  final bool ghost;

  /// Where the person sprite lands in a [size] box.
  Rect personRect(Size size) {
    final k = size.height / designHeight;
    final left = (size.width - designWidth * k) / 2;
    final area = designWidth - (cargo == null ? 0 : cargoWidth);
    return _standing(person, left + area / 2 * k, feetY * k, k);
  }

  /// Where the cargo sprite lands, or null when there is none.
  Rect? cargoRect(Size size) {
    final c = cargo;
    if (c == null) return null;
    final k = size.height / designHeight;
    final right = (size.width + designWidth * k) / 2;
    final w = c.width / ArtAssets.pxPerUnit * k;
    return _standing(c, right - w / 2, feetY * k, k);
  }

  /// The contact shadow under a sprite standing in [sprite]: a soft ellipse
  /// centred on its feet line (`docs/art/gemini-art-pack.md`, Integration).
  static Rect shadowRect(Rect sprite) {
    final w = sprite.width * Metrics.contactShadowWidth;
    return Rect.fromCenter(center: sprite.bottomCenter, width: w, height: w * Metrics.contactShadowHeight);
  }

  static Rect _standing(ui.Image image, double centreX, double feet, double k) {
    final w = image.width / ArtAssets.pxPerUnit * k;
    final h = image.height / ArtAssets.pxPerUnit * k;
    return Rect.fromLTWH(centreX - w / 2, feet - h, w, h);
  }

  static void paintContactShadow(Canvas canvas, Rect sprite) {
    final shadow = shadowRect(sprite);
    canvas.drawOval(
      shadow,
      Paint()
        ..color = LL.contactShadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.width * Metrics.contactShadowBlur),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final body = personRect(size);
    final prop = cargoRect(size);
    paintContactShadow(canvas, body);
    if (prop != null) paintContactShadow(canvas, prop);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;
    final src = Rect.fromLTWH(0, 0, person.width.toDouble(), person.height.toDouble());
    if (ghost) {
      final sigma = body.width * Metrics.ghostGlowBlur;
      canvas.drawImageRect(
        person,
        src,
        body,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = const ColorFilter.mode(LL.ghostGlow, BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
      canvas.drawImageRect(person, src, body, paint..color = Color.fromRGBO(0, 0, 0, Metrics.ghostOpacity));
      return;
    }
    canvas.drawImageRect(person, src, body, paint);
    final c = cargo;
    if (c != null && prop != null) {
      canvas.drawImageRect(c, Rect.fromLTWH(0, 0, c.width.toDouble(), c.height.toDouble()), prop, paint);
    }
  }

  @override
  bool shouldRepaint(SpriteFigurePainter old) =>
      old.person != person || old.cargo != cargo || old.designWidth != designWidth || old.ghost != ghost;
}

/// A cargo sprite on its own, standing on the feet line of a [cargoWidth]-wide
/// box with its contact shadow: an item set down on the cabin floor.
class SpriteCargoPainter extends CustomPainter {
  SpriteCargoPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / designHeight;
    final rect = SpriteFigurePainter._standing(image, size.width / 2, feetY * k, k);
    SpriteFigurePainter.paintContactShadow(canvas, rect);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(SpriteCargoPainter old) => old.image != image;
}
