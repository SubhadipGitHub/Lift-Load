/// The resident cast and the floors they live on.
///
/// Pure Dart: nothing in lib/game imports Flutter, so the engine, generator
/// and solver run under `dart test` and `dart run tool/simulate.dart`.
library;

/// A floor the lifts serve. The label is the only thing shown to players;
/// colour and shape live in the UI layer (lib/ui/theme.dart).
enum Floor {
  coral('2F'),
  sun('3F'),
  teal('5F'),
  blue('6F'),
  plum('8F'),
  leaf('9F');

  const Floor(this.label);

  /// Floor number shown on the resident's tag, e.g. "5F".
  final String label;
}

/// Every resident type. [kg] is the hidden weight: it is NEVER rendered in
/// the game UI. Players learn it from the silhouette (height, build, cargo).
///
/// Each type always weighs the same so the cast is learnable. One type per
/// world is a "liar" whose look understates its weight (the gym regular).
enum ResidentType {
  kid('Schoolkid', 30, 1),
  officeW('Office goer', 60, 1),
  officeM('Office goer', 74, 1),
  aunty('Aunty', 80, 9),
  student('Student', 55, 17),
  uncle('Uncle', 104, 26),
  grandpa('Grandpa', 64, 33),
  rider('Delivery rider', 86, 41),
  gym('Gym regular', 92, 49);

  const ResidentType(this.displayName, this.kg, this.unlockLevel);

  /// Name used in accessibility labels and the cast screen.
  final String displayName;

  /// Hidden weight in kilograms. Engine-only.
  final int kg;

  /// First level this type can appear in.
  final int unlockLevel;

  /// Types available at [level], in unlock order.
  static List<ResidentType> unlockedAt(int level) =>
      values.where((t) => t.unlockLevel <= level).toList(growable: false);

  /// The type introduced exactly at [level], if any.
  static ResidentType? introducedAt(int level) {
    for (final t in values) {
      if (t.unlockLevel == level && level > 1) return t;
    }
    return null;
  }
}

/// One person waiting for a lift.
class Resident {
  const Resident({required this.id, required this.type, required this.floor});

  final int id;
  final ResidentType type;
  final Floor floor;

  /// Hidden weight. Never display this.
  int get kg => type.kg;

  @override
  bool operator ==(Object other) => other is Resident && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Resident#$id(${type.name}→${floor.label})';
}
