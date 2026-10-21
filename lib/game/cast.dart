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

/// Every resident type, in unlock order. [kg] is the hidden weight: it is
/// NEVER rendered in the game UI. Players learn it from the silhouette
/// (height, build, vehicle, cargo).
///
/// Each type always weighs the same so the cast is learnable. Two types are
/// "liars": the gym regular looks lighter than he is, the teen in a puffer
/// jacket looks heavier.
enum ResidentType {
  kid('Schoolkid', 30, 1, canCarry: false),
  officeW('Office goer', 60, 1),
  officeM('Office goer', 74, 1),
  aunty('Aunty', 80, 9),
  student('Student', 55, 17),
  guard('Security guard', 96, 23),
  uncle('Uncle', 104, 26),
  grandpa('Grandpa', 64, 33),
  rider('Delivery rider', 86, 41),
  wheelchair('Patient in a wheelchair', 118, 43, canCarry: false),
  puffer('Teen in a puffer jacket', 48, 45),
  gym('Gym regular', 92, 49),
  pram('Parent with a pram', 84, 63, canCarry: false),
  bellhop('Bellhop with a trolley', 124, 83, canCarry: false);

  const ResidentType(this.displayName, this.kg, this.unlockLevel, {this.canCarry = true});

  /// Name used in accessibility labels and the cast screen.
  final String displayName;

  /// Hidden weight in kilograms. Engine-only.
  final int kg;

  /// First level this type can appear in.
  final int unlockLevel;

  /// Whether this type can carry [Cargo]. Kids and anyone already pushing
  /// a chair, pram or trolley cannot.
  final bool canCarry;

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

/// Something a resident carries. Like a type, each cargo always adds the
/// same hidden [kg], and its prop is drawn next to the resident.
enum Cargo {
  none('', 0, 1),
  waterCan('water can', 20, 13),
  suitcase('suitcase', 12, 21),
  cylinder('gas cylinder', 30, 37);

  const Cargo(this.displayName, this.kg, this.unlockLevel);

  /// Name used in accessibility labels, e.g. "Uncle with a gas cylinder".
  final String displayName;

  /// Hidden extra weight in kilograms. Engine-only.
  final int kg;

  final int unlockLevel;

  /// Cargo available at [level] (never [none]).
  static List<Cargo> unlockedAt(int level) =>
      values.where((c) => c != none && c.unlockLevel <= level).toList(growable: false);

  /// The cargo introduced exactly at [level], if any.
  static Cargo? introducedAt(int level) {
    for (final c in values) {
      if (c != none && c.unlockLevel == level) return c;
    }
    return null;
  }
}

/// One person waiting for a lift.
class Resident {
  const Resident({required this.id, required this.type, required this.floor, this.cargo = Cargo.none});

  final int id;
  final ResidentType type;
  final Floor floor;
  final Cargo cargo;

  /// Hidden weight: type plus cargo. Never display this.
  int get kg => type.kg + cargo.kg;

  @override
  bool operator ==(Object other) => other is Resident && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Resident#$id(${type.name}${cargo == Cargo.none ? '' : '+${cargo.name}'}→${floor.label})';
}
