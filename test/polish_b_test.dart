import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/motion.dart';
import 'package:lift_load/ui/painters/gauge_painter.dart';
import 'package:lift_load/ui/painters/resident_painter.dart';
import 'package:lift_load/ui/painters/shaft_painter.dart';
import 'package:lift_load/ui/screens/home_screen.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/theme.dart';
import 'package:lift_load/ui/widgets/count_up.dart';
import 'package:lift_load/ui/widgets/effects.dart';
import 'package:lift_load/ui/widgets/entrance.dart';
import 'package:lift_load/ui/widgets/glossy.dart';
import 'package:lift_load/ui/widgets/glow_pulse.dart';
import 'package:lift_load/ui/widgets/lift_shaft.dart';
import 'package:lift_load/ui/widgets/load_gauge.dart';
import 'package:lift_load/ui/widgets/play_bar.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';
import 'responsive_test.dart' show crashLevel, sizes, winLevel;

/// The premium motion pass (PRD v1.7 polish pass, slice B): the screen
/// entrance, springy buttons, the ready pulse on Send, the walk and its
/// landing, the gauge, the floor roll and chime, the ride, the sheets, the
/// counters, the reveal and the home screen. Every piece is the same for
/// every resident, stays inside `motion.dart`, and holds still when motion is
/// reduced.

/// Counts [finishSend] calls and the count-up ticks.
class _SpyController extends GameController {
  _SpyController(Level level, {Profile? profile})
      : super(
          profile: profile ?? Profile.fresh(DateTime(2026, 10, 22)),
          ads: StubAdsService(delay: Duration.zero),
          analytics: DebugAnalytics(),
          clock: () => DateTime(2026, 10, 22, 12),
          levelFor: (_) => level,
        );

  int finishes = 0;
  int ticks = 0;

  @override
  void finishSend() {
    finishes++;
    super.finishSend();
  }

  @override
  void countTick() {
    ticks++;
    super.countTick();
  }

  void poke() => notifyListeners();
}

Future<void> _phone(WidgetTester tester, [Size size = const Size(390, 844)]) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpFor(WidgetTester tester, Duration total, {int step = 20}) async {
  for (var t = 0; t < total.inMilliseconds; t += step) {
    await tester.pump(Duration(milliseconds: step));
  }
}

/// Selects lane [lane]'s front, boards it, and lets the walker land.
Future<void> _board(WidgetTester tester, GameController c, [int lane = 0]) async {
  c.tapQueue(lane);
  c.tapLift();
  await tester.pump();
  await tester.pump(BoardMotion.flight + const Duration(milliseconds: 20));
}

/// [type] at the front of lane 0 and a kid in lane 1, one floor, room for all.
Level _flat(ResidentType type, {int capacity = 600}) => Level(
      number: 5,
      capacity: capacity,
      trips: 6,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: const [Floor.coral],
      queues: [
        [
          Resident(id: 1, type: type, floor: Floor.coral),
          const Resident(id: 4, type: ResidentType.kid, floor: Floor.coral)
        ],
        const [Resident(id: 2, type: ResidentType.kid, floor: Floor.coral)],
        const [],
        const [],
      ],
    );

/// The uncle alone fills a lift to the brim, to about 85%, or to a quarter.
final int _uncle = ResidentType.uncle.kg;
Level _uncleLift(int capacity) => Level(
      number: 5,
      capacity: capacity,
      trips: 6,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: const [Floor.coral],
      queues: const [
        [Resident(id: 1, type: ResidentType.uncle, floor: Floor.coral)],
        [Resident(id: 2, type: ResidentType.kid, floor: Floor.coral)],
        [],
        [],
      ],
    );
Level get _atLimit => _uncleLift(_uncle);
Level get _green => _uncleLift((_uncle / 0.85).round());
Level get _light => _uncleLift(_uncle * 4);

Finder _byName(String name) => find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

/// What each [Entrance] on screen is drawn at (0 to 1).
List<double> _entranceOpacities(WidgetTester tester) => [
      for (final e in find.byType(Entrance).evaluate())
        tester
            .widget<Opacity>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Opacity)).first)
            .opacity,
    ];

GaugePainter _gauge(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((p) => p.painter).whereType<GaugePainter>().single;

GlossyPainter _face(WidgetTester tester, Finder button) => tester
    .widgetList<CustomPaint>(find.descendant(of: button, matching: find.byType(CustomPaint)))
    .map((p) => p.painter)
    .whereType<GlossyPainter>()
    .first;

ShaftPainter _shaft(WidgetTester tester) =>
    tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((p) => p.painter).whereType<ShaftPainter>().single;

/// The feet of a walker on screen: the figure's bottom centre, and its height.
({Offset feet, double height})? _walker(WidgetTester tester) {
  final walkers = _byName('_FlightView');
  if (walkers.evaluate().isEmpty) return null;
  final p = tester.widget<Positioned>(find.descendant(of: walkers.first, matching: find.byType(Positioned)).first);
  final fig = tester.widget<ResidentFigure>(find.descendant(of: walkers.first, matching: find.byType(ResidentFigure)));
  final w = fig.height / designHeight * ResidentLook.designWidth(fig.type, fig.cargo);
  return (feet: Offset(p.left! + w / 2, p.top! + fig.height), height: fig.height);
}

void main() {
  group('motion constants', () {
    test('the entrance takes about 600 to 700 ms and everyone is placed inside it', () {
      expect(EntranceMotion.total.inMilliseconds, inInclusiveRange(600, 700));
      expect(EntranceMotion.latestEnd, lessThanOrEqualTo(EntranceMotion.total.inMilliseconds));
      for (final (start, ms) in [
        (EntranceMotion.hudStart, EntranceMotion.hudMs),
        (EntranceMotion.shaftStart, EntranceMotion.shaftMs),
        (EntranceMotion.benchStart, EntranceMotion.benchMs),
        (EntranceMotion.barStart, EntranceMotion.barMs),
      ]) {
        expect(start + ms, lessThanOrEqualTo(EntranceMotion.total.inMilliseconds));
      }
    });

    test('the front row of each lane comes in before the rows behind it', () {
      for (var lane = 0; lane < 5; lane++) {
        for (var row = 0; row < 4; row++) {
          expect(EntranceMotion.personStart(lane, row), lessThan(EntranceMotion.personStart(lane, row + 1)));
        }
      }
      expect(EntranceMotion.personStart(0, 0), lessThan(EntranceMotion.personStart(1, 0)));
    });

    test('Send takes at most 150 ms longer than before the pass', () {
      // Doors close 420, bump 140, rise 500, drop in 450, doors open 360.
      const before = Duration(milliseconds: 1870);
      expect(CabinMotion.sendTotal, lessThanOrEqualTo(before + const Duration(milliseconds: 150)));
    });

    test('springs start at rest, overshoot a little and settle at 1', () {
      for (final spring in [MotionCurves.soft, MotionCurves.pop]) {
        expect(spring.transform(0), 0);
        expect(spring.transform(1), 1);
        expect(spring.transform(0.02), lessThan(0.05));
        final peak = [for (var i = 0; i <= 100; i++) spring.transform(i / 100)].reduce((a, b) => a > b ? a : b);
        expect(peak, greaterThan(1));
        expect(peak, lessThan(1.25));
        expect(spring.transform(0.99), closeTo(1, 0.01));
      }
      final walk = [for (var i = 0; i <= 100; i++) MotionCurves.walk.transform(i / 100)];
      expect(walk.reduce((a, b) => a > b ? a : b), inInclusiveRange(1.005, 1.06));
    });
  });

  group('screen entrance', () {
    testWidgets('comes in over its slices, then rests', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      expect(_entranceOpacities(tester), everyElement(0), reason: 'first frame: nothing is in yet');
      await tester.pump(const Duration(milliseconds: 150));
      final mid = _entranceOpacities(tester);
      expect(mid.any((o) => o > 0 && o < 1), isTrue, reason: 'something is on its way');
      await tester.pump(EntranceMotion.total);
      expect(_entranceOpacities(tester), everyElement(1));
      // The people have risen into place too.
      for (final e in _byName('_StepIn').evaluate()) {
        expect(
            tester
                .widget<Opacity>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Opacity)).first)
                .opacity,
            1);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('front rows rise before the rows behind them', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      double opacityOf(int id) {
        final slot = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_StepIn' && w.key == ValueKey(id));
        return tester.widget<Opacity>(find.descendant(of: slot, matching: find.byType(Opacity)).first).opacity;
      }

      // Lane 0: id 1 in front, id 4 behind it.
      await tester.pump(Duration(milliseconds: EntranceMotion.personStart(0, 0) + 100));
      expect(opacityOf(1), greaterThan(opacityOf(4)));
      await tester.pump(EntranceMotion.total);
      expect(opacityOf(4), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: everything is in at the first frame', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      expect(_entranceOpacities(tester), everyElement(1));
      for (final e in find.byType(Entrance).evaluate()) {
        final t = tester
            .widget<Transform>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Transform)).first);
        expect(t.transform.isIdentity(), isTrue);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('a touch during the entrance still lands, and finishes it', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_entranceOpacities(tester).any((o) => o < 1), isTrue);
      final front = find.bySemanticsLabel(RegExp('^${GameController.describe(c.game.frontOf(0)!)}')).first;
      await tester.tap(front);
      await tester.pump();
      expect(c.game.selection, Selection.queue(0), reason: 'the tap selected the front of lane 0');
      expect(_entranceOpacities(tester), everyElement(1), reason: 'and the entrance is over');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a new level on the same screen comes in again, with no lift springing back', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      expect(_entranceOpacities(tester), everyElement(1));
      c.startLevel();
      await tester.pump();
      expect(_entranceOpacities(tester), everyElement(0));
      await tester.pump(EntranceMotion.total);
      expect(_entranceOpacities(tester), everyElement(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('buttons', () {
    Widget button({VoidCallback? onPressed, bool animate = true}) => app(
          Center(
            child: GlossyButton(
              key: const ValueKey('b'),
              style: SurfaceStyle.mint,
              onPressed: onPressed,
              width: 160,
              height: 60,
              child: const Text('Go'),
            ),
          ),
          animate: animate,
        );

    testWidgets('a press goes down, springs back past rest, and a sweep crosses the face once', (tester) async {
      await tester.pumpWidget(button(onPressed: () {}));
      final b = find.byKey(const ValueKey('b'));
      expect(_face(tester, b).squeeze, 1);
      final gesture = await tester.startGesture(tester.getCenter(b));
      await tester.pump();
      await tester.pump(ButtonMotion.pressIn * 2);
      expect(_face(tester, b).squeeze, closeTo(ButtonMotion.pressedScale, 0.001));
      expect(_face(tester, b).sweep, isNull, reason: 'no sweep until it is let go');
      await gesture.up();
      var peak = 1.0;
      var sweeping = 0;
      for (var t = 0; t < 700; t += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        final f = _face(tester, b);
        if (f.squeeze > peak) peak = f.squeeze;
        if (f.sweep != null) sweeping++;
      }
      expect(peak, greaterThan(1), reason: 'the spring overshoots rest');
      expect(peak, lessThan(1.06));
      expect(sweeping * 10, closeTo(ButtonMotion.sweep.inMilliseconds, 40));
      expect(_face(tester, b).squeeze, closeTo(1, 1e-3));
      expect(_face(tester, b).sweep, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(_face(tester, b).squeeze, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the label stays where it is while the face springs', (tester) async {
      await tester.pumpWidget(button(onPressed: () {}));
      final rest = tester.getTopLeft(find.text('Go'));
      final restSize = tester.getSize(find.text('Go'));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('b'))));
      await tester.pump();
      await tester.pump(ButtonMotion.pressIn * 2);
      // It sinks with the face (the existing press), but is never scaled.
      expect(tester.getSize(find.text('Go')), restSize);
      expect(tester.getTopLeft(find.text('Go')).dx, rest.dx);
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: no spring and no sweep', (tester) async {
      await tester.pumpWidget(button(onPressed: () {}, animate: false));
      final b = find.byKey(const ValueKey('b'));
      final gesture = await tester.startGesture(tester.getCenter(b));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_face(tester, b).squeeze, 1);
      await gesture.up();
      for (var t = 0; t < 500; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(_face(tester, b).squeeze, 1);
        expect(_face(tester, b).sweep, isNull);
      }
    });

    testWidgets('a disabled button neither springs nor sweeps', (tester) async {
      await tester.pumpWidget(button());
      final b = find.byKey(const ValueKey('b'));
      final gesture = await tester.startGesture(tester.getCenter(b));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_face(tester, b).squeeze, 1);
      expect(_face(tester, b).sweep, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Send ready pulse', () {
    Future<_SpyController> play(WidgetTester tester, Level level) async {
      await _phone(tester);
      final c = _SpyController(level)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      return c;
    }

    GlowPulse pulse(WidgetTester tester) => tester.widget<GlowPulse>(find.byKey(SendButton.pulseKey));

    testWidgets('only with the load aboard in the green zone or better', (tester) async {
      for (final (level, zone, ready) in [
        (_light, LoadZone.light, false),
        (_green, LoadZone.green, true),
        (_atLimit, LoadZone.limit, true),
      ]) {
        final c = await play(tester, level);
        expect(pulse(tester).active, isFalse, reason: 'nobody aboard');
        expect(SendButton.readyFor(c.game), isFalse);
        c.tapQueue(0);
        // Selected, not yet aboard: whatever the Scale would say, nothing pulses.
        c.useScale();
        await tester.pump();
        expect(pulse(tester).active, isFalse, reason: 'selected only, $zone');
        c.tapLift();
        await tester.pump(const Duration(milliseconds: 300));
        expect(c.game.zone, zone);
        expect(pulse(tester).active, ready, reason: '$zone');
        expect(SendButton.readyFor(c.game), ready);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('it swells with the idle clock, and rests after the lift goes', (tester) async {
      final c = await play(tester, _green);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump(const Duration(milliseconds: 300));
      double scale() => tester
          .widget<Transform>(
              find.descendant(of: find.byKey(SendButton.pulseKey), matching: find.byType(Transform)).first)
          .transform
          .getMaxScaleOnAxis();
      final a = scale();
      await tester.pump(Duration(milliseconds: (ButtonMotion.readyPeriod * 500).round()));
      final b = scale();
      expect((a - b).abs(), greaterThan(ButtonMotion.readyScale / 4));
      expect(a, inInclusiveRange(1, 1 + ButtonMotion.readyScale));
      expect(b, inInclusiveRange(1, 1 + ButtonMotion.readyScale));
      c.send();
      await tester.pump();
      expect(pulse(tester).active, isFalse, reason: 'the lift is leaving');
      await _pumpFor(tester, CabinMotion.sendTotal + const Duration(milliseconds: 100), step: 50);
      expect(pulse(tester).active, isFalse, reason: 'the next lift is empty');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a disabled Send never pulses, even if told it is ready', (tester) async {
      await tester.pumpWidget(app(
        Center(child: SendButton(enabled: false, ready: true, onPressed: () {}, width: 160)),
        animate: true,
      ));
      expect(pulse(tester).active, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<Transform>(
                find.descendant(of: find.byKey(SendButton.pulseKey), matching: find.byType(Transform)).first)
            .transform
            .getMaxScaleOnAxis(),
        1,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: ready holds still with no glow', (tester) async {
      await _phone(tester);
      final c = _SpyController(_green)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      expect(pulse(tester).active, isTrue);
      expect(GlowPulse.playing(tester.element(find.byKey(SendButton.pulseKey)), true), isFalse);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Transform>(
                find.descendant(of: find.byKey(SendButton.pulseKey), matching: find.byType(Transform)).first)
            .transform
            .getMaxScaleOnAxis(),
        1,
      );
    });
  });

  group('boarding and seating', () {
    /// The walk of the front of lane 0 into the cabin: where its feet are at
    /// four moments, then the settle at the cabin after it lands.
    Future<({List<({Offset feet, double height})> walk, List<List<double>> settle, List<double> ring})> trace(
        WidgetTester tester, ResidentType type) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(type))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      final walk = <({Offset feet, double height})>[];
      const quarter = Duration(milliseconds: BoardMotion.flightMs ~/ 4);
      walk.add(_walker(tester)!);
      for (var i = 0; i < 3; i++) {
        await tester.pump(quarter);
        walk.add(_walker(tester)!);
      }
      final burst = tester.state<EffectsLayerState>(find.byType(EffectsLayer)).debugBursts.single;
      expect(burst.kind, BurstKind.ring);
      final ring = [
        burst.origin.dx,
        burst.origin.dy,
        burst.radius,
        burst.stroke,
        burst.delay.inMicroseconds.toDouble()
      ];
      await tester.pump(quarter + const Duration(milliseconds: 4));
      expect(_walker(tester), isNull, reason: 'landed within the walk time');
      final settle = <List<double>>[];
      for (var i = 0; i < 4; i++) {
        final m = tester
            .widget<Transform>(find.descendant(of: find.byType(LandSettle), matching: find.byType(Transform)).first);
        settle.add(m.transform.storage.toList());
        await tester.pump(BoardMotion.land ~/ 4);
      }
      await tester.pumpWidget(const SizedBox());
      return (walk: walk, settle: settle, ring: ring);
    }

    testWidgets('the same arc, ring and landing for every resident type', (tester) async {
      final first = await trace(tester, ResidentType.values.first);
      for (final type in ResidentType.values.skip(1)) {
        final other = await trace(tester, type);
        for (var i = 0; i < first.walk.length; i++) {
          expect(other.walk[i].feet.dx, closeTo(first.walk[i].feet.dx, 1e-6), reason: '$type step $i x');
          expect(other.walk[i].feet.dy, closeTo(first.walk[i].feet.dy, 1e-6), reason: '$type step $i y');
          expect(other.walk[i].height, closeTo(first.walk[i].height, 1e-6), reason: '$type step $i size');
        }
        expect(other.ring, first.ring, reason: '$type ring');
        for (var i = 0; i < first.settle.length; i++) {
          expect(other.settle[i], first.settle[i], reason: '$type settle $i');
        }
      }
    });

    test('the walk rises on one low arc and is level at both ends', () {
      expect(BoardMotion.riseAt(0), 0);
      expect(BoardMotion.riseAt(1), closeTo(0, 1e-9));
      final peak = [for (var i = 0; i <= 100; i++) BoardMotion.riseAt(i / 100)].reduce((a, b) => a > b ? a : b);
      expect(peak, inInclusiveRange(BoardMotion.arc * 0.9, BoardMotion.arc + BoardMotion.bob));
    });

    testWidgets('landing squashes a little and springs back to rest', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      await tester.pump(BoardMotion.flight);
      await tester.pump(const Duration(milliseconds: 4));
      double sy() => tester
          .widget<Transform>(find.descendant(of: find.byType(LandSettle), matching: find.byType(Transform)).first)
          .transform
          .storage[5];
      expect(sy(), lessThan(1), reason: 'squashed as they land');
      expect(sy(), greaterThanOrEqualTo(1 - BoardMotion.landSquash));
      await tester.pump(BoardMotion.land);
      expect(sy(), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: no walker, no ring, no settle', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => _flat(ResidentType.kid))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      expect(_byName('_FlightView'), findsNothing);
      expect(tester.state<EffectsLayerState>(find.byType(EffectsLayer)).debugBursts, isEmpty);
      for (final e in find.byType(LandSettle).evaluate()) {
        final t = tester
            .widget<Transform>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Transform)).first);
        expect(t.transform.isIdentity(), isTrue);
      }
    });

    testWidgets('people behind the front step up in turn, nearest the front first', (tester) async {
      await _phone(tester);
      final level = Level(
        number: 5,
        capacity: 600,
        trips: 6,
        benchSize: 4,
        difficulty: Difficulty.normal,
        floors: const [Floor.coral],
        queues: const [
          [
            Resident(id: 1, type: ResidentType.kid, floor: Floor.coral),
            Resident(id: 2, type: ResidentType.aunty, floor: Floor.coral),
            Resident(id: 3, type: ResidentType.officeM, floor: Floor.coral),
          ],
          [Resident(id: 4, type: ResidentType.kid, floor: Floor.coral)],
          [],
          [],
        ],
      );
      final c = controller(DebugAnalytics(), levelFor: (_) => level)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      double y(int id) {
        final slot = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_StepIn' && w.key == ValueKey(id));
        return tester.getTopLeft(find.descendant(of: slot, matching: find.byType(ResidentFigure))).dy;
      }

      final y2 = y(2), y3 = y(3);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      // Both start where they stood; the nearer one goes first.
      expect(y(2), closeTo(y2, 0.5));
      expect(y(3), closeTo(y3, 0.5));
      await tester.pump(Duration(milliseconds: BoardMotion.stepStagger + 30));
      final nearer = (y2 - y(2)).abs(), further = (y3 - y(3)).abs();
      expect(nearer, greaterThan(0));
      expect(further, lessThan(nearer));
      await tester.pump(const Duration(seconds: 1));
      expect(y(2), lessThan(y2));
      expect(y(3), lessThan(y3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('gauge', () {
    test('the needle swings the same distance past its mark whatever it travelled', () {
      for (final (from, to) in [(0.0, 0.1), (0.0, 0.5), (0.2, 0.95), (0.1, 0.3), (0.9, 0.4), (0.8, 0.05)]) {
        expect(GaugeMotion.needleAt(from, to, 0), from);
        expect(GaugeMotion.needleAt(from, to, 1), to);
        final up = to > from ? 1 : -1;
        final over = [for (var i = 0; i <= 200; i++) (GaugeMotion.needleAt(from, to, i / 200) - to) * up]
            .reduce((a, b) => a > b ? a : b);
        expect(over, closeTo(GaugeMotion.overshoot, 1e-3), reason: '$from to $to');
        // It never goes back before its start.
        for (var i = 0; i <= 100; i++) {
          expect((GaugeMotion.needleAt(from, to, i / 100) - from) * up, greaterThanOrEqualTo(-1e-9));
        }
      }
    });

    Future<_SpyController> play(WidgetTester tester, Level level) async {
      await _phone(tester);
      final c = _SpyController(level)..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      return c;
    }

    testWidgets('entering the green pulses the glow once and the needle overshoots, then both rest', (tester) async {
      final c = await play(tester, _green);
      expect(_gauge(tester).glow, 0);
      c.tapQueue(0);
      c.tapLift();
      final target = c.game.loadFraction;
      var peakGlow = 0.0, peakNeedle = 0.0;
      for (var t = 0; t < 900; t += 10) {
        await tester.pump(const Duration(milliseconds: 10));
        final g = _gauge(tester);
        if (g.glow > peakGlow) peakGlow = g.glow;
        if (g.fraction > peakNeedle) peakNeedle = g.fraction;
      }
      expect(peakGlow, greaterThan(LoadGauge.glowFor(LoadZone.green)), reason: 'the pulse');
      expect(peakNeedle, closeTo(target + GaugeMotion.overshoot, 2e-3), reason: 'the swing past the mark');
      expect(_gauge(tester).glow, LoadGauge.glowFor(LoadZone.green), reason: 'settled');
      expect(_gauge(tester).fraction, closeTo(target, 1e-9));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the grey never glows, however the needle moves', (tester) async {
      final c = await play(tester, _light);
      c.tapQueue(0);
      c.tapLift();
      for (var t = 0; t < 900; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(_gauge(tester).glow, 0);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('at the limit the glow breathes gently', (tester) async {
      final c = await play(tester, _atLimit);
      c.tapQueue(0);
      c.tapLift();
      await _pumpFor(tester, GaugeMotion.needle + GaugeMotion.zonePulse + const Duration(milliseconds: 100));
      final seen = <double>[];
      for (var t = 0; t < (GaugeMotion.limitPeriod * 1000).round(); t += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        seen.add(_gauge(tester).glow);
      }
      final base = LoadGauge.glowFor(LoadZone.limit);
      expect(seen.reduce((a, b) => a > b ? a : b), greaterThan(base + GaugeMotion.limitBreath / 2));
      expect(seen.reduce((a, b) => a < b ? a : b), lessThan(base - GaugeMotion.limitBreath / 2));
      expect(seen.every((g) => (g - base).abs() <= GaugeMotion.limitBreath + 1e-9), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the Scale ghost changes nothing about the glow or the pulse', (tester) async {
      Future<List<double>> run(double? ghost) async {
        await tester.pumpWidget(app(
          Center(child: LoadGauge(fraction: 0.2, zone: LoadZone.light, ghost: ghost)),
          animate: true,
        ));
        await tester.pumpWidget(app(
          Center(child: LoadGauge(fraction: 0.8, zone: LoadZone.green, ghost: ghost)),
          animate: true,
        ));
        final seen = <double>[];
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 25));
          seen
            ..add(_gauge(tester).glow)
            ..add(_gauge(tester).fraction);
        }
        await tester.pumpWidget(const SizedBox());
        return seen;
      }

      final without = await run(null);
      for (final ghost in [0.1, 0.9, 1.1]) {
        expect(await run(ghost), without, reason: 'ghost $ghost');
      }
    });

    testWidgets('reduced motion: the needle is just there and the glow holds still', (tester) async {
      await tester.pumpWidget(app(Center(child: LoadGauge(fraction: 0.2, zone: LoadZone.light))));
      await tester.pumpWidget(app(Center(child: LoadGauge(fraction: 0.97, zone: LoadZone.limit))));
      expect(_gauge(tester).fraction, 0.97);
      expect(_gauge(tester).glow, LoadGauge.glowFor(LoadZone.limit));
      await tester.pumpAndSettle();
      expect(_gauge(tester).glow, LoadGauge.glowFor(LoadZone.limit));
    });
  });

  group('floor display and chime', () {
    Future<_SpyController> play(WidgetTester tester) async {
      await _phone(tester);
      final c = _SpyController(dockLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      return c;
    }

    String shown(WidgetTester tester) => tester
        .widgetList<RichText>(
            find.descendant(of: find.byKey(LiftShaft.floorDisplayKey), matching: find.byType(RichText)))
        .map((r) => r.text.toPlainText())
        .join('|');

    testWidgets('the floors roll when the lift changes, the chime flashes as it stops, then both rest', (tester) async {
      final c = await play(tester);
      final first = c.game.liftFloors.single.label;
      expect(shown(tester), '▲ $first', reason: 'at rest it is one line');
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      await tester.pump(BoardMotion.flight + const Duration(milliseconds: 20));
      c.send();
      await tester.pump();
      var rolled = false, chimed = false;
      var peakChime = 0.0;
      String? before;
      for (var t = 0; t < CabinMotion.sendTotal.inMilliseconds + 800; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        final display = find.byKey(LiftShaft.floorDisplayKey);
        if (find.descendant(of: display, matching: find.byType(ClipRect)).evaluate().isNotEmpty) {
          rolled = true;
          // Both the old and the new floors are on screen while it rolls.
          expect(shown(tester), contains(first));
          expect(shown(tester), contains(c.game.liftFloors.single.label));
        }
        final chime = tester.widget<LiftShaft>(find.byType(LiftShaft)).chime;
        if (chime > 0) chimed = true;
        if (chime > peakChime) peakChime = chime;
        before = shown(tester);
      }
      expect(c.game.liftFloors.single.label, isNot(first));
      expect(rolled, isTrue, reason: 'the floors rolled');
      expect(chimed, isTrue, reason: 'the chime played');
      expect(before, '▲ ${c.game.liftFloors.single.label}', reason: 'rolled to one line again');
      expect(tester.widget<LiftShaft>(find.byType(LiftShaft)).chime, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: the display changes at once, with no roll and no chime', (tester) async {
      await _phone(tester);
      final c = _SpyController(dockLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      final first = c.game.liftFloors.single.label;
      c.tapQueue(0);
      c.tapLift();
      c.send();
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(LiftShaft.floorDisplayKey), matching: find.byType(ClipRect)), findsNothing);
      expect(c.game.liftFloors.single.label, isNot(first));
      expect(shown(tester), '▲ ${c.game.liftFloors.single.label}');
      expect(tester.widget<LiftShaft>(find.byType(LiftShaft)).chime, 0);
    });
  });

  group('send', () {
    testWidgets('finishSend runs exactly once, in the same order, and takes no longer than before + 150 ms',
        (tester) async {
      await _phone(tester);
      final c = _SpyController(dockLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      await tester.pump(BoardMotion.flight + const Duration(milliseconds: 20));
      c.send();
      await tester.pump();
      expect(c.game.phase, Phase.departing);
      var elapsed = 0;
      while (c.game.phase == Phase.departing && elapsed < 5000) {
        await tester.pump(const Duration(milliseconds: 10));
        elapsed += 10;
      }
      // Doors, bump, rise: the engine moves on exactly when the cabin is out.
      final toEngine = CabinMotion.doorClose + PunchMotion.bump + CabinMotion.rise;
      expect(elapsed, closeTo(toEngine.inMilliseconds, 30));
      expect(c.finishes, 1);
      // Then the next lift drops in and its doors open: nothing was added.
      await _pumpFor(tester, CabinMotion.dropIn + CabinMotion.doorOpen + const Duration(milliseconds: 100), step: 10);
      expect(c.finishes, 1);
      expect(elapsed + (CabinMotion.dropIn + CabinMotion.doorOpen).inMilliseconds, lessThanOrEqualTo(1870 + 150 + 30));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the ride moves the backdrop and rails with the cabin, and stops when it does', (tester) async {
      await _phone(tester);
      final c = _SpyController(dockLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      expect(_shaft(tester).rideDy, 0);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      await tester.pump(BoardMotion.flight + const Duration(milliseconds: 20));
      c.send();
      var rose = false, dropped = false;
      var last = 0.0;
      for (var t = 0; t < CabinMotion.sendTotal.inMilliseconds + 200; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        final dy = _shaft(tester).rideDy;
        if (dy < -1) rose = true;
        if (rose && dy > last + 0.5 && dy < 0) dropped = true;
        last = dy;
      }
      expect(rose, isTrue);
      expect(dropped, isTrue, reason: 'the next lift drops back in');
      expect(_shaft(tester).rideDy, 0, reason: 'still once it has stopped');
      expect(_shaft(tester).rideTravel, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });

    test('the shaft paints at every point of a ride, art or painted', () {
      for (final dy in [0.0, -40.0, -150.0, -300.0, 120.0, 340.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        ShaftPainter(
          style: VenueStyle.of(Venue.society),
          railLeft: 100,
          railRight: 270,
          rideDy: dy,
          rideTravel: 300,
          scale: 1,
        ).paint(canvas, const Size(350, 260));
        recorder.endRecording().dispose();
      }
      final style = VenueStyle.of(Venue.society);
      expect(
        ShaftPainter(style: style, railLeft: 1, railRight: 2, rideDy: -3)
            .shouldRepaint(ShaftPainter(style: style, railLeft: 1, railRight: 2, rideDy: -4)),
        isTrue,
      );
    });
  });

  group('win and fail sheets', () {
    double opacityOf(WidgetTester tester, Finder f) =>
        tester.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity;

    testWidgets('the card springs in and its parts appear one after another', (tester) async {
      await _phone(tester);
      final c = _SpyController(winLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      await tester.pump(BoardMotion.flight + const Duration(milliseconds: 20));
      c.send();
      await _pumpFor(
          tester, CabinMotion.doorClose + PunchMotion.bump + CabinMotion.rise + const Duration(milliseconds: 40),
          step: 10);
      expect(c.game.phase, Phase.won);
      final title = find.text('Tower delivered!'), button = find.text('Continue');
      expect(find.textContaining('complete!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(opacityOf(tester, title), lessThan(0.5), reason: 'the title is still coming');
      expect(opacityOf(tester, button), 0, reason: 'the button comes last');
      await tester.pump(Duration(milliseconds: SheetMotion.startOf(1) + SheetMotion.partMs));
      expect(opacityOf(tester, title), 1);
      expect(opacityOf(tester, button), lessThan(1));
      await tester.pump(SheetMotion.total);
      expect(opacityOf(tester, button), 1);
      // The coins counted up to their total, ticking as they went.
      expect(find.text('+${c.game.levelCoins} coins'), findsOneWidget);
      expect(c.ticks, CountMotion.ticks);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the coins on the win sheet count up from zero', (tester) async {
      await _phone(tester);
      final c = _SpyController(winLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      c.tapQueue(0);
      c.tapLift();
      c.send();
      c.finishSend();
      await tester.pump();
      expect(c.game.phase, Phase.won);
      final seen = <int>[];
      for (var t = 0; t < 2000; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        final m = RegExp(r'^\+(\d+) coins$');
        for (final w in tester.widgetList<Text>(find.byType(Text))) {
          final hit = m.firstMatch(w.data ?? '');
          if (hit != null) seen.add(int.parse(hit.group(1)!));
        }
      }
      expect(seen.first, 0);
      expect(seen.last, c.game.levelCoins);
      expect(seen.toSet().length, greaterThan(2), reason: 'it passes through numbers on the way');
      expect(seen, orderedEquals([...seen]..sort()), reason: 'and only goes up');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the fail sheet comes in the same way', (tester) async {
      await _phone(tester);
      final c = _SpyController(crashLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      await tester.pump(BoardMotion.flight + const Duration(milliseconds: 20));
      c.tapQueue(1);
      c.tapLift();
      await _pumpFor(tester, CabinMotion.fall + const Duration(milliseconds: 600), step: 20);
      expect(c.game.phase, Phase.failed);
      final retry = find.textContaining('Retry');
      expect(opacityOf(tester, retry), lessThan(1));
      await tester.pump(SheetMotion.total);
      expect(opacityOf(tester, retry), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: both sheets are whole at their first frame, with no ticks', (tester) async {
      await _phone(tester);
      final win = _SpyController(winLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: win)));
      win.tapQueue(0);
      win.tapLift();
      win.send();
      win.finishSend();
      await tester.pump();
      expect(opacityOf(tester, find.text('Continue')), 1);
      expect(opacityOf(tester, find.text('Tower delivered!')), 1);
      expect(find.text('+${win.game.levelCoins} coins'), findsOneWidget);
      expect(win.ticks, 0);
      final fail = _SpyController(crashLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: fail)));
      fail.tapQueue(0);
      fail.tapLift();
      fail.tapQueue(1);
      fail.tapLift();
      fail.finishCrash();
      await tester.pump();
      expect(opacityOf(tester, find.textContaining('Retry')), 1);
    });
  });

  group('coin counter', () {
    Widget counter(int value, {int? from, Duration delay = Duration.zero, VoidCallback? onTick, bool animate = true}) =>
        app(
          Center(
            child: CountUp(
              value: value,
              from: from,
              delay: delay,
              onTick: onTick,
              builder: (context, shown, widest) =>
                  StableText('$shown', widest: '$widest', style: const TextStyle(fontSize: 20)),
            ),
          ),
          animate: animate,
        );

    int shown(WidgetTester tester) => int.parse(tester.widget<Text>(find.byType(Text)).data!);

    testWidgets('counts to its new value, bounces as it lands and rests', (tester) async {
      await tester.pumpWidget(counter(900));
      expect(shown(tester), 900);
      await tester.pumpWidget(counter(950));
      final seen = <int>[];
      var peak = 1.0;
      for (var t = 0; t < 1400; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        seen.add(shown(tester));
        final s = tester
            .widget<Transform>(find.descendant(of: find.byType(CountUp), matching: find.byType(Transform)).first)
            .transform
            .getMaxScaleOnAxis();
        if (s > peak) peak = s;
      }
      expect(seen.first, inExclusiveRange(900, 950));
      expect(seen.last, 950);
      expect(seen, orderedEquals([...seen]..sort()));
      expect(peak, greaterThan(1));
      expect(peak, lessThanOrEqualTo(1 + CountMotion.bounceScale + 1e-9));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ticks the tick cue as it counts, and keeps its width while the digits change', (tester) async {
      var ticks = 0;
      await tester.pumpWidget(counter(100, from: 0, onTick: () => ticks++));
      final width = tester.getSize(find.byType(StableText)).width;
      for (var t = 0; t < 1000; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.getSize(find.byType(StableText)).width, width);
      }
      expect(ticks, CountMotion.ticks);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('waits out its delay before counting', (tester) async {
      await tester.pumpWidget(counter(60, from: 0, delay: const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown(tester), 0);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(shown(tester), 60);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: the new value at once, no bounce, no ticks', (tester) async {
      var ticks = 0;
      await tester.pumpWidget(counter(900, animate: false));
      await tester.pumpWidget(counter(950, animate: false, onTick: () => ticks++));
      expect(shown(tester), 950);
      expect(
        tester
            .widget<Transform>(find.descendant(of: find.byType(CountUp), matching: find.byType(Transform)).first)
            .transform
            .isIdentity(),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(ticks, 0);
    });

    testWidgets('the play HUD counts the coins to their new total', (tester) async {
      await _phone(tester);
      final c = _SpyController(dockLevel())..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      final before = c.profile.coins;
      Text coins() => tester.widgetList<Text>(find.byType(Text)).firstWhere((t) => t.data == '${c.profile.coins}');
      expect(coins().data, '$before');
      c.profile.coins += 40;
      c.poke();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final mid = tester.widgetList<Text>(find.byType(Text)).map((t) => int.tryParse(t.data ?? '')).whereType<int>();
      expect(mid.any((v) => v > before && v < before + 40), isTrue, reason: 'on its way: $mid');
      await tester.pump(CountMotion.count + CountMotion.bounce);
      expect(coins().data, '${before + 40}');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reveal of an unknown person', () {
    /// Lane 0: a kid at the front and [type] unknown behind; boarding the kid
    /// reveals [type].
    Level revealLevel(ResidentType type) => Level(
          number: 30,
          capacity: 600,
          trips: 8,
          benchSize: 4,
          difficulty: Difficulty.normal,
          floors: const [Floor.coral],
          queues: [
            [
              const Resident(id: 1, type: ResidentType.kid, floor: Floor.coral),
              Resident(id: 2, type: type, floor: Floor.coral)
            ],
            const [Resident(id: 3, type: ResidentType.kid, floor: Floor.coral)],
            const [],
            const [],
          ],
          unknownIds: const {2},
        );

    Finder stepIn(int id) =>
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_StepIn' && w.key == ValueKey(id));

    Finder flash() =>
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_FlashPainter');

    Future<List<double>> reveal(WidgetTester tester, ResidentType type) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => revealLevel(type))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      await tester.pump(EntranceMotion.total);
      expect(flash(), findsNothing);
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      final seen = <double>[];
      var ghosts = 0;
      for (var t = 0; t < RevealMotion.flash.inMilliseconds + 200; t += 40) {
        await tester.pump(const Duration(milliseconds: 40));
        final pop = find.descendant(of: stepIn(2), matching: _byName('_Pop'));
        final scale = tester
            .widget<Transform>(find.descendant(of: pop, matching: find.byType(Transform)).first)
            .transform
            .storage[0];
        seen.add(scale);
        if (find.descendant(of: pop, matching: find.byType(FadeTransition)).evaluate().isNotEmpty) ghosts++;
      }
      expect(seen.any((s) => s < 1), isTrue, reason: 'it pops up from smaller');
      expect(ghosts, greaterThan(0), reason: 'the ghost dissolves over them');
      await tester.pump(const Duration(milliseconds: 100));
      expect(flash(), findsNothing, reason: 'and the light is gone');
      expect(find.descendant(of: stepIn(2), matching: find.byType(FadeTransition)), findsNothing);
      await tester.pumpWidget(const SizedBox());
      return seen;
    }

    testWidgets('the same pop, dissolve and flash for every type who is revealed', (tester) async {
      final first = await reveal(tester, ResidentType.kid);
      for (final type in [ResidentType.wheelchair, ResidentType.pram, ResidentType.uncle]) {
        expect(await reveal(tester, type), first, reason: '$type');
      }
    });

    testWidgets('reduced motion: they are just there, with no flash and no ghost', (tester) async {
      await _phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => revealLevel(ResidentType.uncle))..startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      expect(flash(), findsNothing);
      expect(find.descendant(of: _byName('_Pop'), matching: find.byType(FadeTransition)), findsNothing);
      final pop =
          tester.widget<Transform>(find.descendant(of: _byName('_Pop'), matching: find.byType(Transform)).first);
      expect(pop.transform.isIdentity(), isTrue);
    });
  });

  group('home screen', () {
    Future<_SpyController> home(WidgetTester tester, {bool animate = true, int lives = 5}) async {
      await _phone(tester);
      final profile = Profile.fresh(DateTime(2026, 10, 22))..lives = lives;
      final c = _SpyController(dockLevel(), profile: profile);
      await tester.pumpWidget(app(HomeScreen(controller: c), animate: animate));
      return c;
    }

    testWidgets('its parts rise in one after another, then rest', (tester) async {
      await home(tester);
      expect(_entranceOpacities(tester), everyElement(0));
      await tester.pump(const Duration(milliseconds: 200));
      final mid = _entranceOpacities(tester);
      expect(mid.first, greaterThan(mid.last), reason: 'the top comes first');
      await tester.pump(HomeMotion.total);
      expect(_entranceOpacities(tester), everyElement(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the Play button breathes on a glow, and an out-of-lives home does not', (tester) async {
      await home(tester);
      await tester.pump(HomeMotion.total);
      expect(tester.widget<GlowPulse>(find.byType(GlowPulse)).active, isTrue);
      await tester.pumpWidget(const SizedBox());
      await home(tester, lives: 0);
      await tester.pump(HomeMotion.total);
      expect(tester.widget<GlowPulse>(find.byType(GlowPulse)).active, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: all there at once, no glow, no twinkle', (tester) async {
      await home(tester, animate: false);
      expect(_entranceOpacities(tester), everyElement(1));
      expect(GlowPulse.playing(tester.element(find.byType(GlowPulse)), true), isFalse);
      final twinkles = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((p) => p.foregroundPainter.runtimeType.toString() == '_TwinklePainter');
      expect(twinkles, isNotEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('the coin total counts up when it changes', (tester) async {
      final c = await home(tester);
      await tester.pump(HomeMotion.total);
      final before = c.profile.coins;
      c.profile.coins += 100;
      c.poke();
      await tester.pump();
      await tester.pump(HomeMotion.coinsAfter + const Duration(milliseconds: 200));
      final mid = tester.widgetList<Text>(find.byType(Text)).map((t) => int.tryParse(t.data ?? '')).whereType<int>();
      expect(mid.any((v) => v > before && v < before + 100), isTrue, reason: '$mid');
      await tester.pump(CountMotion.count + CountMotion.bounce + HomeMotion.coinsAfter);
      expect(find.text('${before + 100}'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('cost', () {
    testWidgets('the new loops share the one idle clock: no ticker of their own', (tester) async {
      Future<int> tickers(Level level) async {
        await _phone(tester);
        final c = _SpyController(level)..startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
        await tester.pump(EntranceMotion.total + const Duration(seconds: 1));
        await _board(tester, c);
        await tester.pump(const Duration(seconds: 2));
        final n = tester.binding.transientCallbackCount;
        final ready = SendButton.readyFor(c.game);
        await tester.pumpWidget(const SizedBox());
        return ready ? n : -n;
      }

      // The same play on a light lift (nothing pulses) and at the limit (the
      // ready pulse and the gauge's breath both run): the same tickers.
      final light = await tickers(_light);
      final limit = await tickers(_atLimit);
      expect(light, lessThan(0));
      expect(limit, greaterThan(0));
      expect(limit, -light);
    });
  });

  group('no overflow while it moves', () {
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('the entrance, the walk, the ride and the sheets at $name', (tester) async {
        await _phone(tester, size);
        for (final lanes in [3, 4, 5]) {
          for (final leftHanded in [false, true]) {
            final reason = '$lanes lanes, left-handed $leftHanded';
            final c = _SpyController(dockLevel(lanes: lanes));
            c.profile.leftHanded = leftHanded;
            c.startLevel();
            await tester.pumpWidget(app(PlayScreen(controller: c), animate: true, textScale: 1.3));
            for (final ms in [0, 150, 200, 350]) {
              await tester.pump(Duration(milliseconds: ms == 0 ? 1 : ms - (ms == 150 ? 0 : 150)));
              expect(tester.takeException(), isNull, reason: 'entrance at $ms, $reason');
            }
            await tester.pump(const Duration(milliseconds: 500));
            c.tapQueue(0);
            c.tapLift();
            for (var i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 70));
              expect(tester.takeException(), isNull, reason: 'walk $i, $reason');
            }
            await tester.pump(const Duration(milliseconds: 300));
            if (lanes == 4) {
              c.send();
              for (var t = 0; t < CabinMotion.sendTotal.inMilliseconds + 200; t += 100) {
                await tester.pump(const Duration(milliseconds: 100));
                expect(tester.takeException(), isNull, reason: 'ride at $t, $reason');
              }
            }
            await tester.pumpWidget(const SizedBox());
          }
        }
      });

      testWidgets('the sheets and home at $name, mid-motion', (tester) async {
        await _phone(tester, size);
        final win = _SpyController(winLevel())..startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: win), animate: true, textScale: 1.3));
        win.tapQueue(0);
        win.tapLift();
        win.send();
        win.finishSend();
        for (var t = 0; t < 1500; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'win sheet at $t');
        }
        final fail = _SpyController(crashLevel())..startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: fail), animate: true, textScale: 1.3));
        fail.tapQueue(0);
        fail.tapLift();
        fail.tapQueue(1);
        fail.tapLift();
        fail.finishCrash();
        for (var t = 0; t < 1500; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'fail sheet at $t');
        }
        await tester
            .pumpWidget(app(HomeScreen(controller: _SpyController(dockLevel())), animate: true, textScale: 1.3));
        for (var t = 0; t < 1000; t += 100) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull, reason: 'home at $t');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('source guards', () {
    const files = [
      'lib/ui/motion.dart',
      'lib/ui/widgets/entrance.dart',
      'lib/ui/widgets/glow_pulse.dart',
      'lib/ui/widgets/count_up.dart',
      'lib/ui/widgets/load_gauge.dart',
      'lib/ui/widgets/pressable.dart',
    ];

    test('the motion code never reads who or what a resident is, or how heavy a load is', () {
      // Everything that moves is the same for everyone: nothing in the motion
      // pieces may name a type, a cargo, a weight, a capacity or the ghost load.
      for (final f in files) {
        final src = File(f).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');
        for (final word in [
          'ResidentType',
          'Cargo',
          '.kg',
          'capacity',
          'ghostLoad',
          'loadFraction',
          'riders',
          'Resident('
        ]) {
          expect(src.contains(word), isFalse, reason: '$f mentions $word');
        }
      }
    });

    test('timings live in motion.dart: no duration literals in the new motion pieces', () {
      for (final f in files.skip(1)) {
        final src = File(f).readAsStringSync();
        expect(RegExp(r'Duration\(\s*(milliseconds|seconds|microseconds)').hasMatch(src), isFalse, reason: f);
      }
    });

    test('the gauge reads only the load aboard: no ghost in the glow or the pulse', () {
      final src = File('lib/ui/widgets/load_gauge.dart').readAsStringSync();
      expect(RegExp(r'ghost\s*[?!]?\s*[<>*+\-/]').hasMatch(src), isFalse);
      // Glow comes from the zone, the pulse and the breath, nothing else.
      final glow = RegExp(r'glow: \(([^;]*)\)').firstMatch(src)!.group(1)!;
      expect(glow.contains('ghost'), isFalse);
    });
  });
}
