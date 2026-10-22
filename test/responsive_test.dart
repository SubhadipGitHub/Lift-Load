import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/painters/cabin_painter.dart';
import 'package:lift_load/ui/painters/sprite_painter.dart';
import 'package:lift_load/ui/screens/home_screen.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/widgets/glossy.dart';
import 'package:lift_load/ui/widgets/lobby.dart';
import 'package:lift_load/ui/widgets/play_bar.dart';
import 'package:lift_load/ui/widgets/power_dock.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';

/// Every screen at every device class, at the largest system text we honour.
/// Any overflow or layout error fails the test.
const sizes = {
  'phone 320x568': Size(320, 568),
  'phone 360x640': Size(360, 640),
  'phone 375x667': Size(375, 667),
  'phone 390x844': Size(390, 844),
  'phone 412x915': Size(412, 915),
  'phone 430x932': Size(430, 932),
  'phone landscape 844x390': Size(844, 390),
  'tablet 600x960': Size(600, 960),
  'tablet 768x1024': Size(768, 1024),
  'tablet 820x1180': Size(820, 1180),
  'tablet 1024x1366': Size(1024, 1366),
  'tablet landscape 1024x768': Size(1024, 768),
  'tablet landscape 1180x820': Size(1180, 820),
  'tablet landscape 1366x1024': Size(1366, 1024),
};

/// Two heavy riders on a 100-capacity lift: boarding the second crashes.
Level crashLevel() => const Level(
      number: 30,
      capacity: 100,
      trips: 5,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: [Floor.coral],
      queues: [
        [Resident(id: 1, type: ResidentType.uncle, floor: Floor.coral)],
        [Resident(id: 2, type: ResidentType.uncle, floor: Floor.coral)],
        [],
        [],
      ],
    );

/// One kid: one send wins. Level 20 is the last of its venue, so the win
/// sheet also shows the building-complete banner.
Level winLevel() => const Level(
      number: 20,
      capacity: 280,
      trips: 5,
      benchSize: 4,
      difficulty: Difficulty.hard,
      floors: [Floor.coral],
      queues: [
        [Resident(id: 1, type: ResidentType.kid, floor: Floor.coral)],
        [],
        [],
        [],
      ],
    );

Future<void> sized(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void expectTouchTarget(WidgetTester tester, Finder f, String what) {
  expect(f, findsWidgets, reason: what);
  final rect = tester.getSemantics(f.first).rect;
  expect(rect.width, greaterThanOrEqualTo(Metrics.minTouch - 0.5), reason: '$what width');
  expect(rect.height, greaterThanOrEqualTo(Metrics.minTouch - 0.5), reason: '$what height');
}

/// Every glossy button on screen keeps a full touch target.
void expectGlossyTargets(WidgetTester tester, String what) {
  final buttons = find.byType(GlossyButton);
  expect(buttons, findsWidgets, reason: what);
  for (final e in buttons.evaluate()) {
    final size = tester.getSize(find.byWidget(e.widget));
    final label = (e.widget as GlossyButton).semanticsLabel ?? e.widget.runtimeType.toString();
    expect(size.width, greaterThanOrEqualTo(Metrics.minTouch - 0.5), reason: '$what: $label width');
    expect(size.height, greaterThanOrEqualTo(Metrics.minTouch - 0.5), reason: '$what: $label height');
  }
}

/// Known figures drawn in [of], and the height each is drawn at on screen
/// (after any FittedBox shrink).
List<double> drawnHeights(WidgetTester tester, Type of) => [
      for (final e in find
          .descendant(of: find.byType(of), matching: find.byWidgetPredicate((w) => w is ResidentFigure && !w.dimmed))
          .evaluate())
        tester.getRect(find.byWidget(e.widget)).height,
    ];

void main() {
  // The sweep runs with the sprites loaded, as the app does.
  setUpAll(() => SpriteCache.instance.load());

  test('the sprites are loaded for the sweep', () {
    expect(SpriteCache.instance.loaded, isTrue);
    expect(SpriteCache.instance.failed, isEmpty);
  });

  test('figures are +60% where they fit and never smaller than v1.6, at every size', () {
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      final m = Metrics.from(size);
      for (final lanes in [3, 4, 5]) {
        final h = m.laneFigureFor(lanes);
        expect(h, lessThanOrEqualTo(m.laneFigure), reason: '$name $lanes lanes');
        expect(h, greaterThanOrEqualTo(54 * m.scale - 1e-9), reason: '$name $lanes lanes, v1.6 size');
        // The widest figure fits its lane, unless the v1.6 size is the floor.
        final lane = (m.lanesWidth - 2 * (m.gap + m.lanePadding)) / lanes - 2 * (m.slotPadding + Metrics.slotBorder);
        if (h > 54 * m.scale) {
          expect(h / 120 * Metrics.widestFigure, lessThanOrEqualTo(lane + 1e-6), reason: '$name $lanes lanes');
        }
      }
      for (var seats = 1; seats <= 7; seats++) {
        final h = m.benchFigureFor(seats);
        expect(h, lessThanOrEqualTo(m.benchFigure), reason: '$name $seats seats');
        expect(h, greaterThanOrEqualTo(52 * m.scale - 1e-9), reason: '$name $seats seats, v1.6 size');
        expect(m.seatHeightFor(h), greaterThanOrEqualTo(Metrics.minTouch));
      }
      expect(m.cabinFigure, 128 * m.scale, reason: name);
    }
    // At the design size, four lanes and a four-seat bench get the full +60%.
    final design = Metrics.from(const Size(390, 844));
    expect(design.laneFigureFor(4), 86);
    expect(design.benchFigureFor(4), closeTo(86 * Metrics.benchToLane, 0.01));
    // Five lanes on the narrowest phone shrink, but stay above v1.6.
    final narrow = Metrics.from(const Size(320, 700));
    expect(narrow.laneFigureFor(5), lessThan(narrow.laneFigure));
    expect(narrow.laneFigureFor(5), greaterThan(54 * narrow.scale));
  });

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('home fits at $name', (tester) async {
      await sized(tester, size);
      final c = controller(DebugAnalytics());
      c.profile.level = 47;
      await tester.pumpWidget(app(HomeScreen(controller: c), textScale: 1.3));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expectGlossyTargets(tester, 'home');
    });

    testWidgets('play fits at $name', (tester) async {
      await sized(tester, size);
      final handle = tester.ensureSemantics();
      // Every kind of cabin in its art, and the hotel's express.
      for (final (venue, kind) in [
        for (final k in LiftKind.values) (Venue.society, k),
        (Venue.hotel, LiftKind.express),
      ]) {
        final c = controller(DebugAnalytics(), levelFor: (_) => variety(venue, kind, Scenario.rushHour));
        c.startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: c), textScale: 1.3));
        final reason = '${venue.name} ${kind.name}';
        expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CabinArtPainter), findsOneWidget,
            reason: reason);
        // Wide figures in the cabin and on the bench.
        c.tapQueue(0);
        c.tapLift();
        c.tapQueue(1);
        c.tapLift();
        c.tapQueue(2);
        c.tapBench(0);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: reason);
      }
      expectTouchTarget(tester, find.bySemanticsLabel(RegExp(r'^Empty bench seat$')), 'bench seat');
      expectTouchTarget(tester, find.bySemanticsLabel(RegExp('Tap to board the selected resident')), 'cabin');
      expectTouchTarget(tester, find.bySemanticsLabel(RegExp(r'^(?!Bench).* going to \dF')), 'lane front');
      expect(tester.getSize(find.byKey(SendButton.buttonKey)).height, greaterThanOrEqualTo(Metrics.minTouch));
      handle.dispose();
    });

    testWidgets('play with the power dock fits at $name', (tester) async {
      await sized(tester, size);
      final handle = tester.ensureSemantics();
      for (final lanes in [3, 4, 5]) {
        for (final leftHanded in [false, true]) {
          final c =
              powerController(DebugAnalytics(), level: dockLevel(lanes: lanes), stock: {Power.swap: 1, Power.seats: 1});
          c.profile.leftHanded = leftHanded;
          c.startLevel();
          await tester.pumpWidget(app(PlayScreen(controller: c), textScale: 1.3));
          final reason = '$lanes lanes, left-handed $leftHanded';
          // Sprites, drawn at the fitted size and not shrunk any further.
          final m = Metrics.from(size);
          final laneFigures = drawnHeights(tester, QueueLanes);
          expect(laneFigures, isNotEmpty, reason: reason);
          for (final h in laneFigures) {
            expect(h, closeTo(m.laneFigureFor(lanes), 0.5), reason: 'lane figure, $reason');
          }
          final figure = find.byType(ResidentFigure).first;
          expect(
            tester.widget<CustomPaint>(find.descendant(of: figure, matching: find.byType(CustomPaint)).first).painter,
            isA<SpriteFigurePainter>(),
          );
          // All four powers on the bar, one with stock and three empty.
          for (final p in Power.values) {
            expectTouchTarget(tester, find.bySemanticsLabel(RegExp('^${RegExp.escape(p.dockLabel)}: ')), p.name);
          }
          expectTouchTarget(tester, find.bySemanticsLabel(RegExp('^Scale: ')), 'scale');
          expectTouchTarget(tester, find.bySemanticsLabel('Back to the tower'), 'back');
          expectTouchTarget(tester, find.bySemanticsLabel('Settings'), 'settings');
          expect(
              tester.getSize(find.byKey(SendButton.buttonKey)).height, greaterThanOrEqualTo(Metrics.minTouch));
          expectGlossyTargets(tester, 'play, $reason');
          // Swap armed with its first lane picked, then the unknown people stepping up.
          await tester.tap(find.byKey(const ValueKey('power-swap')));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'armed, $reason');
          c.tapQueue(0);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'picked, $reason');
          c.cancelPower();
          c.tapQueue(0);
          c.tapBench(0);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'revealed, $reason');
          // +2 seats: the bench wraps into two rows and every seat stays a touch target.
          c.usePower(Power.seats);
          c.tapQueue(1);
          c.tapBench(1);
          await tester.pump();
          expect(c.game.benchLength, 6);
          expect(tester.takeException(), isNull, reason: 'seats, $reason');
          for (final h in drawnHeights(tester, BenchRow)) {
            expect(h, closeTo(m.benchFigureFor(6), 0.5), reason: 'bench figure, $reason');
          }
          expectTouchTarget(tester, find.bySemanticsLabel(RegExp(r'^Empty bench seat$')), 'bench seat, $reason');
          // The get-more sheet and the settings sheet over it.
          await tester.tap(find.byKey(const ValueKey('power-express')));
          await tester.pumpAndSettle();
          expect(find.textContaining('Spend'), findsOneWidget, reason: reason);
          expect(tester.takeException(), isNull, reason: 'sheet, $reason');
          expectGlossyTargets(tester, 'get-more sheet, $reason');
          await tester.tap(find.text('Not now'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Settings'));
          await tester.pumpAndSettle();
          expect(find.text('Left-handed layout'), findsOneWidget);
          expect(find.text('Restart level'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'settings, $reason');
          await tester.tap(find.text('Left-handed layout'));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox());
        }
      }
      handle.dispose();
    });

    testWidgets('fail and win sheets fit at $name', (tester) async {
      await sized(tester, size);
      final crash = controller(DebugAnalytics(), levelFor: (_) => crashLevel());
      crash.startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: crash), textScale: 1.3));
      crash.tapQueue(0);
      crash.tapLift();
      crash.tapQueue(1);
      crash.tapLift();
      crash.finishCrash();
      await tester.pump();
      expect(find.text('Overloaded!'), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'fail sheet');
      expectGlossyTargets(tester, 'fail sheet');

      final win = controller(DebugAnalytics(), levelFor: (_) => winLevel());
      win.startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: win), textScale: 1.3));
      win.tapQueue(0);
      win.tapLift();
      win.send();
      win.finishSend();
      await tester.pump();
      expect(find.textContaining('complete!'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'win sheet');
      expectGlossyTargets(tester, 'win sheet');
    });
  }

  test('form factors', () {
    expect(Metrics.from(const Size(320, 568)).form, FormFactor.compactPhone);
    expect(Metrics.from(const Size(390, 844)).form, FormFactor.phone);
    expect(Metrics.from(const Size(390, 844)).scale, 1);
    expect(Metrics.from(const Size(820, 1180)).form, FormFactor.tabletPortrait);
    expect(Metrics.from(const Size(1180, 820)).form, FormFactor.twoPane);
    expect(Metrics.from(const Size(844, 390)).form, FormFactor.twoPane);
    expect(Metrics.from(const Size(1180, 820)).isTablet, isTrue);
    expect(Metrics.from(const Size(844, 390)).isTablet, isFalse);
  });
}
