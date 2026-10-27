// Gate A report: `dart run tool/gate_a_report.dart results/*`
//
// Reads the files testers return from the tester build (a .json download or
// a pasted LLGA1. code saved to a text file), keeps the latest file per
// tester code, and prints the four prototype metrics from docs/PRD.md
// ("Success criteria") against their targets, then per-level detail.
// See docs/gate-a.md for how to run the test.
import 'dart:io';

import 'package:lift_load/game/cast.dart';
import 'package:lift_load/services/tester_config.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/gate_a_report.dart <result files...>');
    exitCode = 64;
    return;
  }
  final results = <Map<String, dynamic>>[];
  for (final path in args) {
    try {
      results.add(GateAFormat.decode(File(path).readAsStringSync()));
    } on Object catch (e) {
      stderr.writeln('Skipping $path: $e');
    }
  }
  stdout.write(GateAReport.from(results).render());
}

/// A sitting ends after this much idle time between logged events.
const int sittingGapSeconds = 30 * 60;

class LevelStats {
  LevelStats(this.level);

  final int level;
  String difficulty = '?';
  final Set<String> started = {};
  int firstDecided = 0;
  int firstWins = 0;
  int firstWinsWithContinue = 0;
  final Map<String, int> fails = {};
  int abandons = 0;
  int overloads = 0;
  int trips = 0;
  int fillTotal = 0;

  bool get isHard => difficulty == 'hard' || difficulty == 'superHard';
}

class GateAReport {
  GateAReport._();

  final List<String> testers = [];
  int startedLevel1 = 0;
  int clearedTenInOneSitting = 0;
  int hardDecided = 0;
  int hardFirstWins = 0;
  int hardFirstWinsWithContinue = 0;
  // Hard first attempts played without a power (the thesis read: no help), and how many of them were won outright.
  int hardDecidedUnassisted = 0;
  int hardFirstWinsUnassisted = 0;
  int reachedHeavyQuestion = 0;
  final List<(String, String)> heavyAnswers = [];
  int heavySkipped = 0;
  int crashes = 0;
  int crashesRated = 0;
  int crashesUnfair = 0;
  final Map<int, LevelStats> levels = {};
  final Map<String, int> overloadByType = {};
  final Map<String, int> overloadByCargo = {};
  int completedTest = 0;

  // Powers (PRD v1.6, "Gate A"). Names are `Power.name`: swap, seats, trip, express.
  final Map<String, int> powerUsed = {};
  final Map<String, int> powerBought = {};
  final Map<String, int> powerAdRefills = {};
  final Map<String, int> powerEmptyTaps = {};
  final Set<String> testersUsingPower = {};
  final Set<String> _levelsWithPower = {}; // "tester:level"
  int? firstPowerLevel;
  int unknownFair = 0;
  int unknownUnfair = 0;
  int unknownSkipped = 0;

  static GateAReport from(List<Map<String, dynamic>> results) {
    // Testers may send "so far" and again at the end: keep the fullest file.
    final latest = <String, Map<String, dynamic>>{};
    for (final r in results) {
      final code = r['tester'] as String;
      final prev = latest[code];
      if (prev == null || (r['events'] as List).length >= (prev['events'] as List).length) latest[code] = r;
    }
    final report = GateAReport._();
    for (final MapEntry(key: code, value: r) in latest.entries) {
      report._addTester(code, [for (final e in r['events'] as List) Map<String, dynamic>.from(e as Map)]);
    }
    return report;
  }

  LevelStats _level(int n) => levels.putIfAbsent(n, () => LevelStats(n));

  void _addTester(String code, List<Map<String, dynamic>> events) {
    testers.add(code);
    events.sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));
    int lvl(Map<String, dynamic> e) => (e['level'] as num).toInt();
    int attempt(Map<String, dynamic> e) => (e['attempt'] as num?)?.toInt() ?? 0;

    // Sittings: runs of events with no gap over [sittingGapSeconds].
    final sittings = <Set<int>>[];
    num? last;
    for (final e in events) {
      final t = e['t'] as num;
      if (last == null || t - last > sittingGapSeconds) sittings.add({});
      last = t;
      if (e['e'] == 'level_win') sittings.last.add(lvl(e));
    }
    if (events.any((e) => e['e'] == 'level_start' && lvl(e) == 1)) {
      startedLevel1++;
      if (sittings.any((s) => s.containsAll([for (var n = 1; n <= 10; n++) n]))) clearedTenInOneSitting++;
    }

    // First attempts: won outright, won after a continue, or lost (fail
    // without a later win, or abandoned). Started and never finished is
    // left out.
    final firstOutcome = <int, String>{};
    final firstPowers = <int, int>{}; // powers used on the first attempt, from its closing event
    int powers(Map<String, dynamic> e) => (e['powers_used'] as num?)?.toInt() ?? 0;
    for (final e in events) {
      final n = lvl(e);
      // Only level events get a row in the per-level table.
      LevelStats s() => _level(n);
      switch (e['e']) {
        case 'level_start':
          s().difficulty = e['difficulty'] as String? ?? s().difficulty;
          s().started.add(code);
        case 'level_win':
          if (attempt(e) == 1) {
            firstOutcome[n] = ((e['continues'] as num?)?.toInt() ?? 0) == 0 ? 'win' : 'win+continue';
            firstPowers[n] = powers(e);
          }
          if (n >= TesterConfig.heavyTypesAfterLevel) _reachedHeavy.add(code);
        case 'level_fail':
          s().fails[e['kind'] as String] = (s().fails[e['kind'] as String] ?? 0) + 1;
          if (e['kind'] == 'crash') crashes++;
          if (attempt(e) == 1) {
            firstOutcome.putIfAbsent(n, () => 'loss');
            firstPowers.putIfAbsent(n, () => powers(e));
          }
        case 'level_abandon':
          s().abandons++;
          if (attempt(e) == 1) {
            firstOutcome[n] = 'loss';
            firstPowers.putIfAbsent(n, () => powers(e));
          }
        case 'overload':
          s().overloads++;
          final type = e['type'] as String;
          final cargo = e['cargo'] as String? ?? 'none';
          overloadByType[type] = (overloadByType[type] ?? 0) + 1;
          if (cargo != 'none') overloadByCargo[cargo] = (overloadByCargo[cargo] ?? 0) + 1;
        case 'trip_sent':
          s().trips++;
          s().fillTotal += (e['fill_pct'] as num?)?.toInt() ?? 0;
        case 'crash_fairness':
          crashesRated++;
          if (e['fair'] == false) crashesUnfair++;
        case 'exit_heavy_types':
          if (e['skipped'] == true) {
            heavySkipped++;
          } else {
            heavyAnswers.add((code, e['answer'] as String));
          }
        case 'power_used':
          final power = e['power'] as String;
          powerUsed[power] = (powerUsed[power] ?? 0) + 1;
          testersUsingPower.add(code);
          _levelsWithPower.add('$code:$n');
          if (firstPowerLevel == null || n < firstPowerLevel!) firstPowerLevel = n;
        case 'power_bought':
          final power = e['power'] as String;
          powerBought[power] = (powerBought[power] ?? 0) + 1;
        case 'power_refill_ad':
          final power = e['power'] as String;
          powerAdRefills[power] = (powerAdRefills[power] ?? 0) + 1;
        case 'power_empty_tapped':
          final power = e['power'] as String;
          powerEmptyTaps[power] = (powerEmptyTaps[power] ?? 0) + 1;
        case 'exit_unknown_fair':
          if (e['skipped'] == true) {
            unknownSkipped++;
          } else if (e['fair'] == true) {
            unknownFair++;
          } else {
            unknownUnfair++;
          }
        case 'test_complete':
          completedTest++;
      }
    }
    // A loss logged before a continue that went on to win is a win+continue,
    // which the level_win above already recorded over it.
    for (final MapEntry(key: n, value: outcome) in firstOutcome.entries) {
      final s = _level(n);
      s.firstDecided++;
      if (outcome == 'win') s.firstWins++;
      if (outcome == 'win+continue') s.firstWinsWithContinue++;
      if (s.isHard) {
        hardDecided++;
        if (outcome == 'win') hardFirstWins++;
        if (outcome == 'win+continue') hardFirstWinsWithContinue++;
        if ((firstPowers[n] ?? 0) == 0) {
          hardDecidedUnassisted++;
          if (outcome == 'win') hardFirstWinsUnassisted++;
        }
      }
    }
    reachedHeavyQuestion = _reachedHeavy.length;
  }

  final Set<String> _reachedHeavy = {};

  static String _pct(int n, int d) => d == 0 ? '  n/a' : '${(100 * n / d).round().toString().padLeft(4)}%';

  static String _verdict(bool? ok) => switch (ok) { true => 'PASS', false => 'MISS', null => 'n/a' };

  String render() {
    final b = StringBuffer();
    b.writeln('Gate A report: ${testers.length} testers (${testers.join(', ')})');
    b.writeln('Finished all 60 levels: $completedTest');
    b.writeln();
    b.writeln('Prototype gate (docs/PRD.md, Success criteria)');

    final tenRate = startedLevel1 == 0 ? null : clearedTenInOneSitting / startedLevel1;
    b.writeln('  1. Cleared levels 1-10 in one sitting   ${_pct(clearedTenInOneSitting, startedLevel1)}'
        '  ($clearedTenInOneSitting of $startedLevel1)   target >= 70%   ${_verdict(tenRate == null ? null : tenRate >= 0.7)}');

    final hardRate = hardDecided == 0 ? null : hardFirstWins / hardDecided;
    b.writeln('  2. First-attempt wins on Hard levels    ${_pct(hardFirstWins, hardDecided)}'
        '  ($hardFirstWins of $hardDecided first attempts)   target 45-55%   '
        '${_verdict(hardRate == null ? null : hardRate >= 0.45 && hardRate <= 0.55)}');
    b.writeln('     counting wins after a continue:     '
        '${_pct(hardFirstWins + hardFirstWinsWithContinue, hardDecided)}');
    b.writeln('     first attempts that used no power:  '
        '${_pct(hardFirstWinsUnassisted, hardDecidedUnassisted)}  ($hardFirstWinsUnassisted of '
        '$hardDecidedUnassisted; the gate number above counts every first attempt, powers or not)');

    b.writeln('  3. Named the heavy types unprompted     grade by hand below; target >= 60% of the '
        '$reachedHeavyQuestion testers who reached level ${TesterConfig.heavyTypesAfterLevel}');

    final unfairRate = crashesRated == 0 ? null : crashesUnfair / crashesRated;
    b.writeln('  4. Crashes called unfair                ${_pct(crashesUnfair, crashesRated)}'
        '  ($crashesUnfair of $crashesRated rated; $crashes crashes)   target <= 20%   '
        '${_verdict(unfairRate == null ? null : unfairRate <= 0.2)}');
    b.writeln();

    b.writeln('Powers (the build had them on: stock starts at 0, 150 coins or one stub ad per use)');
    String byPower(Map<String, int> m) {
      final entries = m.entries.toList()..sort((a, c) => c.value.compareTo(a.value));
      return entries.isEmpty ? 'none' : entries.map((e) => '${e.key} ${e.value}').join(', ');
    }

    b.writeln(
        '  Used:                ${byPower(powerUsed)}   (${testersUsingPower.length} of ${testers.length} testers, '
        '${_levelsWithPower.length} tester-levels${firstPowerLevel == null ? '' : ', first on level $firstPowerLevel'})');
    b.writeln('  Bought with coins:   ${byPower(powerBought)}');
    b.writeln('  Refilled by stub ad: ${byPower(powerAdRefills)}');
    b.writeln('  Tapped while empty:  ${byPower(powerEmptyTaps)}   (wanted, had none)');
    final unknownAnswered = unknownFair + unknownUnfair;
    b.writeln(
        '  Unknown people fair: ${_pct(unknownFair, unknownAnswered)}  ($unknownFair fair, $unknownUnfair unfair, '
        '$unknownSkipped skipped)   no target set; read beside the crash number (<= 20% unfair)');
    b.writeln();

    b.writeln('Heavy-types answers (${heavyAnswers.length} answered, $heavySkipped skipped)');
    final reference = ResidentType.unlockedAt(TesterConfig.heavyTypesAfterLevel).toList()
      ..sort((a, c) => c.kg.compareTo(a.kg));
    b.writeln('  Heaviest first, as seen by level ${TesterConfig.heavyTypesAfterLevel}: '
        '${reference.map((t) => t.displayName).toSet().join(' > ')}');
    for (final (code, answer) in heavyAnswers) {
      b.writeln('  [ ] $code: $answer');
    }
    b.writeln();

    b.writeln('Per level (first attempts: decided / outright wins)');
    b.writeln('  L    difficulty  testers  first  wins  win%   crash  trips  jam  abandon  overloads  mean fill');
    for (final s in levels.values.toList()..sort((a, c) => a.level.compareTo(c.level))) {
      b.writeln('  ${s.level.toString().padLeft(2)}${s.isHard ? '*' : ' '} '
          '${s.difficulty.padRight(11)} ${s.started.length.toString().padLeft(7)}  '
          '${s.firstDecided.toString().padLeft(5)}  ${s.firstWins.toString().padLeft(4)} '
          '${_pct(s.firstWins, s.firstDecided)}  ${(s.fails['crash'] ?? 0).toString().padLeft(5)}  '
          '${(s.fails['outOfTrips'] ?? 0).toString().padLeft(5)}  ${(s.fails['jam'] ?? 0).toString().padLeft(3)}  '
          '${s.abandons.toString().padLeft(7)}  ${s.overloads.toString().padLeft(9)}  '
          '${s.trips == 0 ? '      -' : '${(s.fillTotal / s.trips).round().toString().padLeft(6)}%'}');
    }
    b.writeln('  * Hard or super hard');
    b.writeln();

    String top(Map<String, int> m) {
      final entries = m.entries.toList()..sort((a, c) => c.value.compareTo(a.value));
      return entries.isEmpty ? 'none' : entries.map((e) => '${e.key} ${e.value}').join(', ');
    }

    b.writeln('Overloads by type:  ${top(overloadByType)}');
    b.writeln('Overloads by cargo: ${top(overloadByCargo)}');
    return b.toString();
  }
}
