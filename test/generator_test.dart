import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/debuts.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/solver.dart';
import 'package:lift_load/game/venue.dart';

void main() {
  final levels = {for (var n = 1; n <= Formulas.lastLevel; n++) n: LevelGenerator.generate(n)};

  List<Resident> everyone(Level l) => [for (final q in l.queues) ...q, for (final a in l.arrivals) a.resident];

  test('levels 1–100 all generate, and the solver clears each within its trip budget', () {
    for (final MapEntry(key: n, value: level) in levels.entries) {
      final result = Solver.solve(level);
      expect(result.cleared, isTrue, reason: 'level $n');
      expect(result.trips, lessThanOrEqualTo(level.trips), reason: 'level $n');
      expect(level.trips, level.parTrips + Formulas.slack(level.difficulty), reason: 'level $n');
      expect(level.residentCount, Formulas.residents(n), reason: 'level $n');
      expect(level.floors, hasLength(Formulas.floors(n)), reason: 'level $n');
    }
  });

  test('generation is deterministic', () {
    for (final n in [17, 67, 87]) {
      final a = LevelGenerator.generate(n);
      final b = LevelGenerator.generate(n);
      expect(a.seed, b.seed);
      expect(
        [for (final r in everyone(a)) '${r.type.name}/${r.cargo.name}/${r.floor.name}'],
        [for (final r in everyone(b)) '${r.type.name}/${r.cargo.name}/${r.floor.name}'],
      );
      expect(a.lockedLane, b.lockedLane);
    }
  });

  test('only unlocked types and cargo appear; nobody who cannot carry does', () {
    for (final MapEntry(key: n, value: level) in levels.entries) {
      final allowed = ResidentType.unlockedAt(n).toSet();
      final cargo = {Cargo.none, ...Cargo.unlockedAt(n)};
      for (final r in everyone(level)) {
        expect(allowed, contains(r.type), reason: 'level $n: $r');
        expect(cargo, contains(r.cargo), reason: 'level $n: $r');
        if (!r.type.canCarry) expect(r.cargo, Cargo.none, reason: 'level $n: $r');
      }
    }
  });

  test('debuts: one per level, on breathers, clear of the Hard sawtooth, and seen enough', () {
    final debutLevels = Debut.levels;
    expect(debutLevels.toSet(), hasLength(debutLevels.length), reason: 'two debuts share a level');
    for (final n in debutLevels) {
      expect(n % 10, isNot(0), reason: 'level $n');
      expect(n % 25, isNot(0), reason: 'level $n');
      expect(Formulas.difficulty(n), Difficulty.breather, reason: 'level $n');
      final level = levels[n]!;
      final people = everyone(level);
      switch (Debut.at(n)!) {
        case TypeDebut(:final type):
          expect(people.where((r) => r.type == type).length, greaterThanOrEqualTo(3), reason: 'level $n');
        case CargoDebut(:final cargo):
          expect(people.where((r) => r.cargo == cargo).length, greaterThanOrEqualTo(3), reason: 'level $n');
        case LiftDebut(:final kind):
          expect(level.liftSchedule.toSet(), {LiftKind.normal, kind}, reason: 'level $n');
          expect(level.parTrips ~/ level.liftSchedule.length, greaterThanOrEqualTo(3), reason: 'level $n');
          expect(level.scenario, isNull, reason: 'level $n');
        case ScenarioDebut(:final scenario):
          expect(level.scenario, scenario, reason: 'level $n');
          expect(level.liftSchedule, [LiftKind.normal], reason: 'level $n');
      }
    }
  });

  test('venues change every 20 levels', () {
    for (final MapEntry(key: n, value: level) in levels.entries) {
      expect(level.venue, Venue.values[(n - 1) ~/ Venue.levelsPerVenue], reason: 'level $n');
    }
    expect(Venue.of(140), Venue.hotel);
  });

  test('levels 1–60 keep the core rules: no lift kinds, no scenarios', () {
    for (var n = 1; n <= 60; n++) {
      expect(levels[n]!.liftSchedule, [LiftKind.normal], reason: 'level $n');
      expect(levels[n]!.scenario, isNull, reason: 'level $n');
    }
  });

  test('scenarios are set up consistently, and never on Super Hard', () {
    for (final MapEntry(key: n, value: level) in levels.entries) {
      if (level.difficulty == Difficulty.superHard) expect(level.scenario, isNull, reason: 'level $n');
      expect(level.lockedLane != null, level.scenario == Scenario.maintenance, reason: 'level $n');
      expect(level.arrivals.isNotEmpty, level.scenario == Scenario.rushHour, reason: 'level $n');
      if (level.scenario == Scenario.rushHour) {
        expect(level.arrivals, hasLength(Formulas.rushWaveSize * Formulas.rushWaveTrips.length), reason: 'level $n');
      }
    }
  });

  test('lift schedules start with a normal lift and use at most two other kinds', () {
    for (final MapEntry(key: n, value: level) in levels.entries) {
      expect(level.liftSchedule.first, LiftKind.normal, reason: 'level $n');
      expect(level.liftSchedule.where((k) => k != LiftKind.normal).toSet().length, lessThanOrEqualTo(2),
          reason: 'level $n');
      for (final k in level.liftSchedule) {
        expect(k.unlockLevel, lessThanOrEqualTo(n), reason: 'level $n');
      }
    }
  });

  test('sawtooth: hard levels get one slack trip, breathers three', () {
    expect(Formulas.difficulty(10), Difficulty.hard);
    expect(Formulas.difficulty(20), Difficulty.hard);
    expect(Formulas.difficulty(50), Difficulty.superHard);
    expect(Formulas.difficulty(11), Difficulty.breather);
    expect(Formulas.slack(Difficulty.hard), 1);
    expect(Formulas.slack(Difficulty.breather), 3);
  });
}
