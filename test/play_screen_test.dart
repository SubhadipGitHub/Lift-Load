import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/theme.dart';

GameController controller(DebugAnalytics analytics) => GameController(
      profile: Profile.fresh(DateTime(2026, 10, 21)),
      ads: StubAdsService(delay: Duration.zero),
      analytics: analytics,
      clock: () => DateTime(2026, 10, 21, 12),
      levelFor: (_) => Level.conceptSlice(),
    );

Future<void> pumpPlay(WidgetTester tester, GameController c) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  c.startLevel();
  await tester.pumpWidget(MaterialApp(theme: LL.theme(), home: PlayScreen(controller: c)));
}

void main() {
  testWidgets('play screen renders the concept slice with no weight shown', (tester) async {
    final c = controller(DebugAnalytics());
    await pumpPlay(tester, c);
    expect(find.text('Lv 12'), findsOneWidget);
    expect(find.text('MAX 4 PERSONS'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    // Hidden weights must never reach the screen.
    expect(find.textContaining('kg'), findsNothing);
    expect(tester.takeException(), isNull);
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
