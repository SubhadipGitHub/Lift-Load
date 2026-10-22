/// Every tuning number in one place. Change numbers here, never inline.
///
/// L = level number (1-based). See docs/PRD.md, "Level, economy and
/// difficulty formulas". Validated by tool/simulate.dart and
/// test/generator_test.dart.
library;

import 'dart:math' as math;

import 'cast.dart';
import 'debuts.dart';
import 'powers.dart';
import 'scenario.dart';

enum Difficulty { normal, hard, superHard, breather }

abstract final class Formulas {
  /// Lanes of waiting residents on the lobby floor: four until level 16, then 3 to 5 (see [laneCount]).
  static const int baseLanes = 4;
  static const int minLanes = 3;
  static const int maxLanes = 5;

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

  /// Slack trips on top of the solver's par. Normal levels get one more once
  /// unknown people appear, because a player cannot plan around them the way
  /// the solver does (PRD v1.6; retuned from Gate A data).
  static int slack(Difficulty d, {int level = 0}) =>
      switch (d) {
        Difficulty.normal => 2,
        Difficulty.hard => 1,
        Difficulty.superHard => 1,
        Difficulty.breather => 3,
      } +
      (d == Difficulty.normal && level >= Debut.unknownLevel ? extraNormalSlack : 0);

  static const int extraNormalSlack = 1;

  /// T(L) = par + slack, where par is the trips the solver bot needs.
  /// (PRD v1 used Σ⌈W_f / 0.85C⌉; it under-counted above 3 floors.)
  static int trips({required int par, required Difficulty difficulty, int level = 0}) =>
      par + slack(difficulty, level: level);

  /// Weight-only lower bound on trips, kept for reporting.
  static int weightBoundTrips(Map<Floor, int> weightByFloor, int capacity) =>
      weightByFloor.values.map((w) => (w / (0.85 * capacity)).ceil()).fold(0, (a, b) => a + b);

  /// Base coins for clearing a level: 20 + 2⌊L/5⌋.
  static int baseCoins(int level) => 20 + 2 * (level ~/ 5);

  // ── Lanes, unknown people and liars (PRD v1.6) ──────────────────────────

  /// Lanes on [level]: four below level 16, five on level 16 so the change is
  /// seen, then 3 (one level in six), 4 (half) or 5 (a third), seeded by the level.
  static int laneCount(int level) {
    if (level < Debut.laneLevel) return baseLanes;
    if (level == Debut.laneLevel) return maxLanes;
    final roll = math.Random(level * 6151 + 29).nextInt(6);
    return roll == 0 ? minLanes : (roll <= 3 ? baseLanes : maxLanes);
  }

  /// How far lane lengths may sit from the average, in residents: 0 below
  /// level 16, then 1 growing to 3.
  static int laneSpread(int level) => level < Debut.laneLevel ? 0 : math.min(1 + (level - Debut.laneLevel) ~/ 10, 3);

  /// Chance that a person behind a lane front is unknown: 0 below level 11,
  /// then 15% growing 1 point a level to 60%.
  static double unknownShare(int level) => level < Debut.unknownLevel
      ? 0
      : math.min(unknownBase + unknownPerLevel * (level - Debut.unknownLevel), unknownMax);

  static const double unknownBase = 0.15;
  static const double unknownPerLevel = 0.01;
  static const double unknownMax = 0.35;

  /// The level that debuts unknown people shows at least this many of them.
  static const int unknownDebutMinimum = 3;

  /// The two "liars": the puffer teen looks heavy and is light, the gym
  /// regular looks light and is heavy.
  static bool isLiar(ResidentType t) => t == ResidentType.puffer || t == ResidentType.gym;

  /// Extra crowd-mix weight for the liars once both are unlocked: 0 before
  /// level 45, then 1 growing a point every 10 levels to 4.
  static int liarBoost(int level) => level < 45 ? 0 : math.min(1 + (level - 45) ~/ 10, 4);

  // ── Powers (PRD v1.6) ───────────────────────────────────────────────────

  /// Every power starts at zero and is bought with coins or one rewarded ad.
  static const int startingPowerStock = 0;

  /// Coins for one use of a power. One value per power, ready for remote config.
  static int powerCoinPrice(Power p) => switch (p) {
        Power.swap || Power.seats || Power.trip || Power.express => 150,
      };

  /// Uses a rewarded ad grants.
  static const int powerAdUses = 1;

  /// Rewarded refills of powers per day, inside the total daily cap.
  static const int powerRefillDailyCap = 6;

  /// Daily rewarded views kept back from power refills for the fail-sheet
  /// continues (repair, trips, seat), so a player who refilled all day can
  /// still watch one to carry on after a crash.
  static const int powerRefillFailReserve = 2;

  /// Uses of a power per level.
  static int powerCap(Power p) => switch (p) {
        Power.swap => 2,
        Power.seats => 1,
        Power.trip => 1,
        Power.express => 1,
      };

  /// Bench seats the seats power adds, and trips the trip power adds.
  static const int powerSeats = 2;
  static const int powerTrips = 1;

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
