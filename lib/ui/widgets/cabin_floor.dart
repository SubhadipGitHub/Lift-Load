/// Where riders stand on the cabin floor: two rows in depth, items set down
/// by their owners' feet.
///
/// The first [Metrics.cabinBackSlots] riders walk to the back wall, a little
/// smaller and darker; everyone after them stands in the front row. Within a
/// row, riders stand left to right in boarding order, overlapping a little,
/// and a row too wide for the cabin shrinks to fit. Placement depends only on
/// boarding order and how riders look (type and cargo, both visible), never
/// on weight (rule 3).
library;

import '../../game/cast.dart';
import '../layout.dart';
import '../painters/resident_painter.dart';
import 'resident_figure.dart';

/// One rider's place, in the cabin's own box (origin at its top left).
class CabinSpot {
  const CabinSpot({
    required this.resident,
    required this.back,
    required this.left,
    required this.feet,
    required this.height,
    required this.cargoForward,
  });

  final Resident resident;

  /// In the back row.
  final bool back;

  /// Left edge of the rider's figure box, and the feet line.
  final double left, feet;

  /// Figure height.
  final double height;

  /// How far in front of the feet line the item stands.
  final double cargoForward;

  double get _unit => height / designHeight;

  /// The person's own box (no item), feet on [feet].
  double get personWidth => _unit * ResidentLook.designWidth(resident.type, Cargo.none);
  double get top => feet - height * (1 - ResidentFigure.belowFeet);

  /// The rider with their item, as the walk into the lift draws them.
  double get footprint => _unit * ResidentLook.designWidth(resident.type, resident.cargo);

  /// The item's box, set down just in front of the owner's feet against their
  /// legs; null without one.
  ({double left, double feet, double width})? get cargo {
    if (resident.cargo == Cargo.none) return null;
    final w = _unit * cargoWidth;
    return (left: left + personWidth - w * Metrics.cabinCargoTuck, feet: feet + cargoForward, width: w);
  }
}

abstract final class CabinFloor {
  /// Spots for [riders] in boarding order, in a cabin of [m]'s size.
  static List<CabinSpot> layout(List<Resident> riders, Metrics m) {
    final split = riders.length < Metrics.cabinBackSlots ? riders.length : Metrics.cabinBackSlots;
    return [
      ..._row(riders.sublist(0, split), m, back: true),
      ..._row(riders.sublist(split), m, back: false),
    ];
  }

  static List<CabinSpot> _row(List<Resident> row, Metrics m, {required bool back}) {
    if (row.isEmpty) return const [];
    final base = m.cabinFigure * (back ? Metrics.cabinBackScale : 1);
    double widthOf(Resident r, double h) => h / designHeight * ResidentLook.designWidth(r.type, r.cargo);
    var span = 0.0;
    for (var i = 0; i < row.length; i++) {
      span += widthOf(row[i], base) * (i == row.length - 1 ? 1 : Metrics.cabinRiderStep);
    }
    final room = m.cabinWidth * Metrics.cabinRowSpan;
    final fit = span > room ? room / span : 1.0;
    final height = base * fit;
    final feet = m.cabinHeight * (back ? Metrics.cabinBackFeetLine : Metrics.cabinFrontFeetLine);
    var left = (m.cabinWidth - span * fit) / 2;
    final spots = <CabinSpot>[];
    for (final r in row) {
      spots.add(CabinSpot(
        resident: r,
        back: back,
        left: left,
        feet: feet,
        height: height,
        cargoForward: m.cabinHeight * Metrics.cabinCargoForward * (back ? Metrics.cabinBackScale : 1),
      ));
      left += widthOf(r, height) * Metrics.cabinRiderStep;
    }
    return spots;
  }
}
