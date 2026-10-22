import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/services/ad_policy.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/widgets/effects.dart';
import 'package:lift_load/ui/widgets/glossy.dart';
import 'package:lift_load/ui/widgets/play_bar.dart';

import 'helpers.dart';

Finder power(Power p) => find.byKey(ValueKey('power-${p.name}'));
Finder badge(Power p, String text) => find.descendant(of: power(p), matching: find.text(text));
Finder send() => find.byKey(SendButton.buttonKey);

/// The lane front standing in [lane], found the way a screen reader finds it.
Finder front(GameController c, int lane) =>
    find.bySemanticsLabel(RegExp('^${RegExp.escape(GameController.describe(c.game.frontOf(lane)!))}'));

Future<void> pump(WidgetTester tester, GameController c, {bool animate = false}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  c.startLevel();
  await tester.pumpWidget(app(PlayScreen(controller: c), animate: animate));
}

void main() {
  testWidgets('the dock shows only the powers this level has unlocked', (tester) async {
    for (final (level, shown) in [
      (12, <Power>[]),
      (Power.swap.unlockLevel, [Power.swap]),
      (Power.seats.unlockLevel, [Power.swap, Power.seats]),
      (Power.trip.unlockLevel, [Power.swap, Power.seats, Power.trip]),
      (Power.express.unlockLevel, Power.values),
    ]) {
      final c = powerController(DebugAnalytics(), level: dockLevel(number: level));
      await pump(tester, c);
      for (final p in Power.values) {
        expect(power(p), shown.contains(p) ? findsOneWidget : findsNothing, reason: '${p.name} at level $level');
      }
      expect(send(), findsOneWidget, reason: 'Send is always there');
    }
  });

  testWidgets('the badge shows the stock, and 0 reads as empty', (tester) async {
    final c = powerController(DebugAnalytics(), stock: {Power.swap: 2});
    await pump(tester, c);
    expect(badge(Power.swap, '2'), findsOneWidget);
    expect(badge(Power.seats, '0'), findsOneWidget);
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp(r'^\+2 seats: .*None left\. Tap to get more')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Swap: .*2 left')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a tap with stock spends one', (tester) async {
    final analytics = DebugAnalytics();
    final c = powerController(analytics, stock: {Power.trip: 2, Power.seats: 1});
    await pump(tester, c);
    final trips = c.game.tripsTotal;
    await tester.tap(power(Power.trip));
    await tester.pump();
    expect(c.powerStock(Power.trip), 1);
    expect(c.game.tripsTotal, trips + Formulas.powerTrips);
    expect(badge(Power.trip, '1'), findsOneWidget);

    await tester.tap(power(Power.seats));
    await tester.pump();
    expect(c.game.benchLength, 4 + Formulas.powerSeats);
    expect(badge(Power.seats, '0'), findsOneWidget);
    expect(analytics.history.where((e) => e.$1 == 'power_used'), hasLength(2));

    // The trip power is at its per-level cap: another tap explains, spends nothing.
    await tester.tap(power(Power.trip));
    await tester.pump();
    expect(c.powerStock(Power.trip), 1);
    expect(c.message, contains('Already used'));
    expect(find.text('Spend ${Formulas.powerCoinPrice(Power.trip)} coins'), findsNothing);
  });

  testWidgets('+2 seats wraps the bench into two rows of seats', (tester) async {
    final handle = tester.ensureSemantics();
    final c = powerController(DebugAnalytics(), stock: {Power.seats: 1});
    await pump(tester, c);
    final seats = find.bySemanticsLabel(RegExp(r'^Empty bench seat$'));
    expect(seats, findsNWidgets(4));
    expect({for (final e in seats.evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dy}, hasLength(1));
    await tester.tap(power(Power.seats));
    await tester.pump();
    expect(seats, findsNWidgets(6));
    final rows = {for (var i = 0; i < 6; i++) tester.getTopLeft(seats.at(i)).dy.round()};
    expect(rows, hasLength(2));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('a tap with 0 stock opens the get-more sheet, which spends coins on request', (tester) async {
    final c = powerController(DebugAnalytics(), coins: 400);
    await pump(tester, c);
    await tester.tap(power(Power.seats));
    await tester.pumpAndSettle();
    final price = Formulas.powerCoinPrice(Power.seats);
    expect(find.text('Spend $price coins'), findsOneWidget);
    expect(find.text('Watch an ad · +${Formulas.powerAdUses} Seats'), findsOneWidget);
    // Opening the sheet plays no ad and grants nothing.
    expect(c.adInFlight, isFalse);
    expect(c.powerStock(Power.seats), 0);

    await tester.tap(find.text('Spend $price coins'));
    await tester.pumpAndSettle();
    expect(find.text('Spend $price coins'), findsNothing, reason: 'the sheet closes');
    expect(c.powerStock(Power.seats), 1);
    expect(c.profile.coins, 400 - price);
    expect(badge(Power.seats, '1'), findsOneWidget);
  });

  testWidgets('the sheet offers an explicit ad that names its reward', (tester) async {
    final c = powerController(DebugAnalytics());
    await pump(tester, c);
    await tester.tap(power(Power.swap));
    await tester.pumpAndSettle();
    expect(c.powerStock(Power.swap), 0);
    await tester.tap(find.text('Watch an ad · +${Formulas.powerAdUses} Swap'));
    await tester.pumpAndSettle();
    expect(c.powerStock(Power.swap), Formulas.powerAdUses);
    expect(find.text('Watch an ad · +${Formulas.powerAdUses} Swap'), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('an ad that ends without a reward grants nothing and says so', (tester) async {
    final c = powerController(DebugAnalytics(), grantReward: false);
    await pump(tester, c);
    await tester.tap(power(Power.express));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Watch an ad'));
    await tester.pumpAndSettle();
    expect(c.powerStock(Power.express), 0);
    expect(find.textContaining('no reward'), findsOneWidget);
    expect(find.textContaining('Watch an ad'), findsOneWidget, reason: 'the sheet stays open');
  });

  testWidgets('disabled buttons in the sheet say why in one line', (tester) async {
    final c = powerController(DebugAnalytics(), coins: 40);
    await pump(tester, c);
    // Use up the day's power refills.
    final spent = c.profile.rewarded;
    var guard = 0;
    while (c.canAdForPower(Power.swap) && guard++ < 20) {
      await c.adForPower(Power.swap);
    }
    expect(spent.canShow(RewardedPlacement.powerRefill, c.now), isFalse);
    await tester.tap(power(Power.seats));
    await tester.pumpAndSettle();
    expect(find.text('Needs ${Formulas.powerCoinPrice(Power.seats)} coins. You have 40.'), findsOneWidget);
    expect(find.text('No more ad refills today.'), findsOneWidget);
    final coinButton = tester
        .widget<GlossyButton>(find.widgetWithText(GlossyButton, 'Spend ${Formulas.powerCoinPrice(Power.seats)} coins'));
    expect(coinButton.onPressed, isNull);
    final adButton =
        tester.widget<GlossyButton>(find.widgetWithText(GlossyButton, 'Watch an ad · +${Formulas.powerAdUses} Seats'));
    expect(adButton.onPressed, isNull);
  });

  testWidgets('no text on the play screen or the sheet counts people waiting', (tester) async {
    final c = powerController(DebugAnalytics(), stock: {Power.swap: 1});
    await pump(tester, c);
    await tester.tap(power(Power.seats));
    await tester.pumpAndSettle();
    final texts = [
      for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? t.textSpan?.toPlainText() ?? ''
    ];
    expect(texts, isNotEmpty);
    for (final t in texts) {
      expect(t.toLowerCase(), isNot(contains('waiting')), reason: t);
      expect(t, isNot(contains('kg')), reason: t);
    }
  });

  group('Swap', () {
    testWidgets('arming highlights the lanes, two lane taps swap the fronts, and it spends one', (tester) async {
      final handle = tester.ensureSemantics();
      final c = powerController(DebugAnalytics(), stock: {Power.swap: 2});
      await pump(tester, c);
      final a = c.game.frontOf(0)!, b = c.game.frontOf(2)!;

      await tester.tap(power(Power.swap));
      await tester.pump();
      expect(c.armedPower, Power.swap);
      expect(find.bySemanticsLabel(RegExp(r'^Swap: .*Armed')), findsOneWidget);
      expect(c.message, contains('first lane'));

      await tester.tap(front(c, 0));
      await tester.pump();
      expect(c.swapFirstLane, 0);
      expect(find.bySemanticsLabel(RegExp('picked for swap')), findsOneWidget);
      expect(c.game.selection, isNull, reason: 'a swap pick is not a selection');

      await tester.tap(front(c, 2));
      await tester.pump();
      expect(c.armedPower, isNull);
      expect(c.swapFirstLane, isNull);
      expect(c.game.frontOf(0), b);
      expect(c.game.frontOf(2), a);
      expect(c.powerStock(Power.swap), 1);
      expect(find.bySemanticsLabel(RegExp('picked for swap')), findsNothing);
      handle.dispose();
    });

    testWidgets('tapping the armed button again cancels and spends nothing', (tester) async {
      final c = powerController(DebugAnalytics(), stock: {Power.swap: 1});
      await pump(tester, c);
      await tester.tap(power(Power.swap));
      await tester.pump();
      expect(c.armedPower, Power.swap);
      await tester.tap(power(Power.swap));
      await tester.pump();
      expect(c.armedPower, isNull);
      expect(c.powerStock(Power.swap), 1);
    });

    testWidgets('picking the same lane twice cancels, and boarding disarms', (tester) async {
      final handle = tester.ensureSemantics();
      final c = powerController(DebugAnalytics(), stock: {Power.swap: 1});
      await pump(tester, c);
      await tester.tap(power(Power.swap));
      await tester.pump();
      await tester.tap(front(c, 1));
      await tester.pump();
      await tester.tap(front(c, 1));
      await tester.pump();
      expect(c.armedPower, isNull);
      expect(c.powerStock(Power.swap), 1);

      await tester.tap(power(Power.swap));
      await tester.pump();
      c.tapLift();
      await tester.pump();
      expect(c.armedPower, isNull);
      handle.dispose();
    });
  });

  group('left-handed bar', () {
    testWidgets('right-handed: powers left, Send right; left-handed mirrors it', (tester) async {
      final c = powerController(DebugAnalytics(), stock: {Power.swap: 1});
      await pump(tester, c);
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getCenter(power(Power.swap)).dx, lessThan(tester.getCenter(send()).dx));
      expect(tester.getCenter(send()).dx, greaterThan(width / 2));
      expect(tester.getCenter(power(Power.swap)).dx, lessThan(width / 2));
      final rightY = tester.getCenter(send()).dy;

      c.setLeftHanded(true);
      await tester.pump();
      expect(tester.getCenter(send()).dx, lessThan(width / 2));
      expect(tester.getCenter(power(Power.swap)).dx, greaterThan(tester.getCenter(send()).dx));
      expect(tester.getCenter(power(Power.express)).dx, greaterThan(width / 2));
      expect(tester.getCenter(send()).dy, rightY, reason: 'only left and right swap');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the settings sheet has a Left-handed switch', (tester) async {
      final c = powerController(DebugAnalytics());
      await pump(tester, c);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(c.profile.leftHanded, isFalse);
      await tester.tap(find.text('Left-handed layout'));
      await tester.pumpAndSettle();
      expect(c.profile.leftHanded, isTrue);
    });
  });

  group('Restart moved into the settings sheet', () {
    testWidgets('the main screen has no Restart; the sheet restarts free before the first move', (tester) async {
      final c = powerController(DebugAnalytics());
      await pump(tester, c);
      expect(find.textContaining('Restart'), findsNothing);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Free until your first move'), findsOneWidget);
      final before = c.game;
      await tester.tap(find.text('Restart level'));
      await tester.pumpAndSettle();
      expect(c.profile.lives, Formulas.maxLives);
      expect(identical(c.game, before), isFalse);
      expect(find.text('Restart level'), findsNothing, reason: 'the sheet closes');
    });

    testWidgets('after a move it asks first and costs a life', (tester) async {
      final c = powerController(DebugAnalytics());
      await pump(tester, c);
      c.tapQueue(0);
      c.tapBench(0);
      await tester.pump();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Costs 1 life, because you have made moves'), findsOneWidget);

      await tester.tap(find.text('Restart level'));
      await tester.pumpAndSettle();
      expect(find.text('Restart this level?'), findsOneWidget);
      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(c.profile.lives, Formulas.maxLives);
      expect(c.game.benchUsed, 1);

      await tester.tap(find.text('Restart level'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restart · 1 life'));
      await tester.pumpAndSettle();
      expect(c.profile.lives, Formulas.maxLives - 1);
      expect(c.game.benchUsed, 0);
    });

    testWidgets('with one life left the sheet says it needs a spare life', (tester) async {
      final c = powerController(DebugAnalytics());
      c.profile
        ..lives = 1
        ..livesStampedAt = c.now;
      await pump(tester, c);
      c.tapQueue(0);
      c.tapBench(0);
      await tester.pump();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Needs a spare life'), findsOneWidget);
      await tester.tap(find.text('Restart level'));
      await tester.pumpAndSettle();
      expect(c.game.benchUsed, 1);
    });
  });

  group('reveal', () {
    testWidgets('a revealed person gets a sparkle burst, and none under reduced motion', (tester) async {
      for (final animate in [true, false]) {
        final c = powerController(DebugAnalytics());
        await pump(tester, c, animate: animate);
        final serial = c.revealSerial;
        c.tapQueue(0);
        c.tapBench(0); // the unknown person behind steps up and is revealed
        expect(c.revealSerial, serial + 1);
        expect(c.revealedLane, 0);
        await tester.pump(const Duration(milliseconds: 60));
        final burst = find.descendant(of: find.byType(EffectsLayer), matching: find.byType(CustomPaint));
        expect(burst, animate ? findsWidgets : findsNothing, reason: 'animate: $animate');
        await tester.pump(const Duration(milliseconds: 700));
        expect(burst, findsNothing, reason: 'the burst removes itself');
        expect(tester.takeException(), isNull);
        // Unmount before the idle clock outlives the test.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the person who steps up is drawn as a normal front, with a floor tag', (tester) async {
      final handle = tester.ensureSemantics();
      final c = powerController(DebugAnalytics());
      await pump(tester, c);
      expect(find.bySemanticsLabel(RegExp('Someone you cannot see yet')), findsWidgets);
      c.tapQueue(0);
      c.tapBench(0);
      await tester.pump();
      final who = c.game.frontOf(0)!;
      expect(front(c, 0), findsOneWidget);
      expect(GameController.describe(who), isNotEmpty);
      handle.dispose();
    });
  });
}
