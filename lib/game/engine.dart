/// The rules of Lift Load as a pure-Dart state machine.
///
/// The UI calls the tap methods, reads the public getters and drains
/// [LiftGame.drainEvents] after every call to drive sound, haptics, toasts
/// and analytics. Animations are owned by the UI: when a send or a crash
/// animation completes, the UI calls [LiftGame.finishSend] or
/// [LiftGame.finishCrash].
library;

import 'cast.dart';
import 'formulas.dart';
import 'level.dart';

enum Phase { playing, departing, falling, won, failed }

enum FailKind { crash, outOfTrips, jam }

enum TripRating { halfEmpty, good, perfect }

enum LoadZone { empty, light, green, limit, overload }

enum BoardResult { notPlaying, noSelection, wrongFloor, boarded, overloaded }

enum BenchResult { ignored, selected, deselected, seated, needSelection }

/// Where the selected resident stands: front of a queue, or a bench seat.
class Selection {
  const Selection.queue(this.index) : fromBench = false;
  const Selection.bench(this.index) : fromBench = true;

  final bool fromBench;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is Selection && other.fromBench == fromBench && other.index == index;

  @override
  int get hashCode => Object.hash(fromBench, index);
}

// ── Events ────────────────────────────────────────────────────────────────

sealed class GameEvent {
  const GameEvent();
}

class SelectedEvent extends GameEvent {
  const SelectedEvent(this.resident);
  final Resident resident;
}

class SeatedEvent extends GameEvent {
  const SeatedEvent(this.resident, this.seat);
  final Resident resident;
  final int seat;
}

class RefusedEvent extends GameEvent {
  const RefusedEvent(this.resident, this.liftFloor);
  final Resident resident;
  final Floor liftFloor;
}

class BoardedEvent extends GameEvent {
  const BoardedEvent(this.resident, this.zone);
  final Resident resident;
  final LoadZone zone;
}

class OverloadEvent extends GameEvent {
  const OverloadEvent(this.resident);
  final Resident resident;
}

class SentEvent extends GameEvent {
  const SentEvent(this.floor, this.rating, this.coins, this.riders);
  final Floor floor;
  final TripRating rating;
  final int coins;
  final int riders;
}

class LiftArrivedEvent extends GameEvent {
  const LiftArrivedEvent(this.floor);
  final Floor floor;
}

class ScalePreviewEvent extends GameEvent {
  const ScalePreviewEvent(this.resident);
  final Resident resident;
}

class WonEvent extends GameEvent {
  const WonEvent(this.coins, this.tripsUsed, this.perfects);
  final int coins;
  final int tripsUsed;
  final int perfects;
}

class FailedEvent extends GameEvent {
  const FailedEvent(this.kind);
  final FailKind kind;
}

class ContinuedEvent extends GameEvent {
  const ContinuedEvent(this.kind);
  final FailKind kind;
}

// ── State machine ─────────────────────────────────────────────────────────

class _Snapshot {
  _Snapshot(LiftGame g)
      : queues = [for (final q in g._queues) List.of(q)],
        bench = List.of(g._bench),
        riders = List.of(g._riders),
        load = g.load;

  final List<List<Resident>> queues;
  final List<Resident?> bench;
  final List<Resident> riders;
  final int load;
}

class LiftGame {
  LiftGame(this.level)
      : _queues = [for (final q in level.queues) List.of(q)],
        _bench = List<Resident?>.filled(level.benchSize, null, growable: true),
        tripsTotal = level.trips,
        liftFloor = level.floors.first {
    if (remainingFor(liftFloor) == 0) {
      final first = _nextFloor(liftFloor);
      if (first == null) throw ArgumentError('Level has no residents');
      liftFloor = first;
    }
  }

  final Level level;
  final List<List<Resident>> _queues;
  final List<Resident?> _bench;
  final List<Resident> _riders = [];
  final List<GameEvent> _events = [];

  Floor liftFloor;
  int load = 0;
  int tripsUsed = 0;
  int tripsTotal;
  Selection? selection;

  /// Load the Scale booster previews (load + selected kg), or null.
  int? ghostLoad;

  Phase phase = Phase.playing;
  FailKind? failKind;

  /// Trip coins banked so far (excludes the level's base coins).
  int tripCoins = 0;
  int perfects = 0;
  int goodTrips = 0;
  bool adContinueUsed = false;

  TripRating? _pendingRating;
  int _pendingCoins = 0;
  Floor? _pendingNext;
  _Snapshot? _beforeCrash;

  // ── Read-only views ──
  List<List<Resident>> get queues => List.unmodifiable(_queues.map(List<Resident>.unmodifiable));
  List<Resident?> get bench => List.unmodifiable(_bench);
  List<Resident> get riders => List.unmodifiable(_riders);
  int get capacity => level.capacity;
  double get loadFraction => load / capacity;
  int get tripsLeft => tripsTotal - tripsUsed;
  int get levelCoins => Formulas.baseCoins(level.number) + tripCoins;
  bool get canSend => phase == Phase.playing && _riders.isNotEmpty;
  int get benchUsed => _bench.where((r) => r != null).length;

  LoadZone get zone => zoneFor(load);

  LoadZone zoneFor(int kg) {
    final f = kg / capacity;
    if (kg == 0) return LoadZone.empty;
    if (f > 1) return LoadZone.overload;
    if (f >= Formulas.perfectFraction) return LoadZone.limit;
    if (f >= Formulas.greenFraction) return LoadZone.green;
    return LoadZone.light;
  }

  Resident? get selected {
    final s = selection;
    if (s == null) return null;
    if (s.fromBench) return _bench[s.index];
    final q = _queues[s.index];
    return q.isEmpty ? null : q.first;
  }

  int remainingFor(Floor f) =>
      _queues.fold(0, (a, q) => a + q.where((r) => r.floor == f).length) +
      _bench.where((r) => r?.floor == f).length;

  int get remainingTotal =>
      _queues.fold(0, (a, q) => a + q.length) + benchUsed;

  /// Next floors after the current lift, up to [count], skipping cleared ones.
  List<Floor> upcomingFloors(int count) {
    final out = <Floor>[];
    var prev = liftFloor;
    for (var i = 0; i < count; i++) {
      final n = _nextFloor(prev);
      if (n == null) break;
      out.add(n);
      prev = n;
    }
    return out;
  }

  List<GameEvent> drainEvents() {
    final out = List.of(_events);
    _events.clear();
    return out;
  }

  // ── Player actions ──

  void tapQueue(int lane) {
    if (phase != Phase.playing || _queues[lane].isEmpty) return;
    final s = Selection.queue(lane);
    ghostLoad = null;
    if (selection == s) {
      selection = null;
      return;
    }
    selection = s;
    _events.add(SelectedEvent(_queues[lane].first));
  }

  BenchResult tapBench(int seat) {
    if (phase != Phase.playing) return BenchResult.ignored;
    final occupant = _bench[seat];
    ghostLoad = null;
    if (occupant != null) {
      final s = Selection.bench(seat);
      if (selection == s) {
        selection = null;
        return BenchResult.deselected;
      }
      selection = s;
      _events.add(SelectedEvent(occupant));
      return BenchResult.selected;
    }
    final s = selection;
    if (s == null || s.fromBench) return BenchResult.needSelection;
    final mover = _queues[s.index].removeAt(0);
    _bench[seat] = mover;
    selection = null;
    _events.add(SeatedEvent(mover, seat));
    _checkJam();
    return BenchResult.seated;
  }

  BoardResult tapLift() {
    if (phase != Phase.playing) return BoardResult.notPlaying;
    final s = selection;
    final r = selected;
    if (s == null || r == null) return BoardResult.noSelection;
    if (r.floor != liftFloor) {
      _events.add(RefusedEvent(r, liftFloor));
      return BoardResult.wrongFloor;
    }
    final before = _Snapshot(this);
    if (s.fromBench) {
      _bench[s.index] = null;
    } else {
      _queues[s.index].removeAt(0);
    }
    _riders.add(r);
    load += r.kg;
    selection = null;
    ghostLoad = null;
    if (load > capacity) {
      _beforeCrash = before;
      phase = Phase.falling;
      _events.add(OverloadEvent(r));
      return BoardResult.overloaded;
    }
    _events.add(BoardedEvent(r, zone));
    return BoardResult.boarded;
  }

  /// Shows the Scale ghost needle for the selected resident. The caller owns
  /// the booster inventory and only calls this when one is available.
  bool previewScale() {
    final r = selected;
    if (phase != Phase.playing || r == null || r.floor != liftFloor) return false;
    ghostLoad = load + r.kg;
    _events.add(ScalePreviewEvent(r));
    return true;
  }

  TripRating? send() {
    if (!canSend) return null;
    final f = loadFraction;
    final TripRating rating;
    final int coins;
    if (f >= Formulas.perfectFraction) {
      rating = TripRating.perfect;
      coins = Formulas.perfectTripCoins;
    } else if (f >= Formulas.greenFraction) {
      rating = TripRating.good;
      coins = Formulas.greenTripCoins;
    } else {
      rating = TripRating.halfEmpty;
      coins = 0;
    }
    _pendingRating = rating;
    _pendingCoins = coins;
    selection = null;
    ghostLoad = null;
    phase = Phase.departing;
    _events.add(SentEvent(liftFloor, rating, coins, _riders.length));
    return rating;
  }

  /// Call when the departure animation completes.
  void finishSend() {
    if (phase != Phase.departing) return;
    tripCoins += _pendingCoins;
    if (_pendingRating == TripRating.perfect) perfects++;
    if (_pendingRating == TripRating.good) goodTrips++;
    _pendingRating = null;
    _pendingCoins = 0;
    _riders.clear();
    load = 0;
    tripsUsed++;
    final next = _nextFloor(liftFloor);
    if (next == null) {
      phase = Phase.won;
      _events.add(WonEvent(levelCoins, tripsUsed, perfects));
      return;
    }
    if (tripsUsed >= tripsTotal) {
      _pendingNext = next;
      _fail(FailKind.outOfTrips);
      return;
    }
    liftFloor = next;
    phase = Phase.playing;
    _events.add(LiftArrivedEvent(next));
    _checkJam();
  }

  /// Call when the crash animation completes.
  void finishCrash() {
    if (phase != Phase.falling) return;
    _fail(FailKind.crash);
  }

  /// Applies the continue for the current fail: repair the lift (the
  /// overloading rider returns to where they stood), +2 trips, or +1 seat.
  void continueAfterFail({required bool viaAd}) {
    if (phase != Phase.failed) return;
    final kind = failKind!;
    switch (kind) {
      case FailKind.crash:
        final snap = _beforeCrash!;
        for (var i = 0; i < _queues.length; i++) {
          _queues[i]
            ..clear()
            ..addAll(snap.queues[i]);
        }
        _bench
          ..clear()
          ..addAll(snap.bench);
        _riders
          ..clear()
          ..addAll(snap.riders);
        load = snap.load;
        _beforeCrash = null;
      case FailKind.outOfTrips:
        tripsTotal += Formulas.adTripsBonus;
        liftFloor = _pendingNext ?? liftFloor;
        _pendingNext = null;
      case FailKind.jam:
        _bench.add(null);
    }
    if (viaAd) adContinueUsed = true;
    failKind = null;
    phase = Phase.playing;
    _events.add(ContinuedEvent(kind));
    if (kind == FailKind.outOfTrips) _events.add(LiftArrivedEvent(liftFloor));
  }

  // ── Internals ──

  void _fail(FailKind kind) {
    phase = Phase.failed;
    failKind = kind;
    selection = null;
    ghostLoad = null;
    _events.add(FailedEvent(kind));
  }

  Floor? _nextFloor(Floor after) {
    final order = level.floors;
    final start = order.indexOf(after);
    for (var step = 1; step <= order.length; step++) {
      final f = order[(start + step) % order.length];
      if (remainingFor(f) > 0) return f;
    }
    return null;
  }

  /// Jammed: the lift is empty, every seat is taken, and nobody who can be
  /// selected is going to this lift's floor.
  void _checkJam() {
    if (phase != Phase.playing || _riders.isNotEmpty) return;
    final benchFull = !_bench.contains(null);
    final frontMatch = _queues.any((q) => q.isNotEmpty && q.first.floor == liftFloor);
    final benchMatch = _bench.any((r) => r?.floor == liftFloor);
    if (benchFull && !frontMatch && !benchMatch) _fail(FailKind.jam);
  }
}
