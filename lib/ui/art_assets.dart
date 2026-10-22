/// The shipped art: the one table from cast, cargo, the unknown ghost and the
/// cabins to an asset path, and a cache of the decoded images. No other file
/// names a path.
///
/// The sprites are full-body cut-outs drawn at [ArtAssets.pxPerUnit] pixels per
/// design unit of the 120-unit figure box (see `painters/resident_painter.dart`),
/// with the feet on the bottom edge of the image. Nothing about an image varies
/// with load: one image per type, one per cargo, one ghost for every unknown.
///
/// Each lift kind has a cabin interior (cover-cropped to the 196 x 214-unit
/// cabin) and two door leaves, each half the cabin (98 x 214 units); the
/// right leaf is the mirror of the left. A leaf is the same whatever rides.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/cast.dart';
import '../game/scenario.dart';

abstract final class ArtAssets {
  static const String _dir = 'assets/art';

  /// Sprite pixels per design unit (the approved art is made at 6).
  static const double pxPerUnit = 6;

  /// How long startup waits for the sprites before showing the first frame.
  /// Past this the painted figures show and the sprites swap in when ready.
  static const Duration preloadWait = Duration(seconds: 3);

  static String resident(ResidentType t) => '$_dir/resident_${t.name}.webp';

  /// The prop's sprite, or null for [Cargo.none].
  static String? cargo(Cargo c) => c == Cargo.none ? null : '$_dir/cargo_${c.name}.webp';

  /// One ghost for every unknown person.
  static const String ghost = '$_dir/unknown_ghost.webp';

  /// The cabin interior of a [kind] of lift.
  static String cabinInterior(LiftKind kind) => '$_dir/cabin_${kind.name}_interior.webp';

  /// One door leaf of a [kind] of lift: the [left] one or its mirror.
  static String cabinDoor(LiftKind kind, {required bool left}) =>
      '$_dir/cabin_${kind.name}_door_${left ? 'left' : 'right'}.webp';

  /// Every image the game ships.
  static List<String> get all => [
        for (final t in ResidentType.values) resident(t),
        for (final c in Cargo.values)
          if (cargo(c) case final path?) path,
        ghost,
        for (final k in LiftKind.values) ...[
          cabinInterior(k),
          cabinDoor(k, left: true),
          cabinDoor(k, left: false),
        ],
      ];
}

/// One kind of cabin's decoded art: its interior and its two door leaves.
typedef CabinArt = ({ui.Image interior, ui.Image left, ui.Image right});

/// The decoded sprites. Loaded once at startup; figures listen and swap from
/// the painted fallback to the sprite when loading finishes. An image that
/// fails to load stays missing, and its figures keep the painter.
class SpriteCache extends ChangeNotifier {
  SpriteCache._();

  static final SpriteCache instance = SpriteCache._();

  final Map<String, ui.Image> _images = {};
  final Set<String> _failed = {};
  Future<void>? _loading;

  /// Paths that could not be loaded or decoded.
  Set<String> get failed => Set.unmodifiable(_failed);

  bool get loaded => _loading != null && _images.length + _failed.length == ArtAssets.all.length;

  /// Loads every sprite once; later calls return the same future.
  Future<void> load({AssetBundle? bundle}) => _loading ??= _load(bundle ?? rootBundle);

  Future<void> _load(AssetBundle bundle) async {
    await Future.wait(ArtAssets.all.map((path) async {
      try {
        final data = await bundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        final frame = await codec.getNextFrame();
        codec.dispose();
        _images[path] = frame.image;
      } on Object catch (e) {
        _failed.add(path);
        debugPrint('Sprite $path failed to load: $e');
      }
    }));
    notifyListeners();
  }

  ui.Image? image(String path) => _images[path];

  ui.Image? resident(ResidentType t) => _images[ArtAssets.resident(t)];

  ui.Image? cargo(Cargo c) => switch (ArtAssets.cargo(c)) {
        final path? => _images[path],
        null => null,
      };

  ui.Image? get ghost => _images[ArtAssets.ghost];

  /// The cabin art for [kind], or null unless the interior and both leaves
  /// loaded (the cabin then keeps its painted look as a whole).
  CabinArt? cabin(LiftKind kind) {
    final interior = _images[ArtAssets.cabinInterior(kind)];
    final left = _images[ArtAssets.cabinDoor(kind, left: true)];
    final right = _images[ArtAssets.cabinDoor(kind, left: false)];
    if (interior == null || left == null || right == null) return null;
    return (interior: interior, left: left, right: right);
  }

  /// Forgets every image (tests use this to exercise the fallback).
  @visibleForTesting
  void debugReset() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _failed.clear();
    _loading = null;
    notifyListeners();
  }
}
