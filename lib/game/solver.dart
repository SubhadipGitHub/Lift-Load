/// A greedy "skilled player" bot with perfect knowledge of hidden weights.
///
/// It is a lower bound on solvability, not an optimum: if the bot clears a
/// level, a human can. Its trip count is the level's par, and the trip
/// budget is par + slack (see [Formulas.trips]).
///
/// Strategy per lift:
///   1. Board the heaviest reachable resident for this floor that fits.
///   2. When nobody fits and the load is below green, bench the front of the
///      lane whose nearest matching (and fitting) resident is shallowest.
///   3. Otherwise send. An empty lift with nothing reachable is a jam.
library;

import 'cast.dart';
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
    final queues = [for (final q in level.queues) List.of(q)];
    final bench = <Resident>[];
    final cap = level.capacity;
    final greenKg = Formulas.greenFraction * cap;
    final order = level.floors;

    int remaining(Floor f) =>
        queues.fold(0, (a, q) => a + q.where((r) => r.floor == f).length) +
        bench.where((r) => r.floor == f).length;

    Floor? next(Floor? after) {
      final start = after == null ? -1 : order.indexOf(after);
      for (var step = 1; step <= order.length; step++) {
        final f = order[(start + step) % order.length];
        if (remaining(f) > 0) return f;
      }
      return null;
    }

    var floor = remaining(order.first) > 0 ? order.first : next(order.first);
    var trips = 0;
    var maxBench = 0;
    var steps = 0;

    while (floor != null) {
      var load = 0;
      while (steps++ < stepLimit) {
        // 1. Heaviest reachable match that fits.
        Resident? best;
        int? bestBench;
        int? bestLane;
        for (var i = 0; i < bench.length; i++) {
          final r = bench[i];
          if (r.floor == floor && load + r.kg <= cap && (best == null || r.kg > best.kg)) {
            best = r;
            bestBench = i;
            bestLane = null;
          }
        }
        for (var i = 0; i < queues.length; i++) {
          if (queues[i].isEmpty) continue;
          final r = queues[i].first;
          if (r.floor == floor && load + r.kg <= cap && (best == null || r.kg > best.kg)) {
            best = r;
            bestLane = i;
            bestBench = null;
          }
        }
        if (best != null) {
          if (bestBench != null) {
            bench.removeAt(bestBench);
          } else {
            queues[bestLane!].removeAt(0);
          }
          load += best.kg;
          continue;
        }
        if (load >= greenKg) break;

        // 2. Dig: bench a blocker to expose a fitting match.
        if (bench.length < level.benchSize) {
          int? digLane;
          var digDepth = 1 << 30;
          for (var i = 0; i < queues.length; i++) {
            final q = queues[i];
            if (q.isEmpty || q.first.floor == floor) continue;
            for (var d = 0; d < q.length; d++) {
              if (q[d].floor == floor && load + q[d].kg <= cap) {
                if (d < digDepth) {
                  digDepth = d;
                  digLane = i;
                }
                break;
              }
            }
          }
          if (digLane != null) {
            bench.add(queues[digLane].removeAt(0));
            if (bench.length > maxBench) maxBench = bench.length;
            continue;
          }
        }
        break;
      }
      if (load == 0) return SolveResult(cleared: false, trips: trips, maxBenchUsed: maxBench);
      trips++;
      floor = next(floor);
    }
    return SolveResult(cleared: true, trips: trips, maxBenchUsed: maxBench);
  }
}
