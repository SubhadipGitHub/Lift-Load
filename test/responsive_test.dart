import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/screens/home_screen.dart';
import 'package:lift_load/ui/screens/play_screen.dart';

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

void main() {
  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('home fits at $name', (tester) async {
      await sized(tester, size);
      final c = controller(DebugAnalytics());
      c.profile.level = 47;
      await tester.pumpWidget(app(HomeScreen(controller: c), textScale: 1.3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('play fits at $name', (tester) async {
      await sized(tester, size);
      final handle = tester.ensureSemantics();
      for (final venue in [Venue.society, Venue.hotel]) {
        final c = controller(DebugAnalytics(), levelFor: (_) => variety(venue, LiftKind.express, Scenario.rushHour));
        c.startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: c), textScale: 1.3));
        // Wide figures in the cabin and on the bench.
        c.tapQueue(0);
        c.tapLift();
        c.tapQueue(1);
        c.tapLift();
        c.tapQueue(2);
        c.tapBench(0);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: venue.name);
      }
      expectTouchTarget(tester, find.bySemanticsLabel(RegExp(r'^Empty bench seat$')), 'bench seat');
      expectTouchTarget(tester, find.bySemanticsLabel(RegExp('Tap to board the selected resident')), 'cabin');
      expectTouchTarget(tester, find.bySemanticsLabel(RegExp(r'^(?!Bench).* going to \dF')), 'lane front');
      expect(tester.getSize(find.widgetWithText(FilledButton, 'Send')).height, greaterThanOrEqualTo(Metrics.minTouch));
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
