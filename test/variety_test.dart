import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/scenario.dart';

/// Lanes as (floor, type, cargo), front first.
Level hand(
  List<List<(Floor, ResidentType, Cargo)>> lanes, {
  int capacity = 360,
  int trips = 10,
  int bench = 2,
  List<Floor> floors = const [c, t],
  List<LiftKind> schedule = const [LiftKind.normal],
  int? lockedLane,
  int lockedUntilTrip = 0,
  List<(int, int, Floor, ResidentType)> arrivals = const [],
}) {
  var id = 0;
  return Level(
    number: 70,
    capacity: capacity,
    trips: trips,
    benchSize: bench,
    difficulty: Difficulty.normal,
    floors: floors,
    queues: [
      for (final lane in lanes) [for (final (f, ty, cg) in lane) Resident(id: ++id, type: ty, floor: f, cargo: cg)],
    ],
    liftSchedule: schedule,
    lockedLane: lockedLane,
    lockedUntilTrip: lockedUntilTrip,
    arrivals: [
      for (final (after, lane, f, ty) in arrivals) Arrival(afterTrip: after, lane: lane, resident: Resident(id: ++id, type: ty, floor: f)),
    ],
  );
}

const c = Floor.coral, t = Floor.teal, b = Floor.blue;
const none = Cargo.none;

void board(LiftGame g, int lane) {
  g.tapQueue(lane);
  g.tapLift();
}

void sendAndArrive(LiftGame g) {
  g.send();
  g.finishSend();
}

void main() {
  group('cargo', () {
    test('a resident weighs type plus cargo', () {
      const r = Resident(id: 1, type: ResidentType.uncle, floor: c, cargo: Cargo.cylinder);
      expect(r.kg, ResidentType.uncle.kg + Cargo.cylinder.kg);
      const plain = Resident(id: 2, type: ResidentType.uncle, floor: c);
      expect(plain.kg, ResidentType.uncle.kg);
    });

    test('cargo counts on the gauge and can snap the cable', () {
      // 104 + 30, 104 + 30 = 268 of 280; one more cylinder carrier crashes.
      final g = LiftGame(hand([
        [(c, ResidentType.uncle, Cargo.cylinder), (c, ResidentType.uncle, Cargo.cylinder), (c, ResidentType.kid, none)],
      ], capacity: 280, floors: const [c]));
      board(g, 0);
      board(g, 0);
      expect(g.load, 268);
      expect(g.zone, LoadZone.limit);
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.overloaded);
    });

    test('kids and anyone pushing a chair, pram or trolley never carry cargo', () {
      expect(ResidentType.kid.canCarry, isFalse);
      expect(ResidentType.wheelchair.canCarry, isFalse);
      expect(ResidentType.pram.canCarry, isFalse);
      expect(ResidentType.bellhop.canCarry, isFalse);
      expect(ResidentType.uncle.canCarry, isTrue);
    });
  });

  group('lift kinds', () {
    test('old and service lifts change capacity for their trip only', () {
      expect(Formulas.liftCapacity(360, LiftKind.old), 270);
      expect(Formulas.liftCapacity(360, LiftKind.service), 504);
      expect(Formulas.liftCapacity(360, LiftKind.express), 360);
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none), (t, ResidentType.kid, none), (c, ResidentType.kid, none), (t, ResidentType.kid, none)],
      ], schedule: const [LiftKind.normal, LiftKind.old, LiftKind.service]));
      expect(g.liftKind, LiftKind.normal);
      expect(g.capacity, 360);
      board(g, 0);
      sendAndArrive(g);
      expect(g.liftKind, LiftKind.old);
      expect(g.capacity, 270);
      board(g, 0);
      sendAndArrive(g);
      expect(g.liftKind, LiftKind.service);
      expect(g.capacity, 504);
    });

    test('zones scale to the old lift, and it crashes below the normal limit', () {
      // Old lift: 270. Uncle 104 + guard 96 = 200 (74%, light); + aunty 80 = 280 > 270.
      final g = LiftGame(hand([
        [(c, ResidentType.uncle, none), (c, ResidentType.guard, none), (c, ResidentType.aunty, none)],
      ], floors: const [c], schedule: const [LiftKind.old]));
      board(g, 0);
      board(g, 0);
      expect(g.zone, LoadZone.light);
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.overloaded);
    });

    test('an express boards both floors, refuses a third, and skips both in the rotation', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none), (t, ResidentType.kid, none), (b, ResidentType.kid, none)],
        [(c, ResidentType.kid, none)],
      ], floors: const [c, t, b], schedule: const [LiftKind.express]));
      expect(g.liftFloors, [c, t]);
      board(g, 0); // coral
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.boarded); // teal
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.wrongFloor); // blue
      expect(g.drainEvents().whereType<RefusedEvent>().single.liftFloors, [c, t]);
      g.selection = null;
      sendAndArrive(g);
      // Rotation continues after teal: blue, then back to coral.
      expect(g.liftFloors, [b, c]);
    });

    test('an express with one floor left serves just that floor', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none), (c, ResidentType.kid, none)],
      ], floors: const [c, t], schedule: const [LiftKind.express]));
      expect(g.liftFloors, [c]);
    });

    test('running out of trips on the way to an express continues into it', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none), (t, ResidentType.kid, none), (b, ResidentType.kid, none)],
      ], floors: const [c, t, b], trips: 1, schedule: const [LiftKind.normal, LiftKind.express]));
      board(g, 0);
      sendAndArrive(g);
      expect(g.failKind, FailKind.outOfTrips);
      g.continueAfterFail(viaAd: true);
      expect(g.liftKind, LiftKind.express);
      expect(g.liftFloors, [t, b]);
    });

    test('repair after a crash on an express keeps both floors', () {
      final g = LiftGame(hand([
        [(c, ResidentType.uncle, none), (t, ResidentType.uncle, none), (c, ResidentType.uncle, none), (t, ResidentType.uncle, none)],
      ], floors: const [c, t], schedule: const [LiftKind.express]));
      for (var i = 0; i < 3; i++) {
        board(g, 0);
      }
      g.tapQueue(0);
      expect(g.tapLift(), BoardResult.overloaded);
      g.finishCrash();
      g.continueAfterFail(viaAd: true);
      expect(g.liftFloors, [c, t]);
      expect(g.riders, hasLength(3));
      expect(g.queues.first, hasLength(1));
    });
  });

  group('maintenance', () {
    test('the coned-off lane ignores taps until its trip, then opens', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none), (c, ResidentType.kid, none)],
        [(c, ResidentType.aunty, none), (t, ResidentType.kid, none)],
      ], floors: const [c, t], lockedLane: 0, lockedUntilTrip: 1));
      g.tapQueue(0);
      expect(g.selection, isNull);
      board(g, 1);
      sendAndArrive(g);
      expect(g.isLaneLocked(0), isFalse);
      expect(g.drainEvents().whereType<LaneOpenedEvent>().single.lane, 0);
    });

    test('a lift is never sent for residents behind the cones', () {
      // Only lane 0 (locked) holds teal; the lift serves coral, then coral
      // is empty, so the lane opens early rather than leave the lift stuck.
      final g = LiftGame(hand([
        [(t, ResidentType.kid, none)],
        [(c, ResidentType.kid, none)],
      ], floors: const [c, t], lockedLane: 0, lockedUntilTrip: 5));
      expect(g.liftFloors, [c]);
      board(g, 1);
      sendAndArrive(g);
      expect(g.phase, Phase.playing);
      expect(g.isLaneLocked(0), isFalse);
      expect(g.liftFloors, [t]);
    });

    test('a jam that only the coned-off lane could clear opens the lane instead', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none)],
        [(t, ResidentType.kid, none), (t, ResidentType.kid, none), (c, ResidentType.kid, none)],
      ], floors: const [c, t], bench: 1, lockedLane: 0, lockedUntilTrip: 3));
      expect(g.liftFloors, [c]);
      g.tapQueue(1);
      g.tapBench(0);
      // Bench full, open lane front is teal, the coral front was coned off.
      expect(g.phase, Phase.playing);
      expect(g.isLaneLocked(0), isFalse);
      expect(g.drainEvents().whereType<LaneOpenedEvent>(), hasLength(1));
    });

    test('a jam with nothing behind the cones either still fails', () {
      final g = LiftGame(hand([
        [(t, ResidentType.kid, none)],
        [(t, ResidentType.kid, none), (t, ResidentType.kid, none), (c, ResidentType.kid, none)],
      ], floors: const [c, t], bench: 1, lockedLane: 0, lockedUntilTrip: 3));
      g.tapQueue(1);
      g.tapBench(0);
      expect(g.failKind, FailKind.jam);
    });
  });

  group('rush hour', () {
    test('arrivals join the back of their lane after their trip', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none), (c, ResidentType.kid, none)],
        [(t, ResidentType.kid, none)],
      ], floors: const [c, t], arrivals: const [(1, 1, c, ResidentType.aunty), (2, 0, t, ResidentType.kid)]));
      expect(g.remainingTotal, 5);
      expect(g.pendingArrivals, hasLength(2));
      board(g, 0);
      sendAndArrive(g);
      expect(g.pendingArrivals, hasLength(1));
      expect(g.queues[1].last.type, ResidentType.aunty);
      expect(g.drainEvents().whereType<ArrivalsEvent>().single.count, 1);
    });

    test('the level is not won while arrivals are still to come', () {
      final g = LiftGame(hand([
        [(c, ResidentType.kid, none)],
      ], floors: const [c, t], arrivals: const [(4, 0, t, ResidentType.kid)]));
      board(g, 0);
      sendAndArrive(g);
      // Lobby emptied before trip 4: the wave arrives now instead.
      expect(g.phase, Phase.playing);
      expect(g.liftFloors, [t]);
      board(g, 0);
      sendAndArrive(g);
      expect(g.phase, Phase.won);
    });
  });
}
