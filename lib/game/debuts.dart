/// One place that knows what is new on each level: a resident type, a
/// cargo, a lift kind or a lobby scenario. Debut levels are breathers
/// ([Formulas.difficulty]) and the generator makes sure the new thing shows
/// up enough to be learned.
library;

import 'cast.dart';
import 'powers.dart';
import 'scenario.dart';

sealed class Debut {
  const Debut();

  /// People behind a lane front start being unknown on this level (PRD v1.6).
  static const int unknownLevel = 11;

  /// The number of lanes starts to vary on this level (PRD v1.6).
  static const int laneLevel = 16;

  /// What debuts on [level], if anything. At most one thing per level.
  static Debut? at(int level) {
    final type = ResidentType.introducedAt(level);
    if (type != null) return TypeDebut(type);
    final cargo = Cargo.introducedAt(level);
    if (cargo != null) return CargoDebut(cargo);
    final kind = LiftKind.introducedAt(level);
    if (kind != null) return LiftDebut(kind);
    final scenario = Scenario.introducedAt(level);
    if (scenario != null) return ScenarioDebut(scenario);
    if (level == unknownLevel) return const UnknownDebut();
    if (level == laneLevel) return const LaneDebut();
    final power = Power.introducedAt(level);
    if (power != null) return PowerDebut(power);
    return null;
  }

  /// Every debut level, for tests and the level table.
  static List<int> get levels => [
        for (final t in ResidentType.values)
          if (t.unlockLevel > 1) t.unlockLevel,
        for (final c in Cargo.values)
          if (c != Cargo.none) c.unlockLevel,
        for (final k in LiftKind.values)
          if (k != LiftKind.normal) k.unlockLevel,
        for (final s in Scenario.values) s.unlockLevel,
        unknownLevel,
        laneLevel,
        for (final p in Power.values) p.unlockLevel,
      ]..sort();

  /// Short name for the level table.
  String get name => switch (this) {
        TypeDebut(:final type) => type.name,
        CargoDebut(:final cargo) => cargo.name,
        LiftDebut(:final kind) => '${kind.name} lift',
        ScenarioDebut(:final scenario) => scenario.name,
        UnknownDebut() => 'unknown people',
        LaneDebut() => 'lane variety',
        PowerDebut(:final power) => '${power.name} power',
      };
}

final class TypeDebut extends Debut {
  const TypeDebut(this.type);
  final ResidentType type;
}

final class CargoDebut extends Debut {
  const CargoDebut(this.cargo);
  final Cargo cargo;
}

final class LiftDebut extends Debut {
  const LiftDebut(this.kind);
  final LiftKind kind;
}

final class ScenarioDebut extends Debut {
  const ScenarioDebut(this.scenario);
  final Scenario scenario;
}

/// From this level some people behind a lane front are unknown until they reach it.
final class UnknownDebut extends Debut {
  const UnknownDebut();
}

/// From this level the number of lanes varies by level.
final class LaneDebut extends Debut {
  const LaneDebut();
}

/// The level a power becomes available.
final class PowerDebut extends Debut {
  const PowerDebut(this.power);
  final Power power;
}
