/// One place that knows what is new on each level: a resident type, a
/// cargo, a lift kind or a lobby scenario. Debut levels are breathers
/// ([Formulas.difficulty]) and the generator makes sure the new thing shows
/// up enough to be learned.
library;

import 'cast.dart';
import 'scenario.dart';

sealed class Debut {
  const Debut();

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
      ]..sort();

  /// Short name for the level table.
  String get name => switch (this) {
        TypeDebut(:final type) => type.name,
        CargoDebut(:final cargo) => cargo.name,
        LiftDebut(:final kind) => '${kind.name} lift',
        ScenarioDebut(:final scenario) => scenario.name,
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
