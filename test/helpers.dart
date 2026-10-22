import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/ads_service.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/services/profile.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/theme.dart';

/// Shared widget-test helpers.

GameController controller(DebugAnalytics analytics, {Level Function(int)? levelFor}) => GameController(
      profile: Profile.fresh(DateTime(2026, 10, 21)),
      ads: StubAdsService(delay: Duration.zero),
      analytics: analytics,
      clock: () => DateTime(2026, 10, 21, 12),
      levelFor: levelFor ?? (_) => Level.conceptSlice(),
    );

/// A World 2 lobby with every wide figure and every cargo prop in it.
Level variety(Venue venue, LiftKind kind, Scenario? scenario) {
  var id = 0;
  Resident r(Floor f, ResidentType t, [Cargo cargo = Cargo.none]) =>
      Resident(id: ++id, type: t, floor: f, cargo: cargo);
  const c = Floor.coral, t = Floor.teal, b = Floor.blue;
  return Level(
    number: 90,
    capacity: 360,
    trips: 12,
    benchSize: 5,
    difficulty: Difficulty.normal,
    floors: const [c, t, b],
    venue: venue,
    liftSchedule: [kind],
    scenario: scenario,
    lockedLane: scenario == Scenario.maintenance ? 3 : null,
    lockedUntilTrip: scenario == Scenario.maintenance ? 3 : 0,
    arrivals:
        scenario == Scenario.rushHour ? [Arrival(afterTrip: 3, lane: 0, resident: r(t, ResidentType.kid))] : const [],
    queues: [
      [
        r(c, ResidentType.bellhop),
        r(t, ResidentType.uncle, Cargo.cylinder),
        r(b, ResidentType.kid),
        r(c, ResidentType.aunty)
      ],
      [r(c, ResidentType.wheelchair), r(b, ResidentType.officeW, Cargo.suitcase), r(t, ResidentType.guard)],
      [
        r(c, ResidentType.pram),
        r(t, ResidentType.puffer),
        r(b, ResidentType.grandpa, Cargo.waterCan),
        r(c, ResidentType.gym)
      ],
      [r(t, ResidentType.rider, Cargo.waterCan), r(c, ResidentType.student), r(b, ResidentType.officeM)],
    ],
  );
}

/// A level with every power unlocked (number 30 by default), [lanes] lanes
/// of four, and an unknown person second and fourth in each lane. Each lane's
/// front is a different type, so a lane is findable by who stands at its front.
Level dockLevel({int number = 30, int lanes = 4, Venue venue = Venue.society}) {
  var id = 0;
  const fronts = [
    (Floor.coral, ResidentType.kid),
    (Floor.teal, ResidentType.uncle),
    (Floor.blue, ResidentType.officeW),
    (Floor.coral, ResidentType.gym),
    (Floor.teal, ResidentType.student),
  ];
  final unknown = <int>{};
  final queues = <List<Resident>>[];
  for (var lane = 0; lane < lanes; lane++) {
    final (floor, type) = fronts[lane];
    queues.add([
      Resident(id: ++id, type: type, floor: floor),
      for (var depth = 1; depth < 4; depth++)
        Resident(
            id: ++id, type: ResidentType.aunty, floor: Floor.coral, cargo: depth == 2 ? Cargo.suitcase : Cargo.none),
    ]);
    unknown.addAll([queues.last[1].id, queues.last[3].id]);
  }
  return Level(
    number: number,
    capacity: 360,
    trips: 8,
    benchSize: 4,
    difficulty: Difficulty.normal,
    floors: const [Floor.coral, Floor.teal, Floor.blue],
    venue: venue,
    queues: queues,
    unknownIds: unknown,
  );
}

/// A controller on [level] with [stock] of each listed power and [coins].
GameController powerController(
  DebugAnalytics analytics, {
  Level? level,
  Map<Power, int> stock = const {},
  int coins = 300,
  bool grantReward = true,
}) {
  final lvl = level ?? dockLevel();
  final profile = Profile.fresh(DateTime(2026, 10, 22))
    ..coins = coins
    ..level = lvl.number;
  stock.forEach(profile.addPower);
  return GameController(
    profile: profile,
    ads: StubAdsService(delay: Duration.zero, grantReward: grantReward),
    analytics: analytics,
    clock: () => DateTime(2026, 10, 22, 12),
    levelFor: (_) => lvl,
  );
}

Future<void> pumpPlay(WidgetTester tester, GameController c) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  c.startLevel();
  await tester.pumpWidget(app(PlayScreen(controller: c)));
}

/// The app shell for widget tests. Animations are off (the same switch as
/// the OS reduce-motion setting), so looping idle motion never blocks
/// `pumpAndSettle`; pass [animate] to test motion itself.
Widget app(Widget home, {bool animate = false, double textScale = 1}) => MaterialApp(
      theme: LL.theme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: !animate,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    );
