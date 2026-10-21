/// Every tuning number in one place. Change numbers here, never inline.
///
/// L = level number (1-based). See docs/PRD.md, "Level, economy and
/// difficulty formulas". Validated by tool/simulate.dart and
/// test/generator_test.dart.
library;

import 'dart:math' as math;

import 'cast.dart';

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

  /// Difficulty sawtooth. Levels that introduce a new resident type are
  /// always breathers so the new silhouette is learned without pressure.
  static Difficulty difficulty(int level) {
    if (ResidentType.introducedAt(level) != null) return Difficulty.breather;
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

  // ── Meta economy ────────────────────────────────────────────────────────
  static const int maxLives = 5;
  static const Duration lifeRegen = Duration(minutes: 30);
  static const int startingCoins = 300;
  static const int startingScales = 3;
  static const int scaleShopPrice = 120;
  static const int coinContinuePrice = 300;
  static const int adTripsBonus = 2;
}
