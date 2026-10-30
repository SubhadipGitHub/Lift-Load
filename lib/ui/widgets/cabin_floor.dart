/// Where riders stand on the cabin floor: two rows in depth, items set down
/// by their owners' feet.
///
/// The first riders walk to the back wall, a little smaller and darker, one
/// per spot of [Metrics.cabinBackSpots]; everyone after them stands in the
/// front row, in the gaps between the back row first so the back row shows
/// through ([Metrics.cabinFrontSpots]). A spot never moves once taken, and a
/// figure near a wall is nudged in so nothing hangs outside the cabin.
/// Placement depends only on boarding order and how riders look (type and
/// cargo, both visible), never on weight (rule 3).
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
    const back = Metrics.cabinBackSpots, front = Metrics.cabinFrontSpots;
    return [
      for (var i = 0; i < riders.length; i++)
        i < back.length
            ? _spot(riders[i], m, back[i], back: true)
            : _spot(riders[i], m, front[(i - back.length) % front.length], back: false),
    ];
  }

  static CabinSpot _spot(Resident r, Metrics m, double across, {required bool back}) {
    final height = m.cabinFigure * (back ? Metrics.cabinBackScale : 1);
    final unit = height / designHeight;
    final person = unit * ResidentLook.designWidth(r.type, Cargo.none);
    final footprint = unit * ResidentLook.designWidth(r.type, r.cargo);
    final left = (m.cabinWidth * across - person / 2).clamp(0.0, m.cabinWidth - footprint);
    return CabinSpot(
      resident: r,
      back: back,
      left: left,
      feet: m.cabinHeight * (back ? Metrics.cabinBackFeetLine : Metrics.cabinFrontFeetLine),
      height: height,
      cargoForward: m.cabinHeight * Metrics.cabinCargoForward * (back ? Metrics.cabinBackScale : 1),
    );
  }
}
