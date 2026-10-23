import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/painters/lobby_painter.dart';
import 'package:lift_load/ui/painters/shaft_painter.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/widgets/lobby.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';

/// A bundle that serves every asset but [missing].
class _MissingBundle extends CachingAssetBundle {
  _MissingBundle(this.missing);

  final String missing;

  @override
  Future<ByteData> load(String key) => key == missing ? Future.error(FlutterError('no $key')) : rootBundle.load(key);
}

/// A small lobby on level [number] of [venue].
Level _level(int number, {Venue? venue}) => Level(
      number: number,
      capacity: 300,
      trips: 6,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: const [Floor.coral, Floor.teal],
      venue: venue ?? Venue.of(number),
      queues: const [
        [Resident(id: 1, type: ResidentType.uncle, floor: Floor.coral)],
        [Resident(id: 2, type: ResidentType.kid, floor: Floor.teal)],
        [Resident(id: 3, type: ResidentType.aunty, floor: Floor.coral)],
        [],
      ],
    );

ShaftPainter _shaft(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ShaftPainter)).painter!
        as ShaftPainter;

Finder _lobbyArt() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LobbyFloorPainter);
Finder _pattern() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FloorPatternPainter);

Future<void> _play(WidgetTester tester, Level level, {bool sprites = true}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = controller(DebugAnalytics(), levelFor: (_) => level)..startLevel();
  await tester.pumpWidget(app(SpriteArtScope(enabled: sprites, child: PlayScreen(controller: c))));
}

void main() {
  setUp(() async {
    SpriteCache.instance.debugReset();
    await SpriteCache.instance.load();
  });

  test('storey bands: 1-7 ground, 8-14 mid, 15-20 high, in every building and its repeats', () {
    for (var storey = 1; storey <= Venue.levelsPerVenue; storey++) {
      final band = storey <= 7
          ? ShaftBand.ground
          : storey <= 14
              ? ShaftBand.mid
              : ShaftBand.high;
      for (final v in Venue.values) {
        expect(ShaftBand.of(_level(v.firstLevel + storey - 1, venue: v)), band, reason: '${v.name} storey $storey');
      }
      // The hotel runs on past level 100, starting its storeys over.
      expect(ShaftBand.of(_level(Venue.hotel.firstLevel + Venue.levelsPerVenue + storey - 1)), band);
    }
    expect(ShaftBand.of(_level(3)), ShaftBand.ground);
    expect(ShaftBand.of(_level(10)), ShaftBand.mid);
    expect(ShaftBand.of(_level(18)), ShaftBand.high);
    expect(ShaftBand.firstStorey, hasLength(ShaftBand.values.length));
  });

  test('Sunrise Towers has a shaft wall per band and a lobby floor; no other venue has any', () {
    for (final v in Venue.values) {
      for (final b in ShaftBand.values) {
        final path = ArtAssets.shaftBackdrop(v, b);
        expect(path != null, v == Venue.society, reason: '${v.name} ${b.name}');
        if (path != null) expect(ArtAssets.all, contains(path));
      }
      expect(ArtAssets.lobbyFloor(v) != null, v == Venue.society, reason: v.name);
    }
    expect(SpriteCache.instance.failed, isEmpty);
    for (final b in ShaftBand.values) {
      final image = SpriteCache.instance.shaftBackdrop(_level(ShaftBand.firstStorey[b.index]))!;
      expect((image.width, image.height), (1200, 800), reason: b.name);
    }
    final floor = SpriteCache.instance.lobbyFloor(Venue.society)!;
    expect((floor.width, floor.height), (1200, 900));
  });

  test('the procedural walls and floors from the earlier pass are not shipped', () {
    final shipped = Directory('assets/art').listSync().map((f) => f.uri.pathSegments.last).toList();
    expect(shipped.where((f) => f.startsWith('society_wall_') || f.startsWith('society_floor_')), isEmpty);
    expect(ArtAssets.all.where((p) => p.contains('society_wall_') || p.contains('society_floor_')), isEmpty);
    expect(shipped.where((f) => f.startsWith('bg_')).toSet(), {for (final p in ArtAssets.backdrops) p.split('/').last});
  });

  test('the cabin stands in the doorway, and the wall always covers the panel', () {
    const image = Size(1200, 800);
    for (final size in [
      const Size(390, 844),
      const Size(320, 568),
      const Size(360, 640),
      const Size(375, 667),
      const Size(412, 915),
      const Size(430, 932),
      const Size(768, 1024),
      const Size(1366, 1024),
    ]) {
      final m = Metrics.from(size);
      final panel = Size(m.columnWidth - 2 * m.gap, m.shaftHeight);
      final railLeft = 10 * m.scale + m.nextColumn + 8 * m.scale;
      final railRight = railLeft + m.cabinWidth;
      final floorY = m.cabinTop + m.cabinHeight;
      final at = ShaftPainter.placement(image, panel,
          railLeft: railLeft, railRight: railRight, floorY: floorY, channel: m.shaftChannel);
      expect(at.left, lessThanOrEqualTo(1e-6), reason: '$size');
      expect(at.top, lessThanOrEqualTo(1e-6), reason: '$size');
      expect(at.right, greaterThanOrEqualTo(panel.width - 1e-6), reason: '$size');
      // Down to the cabin's floor the image is the wall; under it (the message
      // strip) the painter repeats the image's floor row, so the strip is
      // never longer than the floor the image itself shows there.
      expect(at.bottom, greaterThanOrEqualTo(floorY - 1e-6), reason: '$size');
      expect(panel.height - at.bottom, lessThanOrEqualTo(m.messageHeight + 1e-6), reason: '$size');
      const door = ArtAssets.shaftDoorway;
      final doorLeft = at.left + door.left * at.width, doorRight = at.left + door.right * at.width;
      // At least as wide as the cabin and its channels.
      expect(doorRight - doorLeft, greaterThanOrEqualTo(railRight - railLeft + 2 * m.shaftChannel - 1e-6));
      if (m.form == FormFactor.phone || m.form == FormFactor.compactPhone) {
        // On phones the doorway is centred on the cabin and meets its floor.
        expect((doorLeft + doorRight) / 2, closeTo((railLeft + railRight) / 2, 0.5), reason: '$size');
        expect(at.top + door.bottom * at.height, closeTo(floorY, 0.5), reason: '$size');
      }
    }
  });

  for (final (number, band) in [(3, ShaftBand.ground), (10, ShaftBand.mid), (18, ShaftBand.high)]) {
    testWidgets('level $number draws the ${band.name} wall and the lobby floor stays put under the lanes',
        (tester) async {
      await _play(tester, _level(number));
      final art = SpriteCache.instance.image(ArtAssets.shaftBackdrop(Venue.society, band)!);
      expect(_shaft(tester).art, same(art));
      expect(_lobbyArt(), findsOneWidget);
      expect(tester.widget<CustomPaint>(_lobbyArt()).painter, isA<LobbyFloorPainter>());
      expect((tester.widget<CustomPaint>(_lobbyArt()).painter! as LobbyFloorPainter).image,
          same(SpriteCache.instance.lobbyFloor(Venue.society)));
      expect(tester.widget<QueueLanes>(find.byType(QueueLanes)).paintFloor, isFalse);
      expect(_pattern(), findsNothing);
      // The floor sits outside the scroll view, so it does not move with the lanes.
      expect(find.ancestor(of: _lobbyArt(), matching: find.byType(SingleChildScrollView)), findsNothing);
      final lanes = tester.getRect(find.byType(QueueLanes));
      final floor = tester.getRect(_lobbyArt());
      // Inset like the lanes' own floor (their margin is inside QueueLanes).
      final gap = Metrics.from(const Size(390, 844)).gap;
      expect(floor.left, closeTo(lanes.left + gap, 0.5));
      expect(floor.right, closeTo(lanes.right - gap, 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('another venue keeps its painted wall and floor', (tester) async {
    await _play(tester, _level(30));
    expect(_shaft(tester).art, isNull);
    expect(_lobbyArt(), findsNothing);
    expect(_pattern(), findsOneWidget);
    expect(tester.widget<QueueLanes>(find.byType(QueueLanes)).paintFloor, isTrue);
  });

  testWidgets('with the switch off Sunrise Towers is painted as before', (tester) async {
    await _play(tester, _level(3), sprites: false);
    expect(_shaft(tester).art, isNull);
    expect(_lobbyArt(), findsNothing);
    expect(_pattern(), findsOneWidget);
  });

  testWidgets('a backdrop that fails keeps that wall painted, the others in art', (tester) async {
    SpriteCache.instance.debugReset();
    final missing = ArtAssets.shaftBackdrop(Venue.society, ShaftBand.mid)!;
    await tester.runAsync(() => SpriteCache.instance.load(bundle: _MissingBundle(missing)));
    expect(SpriteCache.instance.failed, {missing});
    await _play(tester, _level(10));
    expect(_shaft(tester).art, isNull);
    // The lobby floor loaded, so it still shows.
    expect(_lobbyArt(), findsOneWidget);
    await _play(tester, _level(3));
    expect(_shaft(tester).art, isNotNull);
  });

  testWidgets('a lobby floor that fails falls back to the painted floor', (tester) async {
    SpriteCache.instance.debugReset();
    final missing = ArtAssets.lobbyFloor(Venue.society)!;
    await tester.runAsync(() => SpriteCache.instance.load(bundle: _MissingBundle(missing)));
    await _play(tester, _level(3));
    expect(_lobbyArt(), findsNothing);
    expect(_pattern(), findsOneWidget);
    expect(_shaft(tester).art, isNotNull);
  });
}
