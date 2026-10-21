/// Every tuning number in one place. Change numbers here, never inline.
///
/// L = level number (1-based). See docs/PRD.md, "Level, economy and
/// difficulty formulas". Validated by tool/simulate.dart and
/// test/generator_test.dart.
library;

import 'dart:math' as math;

import 'cast.dart';
import 'debuts.dart';
import 'scenario.dart';

enum Difficulty { normal, hard, superHard, breather }

abstract final class Formulas {
  /// Lanes of waiting residents on the lobby floor.
  static const int queues = 4;

  /// Green zone starts at 75% of capacity.
  static const double greenFraction = 0.75;

  /// "Perfect load" at or above 95% of capacity.
  static const double perfectFraction = 0.95;

  static const int greenTripCoins = 8;
  static const int perfectTripCoins = 15;

  /// Levels the content plan covers (five venues of 20). Levels past this
  /// keep generating in the last venue.
  static const int lastLevel = 100;

  /// Difficulty sawtooth. Levels that introduce anything new (a type, a
  /// cargo, a lift kind, a scenario) are always breathers so it is learned
  /// without pressure.
  static Difficulty difficulty(int level) {
    if (Debut.at(level) != null) return Difficulty.breather;
    if (level % 25 == 0) return Difficulty.superHard;
    if (level % 10 == 0) return Difficulty.hard;
    if (level % 10 == 1 && level > 1) return Difficulty.breather;
    return Difficulty.normal;
  }

  /// k(L) = min(2 + ⌊L/8⌋, 6), +1 floor on Super Hard.
  static int floors(int level) {
    final extra = difficulty(level) == Difficulty.superHard ? 1 : 0;
    return math.min(2 + level ~/ 8 + extra, 6);
  }

  /// N(L) = min(12 + round(1.5L), 72).
  static int residents(int level) => math.min(12 + (1.5 * level).round(), 72);

  /// C(L) = 280 kg, 360 kg from L41.
  static int capacity(int level) => level < 41 ? 280 : 360;

  /// Bench seats: 4 with up to 3 floors, 5 with 4+ floors; one fewer on Hard.
  /// (PRD v1 said 3–4; simulation showed jams above 4 floors.)
  static int bench(int level) {
    final base = floors(level) <= 3 ? 4 : 5;
    final d = difficulty(level);
    return d == Difficulty.hard || d == Difficulty.superHard ? base - 1 : base;
  }

  /// Slack trips on top of the solver's par.
  static int slack(Difficulty d) => switch (d) {
        Difficulty.normal => 2,
        Difficulty.hard => 1,
        Difficulty.superHard => 1,
        Difficulty.breather => 3,
      };

  /// T(L) = par + slack, where par is the trips the solver bot needs.
  /// (PRD v1 used Σ⌈W_f / 0.85C⌉; it under-counted above 3 floors.)
  static int trips({required int par, required Difficulty difficulty}) =>
      par + slack(difficulty);

  /// Weight-only lower bound on trips, kept for reporting.
  static int weightBoundTrips(Map<Floor, int> weightByFloor, int capacity) =>
      weightByFloor.values
          .map((w) => (w / (0.85 * capacity)).ceil())
          .fold(0, (a, b) => a + b);

  /// Base coins for clearing a level: 20 + 2⌊L/5⌋.
  static int baseCoins(int level) => 20 + 2 * (level ~/ 5);

  // ── Cargo ───────────────────────────────────────────────────────────────

  /// Chance that a resident who can carry cargo does, once any is unlocked.
  static const double cargoChance = 0.25;

  /// A newly unlocked cargo is carried at least this many times on its debut.
  static const int debutMinimum = 3;

  // ── Lift kinds (World 2) ────────────────────────────────────────────────
  static const double oldLiftFraction = 0.75;
  static const double serviceLiftFraction = 1.4;

  /// Capacity of one trip on a [kind] of lift, from the level's base [capacity].
  static int liftCapacity(int capacity, LiftKind kind) => switch (kind) {
        LiftKind.old => (capacity * oldLiftFraction).round(),
        LiftKind.service => (capacity * serviceLiftFraction).round(),
        LiftKind.normal || LiftKind.express => capacity,
      };

  /// The repeating pattern of lift kinds for a level; trip i uses
  /// pattern[i % length]. The first lift is always normal. A lift kind's
  /// debut level teaches it alone; other debut levels stay plain.
  static List<LiftKind> liftSchedule(int level) {
    final debut = Debut.at(level);
    if (debut is LiftDebut) return [LiftKind.normal, LiftKind.normal, debut.kind];
    if (debut != null) return const [LiftKind.normal];
    final unlocked = [
      for (final k in LiftKind.values)
        if (k != LiftKind.normal && k.unlockLevel <= level) k,
    ];
    if (unlocked.isEmpty) return const [LiftKind.normal];
    final rng = math.Random(level * 7349 + 11);
    final first = unlocked[rng.nextInt(unlocked.length)];
    if (unlocked.length == 1 || rng.nextBool()) return [LiftKind.normal, LiftKind.normal, first];
    final rest = [...unlocked]..remove(first);
    return [LiftKind.normal, first, LiftKind.normal, rest[rng.nextInt(rest.length)]];
  }

  // ── Lobby scenarios (World 2) ───────────────────────────────────────────

  /// The level's lobby scenario, or null. A scenario's debut forces it; other
  /// debut levels and Super Hard levels get none; otherwise about every
  /// other level draws one of the unlocked scenarios.
  static Scenario? scenario(int level) {
    final debut = Debut.at(level);
    if (debut is ScenarioDebut) return debut.scenario;
    if (debut != null || difficulty(level) == Difficulty.superHard) return null;
    final unlocked = [
      for (final s in Scenario.values)
        if (s.unlockLevel <= level) s,
    ];
    if (unlocked.isEmpty) return null;
    final rng = math.Random(level * 4729 + 3);
    if (!rng.nextBool()) return null;
    return unlocked[rng.nextInt(unlocked.length)];
  }

  /// Maintenance: the coned-off lane opens once this many trips are used.
  static const int maintenanceTrips = 3;

  /// Power cut: residents at this lane depth or deeper are shadows.
  static const int powerCutDepth = 2;

  /// Rush hour: residents per wave, and the trip after which each wave lands.
  static const int rushWaveSize = 4;
  static const List<int> rushWaveTrips = [3, 6];

  // ── Meta economy ────────────────────────────────────────────────────────
  static const int maxLives = 5;
  static const Duration lifeRegen = Duration(minutes: 30);
  static const int startingCoins = 300;
  static const int startingScales = 3;
  static const int scaleShopPrice = 120;
  static const int coinContinuePrice = 300;
  static const int adTripsBonus = 2;
}
