/// Seeded level generator. Same level number → same level, on every device.
///
/// Draws residents from the unlocked cast (weighted by the venue), hands out
/// cargo, deals them into lanes, adds the level's lift schedule and lobby
/// scenario, and asks the [Solver] to prove the layout clears. The first
/// solvable attempt wins and its par sets the trip budget. If 60 attempts
/// fail, the bench grows by one seat (up to two times) before giving up.
library;

import 'dart:math' as math;

import 'cast.dart';
import 'debuts.dart';
import 'formulas.dart';
import 'level.dart';
import 'scenario.dart';
import 'solver.dart';
import 'venue.dart';

abstract final class LevelGenerator {
  static const int baseSeed = 7919;
  static const int attemptsPerBench = 60;

  static Level generate(int number) {
    if (number < 1) throw ArgumentError.value(number, 'number', 'Levels start at 1');
    final difficulty = Formulas.difficulty(number);
    final floorCount = Formulas.floors(number);
    final count = Formulas.residents(number);
    final capacity = Formulas.capacity(number);
    final venue = Venue.of(number);
    final schedule = Formulas.liftSchedule(number);
    final scenario = Formulas.scenario(number);
    final floors = _rotation(number, floorCount);

    for (var extraSeats = 0; extraSeats <= 2; extraSeats++) {
      for (var attempt = 0; attempt < attemptsPerBench; attempt++) {
        final seed = baseSeed * 1000 + number * 97 + attempt + extraSeats * 10007;
        final rng = math.Random(seed);
        final picks = _cast(rng, number, count, floors, venue);
        final arrivals = <Arrival>[];
        if (scenario == Scenario.rushHour) {
          // The last waves of the cast arrive later instead of waiting now.
          final later = picks.sublist(picks.length - Formulas.rushWaveSize * Formulas.rushWaveTrips.length);
          picks.removeRange(picks.length - later.length, picks.length);
          for (var i = 0; i < later.length; i++) {
            arrivals.add(Arrival(
              afterTrip: Formulas.rushWaveTrips[i ~/ Formulas.rushWaveSize],
              lane: rng.nextInt(Formulas.queues),
              resident: later[i],
            ));
          }
        }
        final draft = Level(
          number: number,
          capacity: capacity,
          trips: 1 << 20,
          benchSize: Formulas.bench(number) + extraSeats,
          difficulty: difficulty,
          floors: floors,
          queues: _deal(picks),
          seed: seed,
          venue: venue,
          liftSchedule: schedule,
          scenario: scenario,
          lockedLane: scenario == Scenario.maintenance ? rng.nextInt(Formulas.queues) : null,
          lockedUntilTrip: scenario == Scenario.maintenance ? Formulas.maintenanceTrips : 0,
          arrivals: arrivals,
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

  /// Draws [count] residents, shuffled. A debuting type appears at least
  /// three times; a debuting cargo is carried at least three times.
  static List<Resident> _cast(math.Random rng, int number, int count, List<Floor> floors, Venue venue) {
    final types = ResidentType.unlockedAt(number);
    final cargos = Cargo.unlockedAt(number);
    final debut = Debut.at(number);
    final newType = debut is TypeDebut ? debut.type : null;
    var cargoDebutsLeft = debut is CargoDebut ? Formulas.debutMinimum : 0;

    T weighted<T>(List<T> items, int Function(T) weight) {
      final total = items.fold(0, (a, t) => a + weight(t));
      var roll = rng.nextInt(total);
      for (final t in items) {
        roll -= weight(t);
        if (roll < 0) return t;
      }
      return items.last;
    }

    final picks = <(Floor, ResidentType, Cargo)>[];
    for (var i = 0; i < count; i++) {
      final floor = floors[i % floors.length];
      final type = (newType != null && i < Formulas.debutMinimum) ? newType : weighted(types, venue.weightOf);
      var cargo = Cargo.none;
      if (type.canCarry && cargos.isNotEmpty) {
        if (cargoDebutsLeft > 0) {
          cargo = (debut as CargoDebut).cargo;
          cargoDebutsLeft--;
        } else if (rng.nextDouble() < Formulas.cargoChance) {
          cargo = weighted(cargos, venue.cargoWeightOf);
        }
      }
      picks.add((floor, type, cargo));
    }
    picks.shuffle(rng);
    return [
      for (var i = 0; i < picks.length; i++)
        Resident(id: i + 1, floor: picks[i].$1, type: picks[i].$2, cargo: picks[i].$3),
    ];
  }

  static List<List<Resident>> _deal(List<Resident> picks) {
    final lanes = List.generate(Formulas.queues, (_) => <Resident>[]);
    for (var i = 0; i < picks.length; i++) {
      lanes[i % Formulas.queues].add(picks[i]);
    }
    return lanes;
  }
}
