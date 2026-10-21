/// The buildings the game moves through, 20 levels each. A venue changes the
/// look (lib/ui/theme.dart, `VenueStyle`) and who tends to be waiting.
/// Names are invented; no real buildings, societies or brands.
library;

import 'cast.dart';

enum Venue {
  society('Sunrise Towers', 1, {}, {}),
  office(
    'Skyline Offices',
    21,
    {ResidentType.officeW: 4, ResidentType.officeM: 4, ResidentType.guard: 3},
    {Cargo.suitcase: 3},
  ),
  hospital(
    'Lakeside Hospital',
    41,
    {ResidentType.grandpa: 4, ResidentType.wheelchair: 3, ResidentType.puffer: 3},
    {Cargo.waterCan: 2},
  ),
  mall(
    'Bazaar Mall',
    61,
    {ResidentType.aunty: 4, ResidentType.kid: 3, ResidentType.puffer: 3, ResidentType.pram: 3},
    {Cargo.waterCan: 3, Cargo.suitcase: 2},
  ),
  hotel(
    'Starlight Hotel',
    81,
    {ResidentType.bellhop: 4, ResidentType.officeW: 3, ResidentType.officeM: 3},
    {Cargo.suitcase: 4},
  );

  const Venue(this.displayName, this.firstLevel, this.typeWeights, this.cargoWeights);

  final String displayName;
  final int firstLevel;

  /// Relative odds of each unlocked type in this venue. Unlisted types: 2.
  final Map<ResidentType, int> typeWeights;

  /// Relative odds of each unlocked cargo in this venue. Unlisted cargo: 1.
  final Map<Cargo, int> cargoWeights;

  static const int levelsPerVenue = 20;

  /// Last level of this venue. The hotel runs on past level 100.
  int get lastLevel => firstLevel + levelsPerVenue - 1;

  int weightOf(ResidentType t) => typeWeights[t] ?? 2;
  int cargoWeightOf(Cargo c) => cargoWeights[c] ?? 1;

  static Venue of(int level) {
    var v = society;
    for (final candidate in values) {
      if (candidate.firstLevel <= level) v = candidate;
    }
    return v;
  }
}
