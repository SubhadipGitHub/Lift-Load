import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/services/tester_log.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/screens/home_screen.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/gate_a_report.dart';
import 'helpers.dart';
import 'responsive_test.dart' show crashLevel;

/// One kid, one send: a win on level [number].
Level oneKid(int number) => Level(
      number: number,
      capacity: 280,
      trips: 5,
      benchSize: 4,
      difficulty: Difficulty.hard,
      floors: const [Floor.coral],
      queues: const [
        [Resident(id: 1, type: ResidentType.kid, floor: Floor.coral)],
        [],
        [],
        [],
      ],
    );

/// [oneKid] with the kid unknown (a ghost until the front, which it already is).
Level oneUnknownKid(int number) => Level(
      number: number,
      capacity: 280,
      trips: 5,
      benchSize: 4,
      difficulty: Difficulty.hard,
      floors: const [Floor.coral],
      unknownIds: const {1},
      queues: const [
        [Resident(id: 1, type: ResidentType.kid, floor: Floor.coral)],
        [],
        [],
        [],
      ],
    );

void main() {
  final day = DateTime(2026, 10, 21, 12);

  ({GameController c, DebugAnalytics debug, TesterLog log}) tester({required Level Function(int) levelFor}) {
    final debug = DebugAnalytics();
    final log = TesterLog(code: 'amber-brass-cable', clock: () => day);
    final c = GameController(
      profile: Profile.fresh(day),
      ads: StubAdsService(delay: Duration.zero),
      analytics: FanOutAnalytics([debug, log]),
      clock: () => day,
      levelFor: levelFor,
      tester: const TesterConfig(enabled: true),
      testerLog: log,
    );
    return (c: c, debug: debug, log: log);
  }

  List<Map<String, Object>> events(DebugAnalytics a, String name) => [
        for (final (e, p) in a.history)
          if (e == name) p
      ];

  group('attempts', () {
    test('a restart after a move gives up attempt 1 and starts attempt 2', () {
      final a = DebugAnalytics();
      final c = controller(a, levelFor: oneKid)..startLevel();
      expect(events(a, 'level_start').last['attempt'], 1);
      c
        ..tapQueue(0)
        ..tapBench(0)
        ..restart();
      expect(events(a, 'level_abandon').single['attempt'], 1);
      expect(events(a, 'level_start').last['attempt'], 2);
    });

    test('a fail carries its attempt, and Retry starts the next one', () {
      final a = DebugAnalytics();
      final c = controller(a, levelFor: (_) => crashLevel())..startLevel();
      c
        ..tapQueue(0)
        ..tapLift()
        ..finishCrash();
      expect(events(a, 'level_fail').single['attempt'], 1);
      c.retry();
      expect(events(a, 'level_start').last['attempt'], 2);
    });

    test('a win records its attempt and how many continues it took', () {
      final a = DebugAnalytics();
      final c = controller(a, levelFor: oneKid)..startLevel();
      c
        ..tapQueue(0)
        ..tapLift()
        ..send()
        ..finishSend();
      expect(c.game.phase, Phase.won);
      expect(events(a, 'level_win').single, containsPair('attempt', 1));
      expect(events(a, 'level_win').single, containsPair('continues', 0));
    });

    test('attempt counts survive a save, and old saves start empty', () {
      final p = Profile.fresh(day)..attempts.addAll({3: 2, 10: 5});
      expect(Profile.fromJson(p.toJson(), day).attempts, {3: 2, 10: 5});
      final old = Profile.fresh(day).toJson()..remove('attempts');
      expect(Profile.fromJson(old, day).attempts, isEmpty);
    });
  });

  group('tester mode', () {
    test('play stops after level 60 and the last win logs test_complete', () {
      final t = tester(levelFor: oneKid);
      t.c.profile.level = TesterConfig.lastLevel;
      t.c
        ..startLevel()
        ..tapQueue(0)
        ..tapLift()
        ..send()
        ..finishSend();
      expect(t.c.game.phase, Phase.won);
      expect(t.c.testComplete, isTrue);
      expect(events(t.debug, 'test_complete'), hasLength(1));
      t.c.nextLevel();
      expect(t.c.game.level.number, TesterConfig.lastLevel, reason: 'no level 61 in the tester build');
    });

    test('outside the tester build nothing is capped or asked', () {
      final a = DebugAnalytics();
      final c = controller(a, levelFor: oneKid)..profile.level = 61;
      expect(c.testComplete, isFalse);
      c.startLevel();
      expect(c.game.level.number, 61);
    });

    test('a crash asks once whether it was fair', () {
      final t = tester(levelFor: (_) => crashLevel());
      t.c
        ..startLevel()
        ..tapQueue(0)
        ..tapLift()
        ..finishCrash();
      expect(t.c.askCrashFair, isTrue);
      t.c.rateCrash(fair: false);
      expect(t.c.askCrashFair, isFalse);
      expect(events(t.debug, 'crash_fairness').single, {'level': 30, 'attempt': 1, 'fair': false});
    });

    test('the heavy-types question comes once, from the level 15 win on', () {
      final t = tester(levelFor: oneKid);
      void win(int level) {
        t.c.profile.level = level;
        t.c
          ..startLevel()
          ..tapQueue(0)
          ..tapLift()
          ..send()
          ..finishSend();
      }

      win(14);
      expect(t.c.askHeavyTypes, isFalse);
      win(15);
      expect(t.c.askHeavyTypes, isTrue);
      t.c.answerHeavyTypes('  the uncle and the guard ');
      expect(t.c.askHeavyTypes, isFalse);
      expect(events(t.debug, 'exit_heavy_types').single,
          {'level': 15, 'answer': 'the uncle and the guard', 'skipped': false});
      win(16);
      expect(t.c.askHeavyTypes, isFalse);
    });
  });

  group('powers on', () {
    void win(({GameController c, DebugAnalytics debug, TesterLog log}) t, int level) {
      t.c.profile.level = level;
      t.c
        ..startLevel()
        ..tapQueue(0)
        ..tapLift()
        ..send()
        ..finishSend();
    }

    test('the unknown-people question comes once, on a win with unknown people from level 13 on', () {
      final t = tester(levelFor: oneUnknownKid);
      win(t, 12);
      expect(t.c.askUnknownFair, isFalse, reason: 'before level 13');
      win(t, 13);
      expect(t.c.askUnknownFair, isTrue);
      t.c.answerUnknownFair(false);
      expect(t.c.askUnknownFair, isFalse);
      expect(events(t.debug, 'exit_unknown_fair').single, {'level': 13, 'skipped': false, 'fair': false});
      win(t, 14);
      expect(t.c.askUnknownFair, isFalse, reason: 'once only');
    });

    test('a skip is logged as skipped, with no verdict', () {
      final t = tester(levelFor: oneUnknownKid);
      win(t, 13);
      t.c.answerUnknownFair(null);
      expect(events(t.debug, 'exit_unknown_fair').single, {'level': 13, 'skipped': true});
    });

    test('a win with nobody unknown, or outside the tester build, asks nothing', () {
      final t = tester(levelFor: oneKid);
      win(t, 20);
      expect(t.c.askUnknownFair, isFalse);
      final a = DebugAnalytics();
      final c = controller(a, levelFor: oneUnknownKid)..profile.level = 20;
      c
        ..startLevel()
        ..tapQueue(0)
        ..tapLift()
        ..send()
        ..finishSend();
      expect(c.askUnknownFair, isFalse);
    });

    test('never on the win that asks the heavy-types question', () {
      final t = tester(levelFor: oneUnknownKid);
      win(t, 15);
      expect(t.c.askHeavyTypes, isTrue);
      expect(t.c.askUnknownFair, isFalse);
      t.c.answerHeavyTypes('uncle');
      expect(t.c.askUnknownFair, isFalse, reason: 'not on the same win, straight after');
      win(t, 16);
      expect(t.c.askUnknownFair, isTrue, reason: 'the next win');
    });

    test('the tester log keeps what the powers report reads and nothing else about them', () {
      final log = TesterLog(code: 'mint-river-zinc', clock: () => day);
      for (final name in [
        'power_used',
        'power_bought',
        'power_refill_ad',
        'power_empty_tapped',
        'exit_unknown_fair',
        'unknown_revealed',
        'left_handed_set',
      ]) {
        log.log(name, {'level': 14});
      }
      expect(log.events.map((e) => e['e']),
          ['power_used', 'power_bought', 'power_refill_ad', 'power_empty_tapped', 'exit_unknown_fair']);
      expect(log.unknownFairAsked, isTrue);
    });

    test('a power spent through the controller reaches the log with its level', () {
      final t = tester(levelFor: oneKid);
      t.c.profile
        ..level = 30
        ..addPower(Power.seats, 1);
      t.c.startLevel();
      t.c.usePower(Power.seats);
      final used = t.log.events.where((e) => e['e'] == 'power_used').single;
      expect(used, containsPair('power', 'seats'));
      expect(used, containsPair('level', 30));
    });
  });

  group('tester log', () {
    test('keeps only what the report reads, and the export reads back in both forms', () {
      final log = TesterLog(code: 'mint-river-zinc', clock: () => day)
        ..log('level_start', {'level': 1, 'attempt': 1})
        ..log('scale_used', {'level': 1, 'left': 2})
        ..log('level_win', {'level': 1, 'attempt': 1, 'continues': 0});
      expect(log.events.map((e) => e['e']), ['level_start', 'level_win']);
      for (final text in [log.exportJson(), log.exportCode()]) {
        final back = GateAFormat.decode(text);
        expect(back['tester'], 'mint-river-zinc');
        expect((back['events'] as List).length, 2);
      }
      expect(() => GateAFormat.decode('{"format":"other"}'), throwsFormatException);
    });

    test('the tester code and events persist across app restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = await TesterLog.open(prefs);
      first.log('level_start', {'level': 1, 'attempt': 1});
      final again = await TesterLog.open(prefs);
      expect(again.code, first.code);
      expect(again.events, hasLength(1));
    });
  });

  group('report', () {
    Map<String, dynamic> result(String code, List<Map<String, Object>> events) =>
        {'format': GateAFormat.format, 'tester': code, 'events': events};
    Map<String, Object> e(int t, String name, Map<String, Object> p) => {'t': t, 'e': name, ...p};

    List<Map<String, Object>> clearsOneToTen(int from) => [
          for (var n = 1; n <= 10; n++) ...[
            e(from + n * 60, 'level_start', {'level': n, 'difficulty': n == 10 ? 'hard' : 'normal', 'attempt': 1}),
            e(from + n * 60 + 30, 'level_win', {'level': n, 'attempt': 1, 'continues': 0}),
          ],
        ];

    test('computes the four gate metrics', () {
      final report = GateAReport.from([
        // A: clears 1-10 in one sitting; L10 hard won first time.
        result('a', [
          ...clearsOneToTen(0),
          e(700, 'level_fail', {'level': 11, 'kind': 'crash', 'attempt': 1}),
          e(701, 'crash_fairness', {'level': 11, 'attempt': 1, 'fair': true}),
        ]),
        // B: a two-hour break in the middle, and L10 hard lost then won.
        result('b', [
          ...clearsOneToTen(0).take(10),
          ...[
            for (final x in clearsOneToTen(9000).skip(10))
              if (x['level'] != 10) x,
          ],
          e(9600, 'level_start', {'level': 10, 'difficulty': 'hard', 'attempt': 1}),
          e(9650, 'level_fail', {'level': 10, 'kind': 'crash', 'attempt': 1}),
          e(9651, 'crash_fairness', {'level': 10, 'attempt': 1, 'fair': false}),
          e(9700, 'level_start', {'level': 10, 'difficulty': 'hard', 'attempt': 2}),
          e(9750, 'level_win', {'level': 10, 'attempt': 2, 'continues': 0}),
          e(9800, 'exit_heavy_types', {'level': 15, 'answer': 'uncle', 'skipped': false}),
        ]),
      ]);
      expect(report.testers, hasLength(2));
      expect((report.clearedTenInOneSitting, report.startedLevel1), (1, 2));
      expect((report.hardFirstWins, report.hardDecided), (1, 2));
      expect((report.crashesUnfair, report.crashesRated, report.crashes), (1, 2, 2));
      expect(report.heavyAnswers.single, ('b', 'uncle'));
      expect(report.render(), contains('First-attempt wins on Hard levels'));
    });

    test('reports power use, unassisted Hard first attempts and the unknown-people answers', () {
      final report = GateAReport.from([
        result('a', [
          // L10 hard, first attempt won with a power used; L20 hard, first attempt lost with none.
          e(1, 'level_start', {'level': 10, 'difficulty': 'hard', 'attempt': 1}),
          e(2, 'power_used', {'power': 'seats', 'level': 10, 'left': 0}),
          e(3, 'level_win', {'level': 10, 'attempt': 1, 'continues': 0, 'powers_used': 1}),
          e(4, 'level_start', {'level': 20, 'difficulty': 'hard', 'attempt': 1}),
          e(5, 'level_fail', {'level': 20, 'kind': 'outOfTrips', 'attempt': 1, 'powers_used': 0}),
          e(6, 'power_bought', {'power': 'swap', 'coins': 150, 'level': 20}),
          e(7, 'power_empty_tapped', {'power': 'express', 'level': 29}),
          e(8, 'power_empty_tapped', {'power': 'express', 'level': 29}),
          e(9, 'power_refill_ad', {'power': 'swap', 'level': 21, 'stub': true}),
          e(10, 'exit_unknown_fair', {'level': 13, 'skipped': false, 'fair': true}),
        ]),
        result('b', [
          e(1, 'level_start', {'level': 10, 'difficulty': 'hard', 'attempt': 1}),
          e(2, 'level_win', {'level': 10, 'attempt': 1, 'continues': 0, 'powers_used': 0}),
          e(3, 'exit_unknown_fair', {'level': 14, 'skipped': false, 'fair': false}),
          e(4, 'exit_unknown_fair', {'level': 14, 'skipped': true}),
        ]),
      ]);
      expect((report.hardFirstWins, report.hardDecided), (2, 3));
      expect((report.hardFirstWinsUnassisted, report.hardDecidedUnassisted), (1, 2));
      expect(report.powerUsed, {'seats': 1});
      expect(report.powerBought, {'swap': 1});
      expect(report.powerAdRefills, {'swap': 1});
      expect(report.powerEmptyTaps, {'express': 2});
      expect(report.testersUsingPower, {'a'});
      expect(report.firstPowerLevel, 10);
      expect((report.unknownFair, report.unknownUnfair, report.unknownSkipped), (1, 1, 1));
      final text = report.render();
      expect(text, contains('first attempts that used no power'));
      expect(text, contains('Unknown people fair'));
      expect(text, contains('Tapped while empty:  express 2'));
    });

    test('a file from before the powers (no powers_used, no power events) still reads', () {
      final report = GateAReport.from([
        result('old', [
          e(1, 'level_start', {'level': 10, 'difficulty': 'hard', 'attempt': 1}),
          e(2, 'level_win', {'level': 10, 'attempt': 1, 'continues': 0}),
        ]),
      ]);
      expect((report.hardFirstWinsUnassisted, report.hardDecidedUnassisted), (1, 1));
      expect(report.powerUsed, isEmpty);
      expect(report.render(), contains('Used:                none'));
    });

    test('a resend from the same tester replaces the earlier file', () {
      final early = result('a', clearsOneToTen(0).take(4).toList());
      final full = result('a', clearsOneToTen(0));
      expect(GateAReport.from([early, full]).testers, ['a']);
      expect(GateAReport.from([full, early]).clearedTenInOneSitting, 1);
    });
  });

  group('tester screens', () {
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('the crash sheet asks fair or unfair, and the answer clears it', (w) async {
      await phone(w);
      final t = tester(levelFor: (_) => crashLevel());
      t.c.startLevel();
      await w.pumpWidget(app(PlayScreen(controller: t.c)));
      t.c
        ..tapQueue(0)
        ..tapLift();
      await w.pumpAndSettle();
      expect(find.textContaining('was that crash fair?'), findsOneWidget);
      await w.tap(find.text('Unfair'));
      await w.pumpAndSettle();
      expect(find.textContaining('was that crash fair?'), findsNothing);
      expect(events(t.debug, 'crash_fairness').single['fair'], isFalse);
    });

    testWidgets('the level 15 win asks for the heavy types in free text', (w) async {
      await phone(w);
      final t = tester(levelFor: oneKid);
      t.c
        ..profile.level = 15
        ..startLevel();
      await w.pumpWidget(app(PlayScreen(controller: t.c)));
      t.c
        ..tapQueue(0)
        ..tapLift()
        ..send();
      await w.pumpAndSettle();
      expect(find.textContaining('which residents do you think are the heaviest?'), findsOneWidget);
      await w.enterText(find.byType(TextField), 'the uncle');
      await w.tap(find.text('Save answer'));
      await w.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(t.log.heavyTypesAsked, isTrue);
    });

    testWidgets('a win with unknown people from level 13 asks if they felt fair', (w) async {
      await phone(w);
      final t = tester(levelFor: oneUnknownKid);
      t.c
        ..profile.level = 13
        ..startLevel();
      await w.pumpWidget(app(PlayScreen(controller: t.c)));
      t.c
        ..tapQueue(0)
        ..tapLift()
        ..send();
      await w.pumpAndSettle();
      expect(find.textContaining('did the unknown people in the queue feel fair?'), findsOneWidget);
      await w.tap(find.text('Fair'));
      await w.pumpAndSettle();
      expect(find.textContaining('did the unknown people'), findsNothing);
      expect(events(t.debug, 'exit_unknown_fair').single['fair'], isTrue);
    });

    testWidgets('after level 60 Home offers results instead of a level 61', (w) async {
      await phone(w);
      final t = tester(levelFor: oneKid);
      t.c.profile.level = TesterConfig.lastLevel + 1;
      await w.pumpWidget(app(HomeScreen(controller: t.c)));
      await w.pump();
      expect(find.text('Test complete · Send results'), findsOneWidget);
      expect(find.textContaining('Tester build · amber-brass-cable'), findsOneWidget);
      expect(find.textContaining('Level 61'), findsNothing);
      await w.tap(find.text('Test complete · Send results'));
      await w.pumpAndSettle();
      expect(find.text('Copy results code'), findsOneWidget);
    });
  });
}
