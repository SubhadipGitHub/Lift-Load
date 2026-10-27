import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/services/tester_log.dart';
import 'package:lift_load/ui/game_controller.dart';

import '../tool/gate_a_report.dart';

/// A dry run of the whole Gate A pipeline with bots standing in for testers: real generated levels 1-20, played
/// through [GameController] (so every event is the one a tester's build would log), exported as a tester would send
/// it, and read back by the report. It checks the kit end to end, not the game's difficulty or a human's clear rate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // haptics go through a platform channel

  /// The weight-aware greedy strategy of `Solver`, but played through the controller's taps. [sloppyEvery] makes the
  /// bot ignore the lift's limit on every n-th level, so crashes, retries and the fairness question happen too.
  Future<void> playLevels(
    GameController c,
    void Function() tick, {
    required int upTo,
    int sloppyEvery = 0,
    int abandonAt = 0,
    bool buysPowers = false,
  }) async {
    c.startLevel();
    var guard = 0;
    while (c.profile.level <= upTo && guard++ < 400) {
      final number = c.game.level.number;
      final firstAttempt = (c.profile.attempts[number] ?? 1) == 1;
      if (buysPowers) {
        for (final p in [Power.seats, Power.trip]) {
          while (c.canBuyPower(p) && c.profile.stock(p) < 1) {
            c.buyPowerWithCoins(p);
          }
        }
      }
      tick();
      if (number == Power.swap.unlockLevel && firstAttempt) c.usePower(Power.swap); // none in stock: an empty tap
      if (number == abandonAt && firstAttempt) {
        // A tester walks away after one move: the restart gives up the attempt and starts the next.
        _boardBest(c, ignoreLimit: false);
        c.restart();
        continue;
      }
      final sloppy = sloppyEvery > 0 && number % sloppyEvery == 0 && firstAttempt;
      var steps = 0;
      while (c.game.phase == Phase.playing && steps++ < 4000) {
        final g = c.game;
        if (buysPowers && g.tripsLeft <= 1 && c.profile.stock(Power.trip) > 0 && c.powerUsable(Power.trip)) {
          c.usePower(Power.trip);
          continue;
        }
        if (buysPowers &&
            g.benchUsed >= g.benchLength - 1 &&
            c.profile.stock(Power.seats) > 0 &&
            c.powerUsable(Power.seats)) {
          c.usePower(Power.seats);
          continue;
        }
        if (_boardBest(c, ignoreLimit: sloppy)) continue;
        if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) {
          _send(c);
          continue;
        }
        if (_dig(c)) continue;
        if (g.riders.isEmpty) break;
        _send(c);
      }
      if (c.game.phase == Phase.falling) c.finishCrash();
      tick();
      switch (c.game.phase) {
        case Phase.won:
          if (c.askHeavyTypes) c.answerHeavyTypes('the aunty and the office worker');
          if (c.askUnknownFair) c.answerUnknownFair(c.game.level.number.isEven);
          await c.nextLevel();
        case Phase.failed:
          if (c.askCrashFair) c.rateCrash(fair: false);
          if (!c.canRetry) return;
          c.retry();
        default:
          return; // stuck: a jam the bot cannot dig out of
      }
    }
  }

  test('bots play levels 1-20 through the tester build and the report reads what they send', () async {
    var seconds = 0;
    final start = DateTime(2026, 10, 27, 10);
    DateTime clock() => start.add(Duration(seconds: seconds));

    ({GameController c, TesterLog log, DebugAnalytics debug}) build(String code) {
      final debug = DebugAnalytics();
      final log = TesterLog(code: code, clock: clock);
      final c = GameController(
        profile: Profile.fresh(start),
        ads: StubAdsService(delay: Duration.zero),
        analytics: FanOutAnalytics([debug, log]),
        clock: clock,
        tester: const TesterConfig(enabled: true),
        testerLog: log,
      );
      return (c: c, log: log, debug: debug);
    }

    void tick() => seconds += 25;

    final careful = build('amber-brass-cable');
    final sloppy = build('coral-delta-ember');
    final buyer = build('fern-glow-harbor');
    await playLevels(careful.c, tick, upTo: 20);
    seconds += 3 * 3600; // the next tester starts another day
    await playLevels(sloppy.c, tick, upTo: 20, sloppyEvery: 5, abandonAt: 7);
    seconds += 3 * 3600;
    // 300 coins buys two powers the moment they unlock; more coins come from wins.
    buyer.c.profile.coins = 2000;
    await playLevels(buyer.c, tick, upTo: 20, buysPowers: true);

    final files = [
      for (final t in [careful, sloppy, buyer]) GateAFormat.decode(t.log.exportCode()),
    ];
    final report = GateAReport.from(files);
    final text = report.render();

    expect(report.testers, hasLength(3));
    expect(report.startedLevel1, 3);
    expect(report.clearedTenInOneSitting, greaterThanOrEqualTo(2), reason: 'bots win the early levels');
    expect(report.hardDecided, greaterThanOrEqualTo(3), reason: 'level 10 and 20 are Hard, for each bot');
    expect(report.crashes, greaterThan(0), reason: 'the sloppy bot overloads on purpose');
    expect(report.crashesRated, greaterThan(0));
    expect(report.heavyAnswers, isNotEmpty);
    expect(report.unknownFair + report.unknownUnfair, greaterThanOrEqualTo(2), reason: 'asked once per tester');
    expect(report.powerEmptyTaps['swap'], greaterThan(0), reason: 'an empty tap on the Swap unlock level');
    expect(report.powerUsed, isNotEmpty, reason: 'the buyer spends powers');
    expect(report.testersUsingPower, {'fern-glow-harbor'});
    expect(report.hardDecidedUnassisted, lessThanOrEqualTo(report.hardDecided));
    for (final line in ['Powers (', 'Used:', 'Unknown people fair', 'first attempts that used no power']) {
      expect(text, contains(line));
    }
    expect(text, isNot(contains('Exception')));

    // What a tester sends says nothing about weight.
    for (final t in [careful, sloppy, buyer]) {
      final json = t.log.exportJson();
      expect(json.contains('kg'), isFalse, reason: t.log.code);
      expect(t.log.dropped, 0);
      expect(t.log.events.length, lessThan(TesterLog.maxEvents));
    }
  });
}

bool _boardBest(GameController c, {required bool ignoreLimit}) {
  final g = c.game;
  var bestKg = -1;
  int? bestSeat;
  int? bestLane;
  bool fits(int kg) => ignoreLimit || g.load + kg <= g.capacity;
  for (var i = 0; i < g.benchLength; i++) {
    final r = g.benchAt(i);
    if (r != null && g.goesTo(r.floor) && fits(r.kg) && r.kg > bestKg) {
      bestKg = r.kg;
      bestSeat = i;
      bestLane = null;
    }
  }
  for (var i = 0; i < g.laneCount; i++) {
    if (g.laneLength(i) == 0 || g.isLaneLocked(i)) continue;
    final r = g.laneAt(i, 0);
    if (g.goesTo(r.floor) && fits(r.kg) && r.kg > bestKg) {
      bestKg = r.kg;
      bestLane = i;
      bestSeat = null;
    }
  }
  if (bestSeat != null) {
    c.tapBench(bestSeat);
  } else if (bestLane != null) {
    c.tapQueue(bestLane);
  } else {
    return false;
  }
  c.tapLift();
  return true;
}

bool _dig(GameController c) {
  final g = c.game;
  var seat = -1;
  for (var i = 0; i < g.benchLength && seat < 0; i++) {
    if (g.benchAt(i) == null) seat = i;
  }
  if (seat < 0) return false;
  int? digLane;
  var digDepth = 1 << 30;
  for (var i = 0; i < g.laneCount; i++) {
    final n = g.laneLength(i);
    if (n == 0 || g.isLaneLocked(i) || g.goesTo(g.laneAt(i, 0).floor)) continue;
    for (var d = 0; d < n && d < digDepth; d++) {
      final r = g.laneAt(i, d);
      if (g.goesTo(r.floor) && g.load + r.kg <= g.capacity) {
        digDepth = d;
        digLane = i;
        break;
      }
    }
  }
  if (digLane == null) return false;
  c
    ..tapQueue(digLane)
    ..tapBench(seat);
  return true;
}

void _send(GameController c) {
  c.send();
  if (c.game.phase == Phase.departing) c.finishSend();
  if (c.game.phase == Phase.falling) c.finishCrash();
}
