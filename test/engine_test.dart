import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/scenario.dart';

/// Builds a tiny level: lanes given as (floor, type) pairs, front first.
Level tiny(
  List<List<(Floor, ResidentType)>> lanes, {
  int capacity = 280,
  int trips = 6,
  int bench = 2,
  List<Floor> floors = const [Floor.coral, Floor.teal],
}) {
  var id = 0;
  return Level(
    number: 5,
    capacity: capacity,
    trips: trips,
    benchSize: bench,
    difficulty: Difficulty.normal,
    floors: floors,
    queues: [
      for (final lane in lanes) [for (final (f, t) in lane) Resident(id: ++id, type: t, floor: f)],
    ],
  );
}

const c = Floor.coral, t = Floor.teal;

void main() {
  group('boarding', () {
    test('wrong floor is refused at no cost and stays selected', () {
      final g = LiftGame(tiny([
        [(t, ResidentType.kid)],
        [(c, ResidentType.kid)],
      ]));
      expect(g.liftFloor, c);
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.wrongFloor);
      expect(g.selection, const Selection.queue(0));
      expect(g.riders, isEmpty);
      expect(g.drainEvents().whereType<RefusedEvent>(), hasLength(1));
    });

    test('tap without a selection does nothing', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ], floors: const [c]));
      expect(g.tapLift(), BoardResult.noSelection);
    });

    test('boarding adds hidden weight and reports the zone', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.uncle), (c, ResidentType.aunty)],
      ], floors: const [c]));
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.boarded);
      expect(g.load, 104);
      expect(g.zone, LoadZone.light);
      g.tapQueue(0);
      g.tapLift();
      expect(g.load, 184);
      expect(g.zone, LoadZone.light);
    });

    test('going over capacity snaps the cable, then fails as a crash', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.uncle), (c, ResidentType.uncle), (c, ResidentType.officeM)],
      ], floors: const [c]));
      for (var i = 0; i < 2; i++) {
        g.tapQueue(0);
        g.tapLift();
      }
      expect(g.load, 208);
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.overloaded);
      expect(g.phase, Phase.falling);
      g.finishCrash();
      expect(g.phase, Phase.failed);
      expect(g.failKind, FailKind.crash);
    });

    test('repair after a crash returns the last rider to their lane', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.uncle), (c, ResidentType.uncle), (c, ResidentType.officeM)],
      ], floors: const [c]));
      for (var i = 0; i < 3; i++) {
        g.tapQueue(0);
        g.tapLift();
      }
      g.finishCrash();
      g.continueAfterFail(viaAd: true);
      expect(g.phase, Phase.playing);
      expect(g.load, 208);
      expect(g.riders, hasLength(2));
      expect(g.queues.first.single.type, ResidentType.officeM);
      expect(g.adContinueUsed, isTrue);
    });
  });

  group('sending', () {
    test('ratings and coins follow the zones', () {
      // 74 + 80 + 104 = 258 kg of 280 → 92%: good (green), not perfect.
      final g = LiftGame(tiny([
        [(c, ResidentType.officeM), (c, ResidentType.aunty), (c, ResidentType.uncle)],
        [(t, ResidentType.kid)],
      ]));
      for (var i = 0; i < 3; i++) {
        g.tapQueue(0);
        g.tapLift();
      }
      expect(g.send(), TripRating.good);
      expect(g.phase, Phase.departing);
      g.finishSend();
      expect(g.tripCoins, Formulas.greenTripCoins);
      expect(g.liftFloor, t);
      expect(g.tripsUsed, 1);
    });

    test('perfect load at 95% or more', () {
      // 104 + 92 + 74 = 270 of 280 → 96%.
      final g = LiftGame(tiny([
        [(c, ResidentType.uncle), (c, ResidentType.gym), (c, ResidentType.officeM)],
      ], floors: const [c]));
      for (var i = 0; i < 3; i++) {
        g.tapQueue(0);
        g.tapLift();
      }
      expect(g.send(), TripRating.perfect);
      g.finishSend();
      expect(g.perfects, 1);
      expect(g.phase, Phase.won);
    });

    test('half-empty trips earn nothing and running out of trips fails', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (c, ResidentType.kid)],
      ], floors: const [c], trips: 1));
      g.tapQueue(0);
      g.tapLift();
      expect(g.send(), TripRating.halfEmpty);
      g.finishSend();
      expect(g.tripCoins, 0);
      expect(g.phase, Phase.failed);
      expect(g.failKind, FailKind.outOfTrips);
      g.continueAfterFail(viaAd: true);
      expect(g.tripsLeft, Formulas.adTripsBonus);
      expect(g.phase, Phase.playing);
    });

    test('cannot send an empty lift', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ], floors: const [c]));
      expect(g.canSend, isFalse);
      expect(g.send(), isNull);
    });
  });

  group('bench', () {
    test('seating moves the lane front to the chosen seat', () {
      final g = LiftGame(tiny([
        [(t, ResidentType.kid), (c, ResidentType.kid)],
      ]));
      g.tapQueue(0);
      expect(g.tapBench(1), BenchResult.seated);
      expect(g.bench[1]?.floor, t);
      expect(g.queues.first.single.floor, c);
    });

    test('bench residents can board the lift', () {
      final g = LiftGame(tiny([
        [(t, ResidentType.kid), (c, ResidentType.aunty)],
      ]));
      g.tapQueue(0);
      g.tapBench(0);
      g.tapQueue(0);
      g.tapLift();
      g.send();
      g.finishSend();
      expect(g.liftFloor, t);
      expect(g.tapBench(0), BenchResult.selected);
      expect(g.tapLift(), BoardResult.boarded);
    });

    test('a full bench with nothing for this lift is a jam', () {
      final g = LiftGame(tiny([
        [(t, ResidentType.kid), (t, ResidentType.kid), (t, ResidentType.kid), (c, ResidentType.kid)],
      ], bench: 2));
      g.tapQueue(0);
      g.tapBench(0);
      g.tapQueue(0);
      g.tapBench(1);
      // Lane front is teal, bench is all teal, lift is coral, lift empty.
      expect(g.phase, Phase.failed);
      expect(g.failKind, FailKind.jam);
      g.continueAfterFail(viaAd: false);
      expect(g.bench, hasLength(3));
    });
  });

  group('continues always work', () {
    test('a jam continue adds enough seats to dig out the nearest match', () {
      // Lift is coral; the only coral is 2 deep behind teal kids.
      final g = LiftGame(tiny([
        [(t, ResidentType.kid), (t, ResidentType.kid), (t, ResidentType.kid), (t, ResidentType.kid), (c, ResidentType.kid)],
      ], bench: 2));
      g.tapQueue(0);
      g.tapBench(0);
      g.tapQueue(0);
      g.tapBench(1);
      expect(g.failKind, FailKind.jam);
      expect(g.continueSeats, 2);
      g.continueAfterFail(viaAd: true);
      expect(g.bench, hasLength(4));
      expect(g.drainEvents().whereType<ContinuedEvent>().single.seatsAdded, 2);
      g.tapQueue(0);
      g.tapBench(2);
      g.tapQueue(0);
      g.tapBench(3);
      expect(g.phase, Phase.playing);
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.boarded);
    });

    test('+2 trips into a lift that would jam also adds the seats it needs', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (c, ResidentType.kid), (t, ResidentType.kid)],
        [(c, ResidentType.kid)],
      ], bench: 1, trips: 1));
      g.tapQueue(1);
      g.tapBench(0); // bench full with a coral kid; fine while the lift is coral
      g.tapQueue(0);
      g.tapLift();
      g.send();
      g.finishSend();
      expect(g.failKind, FailKind.outOfTrips);
      // Next lift is teal: bench full, teal is 1 deep. Without a seat it jams.
      expect(g.continueSeats, 1);
      g.continueAfterFail(viaAd: true);
      expect(g.phase, Phase.playing);
      expect(g.liftFloor, t);
      expect(g.tripsLeft, Formulas.adTripsBonus);
      expect(g.bench, hasLength(2));
    });

    test('+2 trips adds no seats when the next lift is fine', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (t, ResidentType.kid)],
      ], trips: 1));
      g.tapQueue(0);
      g.tapLift();
      g.send();
      g.finishSend();
      expect(g.failKind, FailKind.outOfTrips);
      expect(g.continueSeats, 0);
      g.continueAfterFail(viaAd: true);
      expect(g.bench, hasLength(2));
    });
  });

  test('the concept slice traps four-person loads: gym+rider+officeM+kid crashes', () {
    // 92 + 86 + 74 + 30 = 282 > 280, the "MAX 4 PERSONS" trap.
    final g = LiftGame(tiny([
      [(c, ResidentType.gym), (c, ResidentType.rider), (c, ResidentType.officeM), (c, ResidentType.kid)],
    ], floors: const [c]));
    BoardResult last = BoardResult.noSelection;
    for (var i = 0; i < 4; i++) {
      g.tapQueue(0);
      last = g.tapLift();
    }
    expect(last, BoardResult.overloaded);
  });

  test('upcomingLifts follows the rotation', () {
    final g = LiftGame(Level.conceptSlice());
    expect(g.liftFloor, Floor.coral);
    expect(g.upcomingLifts(3).map((s) => s.floors.single), [Floor.teal, Floor.blue, Floor.coral]);
    expect(g.upcomingLifts(3).map((s) => s.kind), everyElement(LiftKind.normal));
  });
}
