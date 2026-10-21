import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';
import 'responsive_test.dart' show crashLevel;

/// With motion on, idle animation never settles, so these tests pump fixed
/// durations instead of pumpAndSettle.
void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('a boarding resident walks into the cabin, then a send runs doors, rise and the next lift',
      (tester) async {
    await phone(tester);
    final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.mall, LiftKind.normal, null));
    c.startLevel();
    await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
    await tester.pump(const Duration(milliseconds: 50));
    final before = find.byType(ResidentFigure).evaluate().length;

    c.tapQueue(0);
    c.tapLift();
    await tester.pump();
    // The walker is an extra figure on top while the cabin copy is hidden.
    expect(find.byType(ResidentFigure).evaluate().length, before + 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ResidentFigure).evaluate().length, before);
    expect(tester.takeException(), isNull);

    c.send();
    await tester.pump();
    expect(c.game.phase, Phase.departing);
    // Doors 180 + rise 500, then the engine moves on; drop 450 + doors 180.
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.game.phase, Phase.playing);
    expect(c.game.tripsUsed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an overload waits for the walk, shakes, sparks and fails', (tester) async {
    await phone(tester);
    final c = controller(DebugAnalytics(), levelFor: (_) => crashLevel());
    c.startLevel();
    await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
    c.tapQueue(0);
    c.tapLift();
    await tester.pump(const Duration(milliseconds: 300));
    c.tapQueue(1);
    c.tapLift();
    await tester.pump();
    expect(c.game.phase, Phase.falling);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.game.phase, Phase.failed);
    expect(find.text('Overloaded!'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: no walkers and the send completes at once', (tester) async {
    await phone(tester);
    final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.mall, LiftKind.normal, null));
    c.startLevel();
    await tester.pumpWidget(app(PlayScreen(controller: c)));
    final before = find.byType(ResidentFigure).evaluate().length;
    c.tapQueue(0);
    c.tapLift();
    await tester.pump();
    expect(find.byType(ResidentFigure).evaluate().length, before);
    c.send();
    await tester.pumpAndSettle();
    expect(c.game.phase, Phase.playing);
    expect(c.game.tripsUsed, 1);
  });

  // Leaving mid-sequence (back, then "Leave") disposes the screen while the
  // cabin animates; the rest of the sequence must stop, not touch disposed
  // controllers or the engine.
  for (final (label, ms) in [('door close', 100), ('rise', 400), ('next lift drop-in', 800)]) {
    testWidgets('leaving during the $label is clean', (tester) async {
      await phone(tester);
      final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.mall, LiftKind.normal, null));
      c.startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
      c.tapQueue(0);
      c.tapLift();
      await tester.pump(const Duration(milliseconds: 300));
      c.send();
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a send right after boarding: the walker lands and the trip completes', (tester) async {
    await phone(tester);
    final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.mall, LiftKind.normal, null));
    c.startLevel();
    await tester.pumpWidget(app(PlayScreen(controller: c), animate: true));
    await tester.pump(const Duration(milliseconds: 50));
    final before = find.byType(ResidentFigure).evaluate().length;
    c.tapQueue(0);
    c.tapLift();
    c.send();
    await tester.pump();
    expect(find.byType(ResidentFigure).evaluate().length, before + 1, reason: 'walker in flight');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ResidentFigure).evaluate().length, before, reason: 'walker landed, rider visible');
    expect(c.game.phase, Phase.departing);
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.game.phase, Phase.playing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('a refused head-shake stays with the refused resident, not the next one up', () {
    final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.mall, LiftKind.normal, null))..startLevel();
    final lane = [for (var i = 0; i < 4; i++) i].firstWhere((i) {
      final front = c.game.queues[i].firstOrNull;
      return front != null && !c.game.liftFloors.contains(front.floor);
    });
    c.tapQueue(lane);
    c.tapLift();
    expect(c.refusedSpot, Selection.queue(lane));
    // They sit down instead; whoever steps up to the front was never refused.
    c.tapBench(0);
    expect(c.refused, isNotNull);
    expect(c.refusedSpot, isNull);
  });
}
