/// A greedy "skilled player" bot with perfect knowledge of hidden weights.
///
/// It is a lower bound on solvability, not an optimum: if the bot clears a
/// level, a human can. Its trip count is the level's par, and the trip
/// budget is par + slack (see [Formulas.trips]).
///
/// The bot plays through [LiftGame] itself, so every rule the player meets
/// (lift kinds, express floors, coned-off lanes, late arrivals, jams) is the
/// rule the bot meets.
///
/// Strategy per lift:
///   1. Board the heaviest reachable resident for this lift that fits.
///   2. When nobody fits and the load is below green, bench the front of the
///      lane whose nearest matching (and fitting) resident is shallowest.
///   3. Otherwise send. An empty lift with nothing reachable is a jam.
library;

import 'engine.dart';
import 'formulas.dart';
import 'level.dart';

class SolveResult {
  const SolveResult({required this.cleared, required this.trips, required this.maxBenchUsed});

  final bool cleared;
  final int trips;
  final int maxBenchUsed;

  @override
  String toString() => 'SolveResult(cleared: $cleared, trips: $trips, bench: $maxBenchUsed)';
}

abstract final class Solver {
  static SolveResult solve(Level level, {int stepLimit = 20000}) {
    final g = LiftGame(level, recordEvents: false);
    var maxBench = 0;
    var steps = 0;
    while (g.phase == Phase.playing && steps++ < stepLimit) {
      if (_boardBest(g)) continue;
      if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) {
        _send(g);
        continue;
      }
      if (_dig(g)) {
        if (g.benchUsed > maxBench) maxBench = g.benchUsed;
        continue;
      }
      if (g.riders.isEmpty) break;
      _send(g);
    }
    return SolveResult(cleared: g.phase == Phase.won, trips: g.tripsUsed, maxBenchUsed: maxBench);
  }

  static void _send(LiftGame g) {
    g.send();
    g.finishSend();
  }

  /// 1. Heaviest selectable resident for this lift that fits.
  static bool _boardBest(LiftGame g) {
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

  /// 2. Bench a blocker to expose a fitting match.
  static bool _dig(LiftGame g) {
    var seat = -1;
    for (var i = 0; i < g.benchLength && seat < 0; i++) {
      if (g.benchAt(i) == null) seat = i;
    }
    if (seat < 0) return false;
    int? digLane;
    var digDepth = 1 << 30;
    for (var i = 0; i < g.laneCount; i++) {
      final n = g.laneLength(i);
      if (n == 0 || g.isLaneLocked(i) || g.goesTo(g.laneAt(i, 0).floor)) continue;
      for (var d = 0; d < n && d < digDepth; d++) {
        final r = g.laneAt(i, d);
        if (g.goesTo(r.floor) && g.load + r.kg <= g.capacity) {
          digDepth = d;
          digLane = i;
          break;
        }
      }
    }
    if (digLane == null) return false;
    g.tapQueue(digLane);
    g.tapBench(seat);
    return true;
  }
}
