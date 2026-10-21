import 'cast.dart';
import 'formulas.dart';

/// An immutable level definition. Created by [LevelGenerator] or by hand
/// in tests. [queues] lists each lane front-first.
class Level {
  const Level({
    required this.number,
    required this.capacity,
    required this.trips,
    required this.benchSize,
    required this.difficulty,
    required this.floors,
    required this.queues,
    this.parTrips = 0,
    this.seed = 0,
  });

  final int number;

  /// Lift capacity in hidden kg.
  final int capacity;

  /// Trip budget for the level.
  final int trips;

  final int benchSize;
  final Difficulty difficulty;

  /// Floors in lift rotation order.
  final List<Floor> floors;

  /// Lanes, front of the lane at index 0.
  final List<List<Resident>> queues;

  /// Trips the solver bot needed. 0 for hand-built levels.
  final int parTrips;

  final int seed;

  int get residentCount => queues.fold(0, (a, q) => a + q.length);

  Level copyWith({int? trips, int? benchSize, int? parTrips}) => Level(
        number: number,
        capacity: capacity,
        trips: trips ?? this.trips,
        benchSize: benchSize ?? this.benchSize,
        difficulty: difficulty,
        floors: floors,
        queues: queues,
        parTrips: parTrips ?? this.parTrips,
        seed: seed,
      );

  /// The 18-resident slice from the concept canvas (Play artboard). Used by
  /// widget tests and as the M1 hand-built level.
  static Level conceptSlice() {
    var id = 0;
    List<Resident> lane(List<(Floor, ResidentType)> spec) => [
          for (final (floor, type) in spec)
            Resident(id: ++id, type: type, floor: floor),
        ];
    const c = Floor.coral, t = Floor.teal, b = Floor.blue;
    const kid = ResidentType.kid,
        student = ResidentType.student,
        officeW = ResidentType.officeW,
        officeM = ResidentType.officeM,
        aunty = ResidentType.aunty,
        grandpa = ResidentType.grandpa,
        uncle = ResidentType.uncle,
        gym = ResidentType.gym,
        rider = ResidentType.rider;
    return Level(
      number: 12,
      capacity: 280,
      trips: 8,
      benchSize: 4,
      difficulty: Difficulty.normal,
      floors: const [c, t, b],
      queues: [
        lane([(c, uncle), (t, kid), (b, officeM), (c, student), (t, officeW)]),
        lane([(t, gym), (c, kid), (b, rider), (t, rider)]),
        lane([(b, aunty), (c, aunty), (t, officeM), (b, kid), (c, grandpa)]),
        lane([(c, officeW), (b, uncle), (t, student), (b, grandpa)]),
      ],
    );
  }
}
