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
import 'scenario.dart';

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

/// One lift visit: the floor(s) it serves and what kind of cabin it is.
class LiftStop {
  const LiftStop(this.floors, this.kind);

  /// One floor, or two for an express.
  final List<Floor> floors;
  final LiftKind kind;
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
  const RefusedEvent(this.resident, this.liftFloors);
  final Resident resident;
  final List<Floor> liftFloors;
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
  const SentEvent(this.floors, this.kind, this.rating, this.coins, this.riders);
  final List<Floor> floors;
  final LiftKind kind;
  final TripRating rating;
  final int coins;
  final int riders;
}

class LiftArrivedEvent extends GameEvent {
  const LiftArrivedEvent(this.floors, this.kind);
  final List<Floor> floors;
  final LiftKind kind;
}

/// Rush hour: [count] residents joined the lanes.
class ArrivalsEvent extends GameEvent {
  const ArrivalsEvent(this.count);
  final int count;
}

/// Maintenance finished: [lane] can be selected again.
class LaneOpenedEvent extends GameEvent {
  const LaneOpenedEvent(this.lane);
  final int lane;
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
  /// [recordEvents] is false for the solver bot, which never drains them.
  LiftGame(this.level, {bool recordEvents = true})
      : _record = recordEvents,
        _queues = [for (final q in level.queues) List.of(q)],
        _bench = List<Resident?>.filled(level.benchSize, null, growable: true),
        _pendingArrivals = List.of(level.arrivals),
        _lockedLane = level.lockedLane,
        tripsTotal = level.trips {
    final first = _stopAfter(null, 0);
    if (first == null) throw ArgumentError('Level has no residents');
    _setStop(first);
  }

  final Level level;
  final bool _record;
  final List<List<Resident>> _queues;
  final List<Resident?> _bench;
  final List<Resident> _riders = [];
  final List<Arrival> _pendingArrivals;
  final List<GameEvent> _events = [];
  int? _lockedLane;

  /// Floors the waiting lift serves: one, or two for an express.
  late List<Floor> liftFloors;
  late LiftKind liftKind;
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
  LiftStop? _pendingStop;
  _Snapshot? _beforeCrash;

  // ── Read-only views ──
  List<List<Resident>> get queues => List.unmodifiable(_queues.map(List<Resident>.unmodifiable));
  List<Resident?> get bench => List.unmodifiable(_bench);
  List<Resident> get riders => List.unmodifiable(_riders);

  /// The first (or only) floor of the waiting lift.
  Floor get liftFloor => liftFloors.first;

  /// Capacity of the waiting lift, which depends on its [liftKind].
  int get capacity => Formulas.liftCapacity(level.capacity, liftKind);
  double get loadFraction => load / capacity;
  int get tripsLeft => tripsTotal - tripsUsed;
  int get levelCoins => Formulas.baseCoins(level.number) + tripCoins;
  bool get canSend => phase == Phase.playing && _riders.isNotEmpty;
  int get benchUsed => _bench.where((r) => r != null).length;

  /// Cheap lane access for the solver bot (no list copies).
  int laneLength(int lane) => _queues[lane].length;
  Resident laneAt(int lane, int depth) => _queues[lane][depth];

  /// Maintenance: the coned-off lane, while it is closed.
  int? get lockedLane => _lockedLane;
  bool isLaneLocked(int lane) => _lockedLane == lane;

  /// Trips still to run before the coned-off lane opens.
  int get tripsUntilLaneOpens => level.lockedUntilTrip - tripsUsed;

  /// Rush hour: residents still to arrive, in order.
  List<Arrival> get pendingArrivals => List.unmodifiable(_pendingArrivals);

  bool goesTo(Floor f) => liftFloors.contains(f);

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

  /// Residents for [f] in the lobby now (lanes and bench).
  int remainingFor(Floor f) =>
      _queues.fold(0, (a, q) => a + q.where((r) => r.floor == f).length) +
      _bench.where((r) => r?.floor == f).length;

  /// Everyone still to deliver, including residents yet to arrive.
  int get remainingTotal => _queues.fold(0, (a, q) => a + q.length) + benchUsed + _pendingArrivals.length;

  /// The next [count] lifts after the waiting one, as the lobby stands now.
  List<LiftStop> upcomingLifts(int count) {
    final out = <LiftStop>[];
    var prev = liftFloors.last;
    for (var i = 0; i < count; i++) {
      final stop = _stopAfter(prev, tripsUsed + 1 + i);
      if (stop == null) break;
      out.add(stop);
      prev = stop.floors.last;
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
    if (phase != Phase.playing || _queues[lane].isEmpty || isLaneLocked(lane)) return;
    final s = Selection.queue(lane);
    ghostLoad = null;
    if (selection == s) {
      selection = null;
      return;
    }
    selection = s;
    _emit(SelectedEvent(_queues[lane].first));
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
      _emit(SelectedEvent(occupant));
      return BenchResult.selected;
    }
    final s = selection;
    if (s == null || s.fromBench) return BenchResult.needSelection;
    final mover = _queues[s.index].removeAt(0);
    _bench[seat] = mover;
    selection = null;
    _emit(SeatedEvent(mover, seat));
    _checkJam();
    return BenchResult.seated;
  }

  BoardResult tapLift() {
    if (phase != Phase.playing) return BoardResult.notPlaying;
    final s = selection;
    final r = selected;
    if (s == null || r == null) return BoardResult.noSelection;
    if (!goesTo(r.floor)) {
      _emit(RefusedEvent(r, List.unmodifiable(liftFloors)));
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
      _emit(OverloadEvent(r));
      return BoardResult.overloaded;
    }
    _emit(BoardedEvent(r, zone));
    return BoardResult.boarded;
  }

  /// Shows the Scale ghost needle for the selected resident. The caller owns
  /// the booster inventory and only calls this when one is available.
  bool previewScale() {
    final r = selected;
    if (phase != Phase.playing || r == null || !goesTo(r.floor)) return false;
    ghostLoad = load + r.kg;
    _emit(ScalePreviewEvent(r));
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
    _emit(SentEvent(List.unmodifiable(liftFloors), liftKind, rating, coins, _riders.length));
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
    final served = liftFloors.last;
    _admitArrivals(all: false);
    if (_lockedLane != null && tripsUsed >= level.lockedUntilTrip) _openLane();
    var next = _stopAfter(served, tripsUsed);
    if (next == null && (_pendingArrivals.isNotEmpty || _lockedLane != null)) {
      // Only late arrivals or the coned-off lane are left: bring them in now
      // rather than leave the lift with nowhere to go.
      _admitArrivals(all: true);
      if (_lockedLane != null) _openLane();
      next = _stopAfter(served, tripsUsed);
    }
    if (next == null) {
      phase = Phase.won;
      _emit(WonEvent(levelCoins, tripsUsed, perfects));
      return;
    }
    if (tripsUsed >= tripsTotal) {
      _pendingStop = next;
      _fail(FailKind.outOfTrips);
      return;
    }
    _arrive(next);
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
      case FailKind.jam:
        _bench.add(null);
    }
    if (viaAd) adContinueUsed = true;
    failKind = null;
    phase = Phase.playing;
    _emit(ContinuedEvent(kind));
    if (kind == FailKind.outOfTrips) {
      final next = _pendingStop!;
      _pendingStop = null;
      _arrive(next);
    }
  }

  // ── Internals ──

  void _emit(GameEvent e) {
    if (_record) _events.add(e);
  }

  void _fail(FailKind kind) {
    phase = Phase.failed;
    failKind = kind;
    selection = null;
    ghostLoad = null;
    _emit(FailedEvent(kind));
  }

  void _setStop(LiftStop stop) {
    liftFloors = stop.floors;
    liftKind = stop.kind;
  }

  void _arrive(LiftStop stop) {
    _setStop(stop);
    phase = Phase.playing;
    _emit(LiftArrivedEvent(List.unmodifiable(stop.floors), stop.kind));
    _checkJam();
  }

  void _admitArrivals({required bool all}) {
    var count = 0;
    while (_pendingArrivals.isNotEmpty && (all || _pendingArrivals.first.afterTrip <= tripsUsed)) {
      final a = _pendingArrivals.removeAt(0);
      _queues[a.lane].add(a.resident);
      count++;
    }
    if (count > 0) _emit(ArrivalsEvent(count));
  }

  void _openLane() {
    final lane = _lockedLane!;
    _lockedLane = null;
    _emit(LaneOpenedEvent(lane));
  }

  /// Residents for [f] the lift can actually reach: open lanes and bench.
  /// Lifts are routed by this, so a lift never comes for people behind the
  /// cones or people who have not arrived yet.
  bool _reachable(Floor f) {
    for (var i = 0; i < _queues.length; i++) {
      if (i == _lockedLane) continue;
      for (final r in _queues[i]) {
        if (r.floor == f) return true;
      }
    }
    return _bench.any((r) => r?.floor == f);
  }

  Floor? _nextFloor(Floor? after) {
    final order = level.floors;
    final start = after == null ? -1 : order.indexOf(after);
    for (var step = 1; step <= order.length; step++) {
      final f = order[(start + step) % order.length];
      if (_reachable(f)) return f;
    }
    return null;
  }

  /// The lift that follows one that served up to [after], as trip
  /// [tripIndex]. An express adds the next floor in rotation, if any.
  LiftStop? _stopAfter(Floor? after, int tripIndex) {
    final kind = level.kindForTrip(tripIndex);
    final first = _nextFloor(after);
    if (first == null) return null;
    if (kind == LiftKind.express) {
      final second = _nextFloor(first);
      if (second != null && second != first) return LiftStop([first, second], kind);
    }
    return LiftStop([first], kind);
  }

  /// Jammed: the lift is empty, every seat is taken, and nobody who can be
  /// selected is going to one of this lift's floors. While a lane is coned
  /// off, the maintenance ends early instead: a jam the player could only
  /// see through the cones would be unfair.
  void _checkJam() {
    if (phase != Phase.playing || _riders.isNotEmpty || _bench.contains(null)) return;
    if (_canBoardNow()) return;
    if (_lockedLane != null) {
      _openLane();
      if (_canBoardNow()) return;
    }
    _fail(FailKind.jam);
  }

  bool _canBoardNow() {
    for (var i = 0; i < _queues.length; i++) {
      if (i != _lockedLane && _queues[i].isNotEmpty && goesTo(_queues[i].first.floor)) return true;
    }
    return _bench.any((r) => r != null && goesTo(r.floor));
  }
}
