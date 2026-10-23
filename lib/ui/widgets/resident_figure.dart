import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../art_assets.dart';
import '../layout.dart';
import '../painters/resident_painter.dart';
import '../painters/sprite_painter.dart';
import '../theme.dart';
import 'glossy.dart';

/// Whether figures below use the sprite art (`Profile.useSpriteArt`). With no
/// scope above, sprites are on, the same as a fresh profile.
class SpriteArtScope extends InheritedWidget {
  const SpriteArtScope({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SpriteArtScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(SpriteArtScope old) => old.enabled != enabled;
}

/// A resident drawn at [height] logical pixels. Width is half the height,
/// plus room for a vehicle or [cargo].
///
/// With sprite art on and the images loaded ([SpriteCache]) the approved
/// sprite stands in the box with a contact shadow; otherwise, or when an
/// image failed to load, [ResidentPainter] draws the figure. Both use the
/// same box, so switching never moves a layout.
class ResidentFigure extends StatelessWidget {
  const ResidentFigure({
    super.key,
    required this.type,
    this.cargo = Cargo.none,
    this.height = 52,
    this.dimmed = false,
    this.blink = false,
  });

  /// The unknown person: one generic shadow for everyone, so nothing about them shows.
  const ResidentFigure.unknown({super.key, this.height = 52})
      : type = ResidentType.kid,
        cargo = Cargo.none,
        dimmed = true,
        blink = false;

  /// Draws [r] with their cargo.
  ResidentFigure.of(Resident r, {Key? key, double height = 52, bool dimmed = false, bool blink = false})
      : this(key: key, type: r.type, cargo: r.cargo, height: height, dimmed: dimmed, blink: blink);

  final ResidentType type;
  final Cargo cargo;
  final double height;

  /// Draw a generic shadow instead of the resident (an unknown person).
  final bool dimmed;

  /// Eyes closed for this frame (the painted figure only; a sprite has no blink frame).
  final bool blink;

  /// The fraction of the box below the feet line.
  static const double belowFeet = (designHeight - feetY) / designHeight;

  /// The sprite painter for this figure, or null when the painter must draw it.
  CustomPainter? _sprite(SpriteCache cache) {
    if (dimmed) return switch (cache.ghost) { final g? => SpriteFigurePainter.ghost(g), null => null };
    final person = cache.resident(type);
    final prop = cache.cargo(cargo);
    if (person == null || (cargo != Cargo.none && prop == null)) return null;
    return SpriteFigurePainter(person: person, cargo: prop, designWidth: ResidentLook.designWidth(type, cargo));
  }

  @override
  Widget build(BuildContext context) {
    final painted = ResidentPainter(type, cargo: cargo, dimmed: dimmed, blink: blink);
    final sprites = SpriteArtScope.of(context);
    return SizedBox(
      width: height / designHeight * ResidentLook.designWidth(type, cargo, dimmed: dimmed),
      height: height,
      child: !sprites
          ? CustomPaint(painter: painted)
          : ListenableBuilder(
              listenable: SpriteCache.instance,
              builder: (context, _) => CustomPaint(painter: _sprite(SpriteCache.instance) ?? painted),
            ),
    );
  }
}

/// The floor tag shown above a waiting resident: a glossy pill in the
/// floor's colour with its label (style frame, `.tag`).
/// The outline and edge paint around the tag, so its layout height is the
/// same as before the restyle.
class FloorTag extends StatelessWidget {
  const FloorTag({super.key, required this.floor, this.compact = false, this.scale = 1});

  final Floor floor;
  final bool compact;

  /// Layout scale from [Metrics].
  final double scale;

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Glossy(
      style: SurfaceStyle.floor(floor),
      depth: SurfaceDepth.tag,
      inset: false,
      height: (compact ? Metrics.compactTagHeight : Metrics.tagHeight) * k,
      padding: EdgeInsets.symmetric(horizontal: (compact ? 6 : 9) * k),
      child: Text(
        floor.label,
        style: TextStyle(fontSize: (compact ? 10 : 12) * k, fontWeight: FontWeight.w800, color: LL.ink, height: 1),
      ),
    );
  }
}
