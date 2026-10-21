/// Seeded level generator. Same level number → same level, on every device.
///
/// Draws residents from the unlocked cast, deals them into lanes, and asks
/// the [Solver] to prove the layout clears. The first solvable attempt wins
/// and its par sets the trip budget. If 60 attempts fail, the bench grows by
/// one seat (up to two times) before giving up.
library;

import 'dart:math' as math;

import 'cast.dart';
import 'formulas.dart';
import 'level.dart';
import 'solver.dart';

abstract final class LevelGenerator {
  static const int baseSeed = 7919;
  static const int attemptsPerBench = 60;

  static Level generate(int number) {
    if (number < 1) throw ArgumentError.value(number, 'number', 'Levels start at 1');
    final difficulty = Formulas.difficulty(number);
    final floorCount = Formulas.floors(number);
    final count = Formulas.residents(number);
    final capacity = Formulas.capacity(number);
    final types = ResidentType.unlockedAt(number);
    final introduced = ResidentType.introducedAt(number);
    final floors = _rotation(number, floorCount);

    for (var extraSeats = 0; extraSeats <= 2; extraSeats++) {
      for (var attempt = 0; attempt < attemptsPerBench; attempt++) {
        final seed = baseSeed * 1000 + number * 97 + attempt + extraSeats * 10007;
        final rng = math.Random(seed);
        final draft = Level(
          number: number,
          capacity: capacity,
          trips: 1 << 20,
          benchSize: Formulas.bench(number) + extraSeats,
          difficulty: difficulty,
          floors: floors,
          queues: _deal(rng, count, floors, types, introduced),
          seed: seed,
        );
        final result = Solver.solve(draft);
        if (result.cleared) {
          return draft.copyWith(
            trips: Formulas.trips(par: result.trips, difficulty: difficulty),
            parTrips: result.trips,
          );
        }
      }
    }
    throw StateError('No solvable layout found for level $number');
  }

  /// k consecutive floors from a level-dependent starting point, so early
  /// levels do not always use the same two colours.
  static List<Floor> _rotation(int number, int k) {
    final all = Floor.values;
    final start = (number * 5) % all.length;
    return List.unmodifiable([for (var i = 0; i < k; i++) all[(start + i) % all.length]]);
  }

  static List<List<Resident>> _deal(
    math.Random rng,
    int count,
    List<Floor> floors,
    List<ResidentType> types,
    ResidentType? introduced,
  ) {
    final picks = <(Floor, ResidentType)>[];
    for (var i = 0; i < count; i++) {
      final floor = floors[i % floors.length];
      // A newly unlocked type appears at least three times on its debut.
      final type = (introduced != null && i < 3) ? introduced : types[rng.nextInt(types.length)];
      picks.add((floor, type));
    }
    picks.shuffle(rng);
    final lanes = List.generate(Formulas.queues, (_) => <Resident>[]);
    for (var i = 0; i < picks.length; i++) {
      final (floor, type) = picks[i];
      lanes[i % Formulas.queues].add(Resident(id: i + 1, type: type, floor: floor));
    }
    return lanes;
  }
}
