// Solver study for PRD v1.6: how much do unknown people and powers move the
// clear rate? `dart run tool/blind_study.dart [from] [to]`.
//
// Three bots play every level with the level's real trip budget:
//   full   the shipped greedy solver (sees everyone; its trips are par)
//   blind  same strategy, but digs only toward people it can see, and when it
//          sees no target it benches the front of a lane with unknown people
//          behind it to see who they are
//   power  blind, plus one +1 trip when it is on its last trip with people
//          left, and one +2 seats when the bench is full and it needs a dig
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/game/solver.dart';

class Outcome {
  Outcome(this.cleared, this.trips);
  final bool cleared;
  final int trips;
}

Outcome play(Level level, {required bool usePowers}) {
  final g = LiftGame(level, recordEvents: false);
  var steps = 0;
  while (g.phase == Phase.playing && steps++ < 20000) {
    if (boardBest(g)) continue;
    if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) {
      send(g, usePowers);
      continue;
    }
    if (dig(g, usePowers)) continue;
    if (g.riders.isEmpty) break;
    send(g, usePowers);
  }
  return Outcome(g.phase == Phase.won, g.tripsUsed);
}

void send(LiftGame g, bool usePowers) {
  if (usePowers && g.tripsLeft == 1 && g.remainingTotal > g.riders.length) g.addTrip();
  g.send();
  g.finishSend();
}

bool boardBest(LiftGame g) {
  var bestKg = -1;
  int? bestSeat;
  int? bestLane;
  for (var i = 0; i < g.benchLength; i++) {
    final r = g.benchAt(i);
    if (r != null && g.goesTo(r.floor) && g.load + r.kg <= g.capacity && r.kg > bestKg) {
      bestKg = r.kg;
      bestSeat = i;
      bestLane = null;
    }
  }
  for (var i = 0; i < g.laneCount; i++) {
    if (g.laneLength(i) == 0 || g.isLaneLocked(i)) continue;
    final r = g.laneAt(i, 0);
    if (g.goesTo(r.floor) && g.load + r.kg <= g.capacity && r.kg > bestKg) {
      bestKg = r.kg;
      bestLane = i;
      bestSeat = null;
    }
  }
  if (bestSeat != null) {
    g.tapBench(bestSeat);
  } else if (bestLane != null) {
    g.tapQueue(bestLane);
  } else {
    return false;
  }
  g.tapLift();
  return true;
}

bool dig(LiftGame g, bool usePowers) {
  var seat = -1;
  for (var i = 0; i < g.benchLength && seat < 0; i++) {
    if (g.benchAt(i) == null) seat = i;
  }
  if (seat < 0) {
    if (usePowers && g.canUsePower(Power.seats) && wantsDig(g)) {
      g.addSeats();
      return dig(g, false);
    }
    return false;
  }
  final lanes = g.visibleLanes;
  int? digLane;
  var digDepth = 1 << 30;
  for (var i = 0; i < g.laneCount; i++) {
    final n = g.laneLength(i);
    if (n == 0 || g.isLaneLocked(i) || g.goesTo(g.laneAt(i, 0).floor)) continue;
    for (var d = 0; d < n && d < digDepth; d++) {
      final r = lanes[i][d]; // null = unknown: the bot cannot aim at it
      if (r != null && g.goesTo(r.floor) && g.load + r.kg <= g.capacity) {
        digDepth = d;
        digLane = i;
        break;
      }
    }
  }
  if (digLane == null && g.riders.isEmpty) {
    // Nothing visible to aim at: explore the lane with the most unknowns.
    var most = 0;
    for (var i = 0; i < g.laneCount; i++) {
      if (g.laneLength(i) == 0 || g.isLaneLocked(i)) continue;
      final unknown = lanes[i].where((r) => r == null).length;
      if (unknown > most) {
        most = unknown;
        digLane = i;
      }
    }
  }
  if (digLane == null) return false;
  g.tapQueue(digLane);
  g.tapBench(seat);
  return true;
}

bool wantsDig(LiftGame g) {
  for (var i = 0; i < g.laneCount; i++) {
    if (g.laneLength(i) > 0 && !g.isLaneLocked(i) && !g.goesTo(g.laneAt(i, 0).floor)) return true;
  }
  return false;
}

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 11;
  final to = args.length > 1 ? int.parse(args[1]) : 100;
  print('  L  unk%  lanes  budget  par  blind(clear,trips)  power(clear,trips)');
  var rows = 0, blindOk = 0, powerOk = 0, fullOk = 0;
  final bucket = <int, List<int>>{};
  for (var n = from; n <= to; n++) {
    final level = LevelGenerator.generate(n);
    final full = Solver.solve(level);
    final blind = play(level, usePowers: false);
    final power = play(level, usePowers: true);
    rows++;
    if (full.cleared) fullOk++;
    if (blind.cleared) blindOk++;
    if (power.cleared) powerOk++;
    final b = bucket.putIfAbsent((n ~/ 10) * 10, () => [0, 0, 0, 0]);
    b[0]++;
    if (full.cleared) b[1]++;
    if (blind.cleared) b[2]++;
    if (power.cleared) b[3]++;
    if (!blind.cleared || !power.cleared || n % 10 == 1) {
      print('${'$n'.padLeft(3)}  ${(level.unknownIds.length * 100 / level.residentCount).round().toString().padLeft(3)}%'
          '${'${level.laneCount}'.padLeft(6)}${'${level.trips}'.padLeft(8)}${'${level.parTrips}'.padLeft(6)}'
          '${'${blind.cleared ? 'win' : 'FAIL'} ${blind.trips}'.padLeft(16)}'
          '${'${power.cleared ? 'win' : 'FAIL'} ${power.trips}'.padLeft(20)}');
    }
  }
  print('\ndecade   levels  full  blind  power');
  for (final e in bucket.entries) {
    print('${'${e.key}s'.padRight(8)}${'${e.value[0]}'.padLeft(6)}${'${e.value[1]}'.padLeft(7)}${'${e.value[2]}'.padLeft(7)}${'${e.value[3]}'.padLeft(7)}');
  }
  print('total   ${'$rows'.padLeft(6)}${'$fullOk'.padLeft(7)}${'$blindOk'.padLeft(7)}${'$powerOk'.padLeft(7)}');
}
