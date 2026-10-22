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
        final lanes = Formulas.laneCount(number);
        final arrivals = <Arrival>[];
        if (scenario == Scenario.rushHour) {
          // The last waves of the cast arrive later instead of waiting now.
          final later = picks.sublist(picks.length - Formulas.rushWaveSize * Formulas.rushWaveTrips.length);
          picks.removeRange(picks.length - later.length, picks.length);
          for (var i = 0; i < later.length; i++) {
            arrivals.add(Arrival(
              afterTrip: Formulas.rushWaveTrips[i ~/ Formulas.rushWaveSize],
              lane: rng.nextInt(lanes),
              resident: later[i],
            ));
          }
        }
        final queues = _deal(rng, picks, lanes, Formulas.laneSpread(number));
        final draft = Level(
          number: number,
          capacity: capacity,
          trips: 1 << 20,
          benchSize: Formulas.bench(number) + extraSeats,
          difficulty: difficulty,
          floors: floors,
          queues: queues,
          seed: seed,
          venue: venue,
          liftSchedule: schedule,
          scenario: scenario,
          lockedLane: scenario == Scenario.maintenance ? rng.nextInt(lanes) : null,
          lockedUntilTrip: scenario == Scenario.maintenance ? Formulas.maintenanceTrips : 0,
          arrivals: arrivals,
          unknownIds: _unknown(rng, number, queues),
        );
        final result = Solver.solve(draft);
        if (result.cleared) {
          return draft.copyWith(
            trips: Formulas.trips(par: result.trips, difficulty: difficulty, level: number),
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
      final type = (newType != null && i < Formulas.debutMinimum)
          ? newType
          : weighted(types, (t) => venue.weightOf(t) + (Formulas.isLiar(t) ? Formulas.liarBoost(number) : 0));
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

  /// Deals [picks] into [lanes] lanes. Lanes start even, then [spread] makes them
  /// uneven: residents move from one lane's back to another's, never leaving a
  /// lane more than [spread] from the average or empty.
  static List<List<Resident>> _deal(math.Random rng, List<Resident> picks, int lanes, int spread) {
    final counts = List<int>.generate(lanes, (i) => picks.length ~/ lanes + (i < picks.length % lanes ? 1 : 0));
    final average = picks.length / lanes;
    for (var move = 0; move < spread * lanes * 2; move++) {
      final from = rng.nextInt(lanes);
      final to = rng.nextInt(lanes);
      if (from == to || counts[from] <= 1) continue;
      if ((counts[from] - 1 - average).abs() > spread || (counts[to] + 1 - average).abs() > spread) continue;
      counts[from]--;
      counts[to]++;
    }
    final out = List.generate(lanes, (_) => <Resident>[]);
    var next = 0;
    for (var lane = 0; lane < lanes; lane++) {
      for (var i = 0; i < counts[lane]; i++) {
        out[lane].add(picks[next++]);
      }
    }
    return out;
  }

  /// Which residents are unknown: each person behind a lane's front, with the
  /// level's unknown share. The unknown debut level guarantees at least
  /// [Formulas.unknownDebutMinimum] so the new thing is seen.
  static Set<int> _unknown(math.Random rng, int number, List<List<Resident>> queues) {
    final share = Formulas.unknownShare(number);
    if (share <= 0) return const {};
    final behind = [
      for (final lane in queues) ...lane.skip(1),
    ];
    final picked = <int>{
      for (final r in behind)
        if (rng.nextDouble() < share) r.id,
    };
    if (Debut.at(number) is UnknownDebut) {
      final pool = [for (final r in behind) if (!picked.contains(r.id)) r.id]..shuffle(rng);
      for (final id in pool) {
        if (picked.length >= Formulas.unknownDebutMinimum) break;
        picked.add(id);
      }
    }
    return Set.unmodifiable(picked);
  }
}
