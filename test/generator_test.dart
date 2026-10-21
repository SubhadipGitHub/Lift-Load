import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';
import 'package:lift_load/game/solver.dart';

void main() {
  test('levels 1–60 all generate, and the solver clears each within its trip budget', () {
    for (var n = 1; n <= 60; n++) {
      final level = LevelGenerator.generate(n);
      final result = Solver.solve(level);
      expect(result.cleared, isTrue, reason: 'level $n');
      expect(result.trips, lessThanOrEqualTo(level.trips), reason: 'level $n');
      expect(level.trips, level.parTrips + Formulas.slack(level.difficulty), reason: 'level $n');
      expect(level.residentCount, Formulas.residents(n), reason: 'level $n');
      expect(level.floors, hasLength(Formulas.floors(n)), reason: 'level $n');
    }
  });

  test('generation is deterministic', () {
    final a = LevelGenerator.generate(17);
    final b = LevelGenerator.generate(17);
    expect(a.seed, b.seed);
    expect(
      [for (final q in a.queues) [for (final r in q) '${r.type.name}/${r.floor.name}']],
      [for (final q in b.queues) [for (final r in q) '${r.type.name}/${r.floor.name}']],
    );
  });

  test('only unlocked types appear, and a newly unlocked type debuts at least 3 times', () {
    for (var n = 1; n <= 60; n++) {
      final level = LevelGenerator.generate(n);
      final allowed = ResidentType.unlockedAt(n).toSet();
      final types = [for (final q in level.queues) for (final r in q) r.type];
      expect(types.every(allowed.contains), isTrue, reason: 'level $n');
      final debut = ResidentType.introducedAt(n);
      if (debut != null) {
        expect(types.where((t) => t == debut).length, greaterThanOrEqualTo(3), reason: 'level $n');
        expect(Formulas.difficulty(n), Difficulty.breather, reason: 'level $n');
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
