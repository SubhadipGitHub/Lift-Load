// Star study for PRD v1.8 (C. Combo and stars): with full knowledge, how many
// stars can each level give, and do the proposed thresholds keep 3 stars
// reachable? `dart run tool/star_study.dart [from] [to] [beam]`.
//
// Three players:
//   best    a best-play search that sees every hidden weight. Per lift it
//           enumerates exact fills (boarding fronts and bench seats, digging
//           up to three blockers to the bench); across lifts it keeps a beam
//           of the best partial runs. Every candidate is replayed through
//           LiftGame, so lift kinds, express floors, coned lanes, late
//           arrivals and jams are the rules the player meets. It is a strong
//           lower bound on what is reachable, not a proof of the optimum.
//   greedy  the shipped Solver strategy (heaviest that fits, shallowest dig).
//   blind   the blind bot of tool/blind_study.dart (aims only at people it
//           can see): the nearest stand-in for a practised human.
//
// It scores the PRD's proposed rule (3 stars: every send green or better and
// >= ceil(sends/3) perfects), stricter and looser variants, and a per-level
// perfect target taken from best play. Findings: docs/star-study.md.
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';
import 'package:lift_load/game/level.dart';

import 'blind_study.dart' as blind;

// ── Actions, replayed through the engine ──

/// One tap sequence: board a lane front, board a bench seat, bench a lane
/// front into a seat, or send.
class Act {
  const Act.boardLane(this.a)
      : kind = 0,
        b = 0;
  const Act.boardSeat(this.a)
      : kind = 1,
        b = 0;
  const Act.bench(this.a, this.b) : kind = 2;
  const Act.send()
      : kind = 3,
        a = 0,
        b = 0;
  final int kind, a, b;
}

/// Applies [acts] to [g]; false if any step did not do what it meant to.
bool apply(LiftGame g, Iterable<Act> acts) {
  for (final act in acts) {
    if (g.phase != Phase.playing) return false;
    switch (act.kind) {
      case 0:
        g.tapQueue(act.a);
        if (g.tapLift() != BoardResult.boarded) return false;
      case 1:
        g.tapBench(act.a);
        if (g.tapLift() != BoardResult.boarded) return false;
      case 2:
        g.tapQueue(act.a);
        if (g.tapBench(act.b) != BenchResult.seated) return false;
      default:
        if (g.send() == null) return false;
        g.finishSend();
    }
  }
  return true;
}

LiftGame replay(Level level, List<Act> acts) {
  final g = LiftGame(level, recordEvents: false);
  apply(g, acts);
  return g;
}

// ── One lift: enumerate fills ──

class TripPlan {
  TripPlan(this.acts, this.load, this.digs);
  final List<Act> acts;
  final int load, digs;
}

int tier(int load, int capacity) {
  final f = load / capacity;
  return f >= Formulas.perfectFraction ? 2 : (f >= Formulas.greenFraction ? 1 : 0);
}

/// Distinct fills for the lift waiting now (riders empty), best first.
int planWidth = 10, planBudget = 4000;

List<TripPlan> planTrip(LiftGame g, {int maxDigs = 3}) {
  final maxPlans = planWidth, nodeBudget = planBudget;
  final lanes = [for (var i = 0; i < g.laneCount; i++) g.isLaneLocked(i) ? <Resident>[] : g.queues[i]];
  final cap = g.capacity;
  final offsets = List<int>.filled(lanes.length, 0);
  final bench = List<Resident?>.of(g.bench);
  final acts = <Act>[];
  final seen = <String>{};
  final found = <String, TripPlan>{};
  var nodes = 0;

  bool wantedBehind(int lane) {
    final q = lanes[lane];
    for (var d = offsets[lane] + 1; d < q.length; d++) {
      if (g.goesTo(q[d].floor)) return true;
    }
    return false;
  }

  void dfs(int load, int digs) {
    if (nodes++ > nodeBudget) return;
    final key = '${offsets.join(',')}|${[for (final r in bench) r?.id ?? -1].join(',')}';
    if (!seen.add(key)) return;
    if (load > 0) found[key] = TripPlan([...acts, const Act.send()], load, digs);
    for (var s = 0; s < bench.length; s++) {
      final r = bench[s];
      if (r == null || !g.goesTo(r.floor) || load + r.kg > cap) continue;
      bench[s] = null;
      acts.add(Act.boardSeat(s));
      dfs(load + r.kg, digs);
      acts.removeLast();
      bench[s] = r;
    }
    for (var i = 0; i < lanes.length; i++) {
      if (offsets[i] >= lanes[i].length) continue;
      final r = lanes[i][offsets[i]];
      if (g.goesTo(r.floor)) {
        if (load + r.kg > cap) continue;
        offsets[i]++;
        acts.add(Act.boardLane(i));
        dfs(load + r.kg, digs);
        acts.removeLast();
        offsets[i]--;
      } else if (digs < maxDigs && wantedBehind(i)) {
        final seat = bench.indexOf(null);
        if (seat < 0) continue;
        bench[seat] = r;
        offsets[i]++;
        acts.add(Act.bench(i, seat));
        dfs(load, digs + 1);
        acts.removeLast();
        offsets[i]--;
        bench[seat] = null;
      }
    }
  }

  dfs(0, 0);
  // Weight this lift's floors still hold; a fill that leaves an unsplittable
  // remainder forces a grey send later, so it ranks after one that does not.
  var floorLeft = 0;
  for (final q in g.queues) {
    for (final r in q) {
      if (g.goesTo(r.floor)) floorLeft += r.kg;
    }
  }
  for (final r in g.bench) {
    if (r != null && g.goesTo(r.floor)) floorLeft += r.kg;
  }
  for (final a in g.pendingArrivals) {
    if (g.goesTo(a.resident.floor)) floorLeft += a.resident.kg;
  }
  int doom(TripPlan p) {
    final w = floorLeft - p.load;
    return (w + cap - 1) ~/ cap > (w / (Formulas.greenFraction * cap)).floor() ? 1 : 0;
  }

  final plans = found.values.toList()
    ..sort((x, y) {
      final o = doom(x) - doom(y);
      if (o != 0) return o;
      final t = tier(y.load, cap) - tier(x.load, cap);
      if (t != 0) return t;
      final d = x.digs - y.digs;
      if (d != 0) return d;
      return y.load - x.load;
    });
  return plans.take(maxPlans).toList();
}

/// The greedy solver's fill for the lift waiting now, as acts: board the
/// heaviest that fits, else dig the shallowest fitting match, else send.
TripPlan? greedyTrip(Level level, List<Act> prefix) {
  final g = replay(level, prefix);
  final acts = <Act>[];
  var digs = 0;
  for (var steps = 0; g.phase == Phase.playing && steps < 400; steps++) {
    final fits = <(int, Act)>[];
    for (var s = 0; s < g.benchLength; s++) {
      final r = g.benchAt(s);
      if (r != null && g.goesTo(r.floor) && g.load + r.kg <= g.capacity) fits.add((r.kg, Act.boardSeat(s)));
    }
    for (var i = 0; i < g.laneCount; i++) {
      if (g.laneLength(i) == 0 || g.isLaneLocked(i)) continue;
      final r = g.laneAt(i, 0);
      if (g.goesTo(r.floor) && g.load + r.kg <= g.capacity) fits.add((r.kg, Act.boardLane(i)));
    }
    Act? act;
    if (fits.isNotEmpty) {
      fits.sort((x, y) => y.$1 - x.$1);
      act = fits.first.$2;
    } else if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) {
      act = const Act.send();
    } else {
      final seat = g.bench.indexOf(null);
      final lane = seat < 0 ? null : digLaneFor(g);
      if (lane != null) {
        act = Act.bench(lane, seat);
        digs++;
      } else if (g.riders.isNotEmpty) {
        act = const Act.send();
      }
    }
    if (act == null || !apply(g, [act])) return null;
    acts.add(act);
    if (act.kind == 3) return TripPlan(acts, -1, digs); // load filled in by the caller
  }
  return null;
}

// ── Across lifts: beam search ──

/// Floors whose weight still to deliver (lanes, bench, late arrivals, riders)
/// cannot be split into trips that are all green: no k with
/// green * k * capacity <= weight <= k * capacity. Each one forces a grey send
/// in World 1, where every lift has one capacity and serves one floor.
int doomedFloors(LiftGame g) {
  final left = <Floor, int>{};
  void add(Resident r) => left[r.floor] = (left[r.floor] ?? 0) + r.kg;
  for (final q in g.queues) {
    q.forEach(add);
  }
  for (final r in g.bench) {
    if (r != null) add(r);
  }
  for (final a in g.pendingArrivals) {
    add(a.resident);
  }
  g.riders.forEach(add);
  final cap = g.capacity;
  return left.values.where((w) => (w + cap - 1) ~/ cap > (w / (Formulas.greenFraction * cap)).floor()).length;
}

class Node {
  Node(this.acts, this.greys, this.perfects, this.remaining, this.benchUsed, this.sig, [this.doomed = 0]);
  final List<Act> acts;
  final int greys, perfects, remaining, benchUsed, doomed;
  final String sig;
}

class Finish {
  Finish(this.sends, this.perfects, this.greys, this.spare);
  final int sends, perfects, greys, spare;
}

String sigOf(LiftGame g) => '${[for (final q in g.queues) q.map((r) => r.id).join('.')].join('|')}#'
    '${[for (final r in g.bench) r?.id ?? -1].join('.')}#${g.liftFloors.join('.')}';

/// Every finish the beam reaches, under [order] (smaller is better).
List<Finish> beam(Level level, int width, int Function(Node a, Node b) order) {
  var frontier = [Node(const [], 0, 0, 1 << 30, 0, '')];
  final finishes = <Finish>[];
  for (var depth = 0; depth < level.trips && frontier.isNotEmpty; depth++) {
    final next = <String, Node>{};
    for (final node in frontier) {
      final g = replay(level, node.acts);
      if (g.phase != Phase.playing) continue;
      final greedy = greedyTrip(level, node.acts);
      for (final plan in [...planTrip(g), if (greedy != null) greedy]) {
        final c = replay(level, node.acts);
        // The load at the moment of sending decides the rating.
        if (!apply(c, plan.acts.sublist(0, plan.acts.length - 1))) continue;
        final t = tier(c.load, c.capacity);
        if (!apply(c, [const Act.send()])) continue;
        final grey = t == 0 ? 1 : 0;
        final perfect = t == 2 ? 1 : 0;
        if (c.phase == Phase.won) {
          finishes.add(Finish(c.tripsUsed, node.perfects + perfect, node.greys + grey, c.tripsLeft));
          continue;
        }
        if (c.phase != Phase.playing) continue;
        final child = Node([...node.acts, ...plan.acts], node.greys + grey, node.perfects + perfect, c.remainingTotal,
            c.benchUsed, sigOf(c), doomedFloors(c));
        final have = next[child.sig];
        if (have == null || order(child, have) < 0) next[child.sig] = child;
      }
    }
    frontier = next.values.toList()..sort(order);
    if (frontier.length > width) frontier = frontier.sublist(0, width);
  }
  return finishes;
}

/// Toward 3 stars: fewest grey sends made or forced, then most perfects, then least left.
int forThree(Node a, Node b) {
  if (a.greys + a.doomed != b.greys + b.doomed) return a.greys + a.doomed - b.greys - b.doomed;
  if (a.perfects != b.perfects) return b.perfects - a.perfects;
  if (a.remaining != b.remaining) return a.remaining - b.remaining;
  return a.benchUsed - b.benchUsed;
}

/// Toward a spare trip: least left, then fewest greys, then most perfects.
int forSpeed(Node a, Node b) {
  if (a.remaining != b.remaining) return a.remaining - b.remaining;
  if (a.greys != b.greys) return a.greys - b.greys;
  if (a.perfects != b.perfects) return b.perfects - a.perfects;
  return a.benchUsed - b.benchUsed;
}

// ── Exhaustive check: can every send be green? ──

enum Proof { yes, no, unknown }

/// Depth-first over every single tap (board any fitting front or seat, bench
/// any front, send only at green or better), memoised on the whole engine
/// state. Returns the most perfects found on an all-green win, or reports
/// [Proof.no] when the space is exhausted without one.
({Proof proof, int perfects}) allGreen(Level level, {int stateBudget = 200000}) {
  final seen = <String>{};
  var best = -1;
  var exhausted = true;
  final worldOne = level.number < 61; // World 2 lift kinds (scenario.dart) change capacity per lift

  void dfs(List<Act> acts) {
    if (seen.length > stateBudget) {
      exhausted = false;
      return;
    }
    final g = replay(level, acts);
    if (g.phase == Phase.won) {
      if (g.perfects > best) best = g.perfects;
      return;
    }
    if (g.phase != Phase.playing) return;
    if (worldOne && doomedFloors(g) > 0) return;
    if (!seen.add('${sigOf(g)}#${g.load}#${g.tripsUsed}#${g.perfects}')) return;
    final moves = <Act>[];
    for (var s = 0; s < g.benchLength; s++) {
      final r = g.benchAt(s);
      if (r != null && g.goesTo(r.floor) && g.load + r.kg <= g.capacity) moves.add(Act.boardSeat(s));
    }
    final seat = g.bench.indexOf(null);
    for (var i = 0; i < g.laneCount; i++) {
      if (g.laneLength(i) == 0 || g.isLaneLocked(i)) continue;
      final r = g.laneAt(i, 0);
      if (g.goesTo(r.floor) && g.load + r.kg <= g.capacity) moves.add(Act.boardLane(i));
      if (seat >= 0) moves.add(Act.bench(i, seat));
    }
    if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) moves.add(const Act.send());
    for (final m in moves) {
      dfs([...acts, m]);
    }
  }

  dfs(const []);
  if (best >= 0) return (proof: Proof.yes, perfects: best);
  return (proof: exhausted ? Proof.no : Proof.unknown, perfects: -1);
}

// ── Greedy and blind, with ratings ──

Finish? playBot(Level level, {required bool sees}) {
  final g = LiftGame(level, recordEvents: false);
  var greys = 0;
  void send() {
    if (g.load < Formulas.greenFraction * g.capacity) greys++;
    g.send();
    g.finishSend();
  }

  var steps = 0;
  while (g.phase == Phase.playing && steps++ < 20000) {
    if (blind.boardBest(g)) continue;
    if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) {
      send();
      continue;
    }
    if (sees ? fullDig(g) : blind.dig(g, false)) continue;
    if (g.riders.isEmpty) break;
    send();
  }
  if (g.phase != Phase.won) return null;
  return Finish(g.tripsUsed, g.perfects, greys, g.tripsLeft);
}

/// The Solver's dig: bench the front of the lane whose nearest fitting match is shallowest.
bool fullDig(LiftGame g) {
  final seat = g.bench.indexOf(null);
  if (seat < 0) return false;
  final lane = digLaneFor(g);
  if (lane == null) return false;
  g.tapQueue(lane);
  g.tapBench(seat);
  return true;
}

int? digLaneFor(LiftGame g) {
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
  return digLane;
}

// ── Report ──

/// A candidate 3-star rule, judged on a won run.
typedef Rule = ({String name, bool Function(Finish f) three});

int ceilDiv(int a, int b) => (a + b - 1) ~/ b;

final rules = <Rule>[
  (name: 'spec: no grey, perf >= s/3', three: (f) => f.greys == 0 && f.perfects >= ceilDiv(f.sends, 3)),
  (name: 'no grey, perf >= 1', three: (f) => f.greys == 0 && f.perfects >= 1),
  (name: 'grey <= s/4, perf >= s/3', three: (f) => f.greys <= f.sends ~/ 4 && f.perfects >= ceilDiv(f.sends, 3)),
  (name: 'grey <= s/4, perf >= s/4', three: (f) => f.greys <= f.sends ~/ 4 && f.perfects >= ceilDiv(f.sends, 4)),
  (name: 'grey <= s/3, perf >= s/4', three: (f) => f.greys <= f.sends ~/ 3 && f.perfects >= ceilDiv(f.sends, 4)),
  (name: 'grey <= s/3, perf >= s/5', three: (f) => f.greys <= f.sends ~/ 3 && f.perfects >= ceilDiv(f.sends, 5)),
];

void main(List<String> args) {
  if (args.isNotEmpty && args.first == 'prove') return prove(args.skip(1).map(int.parse).toList());
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : Formulas.lastLevel;
  final width = args.length > 2 ? int.parse(args[2]) : 40;
  if (args.length > 3) planWidth = int.parse(args[3]);
  if (args.length > 4) planBudget = int.parse(args[4]);

  String run(Finish? f) => f == null
      ? '     lost      '
      : '${'${f.sends}'.padLeft(4)}${'${f.greys}'.padLeft(4)}${'${f.perfects}'.padLeft(4)}${'${f.spare}'.padLeft(3)}';

  print('Star study, levels $from-$to (beam $width). Runs show sends, grey sends, perfects, spare trips.');
  print('"forced" counts floors whose weight cannot split into all-green trips at the start (World 1 exact).');
  print('');
  print('  L forced   best(fewest grey)   greedy           blind      best perfects');
  final passBest = {for (final r in rules) r.name: 0};
  final passGreedy = {for (final r in rules) r.name: 0};
  final passBlind = {for (final r in rules) r.name: 0};
  var levels = 0, bestWins = 0, greedyWins = 0, blindWins = 0, forcedLevels = 0;
  var greySum = 0.0, perfSum = 0.0, bGreySum = 0.0, bPerfSum = 0.0;
  final targets = <({String name, int Function(int best) target})>[
    (name: 'all of best', target: (b) => b < 1 ? 1 : b),
    (name: '3/4 of best', target: (b) => (b * 3 ~/ 4).clamp(1, 1 << 20)),
    (name: '2/3 of best', target: (b) => (b * 2 ~/ 3).clamp(1, 1 << 20)),
    (name: '1/2 of best', target: (b) => (b ~/ 2).clamp(1, 1 << 20)),
  ];
  final tBest = {for (final t in targets) t.name: 0},
      tGreedy = {...tBest},
      tBlind = {...tBest},
      tBlind2 = {...tBest},
      tBlind2p = {...tBest};
  final sw = Stopwatch()..start();
  for (var n = from; n <= to; n++) {
    final level = LevelGenerator.generate(n);
    final forced = doomedFloors(LiftGame(level, recordEvents: false));
    final finishes = [...beam(level, width, forThree), ...beam(level, width, forSpeed)];
    final greedy = playBot(level, sees: true);
    final blindRun = playBot(level, sees: false);
    if (greedy != null) finishes.add(greedy); // best play is never worse than greedy
    levels++;
    final bestPerf = finishes.fold(0, (m, f) => f.perfects > m ? f.perfects : m);
    for (final t in targets) {
      final p = t.target(bestPerf);
      if (finishes.any((f) => f.perfects >= p)) tBest[t.name] = tBest[t.name]! + 1;
      if (greedy != null && greedy.perfects >= p) tGreedy[t.name] = tGreedy[t.name]! + 1;
      if (blindRun != null && blindRun.perfects >= p) tBlind[t.name] = tBlind[t.name]! + 1;
      if (blindRun != null && (blindRun.spare >= 1 || blindRun.perfects >= (p + 1) ~/ 2)) {
        tBlind2[t.name] = tBlind2[t.name]! + 1;
      }
      if (blindRun != null && blindRun.perfects >= (p + 1) ~/ 2) tBlind2p[t.name] = tBlind2p[t.name]! + 1;
    }
    if (forced > 0) forcedLevels++;
    if (finishes.isNotEmpty) bestWins++;
    if (greedy != null) greedyWins++;
    if (blindRun != null) blindWins++;
    for (final r in rules) {
      if (finishes.any(r.three)) passBest[r.name] = passBest[r.name]! + 1;
      if (greedy != null && r.three(greedy)) passGreedy[r.name] = passGreedy[r.name]! + 1;
      if (blindRun != null && r.three(blindRun)) passBlind[r.name] = passBlind[r.name]! + 1;
    }
    Finish? shown;
    for (final f in finishes) {
      if (shown == null || f.greys < shown.greys || (f.greys == shown.greys && f.perfects > shown.perfects)) shown = f;
    }
    if (shown != null) {
      greySum += shown.greys / shown.sends;
      perfSum += shown.perfects / shown.sends;
    }
    if (blindRun != null) {
      bGreySum += blindRun.greys / blindRun.sends;
      bPerfSum += blindRun.perfects / blindRun.sends;
    }
    print('${'$n'.padLeft(3)}${'$forced'.padLeft(5)}      ${run(shown)}      ${run(greedy)}  ${run(blindRun)}'
        '${'$bestPerf'.padLeft(8)}');
  }

  String pct(int k) => '${(k * 100 / levels).round()}%'.padLeft(5);
  print('');
  print('Won: best $bestWins, greedy $greedyWins, blind $blindWins of $levels. '
      'Levels with a forced grey at the start: $forcedLevels.');
  print('Mean share of sends, best (fewest grey): grey ${(greySum / bestWins * 100).round()}%, '
      'perfect ${(perfSum / bestWins * 100).round()}%. Blind: grey ${(bGreySum / blindWins * 100).round()}%, '
      'perfect ${(bPerfSum / blindWins * 100).round()}%.');
  print('');
  print('Levels where each player earns 3 stars, by candidate rule (best is a lower bound):');
  print('  ${'rule'.padRight(28)}  best  greedy  blind');
  for (final r in rules) {
    print('  ${r.name.padRight(28)}${pct(passBest[r.name]!)}${pct(passGreedy[r.name]!).padLeft(8)}'
        '${pct(passBlind[r.name]!).padLeft(7)}');
  }
  print('');
  print('Per-level perfect target P from best play (3 stars: win with >= P perfects; 2 stars: a spare trip or');
  print('>= ceil(P/2) perfects). Share of all levels:');
  print('  ${'target P'.padRight(14)}  best 3*  greedy 3*  blind 3*  blind 2*+  (2* by perfects only)');
  for (final t in targets) {
    print('  ${t.name.padRight(14)}${pct(tBest[t.name]!).padLeft(9)}${pct(tGreedy[t.name]!).padLeft(11)}'
        '${pct(tBlind[t.name]!).padLeft(10)}${pct(tBlind2[t.name]!).padLeft(11)}${pct(tBlind2p[t.name]!).padLeft(12)}');
  }
  print('(${(sw.elapsedMilliseconds / 1000).toStringAsFixed(0)} s)');
}

/// `dart run tool/star_study.dart prove [from] [to] [states]`: the exhaustive
/// all-green check per level (slow; World 1 prunes with [doomedFloors]).
void prove(List<int> a) {
  final from = a.isNotEmpty ? a[0] : 1, to = a.length > 1 ? a[1] : 10, budget = a.length > 2 ? a[2] : 300000;
  for (var n = from; n <= to; n++) {
    final r = allGreen(LevelGenerator.generate(n), stateBudget: budget);
    final what = switch (r.proof) {
      Proof.yes => 'all green possible (most perfects found ${r.perfects})',
      Proof.no => 'all green impossible (search exhausted)',
      Proof.unknown => 'undecided within $budget states',
    };
    print('${'$n'.padLeft(3)}  $what');
  }
}
