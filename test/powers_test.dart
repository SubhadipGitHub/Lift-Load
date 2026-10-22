import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/game/scenario.dart';

const c = Floor.coral, t = Floor.teal;

/// A tiny level: lanes of (floor, type), front first. Ids count up from 1 across lanes, front to back.
Level tiny(
  List<List<(Floor, ResidentType)>> lanes, {
  int capacity = 280,
  int trips = 6,
  int bench = 2,
  Set<int> unknown = const {},
  int? lockedLane,
  List<Floor> floors = const [c, t],
}) {
  var id = 0;
  return Level(
    number: 20,
    capacity: capacity,
    trips: trips,
    benchSize: bench,
    difficulty: Difficulty.normal,
    floors: floors,
    unknownIds: unknown,
    lockedLane: lockedLane,
    lockedUntilTrip: lockedLane == null ? 0 : 3,
    scenario: lockedLane == null ? null : Scenario.maintenance,
    queues: [
      for (final lane in lanes) [for (final (f, ty) in lane) Resident(id: ++id, type: ty, floor: f)],
    ],
  );
}

void main() {
  group('unknown people', () {
    // Lane 0: ids 1 (front), 2, 3. Lane 1: ids 4 (front), 5.
    Level lobby({Set<int> unknown = const {2, 3, 5}, int capacity = 280}) => tiny([
          [(c, ResidentType.kid), (t, ResidentType.uncle), (c, ResidentType.aunty)],
          [(c, ResidentType.officeW), (t, ResidentType.gym)],
        ], unknown: unknown, capacity: capacity);

    test('the player sees null for every unknown person behind a front, and never for a front', () {
      final g = LiftGame(lobby());
      final lanes = g.visibleLanes;
      expect(lanes[0].map((r) => r?.id), [1, null, null]);
      expect(lanes[1].map((r) => r?.id), [4, null]);
      expect(g.isUnknownAt(0, 1), isTrue);
      expect(g.isUnknownAt(0, 0), isFalse);
    });

    test('a lane front is known even if its id is listed as unknown', () {
      final g = LiftGame(lobby(unknown: {1, 4}));
      expect(g.visibleLanes[0].first?.id, 1);
      expect(g.visibleLanes[1].first?.id, 4);
    });

    test('full information stays available for the solver and tests', () {
      final g = LiftGame(lobby());
      expect(g.queues[0].map((r) => r.id), [1, 2, 3]);
      expect(g.queues[0][1].type, ResidentType.uncle);
    });

    test('an unknown person is revealed, once, when boarding moves them to the front', () {
      final g = LiftGame(lobby());
      g.drainEvents();
      g.tapQueue(0);
      g.tapLift();
      final events = g.drainEvents().whereType<RevealedEvent>().toList();
      expect(events, hasLength(1));
      expect(events.single.resident.id, 2);
      expect(events.single.lane, 0);
      expect(g.visibleLanes[0].map((r) => r?.id), [2, null]);
    });

    test('seating a front on the bench reveals the next person too', () {
      final g = LiftGame(lobby());
      g.drainEvents();
      g.tapQueue(1);
      g.tapBench(0);
      expect(g.visibleLanes[1].map((r) => r?.id), [5]);
      expect(g.drainEvents().whereType<RevealedEvent>().single.resident.id, 5);
    });

    test('a crash reveals nobody: the person behind stays unknown, before and after the repair', () {
      final g = LiftGame(lobby(capacity: 5)); // anyone overloads the lift
      g.tapQueue(0);
      g.tapLift();
      expect(g.phase, Phase.falling);
      expect(g.visibleLanes[0][0], isNull, reason: 'person 2 has not stepped up while the lift falls');
      expect(g.frontOf(0), isNull);
      expect(g.drainEvents().whereType<RevealedEvent>(), isEmpty);
      g.finishCrash();
      g.continueAfterFail(viaAd: false);
      expect(g.queues[0].map((r) => r.id), [1, 2, 3]);
      expect(g.visibleLanes[0].map((r) => r?.id), [1, null, null]);
    });

    test('the UI-facing lanes carry no type, cargo or floor for an unknown person', () {
      final g = LiftGame(lobby());
      final unknownCount = g.visibleLanes.expand((l) => l).where((r) => r == null).length;
      expect(unknownCount, 3);
    });
  });

  group('swap', () {
    Level lobby({int? lockedLane}) => tiny([
          [(c, ResidentType.kid), (t, ResidentType.aunty)],
          [(t, ResidentType.uncle)],
          [(c, ResidentType.officeW)],
          const [],
        ], lockedLane: lockedLane);

    test('swaps two lane fronts, clears the selection and costs a use', () {
      final g = LiftGame(lobby());
      g.tapQueue(0);
      g.drainEvents();
      expect(g.swapFronts(0, 1), isTrue);
      expect(g.queues[0].map((r) => r.type), [ResidentType.uncle, ResidentType.aunty]);
      expect(g.queues[1].single.type, ResidentType.kid);
      expect(g.selection, isNull);
      expect(g.powerUses(Power.swap), 1);
      final events = g.drainEvents().whereType<SwapEvent>().toList();
      expect(events.single.laneA, 0);
      expect(events.single.laneB, 1);
    });

    test('is refused for the same lane, an empty lane, a coned-off lane or a bad index', () {
      final g = LiftGame(lobby(lockedLane: 2));
      expect(g.swapFronts(0, 0), isFalse);
      expect(g.swapFronts(0, 3), isFalse, reason: 'lane 3 is empty');
      expect(g.swapFronts(0, 2), isFalse, reason: 'lane 2 is coned off');
      expect(g.swapFronts(-1, 1), isFalse);
      expect(g.swapFronts(0, 9), isFalse);
      expect(g.powerUses(Power.swap), 0);
    });

    test('is capped per level', () {
      final g = LiftGame(lobby());
      for (var i = 0; i < Formulas.powerCap(Power.swap); i++) {
        expect(g.canUsePower(Power.swap), isTrue);
        expect(g.swapFronts(0, 1), isTrue);
      }
      expect(g.canUsePower(Power.swap), isFalse);
      expect(g.swapFronts(0, 1), isFalse);
    });

    test('needs two open lanes with people', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
        const [],
      ]));
      expect(g.canUsePower(Power.swap), isFalse);
    });
  });

  group('seats and trips', () {
    test('+2 seats adds bench seats once per level', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ], bench: 3));
      expect(g.benchLength, 3);
      g.drainEvents();
      expect(g.addSeats(), isTrue);
      expect(g.benchLength, 3 + Formulas.powerSeats);
      expect(g.drainEvents().whereType<SeatsAddedEvent>().single.count, Formulas.powerSeats);
      expect(g.addSeats(), isFalse, reason: 'one use per level');
      expect(g.benchLength, 3 + Formulas.powerSeats);
    });

    test('+1 trip raises the budget once per level', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ], trips: 4));
      expect(g.tripsLeft, 4);
      expect(g.addTrip(), isTrue);
      expect(g.tripsLeft, 4 + Formulas.powerTrips);
      expect(g.tripsTotal, 5);
      expect(g.addTrip(), isFalse);
    });

    test('neither works once the level is over', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ]));
      g.tapQueue(0);
      g.tapLift();
      g.send();
      g.finishSend();
      expect(g.phase, Phase.won);
      expect(g.addSeats(), isFalse);
      expect(g.addTrip(), isFalse);
    });

    test('neither works while the lift is departing', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (c, ResidentType.kid)],
      ]));
      g.tapQueue(0);
      g.tapLift();
      g.send();
      expect(g.phase, Phase.departing);
      expect(g.addTrip(), isFalse);
    });
  });

  group('express', () {
    test('delivers the selected lane front straight away: no trip, no load, no seat', () {
      final g = LiftGame(tiny([
        [(t, ResidentType.uncle), (c, ResidentType.kid)],
        [(c, ResidentType.officeW)],
      ]));
      final before = g.remainingTotal;
      g.tapQueue(0); // the uncle, going to a floor the waiting lift does not serve
      g.drainEvents();
      final who = g.expressDeliver();
      expect(who?.type, ResidentType.uncle);
      expect(g.remainingTotal, before - 1);
      expect(g.tripsUsed, 0);
      expect(g.load, 0);
      expect(g.benchUsed, 0);
      expect(g.selection, isNull);
      expect(g.queues[0].single.type, ResidentType.kid);
      expect(g.drainEvents().whereType<ExpressEvent>().single.resident.type, ResidentType.uncle);
      expect(g.powerUses(Power.express), 1);
    });

    test('works on a bench resident', () {
      final g = LiftGame(tiny([
        [(t, ResidentType.aunty), (c, ResidentType.kid)],
      ]));
      g.tapQueue(0);
      g.tapBench(0);
      g.tapBench(0); // select the seated aunty
      expect(g.selected?.type, ResidentType.aunty);
      expect(g.expressDeliver()?.type, ResidentType.aunty);
      expect(g.benchUsed, 0);
    });

    test('needs a selection, and is capped per level', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (c, ResidentType.kid), (c, ResidentType.kid)],
      ]));
      expect(g.canUsePower(Power.express), isFalse);
      expect(g.expressDeliver(), isNull);
      g.tapQueue(0);
      expect(g.expressDeliver(), isNotNull);
      g.tapQueue(0);
      expect(g.canUsePower(Power.express), isFalse, reason: 'one use per level');
      expect(g.expressDeliver(), isNull);
    });

    test('delivering the last person wins the level', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ]));
      g.tapQueue(0);
      g.drainEvents();
      g.expressDeliver();
      expect(g.phase, Phase.won);
      expect(g.drainEvents().whereType<WonEvent>(), hasLength(1));
    });

    test('with riders aboard the level is not won until they are sent', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
        [(t, ResidentType.officeW)],
      ]));
      g.tapQueue(0);
      g.tapLift();
      g.tapQueue(1);
      g.expressDeliver();
      expect(g.phase, Phase.playing);
      g.send();
      g.finishSend();
      expect(g.phase, Phase.won);
    });

    test('re-routes a waiting lift whose floor nobody can reach any more', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
        [(t, ResidentType.officeW)],
      ]));
      expect(g.liftFloors, [c]);
      g.tapQueue(0);
      g.drainEvents();
      g.expressDeliver(); // the only coral resident leaves
      expect(g.phase, Phase.playing);
      expect(g.liftFloors, [t], reason: 'the lift must not wait for nobody');
      expect(g.drainEvents().whereType<LiftArrivedEvent>(), hasLength(1));
      g.tapQueue(1);
      expect(g.tapLift(), BoardResult.boarded);
    });

    test('reveals an unknown person who steps up after the delivery', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (c, ResidentType.aunty)],
      ], unknown: {2}));
      g.tapQueue(0);
      g.drainEvents();
      g.expressDeliver();
      expect(g.visibleLanes[0].single?.id, 2);
      expect(g.drainEvents().whereType<RevealedEvent>(), hasLength(1));
    });
  });

  group('the same level plays the same without powers', () {
    test('a fresh game has no power uses', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
      ]));
      for (final p in Power.values) {
        expect(g.powerUses(p), 0);
      }
    });
  });

  group('express jam guard', () {
    // One bench seat, already holding a teal. The lift is for coral. The only
    // boardable person is lane 0's front coral: Express on them would jam.
    Level jammed() => tiny([
          [(c, ResidentType.kid), (t, ResidentType.aunty), (c, ResidentType.officeW)],
          [(t, ResidentType.uncle)],
        ], bench: 1);

    test('Express is refused when it would leave an empty lift, a full bench and nobody to board', () {
      final g = LiftGame(jammed());
      g.tapQueue(1);
      g.tapBench(0);
      g.tapQueue(0);
      expect(g.canUsePower(Power.express), isFalse);
      expect(g.expressDeliver(), isNull);
      expect(g.phase, Phase.playing);
      expect(g.powerUses(Power.express), 0);
      expect(g.queues[0].first.id, 1, reason: 'nothing changed');
    });

    test('Express is allowed when someone else can still board', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
        [(c, ResidentType.aunty)],
        [(t, ResidentType.uncle)],
      ], bench: 1));
      g.tapQueue(2);
      g.tapBench(0);
      g.tapQueue(0);
      expect(g.canUsePower(Power.express), isTrue);
      expect(g.expressDeliver()?.id, 1);
      expect(g.phase, Phase.playing);
    });
  });

  group('powers only work while playing', () {
    test('Swap and Express are refused during a send and a fall', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid)],
        [(c, ResidentType.aunty)],
        [(c, ResidentType.uncle), (t, ResidentType.kid)],
      ]));
      g.tapQueue(0);
      g.tapLift();
      g.send();
      expect(g.phase, Phase.departing);
      expect(g.canUsePower(Power.swap), isFalse);
      expect(g.swapFronts(1, 2), isFalse);
      g.tapQueue(1);
      expect(g.canUsePower(Power.express), isFalse);
      expect(g.expressDeliver(), isNull);
    });

    test('Swap leaves the people behind the fronts masked', () {
      final g = LiftGame(tiny([
        [(c, ResidentType.kid), (t, ResidentType.uncle)],
        [(t, ResidentType.officeW), (c, ResidentType.gym)],
      ], unknown: {2, 4}));
      expect(g.swapFronts(0, 1), isTrue);
      expect(g.visibleLanes[0].map((r) => r?.id), [3, null]);
      expect(g.visibleLanes[1].map((r) => r?.id), [1, null]);
    });
  });
}
