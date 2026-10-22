import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/motion.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/widgets/effects.dart';
import 'package:lift_load/ui/widgets/lift_shaft.dart';
import 'package:lift_load/ui/widgets/punch.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';
import 'responsive_test.dart' show crashLevel, sizes;

/// Counts [finishSend] calls.
class _SpyController extends GameController {
  _SpyController(Level level)
      : super(
          profile: Profile.fresh(DateTime(2026, 10, 22)),
          ads: StubAdsService(delay: Duration.zero),
          analytics: DebugAnalytics(),
          clock: () => DateTime(2026, 10, 22, 12),
          levelFor: (_) => level,
        );

  int finishes = 0;

  @override
  void finishSend() {
    finishes++;
    super.finishSend();
  }
}

/// An uncle at the front of lane 0 on a lift of [capacity], and a kid in
/// lane 1 so the level goes on after the send. Bench seat 0 can take a
/// lane-0 resident; lane 2 has a second uncle for the bench tests.
Level _trip(int capacity) => Level(
      number: 5,
      capacity: capacity,
      trips: 6,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: const [Floor.coral],
      queues: const [
        [Resident(id: 1, type: ResidentType.uncle, floor: Floor.coral)],
        [Resident(id: 2, type: ResidentType.kid, floor: Floor.coral)],
        [Resident(id: 3, type: ResidentType.uncle, floor: Floor.coral)],
        [],
      ],
    );

/// The uncle alone fills the lift to the brim (perfect), to about 85%
/// (good), or to a quarter (half-empty).
final int _uncle = ResidentType.uncle.kg;
Level get _perfect => _trip(_uncle);
Level get _good => _trip((_uncle / 0.85).round());
Level get _halfEmpty => _trip(_uncle * 4);

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Boards the uncle in lane 0, lets the walk land, and sends.
Future<void> _boardAndSend(WidgetTester tester, GameController c) async {
  c.tapQueue(0);
  c.tapLift();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  c.send();
  await tester.pump();
  expect(c.game.phase, Phase.departing);
}

Finder _inSlam(Finder f) => find.descendant(of: find.byType(ScoreSlam), matching: f);

double _bump(WidgetTester tester) => (find.byType(LiftShaft).evaluate().single.widget as LiftShaft).cabinBump;

List<Burst> _bursts(WidgetTester tester) => tester.state<EffectsLayerState>(find.byType(EffectsLayer)).debugBursts;

/// The rect of the selected resident's figure (the one under the active hop).
Rect _hopper(WidgetTester tester) => tester.getRect(find
    .descendant(of: find.byWidgetPredicate((w) => w is SelectedHop && w.active), matching: find.byType(ResidentFigure))
    .first);

void main() {
  setUpAll(() => SpriteCache.instance.load());

  group('motion constants', () {
    test('the bump rests at both ends, dips and squashes, then rebounds above rest', () {
      for (final t in [0.0, 1.0]) {
        final b = PunchMotion.bumpAt(t);
        expect((b.dy, b.sx, b.sy), (0.0, 1.0, 1.0));
      }
      final down = PunchMotion.bumpAt(PunchMotion.bumpDownAt);
      expect(down.dy, closeTo(PunchMotion.bumpDrop, 1e-9));
      expect(down.sy, lessThan(1));
      expect(down.sx, greaterThan(1));
      final up = PunchMotion.bumpAt(PunchMotion.bumpUpAt);
      expect(up.dy, closeTo(-PunchMotion.bumpRebound, 1e-9));
      expect((up.sx, up.sy), (1.0, 1.0));
    });

    test('the send gets at most 150 ms slower, and the slam overshoots then fades', () {
      // Slice 2: doors 420, rise 500, drop-in 450, open 360.
      const before = Duration(milliseconds: 420 + 500 + 450 + 360);
      expect(CabinMotion.sendTotal - before, lessThanOrEqualTo(const Duration(milliseconds: 150)));
      expect(CabinMotion.sendTotal - before, PunchMotion.bump);
      final scales = [for (var t = 0.0; t <= 1; t += 0.01) PunchMotion.slamAt(t).scale];
      expect(scales.first, PunchMotion.slamFrom);
      expect(scales.reduce((a, b) => a > b ? a : b), greaterThan(1), reason: 'overshoot');
      expect(PunchMotion.slamAt(0.5).opacity, 1);
      expect(PunchMotion.slamAt(1).opacity, 0);
    });
  });

  test('a selected front rises and hops inside the floor\'s top room at every size', () {
    for (final size in sizes.values) {
      final m = Metrics.from(size);
      expect(m.selectedLift + PunchMotion.hopHeight * m.scale, lessThanOrEqualTo(m.laneTop + 1e-9), reason: '$size');
    }
  });

  group('score slam', () {
    for (final (name, level, rating, coins) in [
      ('perfect', () => _perfect, TripRating.perfect, Formulas.perfectTripCoins),
      ('good', () => _good, TripRating.good, Formulas.greenTripCoins),
      ('half-empty', () => _halfEmpty, TripRating.halfEmpty, 0),
    ]) {
      testWidgets('a $name trip slams its rating and coins in once the doors shut', (tester) async {
        await _phone(tester);
        final c = _SpyController(level())..startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
        await _boardAndSend(tester, c);
        expect(c.sentRating, rating);
        // Doors closing: nothing yet.
        await _pumpFor(tester, CabinMotion.doorClose ~/ 2);
        expect(find.byType(ScoreSlam), findsNothing);
        await _pumpFor(tester, CabinMotion.doorClose ~/ 2 + PunchMotion.slamIn);
        expect(find.byType(ScoreSlam), findsOneWidget);
        expect(_inSlam(find.text(ScoreSlam.label(rating))), findsWidgets);
        if (coins > 0) {
          expect(_inSlam(find.text('+$coins')), findsWidgets);
        } else {
          expect(_inSlam(find.textContaining('+')), findsNothing);
        }
        // Coins fly only on a good or perfect trip, from the coin icon.
        final flying = _bursts(tester).where((b) => b.kind == BurstKind.coins).toList();
        if (coins > 0) {
          expect(flying, hasLength(1));
          expect(flying.single.count, rating == TripRating.perfect ? PunchMotion.coinsPerfect : PunchMotion.coinsGood);
          expect(flying.single.sprite, same(SpriteCache.instance.icon(GameIcon.coin)));
          expect(flying.single.label, isNull, reason: 'the slam shows the coins');
        } else {
          expect(flying, isEmpty);
        }
        // The slam plays on over the arrival, then goes; the pill pulses once
        // the coins land.
        await _pumpFor(tester, PunchMotion.slam);
        expect(find.byType(ScoreSlam), findsNothing);
        expect(c.finishes, 1);
        final pulse = tester.widget<Pulse>(find.byType(Pulse));
        expect(pulse.serial, coins > 0 ? 1 : 0);
        await _pumpFor(tester, CabinMotion.sendTotal);
        expect(c.finishes, 1, reason: 'finishSend runs once per send');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('a crash slams nothing and flies no coins', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => crashLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      c.tapQueue(0);
      c.tapLift();
      await tester.pump(const Duration(milliseconds: 300));
      c.tapQueue(1);
      c.tapLift();
      await tester.pump();
      expect(c.game.phase, Phase.falling);
      for (var t = Duration.zero; t < CabinMotion.fall * 2; t += const Duration(milliseconds: 50)) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(ScoreSlam), findsNothing);
        expect(_bursts(tester).where((b) => b.kind == BurstKind.coins), isEmpty);
        expect(_bump(tester), 0);
      }
      expect(c.game.phase, Phase.failed);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the cabin bumps after the doors shut and before it rises; finishSend once', (tester) async {
      await _phone(tester);
      final c = _SpyController(_perfect)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await _boardAndSend(tester, c);
      final cabin = find.bySemanticsLabel(RegExp('Tap to board the selected resident'));
      final rest = tester.getRect(cabin);
      var bumped = false, lower = false;
      const step = Duration(milliseconds: 10);
      for (var t = Duration.zero; t < CabinMotion.doorClose + PunchMotion.bump; t += step) {
        await tester.pump(step);
        final shaft = find.byType(LiftShaft).evaluate().single.widget as LiftShaft;
        if (shaft.cabinBump > 0 && shaft.cabinBump < 1) {
          bumped = true;
          expect(shaft.doorOpen, 0, reason: 'the bump follows the doors');
          if (tester.getRect(cabin).bottom > rest.bottom + 0.5) lower = true;
        }
      }
      expect(bumped, isTrue);
      expect(lower, isTrue, reason: 'the cabin dips on its floor');
      expect(c.finishes, 0);
      await _pumpFor(tester, CabinMotion.rise + const Duration(milliseconds: 60));
      expect(c.finishes, 1);
      await _pumpFor(tester, CabinMotion.sendTotal);
      expect(c.finishes, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('lobby life', () {
    testWidgets('free seats breathe only while a lane resident is selected', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _halfEmpty)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(const Duration(milliseconds: 50));
      Iterable<Breathe> breathing() => tester.widgetList<Breathe>(find.byType(Breathe)).where((b) => b.active);
      expect(find.byType(Breathe), findsNWidgets(c.game.bench.length));
      expect(breathing(), isEmpty);

      c.tapQueue(0);
      await tester.pump();
      expect(breathing(), hasLength(c.game.bench.length));
      // The seat grows and shrinks a little with its breath.
      final seat = find.byWidgetPredicate((w) => w is Breathe && w.active).first;
      Matrix4 scale() =>
          tester.widget<Transform>(find.descendant(of: seat, matching: find.byType(Transform)).first).transform;
      final a = scale().getMaxScaleOnAxis();
      await tester.pump(Duration(milliseconds: (PunchMotion.seatBreathe * 1000 / 2).round()));
      final b = scale().getMaxScaleOnAxis();
      expect((a - b).abs(), greaterThan(PunchMotion.seatBreatheScale / 4));
      expect(a, inInclusiveRange(1, 1 + PunchMotion.seatBreatheScale));

      // Seat them: one seat taken, nothing selected, nothing breathes.
      c.tapBench(0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(breathing(), isEmpty);
      // A bench resident selected cannot take another seat: still nothing.
      c.tapBench(0);
      await tester.pump();
      expect(c.game.selection, Selection.bench(0));
      expect(breathing(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('only the selected resident hops, on a warm glow, in a lane or on the bench', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _halfEmpty)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(const Duration(milliseconds: 50));
      Iterable<SelectedHop> hopping() =>
          tester.widgetList<SelectedHop>(find.byType(SelectedHop)).where((h) => h.active);
      expect(hopping(), isEmpty);
      expect(find.byType(HopGlow), findsWidgets);
      expect(tester.widgetList<HopGlow>(find.byType(HopGlow)).where((g) => g.active), isEmpty);

      c.tapQueue(2);
      await tester.pump();
      expect(hopping(), hasLength(1));
      expect(tester.widgetList<HopGlow>(find.byType(HopGlow)).where((g) => g.active), hasLength(1));
      // The hopper is lane 2's front (the second uncle at a front).
      final active = find.byWidgetPredicate((w) => w is SelectedHop && w.active);
      expect(find.descendant(of: active, matching: find.byType(ResidentFigure)), findsOneWidget);
      final lane2 = tester.getRect(find.bySemanticsLabel(RegExp(r'^Uncle going to')).last);
      expect(_hopper(tester).center.dx, closeTo(lane2.center.dx, 1));
      // It lifts off from rest, reaches its height half way, and comes back down.
      double lift() => -tester
          .widget<Transform>(find.descendant(of: active, matching: find.byType(Transform)).first)
          .transform
          .getTranslation()
          .y;
      expect(lift(), closeTo(0, 0.01));
      final half = Duration(milliseconds: (PunchMotion.hop * 1000 / 2).round());
      await tester.pump(half);
      expect(lift(), closeTo(PunchMotion.hopHeight, 0.05));
      await tester.pump(half);
      expect(lift(), closeTo(0, 0.05));

      // On the bench: the seated resident hops, nobody in the lanes does.
      c.tapBench(0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(hopping(), isEmpty);
      c.tapBench(0);
      await tester.pump();
      expect(hopping(), hasLength(1));
      expect(
          find.descendant(
              of: find.bySemanticsLabel(RegExp(r'^Bench: ')),
              matching: find.byWidgetPredicate((w) => w is SelectedHop && w.active)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: no hop, no breath, no bump, no slam, no coins; the send completes at once',
        (tester) async {
      await _phone(tester);
      final c = _SpyController(_perfect)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      c.tapQueue(2);
      await tester.pump();
      // Selected and glowing, standing still.
      expect(tester.widgetList<HopGlow>(find.byType(HopGlow)).where((g) => g.active), hasLength(1));
      await tester.pump();
      final rest = _hopper(tester);
      final seat = find.byWidgetPredicate((w) => w is Breathe && w.active).first;
      final seatRect = tester.getRect(seat);
      expect(find.descendant(of: seat, matching: find.byType(Transform)), findsNothing);
      await tester.pump(const Duration(milliseconds: 550));
      expect(_hopper(tester), rest);
      expect(tester.getRect(seat), seatRect);

      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      c.send();
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        expect(find.byType(ScoreSlam), findsNothing);
        expect(_bursts(tester), isEmpty);
        expect(_bump(tester), 0);
      }
      expect(c.finishes, 1);
      expect(c.game.phase, Phase.playing);
      expect(c.game.tripsUsed, 1);
      expect(tester.widget<Pulse>(find.byType(Pulse)).serial, 0);
    });
  });
}
