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
///
/// The icons are 256 px squares: one per [GameIcon], one badge per lift kind
/// (the normal lift has none) and one per lobby scenario. None of them says
/// anything about a weight.
///
/// Sunrise Towers (the society venue) has painted backdrops: a shaft wall per
/// storey band ([ShaftBand]) and one lobby floor. The other venues have none
/// yet and keep their painted backgrounds.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/cast.dart';
import '../game/level.dart';
import '../game/scenario.dart';
import '../game/venue.dart';

/// The approved icons that stand for a thing in the game (not a lift kind or
/// scenario, which have their own lookups). Each has a Material or painted
/// fallback in `widgets/art_icon.dart`.
enum GameIcon {
  heart('heart'),
  coin('coin'),
  scale('scale'),
  trip('trip'),
  seat('seat'),
  restart('restart'),
  play('play'),
  lock('lock'),
  hourglass('hourglass'),
  star('star'),
  trophy('trophy'),
  cableSnap('cable_snap');

  const GameIcon(this.file);

  /// The name in `icon_<file>.webp`.
  final String file;
}

/// Where in its 20-level building a level sits, which picks the shaft wall:
/// the wainscot and lamps at the bottom, windows onto the city in the middle,
/// arched windows and a night sky at the top.
enum ShaftBand {
  ground,
  mid,
  high;

  /// The first storey (1 to [Venue.levelsPerVenue]) of each band, in order:
  /// storeys 1-7 ground, 8-14 mid, 15-20 high.
  static const List<int> firstStorey = [1, 8, 15];

  /// The storey of [level] in its building, 1 to [Venue.levelsPerVenue]; a
  /// level past the last building's twenty (the hotel runs on) repeats them.
  static int storeyOf(Level level) {
    final n = Venue.levelsPerVenue;
    return ((level.number - level.venue.firstLevel) % n + n) % n + 1;
  }

  static ShaftBand of(Level level) {
    final storey = storeyOf(level);
    var band = ShaftBand.ground;
    for (final b in values) {
      if (storey >= firstStorey[b.index]) band = b;
    }
    return band;
  }
}

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

  /// An icon from the approved set.
  static String icon(GameIcon i) => '$_dir/icon_${i.file}.webp';

  /// A lift kind's badge, or null for the normal lift (it has none).
  static String? kindIcon(LiftKind kind) => kind == LiftKind.normal ? null : '$_dir/icon_kind_${kind.name}.webp';

  /// A lobby scenario's icon: cones for maintenance, a stopwatch for rush hour.
  static String scenarioIcon(Scenario s) => switch (s) {
        Scenario.maintenance => '$_dir/icon_scene_maintenance.webp',
        Scenario.rushHour => '$_dir/icon_scene_rush.webp',
      };

  /// The venues with painted backdrops (the rest keep their painted look).
  static const Set<Venue> backdropVenues = {Venue.society};

  /// The shaft wall behind the rails, cabin, NEXT strip and gauge, or null
  /// for a venue without one. 1200 x 800 px.
  static String? shaftBackdrop(Venue venue, ShaftBand band) =>
      backdropVenues.contains(venue) ? '$_dir/bg_${venue.name}_shaft_${band.name}.webp' : null;

  /// The lobby floor under the lanes, or null for a venue without one.
  /// 1200 x 900 px, lifted so lane text and floor tags keep 4.3:1 contrast.
  static String? lobbyFloor(Venue venue) => backdropVenues.contains(venue) ? '$_dir/bg_${venue.name}_lobby.webp' : null;

  /// The cover art behind a wide screen: the landscape scene (1920 x 1080) for a window wider than tall, the portrait
  /// one (1080 x 1920) for a tablet standing up. It lives in `assets/cover/`, outside the sprite table: it is
  /// decoded only on a wide screen, never preloaded.
  static String coverArt({required bool landscape}) =>
      landscape ? 'assets/cover/cover_landscape.webp' : 'assets/cover/cover_portrait.webp';

  /// The lift doorway in every shaft wall, as fractions of the image: the
  /// cabin is drawn standing in it (`painters/shaft_painter.dart`).
  static const ui.Rect shaftDoorway = ui.Rect.fromLTRB(332 / 1200, 72 / 800, 868 / 1200, 744 / 800);

  /// Every backdrop the game ships.
  static List<String> get backdrops => [
        for (final v in Venue.values) ...[
          for (final b in ShaftBand.values)
            if (shaftBackdrop(v, b) case final path?) path,
          if (lobbyFloor(v) case final path?) path,
        ],
      ];

  /// Every icon the game ships.
  static List<String> get icons => [
        for (final i in GameIcon.values) icon(i),
        for (final k in LiftKind.values)
          if (kindIcon(k) case final path?) path,
        for (final s in Scenario.values) scenarioIcon(s),
      ];

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
        ...icons,
        ...backdrops,
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

  ui.Image? icon(GameIcon i) => _images[ArtAssets.icon(i)];

  ui.Image? kindIcon(LiftKind kind) => switch (ArtAssets.kindIcon(kind)) {
        final path? => _images[path],
        null => null,
      };

  ui.Image? scenarioIcon(Scenario s) => _images[ArtAssets.scenarioIcon(s)];

  /// The shaft wall for [level] (its venue and storey band), or null.
  ui.Image? shaftBackdrop(Level level) => switch (ArtAssets.shaftBackdrop(level.venue, ShaftBand.of(level))) {
        final path? => _images[path],
        null => null,
      };

  /// The lobby floor for [venue], or null.
  ui.Image? lobbyFloor(Venue venue) => switch (ArtAssets.lobbyFloor(venue)) {
        final path? => _images[path],
        null => null,
      };

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
