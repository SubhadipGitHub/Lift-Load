import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/screens/play_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('play screen renders the concept slice with no weight shown', (tester) async {
    final c = controller(DebugAnalytics());
    await pumpPlay(tester, c);
    expect(find.text('Lv 12'), findsOneWidget);
    expect(find.text('MIND THE LOAD'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    // Hidden weights must never reach the screen.
    expect(find.textContaining('kg'), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('every venue, lift kind and scenario renders without overflow or weights', (tester) async {
    for (final venue in Venue.values) {
      for (final kind in LiftKind.values) {
        for (final scenario in [null, ...Scenario.values]) {
          final c = controller(DebugAnalytics(), levelFor: (_) => variety(venue, kind, scenario));
          await pumpPlay(tester, c);
          // Fill the cabin with the wide figures and park a few on the bench.
          c.tapQueue(0);
          c.tapLift();
          c.tapQueue(1);
          c.tapLift();
          c.tapQueue(2);
          c.tapBench(0);
          c.tapQueue(3);
          c.tapBench(1);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${venue.name} ${kind.name} ${scenario?.name}');
          expect(find.textContaining('kg'), findsNothing);
        }
      }
    }
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('tapping a coned-off lane explains why', (tester) async {
    final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.mall, LiftKind.normal, Scenario.maintenance));
    await pumpPlay(tester, c);
    c.tapQueue(3);
    await tester.pump();
    expect(c.game.selection, isNull);
    expect(c.message, contains('maintenance'));
    expect(find.text('Opens in\n3 trips'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a rush-hour wave is announced, not hidden by the arriving lift', (tester) async {
    var id = 100;
    Resident r(Floor f) => Resident(id: ++id, type: ResidentType.kid, floor: f);
    final level = Level(
      number: 87,
      capacity: 360,
      trips: 10,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: const [Floor.coral, Floor.teal],
      scenario: Scenario.rushHour,
      queues: [
        [r(Floor.coral)],
        [r(Floor.teal)],
        const [],
        const [],
      ],
      arrivals: [
        Arrival(afterTrip: 1, lane: 2, resident: r(Floor.teal)),
        Arrival(afterTrip: 1, lane: 3, resident: r(Floor.coral))
      ],
    );
    final c = controller(DebugAnalytics(), levelFor: (_) => level);
    await pumpPlay(tester, c);
    c.tapQueue(0);
    c.tapLift();
    c.send();
    await tester.pumpAndSettle();
    expect(c.message, contains('Rush hour: +2'));
    expect(c.message, contains('arriving'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('restart is free before the first move and costs a life after it', (tester) async {
    final analytics = DebugAnalytics();
    final c = controller(analytics);
    await pumpPlay(tester, c);
    expect(c.levelInProgress, isFalse);
    c.tapQueue(0); // selecting alone is not a move
    c.restart();
    expect(c.profile.lives, Formulas.maxLives);

    c.tapQueue(0);
    c.tapLift();
    await tester.pump();
    expect(find.text('Restart · 1 life'), findsOneWidget);
    c.restart();
    await tester.pump();
    expect(c.profile.lives, Formulas.maxLives - 1);
    expect(c.game.riders, isEmpty);
    expect(analytics.history.where((e) => e.$1 == 'level_abandon'), hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('restart with one life left is refused once moves are made', (tester) async {
    final c = controller(DebugAnalytics());
    c.profile
      ..lives = 1
      ..livesStampedAt = c.now; // no regen before the check
    await pumpPlay(tester, c);
    c.tapQueue(0);
    c.tapLift();
    expect(c.canRestart, isFalse);
    c.restart();
    expect(c.profile.lives, 1);
    expect(c.game.riders, hasLength(1));
    expect(c.message, contains('last life'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('leaving a level in progress asks first and costs a life', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = controller(DebugAnalytics());
    c.startLevel();
    await tester.pumpWidget(app(const Scaffold(body: Text('home'))));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => PlayScreen(controller: c)));
    await tester.pumpAndSettle();

    c.tapQueue(0);
    c.tapLift();
    await tester.tap(find.byTooltip('Back to the tower'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this level?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(c.profile.lives, Formulas.maxLives);

    await tester.tap(find.byTooltip('Back to the tower'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave · 1 life'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(c.profile.lives, Formulas.maxLives - 1);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('leaving an untouched level is free and does not ask', (tester) async {
    final c = controller(DebugAnalytics());
    c.startLevel();
    await tester.pumpWidget(app(const Scaffold(body: Text('home'))));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => PlayScreen(controller: c)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to the tower'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(c.profile.lives, Formulas.maxLives);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('board, send, and the next lift arrives', (tester) async {
    final analytics = DebugAnalytics();
    final c = controller(analytics);
    await pumpPlay(tester, c);

    c.tapQueue(0); // uncle → 2F
    c.tapLift();
    await tester.pump();
    expect(c.game.riders, hasLength(1));

    c.send();
    await tester.pumpAndSettle();
    expect(c.game.phase, Phase.playing);
    expect(c.game.tripsUsed, 1);
    expect(c.message, contains('arriving'));
    expect(analytics.history.map((e) => e.$1), containsAll(['level_start', 'trip_sent']));
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('overload plays the crash, shows the fail sheet, and the ad repairs it', (tester) async {
    final c = controller(DebugAnalytics());
    await pumpPlay(tester, c);

    // Build the 2F lift past capacity, benching anyone for other floors.
    c.tapQueue(0); // uncle 104
    c.tapLift();
    c.tapQueue(2); // aunty 80 (6F) → bench
    c.tapBench(0);
    c.tapQueue(2); // aunty 80 (2F)
    c.tapLift(); // 184
    c.tapQueue(1); // gym 92 (5F) → bench
    c.tapBench(1);
    c.tapQueue(1); // kid 30 (2F)
    c.tapLift(); // 214
    c.tapQueue(3); // officeW 60 (2F)
    c.tapLift(); // 274
    c.tapQueue(0); // kid 30 (5F) → bench
    c.tapBench(2);
    c.tapQueue(0); // officeM 74 (6F) → bench
    c.tapBench(3);
    c.tapQueue(0); // student 55 (2F) → 329, over 280
    expect(c.game.tapLift(), BoardResult.overloaded);
    c.finishCrash();
    await tester.pumpAndSettle();
    expect(find.text('Overloaded!'), findsWidgets);
    await c.continueWithAd();
    await tester.pumpAndSettle();
    expect(c.game.phase, Phase.playing);
    expect(c.game.load, 274);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
