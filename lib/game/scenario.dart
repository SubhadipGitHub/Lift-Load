/// Lift kinds and lobby scenarios: the World 2 (L61+) variations on the
/// core loop. Which kinds and scenario a level uses is decided by
/// [Formulas.liftSchedule] and [Formulas.scenario].
library;

import 'cast.dart';

/// The kind of cabin serving one trip. Capacity multipliers live in
/// [Formulas.liftCapacity].
enum LiftKind {
  normal(1),

  /// A creaky cabin: holds less than usual.
  old(61),

  /// A freight cabin: holds more than usual.
  service(65),

  /// Stops at two floors in one trip: this floor and the next in rotation.
  express(71);

  const LiftKind(this.unlockLevel);

  final int unlockLevel;

  static LiftKind? introducedAt(int level) {
    for (final k in values) {
      if (k != normal && k.unlockLevel == level) return k;
    }
    return null;
  }
}

/// A level-wide lobby modifier. At most one per level.
enum Scenario {
  /// One lane is coned off for the first few trips.
  maintenance(67),

  /// Waves of new residents join the lanes after set trips.
  rushHour(87);

  const Scenario(this.unlockLevel);

  final int unlockLevel;

  static Scenario? introducedAt(int level) {
    for (final s in values) {
      if (s.unlockLevel == level) return s;
    }
    return null;
  }
}

/// A resident who joins the back of [lane] once [afterTrip] trips are used.
class Arrival {
  const Arrival({required this.afterTrip, required this.lane, required this.resident});

  final int afterTrip;
  final int lane;
  final Resident resident;
}
