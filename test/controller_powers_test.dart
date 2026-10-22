import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/services/ad_policy.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/game_controller.dart';

const c = Floor.coral, t = Floor.teal;

/// Level 30 (every power unlocked). Lane 0: kid, uncle. Lane 1: officeW, gym. Lane 2: aunty.
Level lobby({int number = 30}) {
  var id = 0;
  Resident r(Floor f, ResidentType ty) => Resident(id: ++id, type: ty, floor: f);
  return Level(
    number: number,
    capacity: 280,
    trips: 4,
    benchSize: 2,
    difficulty: Difficulty.normal,
    floors: const [c, t],
    queues: [
      [r(c, ResidentType.kid), r(t, ResidentType.uncle)],
      [r(t, ResidentType.officeW), r(c, ResidentType.gym)],
      [r(c, ResidentType.aunty)],
    ],
    unknownIds: const {2, 4},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final day = DateTime(2026, 10, 22, 12);

  ({GameController ctl, DebugAnalytics log, Profile profile}) make({
    Map<Power, int> stock = const {},
    int coins = 0,
    bool grant = true,
    int number = 30,
  }) {
    final profile = Profile.fresh(day)
      ..coins = coins
      ..level = number;
    stock.forEach(profile.addPower);
    final log = DebugAnalytics();
    final ctl = GameController(
      profile: profile,
      ads: StubAdsService(delay: Duration.zero, grantReward: grant),
      analytics: log,
      clock: () => day,
      levelFor: (_) => lobby(number: number),
    )..startLevel();
    return (ctl: ctl, log: log, profile: profile);
  }

  List<Map<String, Object>> events(DebugAnalytics a, String name) =>
      [for (final (n, params) in a.history) if (n == name) params];

  group('empty stock', () {
    test('a tap with nothing in stock spends nothing and logs the tap', () {
      final m = make();
      m.ctl.usePower(Power.seats);
      expect(m.ctl.game.benchLength, 2);
      expect(events(m.log, 'power_empty_tapped').single['power'], 'seats');
    });

    test('a locked power says when it unlocks and does not log an empty tap', () {
      final m = make(number: 10, stock: {Power.swap: 1});
      m.ctl.usePower(Power.swap);
      expect(m.ctl.armedPower, isNull);
      expect(m.ctl.message, contains('14'));
      expect(events(m.log, 'power_empty_tapped'), isEmpty);
    });
  });

  group('using a power', () {
    test('+2 seats and +1 trip spend one from stock and log it', () {
      final m = make(stock: {Power.seats: 1, Power.trip: 1});
      m.ctl.usePower(Power.seats);
      m.ctl.usePower(Power.trip);
      expect(m.ctl.game.benchLength, 4);
      expect(m.ctl.game.tripsTotal, 5);
      expect(m.profile.stock(Power.seats), 0);
      expect(m.profile.stock(Power.trip), 0);
      expect(events(m.log, 'power_used').map((e) => e['power']), ['seats', 'trip']);
    });

    test('a power at its per-level cap is refused without spending stock', () {
      final m = make(stock: {Power.seats: 3});
      m.ctl.usePower(Power.seats);
      m.ctl.usePower(Power.seats);
      expect(m.profile.stock(Power.seats), 2);
      expect(m.ctl.game.benchLength, 4);
    });

    test('Express needs a selection, then delivers and spends one', () {
      final m = make(stock: {Power.express: 1});
      m.ctl.usePower(Power.express);
      expect(m.profile.stock(Power.express), 1);
      expect(m.ctl.message, contains('Select'));
      m.ctl.tapQueue(2);
      m.ctl.usePower(Power.express);
      expect(m.profile.stock(Power.express), 0);
      expect(m.ctl.game.visibleLanes[2], isEmpty);
    });
  });

  group('Swap', () {
    test('arms, takes two lanes, swaps the fronts and spends one', () {
      final m = make(stock: {Power.swap: 1});
      final a = m.ctl.game.frontOf(0)!.id, b = m.ctl.game.frontOf(1)!.id;
      m.ctl.usePower(Power.swap);
      expect(m.ctl.armedPower, Power.swap);
      expect(m.profile.stock(Power.swap), 1, reason: 'arming alone is free');
      m.ctl.tapQueue(0);
      expect(m.ctl.swapFirstLane, 0);
      m.ctl.tapQueue(1);
      expect(m.ctl.game.frontOf(0)!.id, b);
      expect(m.ctl.game.frontOf(1)!.id, a);
      expect(m.ctl.armedPower, isNull);
      expect(m.profile.stock(Power.swap), 0);
      expect(events(m.log, 'power_used').single['power'], 'swap');
    });

    test('tapping the armed button again, the same lane twice, or the bench cancels for free', () {
      final m = make(stock: {Power.swap: 1});
      m.ctl.usePower(Power.swap);
      m.ctl.usePower(Power.swap);
      expect(m.ctl.armedPower, isNull);

      m.ctl.usePower(Power.swap);
      m.ctl.tapQueue(0);
      m.ctl.tapQueue(0);
      expect(m.ctl.armedPower, isNull);

      m.ctl.usePower(Power.swap);
      m.ctl.tapBench(0);
      expect(m.ctl.armedPower, isNull);
      expect(m.profile.stock(Power.swap), 1);
    });

    test('while armed, a lane tap picks a lane instead of selecting a resident', () {
      final m = make(stock: {Power.swap: 1});
      m.ctl.usePower(Power.swap);
      m.ctl.tapQueue(0);
      expect(m.ctl.game.selected, isNull);
    });

    test('a new level clears an armed Swap', () {
      final m = make(stock: {Power.swap: 1});
      m.ctl.usePower(Power.swap);
      m.ctl.startLevel();
      expect(m.ctl.armedPower, isNull);
      expect(m.ctl.swapFirstLane, isNull);
    });
  });

  group('refills', () {
    test('coins buy one use at the configured price', () {
      final m = make(coins: Formulas.powerCoinPrice(Power.trip) + 10);
      expect(m.ctl.canBuyPower(Power.trip), isTrue);
      m.ctl.buyPowerWithCoins(Power.trip);
      expect(m.profile.stock(Power.trip), 1);
      expect(m.profile.coins, 10);
      expect(events(m.log, 'power_bought').single['coins'], Formulas.powerCoinPrice(Power.trip));
    });

    test('too few coins buys nothing', () {
      final m = make(coins: Formulas.powerCoinPrice(Power.trip) - 1);
      m.ctl.buyPowerWithCoins(Power.trip);
      expect(m.profile.stock(Power.trip), 0);
      expect(m.profile.coins, Formulas.powerCoinPrice(Power.trip) - 1);
    });

    test('a watched ad grants the configured uses, and counts against the refill cap', () async {
      final m = make();
      await m.ctl.adForPower(Power.express);
      expect(m.profile.stock(Power.express), Formulas.powerAdUses);
      expect(m.profile.rewarded.used[RewardedPlacement.powerRefill.name], 1);
      expect(events(m.log, 'power_refill_ad'), hasLength(1));
    });

    test('an ad that does not complete grants nothing', () async {
      final m = make(grant: false);
      await m.ctl.adForPower(Power.express);
      expect(m.profile.stock(Power.express), 0);
    });

    test('the daily refill cap closes the offer', () async {
      final m = make();
      for (var i = 0; i < Formulas.powerRefillDailyCap; i++) {
        await m.ctl.adForPower(Power.seats);
      }
      expect(m.ctl.canAdForPower(Power.seats), isFalse);
      await m.ctl.adForPower(Power.seats);
      expect(m.profile.stock(Power.seats), Formulas.powerRefillDailyCap * Formulas.powerAdUses);
    });
  });

  group('locked powers', () {
    test('coins cannot buy a power the player has not reached', () {
      final m = make(coins: 1000);
      m.profile.level = 5;
      expect(m.ctl.canBuyPower(Power.swap), isFalse);
      m.ctl.buyPowerWithCoins(Power.swap);
      expect(m.profile.coins, 1000);
      expect(m.profile.stock(Power.swap), 0);
    });

    test('an ad cannot be shown for one, and none is offered outside play', () async {
      final m = make();
      m.profile.level = 5;
      await m.ctl.adForPower(Power.swap);
      expect(m.profile.rewarded.totalToday, 0);
      expect(m.profile.stock(Power.swap), 0);
    });
  });

  test('left-handed is saved in the profile and logged', () {
    final m = make();
    m.ctl.setLeftHanded(true);
    expect(m.profile.leftHanded, isTrue);
    expect(events(m.log, 'setting_changed').last['setting'], 'left_handed');
  });

  test('level_start reports lane count and unknown share', () {
    final m = make(stock: {Power.seats: 1});
    final start = events(m.log, 'level_start').single;
    expect(start['lanes'], 3);
    expect(start['unknown_share'], 40); // 2 of 5 residents
  });

  test('powers_used reaches the abandon event', () {
    final m = make(stock: {Power.seats: 1});
    m.ctl.usePower(Power.seats);
    expect(m.ctl.powerUsable(Power.seats), isFalse, reason: 'at its cap');
    m.ctl.tapQueue(2);
    m.ctl.tapBench(0);
    m.ctl.quitToHome();
    expect(events(m.log, 'level_abandon').single['powers_used'], 1);
  });
}
