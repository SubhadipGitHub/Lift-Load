/// The four powers a player can spend during a level (the Scale is a separate
/// booster). What a power does is in [LiftGame]; how many a player owns is in
/// the profile; every number (caps, prices, ad uses) is in [Formulas].
/// See docs/PRD-v1.6-powers.md.
library;

enum Power {
  /// Swaps the front residents of two lanes.
  swap(14),

  /// Adds bench seats for the rest of the level.
  seats(19),

  /// Adds one trip to the level's budget.
  trip(27),

  /// Delivers the selected resident straight to their floor.
  express(29);

  const Power(this.unlockLevel);

  final int unlockLevel;

  static Power? introducedAt(int level) {
    for (final p in values) {
      if (p.unlockLevel == level) return p;
    }
    return null;
  }
}
