import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/motion.dart';
import 'package:lift_load/ui/painters/cabin_painter.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/widgets/lift_shaft.dart';
import 'package:lift_load/ui/widgets/entrance.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';
import 'responsive_test.dart' show crashLevel;

/// Counts [finishSend] calls and records where the doors were at each one.
class _SpyController extends GameController {
  _SpyController(Level level)
      : super(
          profile: Profile.fresh(DateTime(2026, 10, 22)),
          ads: StubAdsService(delay: Duration.zero),
          analytics: DebugAnalytics(),
          clock: () => DateTime(2026, 10, 22, 12),
          levelFor: (_) => level,
        );

  /// Reads the doors as the play screen last drew them.
  double Function()? doors;
  final List<double> doorsAtFinish = [];

  @override
  void finishSend() {
    doorsAtFinish.add(doors?.call() ?? double.nan);
    super.finishSend();
  }
}

/// A bundle that serves every asset but [missing].
class _MissingBundle extends CachingAssetBundle {
  _MissingBundle(this.missing);

  final String missing;

  @override
  Future<ByteData> load(String key) => key == missing ? Future.error(FlutterError('no $key')) : rootBundle.load(key);
}

Level _level(LiftKind kind) => variety(Venue.society, kind, null);

Finder _painter<T>() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is T);

T? _painterOf<T>(WidgetTester tester) {
  final found = _painter<T>();
  return found.evaluate().isEmpty ? null : tester.widget<CustomPaint>(found).painter as T;
}

/// The doors as the play screen last drew them. Read off the element tree
/// directly, so it also works from inside a pump (the spy's probe).
double _doors(WidgetTester tester) => (find.byType(LiftShaft).evaluate().single.widget as LiftShaft).doorOpen;

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Boards the first lane's front (they go to the waiting lift's floor in
/// [variety]) and lets the walk land.
Future<void> _board(WidgetTester tester, GameController c) async {
  c.tapQueue(0);
  c.tapLift();
  expect(c.game.riders, isNotEmpty);
  // The walk starts on the next frame.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

void main() {
  setUp(() async {
    SpriteCache.instance.debugReset();
    await SpriteCache.instance.load();
  });

  test('each kind of lift has its interior and two leaves, and they decode', () {
    expect(SpriteCache.instance.failed, isEmpty);
    for (final k in LiftKind.values) {
      final art = SpriteCache.instance.cabin(k);
      expect(art, isNotNull, reason: k.name);
      // Half the 196 x 214-unit cabin each, the same size left and right.
      for (final leaf in [art!.left, art.right]) {
        expect(leaf.width / leaf.height, closeTo(98 / 214, 0.01), reason: k.name);
      }
      expect(art.left.width, art.right.width);
      expect(art.left.height, art.right.height);
      expect(art.interior.width, greaterThan(0));
      expect(
          ArtAssets.all,
          containsAll([
            ArtAssets.cabinInterior(k),
            ArtAssets.cabinDoor(k, left: true),
            ArtAssets.cabinDoor(k, left: false),
          ]));
    }
  });

  test('open, the leaves sit fully outside the cabin; closed, they meet at the centre', () {
    const size = Size(196, 214);
    final cabin = Offset.zero & size;
    for (final left in [true, false]) {
      final open = CabinLeavesPainter.leafRect(size, 1, left: left);
      expect(open.intersect(cabin).width, lessThanOrEqualTo(0), reason: 'open, left $left');
      final shut = CabinLeavesPainter.leafRect(size, 0, left: left);
      expect(shut.width, size.width / 2);
      expect(shut.height, size.height);
      expect(left ? shut.right : shut.left, size.width / 2);
      expect(left ? shut.left : shut.right, left ? 0 : size.width);
    }
  });

  for (final kind in LiftKind.values) {
    testWidgets('a ${kind.name} lift draws its own interior, doors open while playing', (tester) async {
      final c = controller(DebugAnalytics(), levelFor: (_) => _level(kind));
      await pumpPlay(tester, c);
      expect(c.game.liftKind, kind);
      final art = SpriteCache.instance.cabin(kind)!;
      expect(_painterOf<CabinArtPainter>(tester)!.interior, same(art.interior));
      expect(_painter<CabinInteriorPainter>(), findsNothing);
      // Open: no leaf is drawn.
      expect(_doors(tester), 1);
      expect(_painter<CabinLeavesPainter>(), findsNothing);
      // The floors this lift serves are in the display above the cabin, once.
      final display = find.byKey(LiftShaft.floorDisplayKey);
      for (final f in c.game.liftFloors) {
        expect(find.descendant(of: display, matching: find.textContaining(f.label)), findsOneWidget);
      }
    });
  }

  testWidgets('send: the doors close, then the lift rises, finishSend once, then the next lift opens', (tester) async {
    await _phone(tester);
    final c = _SpyController(_level(LiftKind.express))..startLevel();
    c.doors = () => _doors(tester);
    await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
    await tester.pump(const Duration(milliseconds: 50));
    await _board(tester, c);
    expect(_doors(tester), 1);

    c.send();
    await tester.pump();
    expect(c.game.phase, Phase.departing);
    // Mid-close: the leaves are part way in, the seam shadow and dim showing.
    await _pumpFor(tester, CabinMotion.doorTravel ~/ 2);
    final mid = _doors(tester);
    expect(mid, inExclusiveRange(0, 1));
    final leaves = _painterOf<CabinLeavesPainter>(tester)!;
    final art = SpriteCache.instance.cabin(LiftKind.express)!;
    expect(leaves.left, same(art.left));
    expect(leaves.right, same(art.right));
    expect(leaves.open, mid);
    // The cabin has not moved yet.
    final cabinTop = tester.getTopLeft(find.bySemanticsLabel(RegExp('Tap to board the selected resident'))).dy;

    // Closed after the full close (travel and settle); still departing.
    await _pumpFor(tester, CabinMotion.doorClose - CabinMotion.doorTravel ~/ 2);
    expect(_doors(tester), 0);
    expect(c.game.phase, Phase.departing);
    expect(c.doorsAtFinish, isEmpty);
    expect(tester.getTopLeft(find.bySemanticsLabel(RegExp('Tap to board the selected resident'))).dy, cabinTop);

    // The rise: still closed, then the engine moves on exactly once.
    await _pumpFor(tester, CabinMotion.rise ~/ 2);
    expect(_doors(tester), 0);
    expect(c.game.phase, Phase.departing);
    await _pumpFor(tester, CabinMotion.rise);
    expect(c.doorsAtFinish, [0]);
    expect(c.game.phase, Phase.playing);
    expect(c.game.tripsUsed, 1);

    // The next lift arrives shut and opens.
    await _pumpFor(tester, CabinMotion.dropIn + CabinMotion.doorOpen);
    expect(_doors(tester), 1);
    expect(_painter<CabinLeavesPainter>(), findsNothing);
    await _pumpFor(tester, CabinMotion.sendTotal);
    expect(c.doorsAtFinish, hasLength(1), reason: 'finishSend runs once per send');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the doors settle: they bounce back a little from the seam and meet again', (tester) async {
    await _phone(tester);
    final c = controller(DebugAnalytics(), levelFor: (_) => _level(LiftKind.normal))..startLevel();
    await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
    await tester.pump(const Duration(milliseconds: 50));
    await _board(tester, c);
    c.send();
    await tester.pump();
    final seen = <double>[];
    const step = Duration(milliseconds: 10);
    for (var t = Duration.zero; t < CabinMotion.doorClose; t += step) {
      await tester.pump(step);
      seen.add(_doors(tester));
    }
    final m = Metrics.from(const Size(390, 844));
    final settle = m.doorSettle / (m.cabinWidth / 2);
    final shut = seen.indexOf(0);
    expect(shut, greaterThan(0), reason: 'the leaves reach the seam');
    final bounce = seen.sublist(shut).reduce((a, b) => a > b ? a : b);
    expect(bounce, greaterThan(0));
    expect(bounce, lessThanOrEqualTo(settle + 1e-9));
    expect(seen.last, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: the doors snap, never drawn part way, and the send completes at once', (tester) async {
    await _phone(tester);
    final c = _SpyController(_level(LiftKind.normal))..startLevel();
    c.doors = () => _doors(tester);
    await tester.pumpWidget(app(PlayScreen(controller: c)));
    c.tapQueue(0);
    c.tapLift();
    await tester.pump();
    c.send();
    // No time passes: every frame shows the doors fully open or fully shut.
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      expect(_doors(tester), anyOf(0, 1));
      expect(_painter<CabinLeavesPainter>().evaluate().length, lessThanOrEqualTo(1));
    }
    expect(c.doorsAtFinish, hasLength(1));
    expect(c.game.phase, Phase.playing);
    expect(c.game.tripsUsed, 1);
    expect(_doors(tester), 1);
    expect(_painter<CabinLeavesPainter>(), findsNothing);
  });

  testWidgets('an overload falls with the doors open, and the fall is not delayed', (tester) async {
    await _phone(tester);
    final c = controller(DebugAnalytics(), levelFor: (_) => crashLevel())..startLevel();
    await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
    await _board(tester, c);
    c.tapQueue(1);
    c.tapLift();
    await tester.pump();
    expect(c.game.phase, Phase.falling);
    // The walk, then part way down.
    await _pumpFor(tester, CabinMotion.fall);
    expect(c.game.phase, Phase.falling);
    expect(_doors(tester), 1);
    expect(_painter<CabinLeavesPainter>(), findsNothing);
    await _pumpFor(tester, CabinMotion.fall);
    expect(c.game.phase, Phase.failed);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with the switch off the cabin is painted, and riders keep the feet line', (tester) async {
    final c = controller(DebugAnalytics(), levelFor: (_) => _level(LiftKind.service));
    c.startLevel();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(SpriteArtScope(enabled: false, child: PlayScreen(controller: c))));
    expect(_painter<CabinInteriorPainter>(), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is CabinDoorsPainter), findsOneWidget);
    expect(_painter<CabinArtPainter>(), findsNothing);
    c.tapQueue(0);
    c.tapLift();
    await tester.pump();
    final cabin = tester.getRect(find.bySemanticsLabel(RegExp('Tap to board the selected resident')));
    final rider = find.descendant(of: find.byType(LiftShaft), matching: find.byType(ResidentFigure)).first;
    final box = tester.getRect(rider);
    tester.element(find.byType(LandSettle)).visitAncestorElements((e) { final ro = e.renderObject; if (ro is RenderBox && ro.hasSize) { print('DBG ${e.widget.runtimeType} ${ro.size} ${ro.localToGlobal(Offset.zero)}'); } return true; });
    final feet = box.bottom - box.height * ResidentFigure.belowFeet;
    expect(feet, closeTo(cabin.top + cabin.height * Metrics.cabinFeetLine, 0.5));
  });

  testWidgets('a cabin image that fails keeps that kind painted, the others in art', (tester) async {
    SpriteCache.instance.debugReset();
    final missing = ArtAssets.cabinDoor(LiftKind.old, left: false);
    await tester.runAsync(() => SpriteCache.instance.load(bundle: _MissingBundle(missing)));
    expect(SpriteCache.instance.failed, {missing});
    expect(SpriteCache.instance.cabin(LiftKind.old), isNull);
    expect(SpriteCache.instance.cabin(LiftKind.normal), isNotNull);

    final old = controller(DebugAnalytics(), levelFor: (_) => _level(LiftKind.old));
    await pumpPlay(tester, old);
    expect(_painter<CabinInteriorPainter>(), findsOneWidget);
    expect(_painter<CabinArtPainter>(), findsNothing);

    final normal = controller(DebugAnalytics(), levelFor: (_) => _level(LiftKind.normal));
    await pumpPlay(tester, normal);
    expect(_painter<CabinArtPainter>(), findsOneWidget);
  });
}
