import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../../game/powers.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/resident_painter.dart';
import '../theme.dart';
import '../widgets/art_icon.dart';
import '../widgets/cabin_floor.dart';
import '../widgets/count_up.dart';
import '../widgets/effects.dart';
import '../widgets/entrance.dart';
import '../widgets/glossy.dart';
import '../widgets/lane_scroller.dart';
import '../widgets/lift_shaft.dart';
import '../widgets/lobby.dart';
import '../widgets/play_bar.dart';
import '../widgets/punch.dart';
import '../widgets/resident_figure.dart';
import '../widgets/result_sheets.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/wide_backdrop.dart';

/// The level screen. Owns the cabin animations: when the engine enters
/// [Phase.departing] or [Phase.falling], this screen animates the cabin and
/// then tells the controller the animation finished.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);
  late final AnimationController _doors = AnimationController(vsync: this, value: 1);
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController _bump = AnimationController(vsync: this, duration: PunchMotion.bump);
  late final AnimationController _slam = AnimationController(vsync: this, duration: PunchMotion.slam);

  /// The level entrance (0 to 1 over [EntranceMotion.total]); at 1 the screen
  /// is as laid out. A touch jumps it to the end, so it never holds up play.
  late final AnimationController _entrance = AnimationController(vsync: this, duration: EntranceMotion.total);
  LiftGame? _entranceGame;

  /// The chime light when a lift stops (0 to 1 over [FloorMotion.chime]).
  late final AnimationController _chime = AnimationController(vsync: this, duration: FloorMotion.chime);
  Animation<double> _dy = const AlwaysStoppedAnimation(0);
  Animation<double> _tilt = const AlwaysStoppedAnimation(0);
  Phase? _lastPhase;

  /// The last reveal this screen has played, and who it was.
  late int _seenReveal = c.revealSerial;
  int? _revealedId;
  LiftGame? _revealGame;

  /// Bumped on every phase change, controller swap and dispose; see [_live].
  int _seq = 0;

  /// The trip just sent (its rating and coins), held until the doors shut;
  /// then the score on screen, and the coin pill's pulse count.
  TripRating? _sentRating;
  int _sentCoins = 0;
  TripRating? _slamRating;
  int _slamCoins = 0;
  Rect? _slamRect;
  int _coinPulse = 0;

  /// Where things are on screen, for walks and effects.
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _laneKeys = [];
  final List<GlobalKey> _seatKeys = [];
  final GlobalKey _cabinKey = GlobalKey();
  final GlobalKey _shaftKey = GlobalKey();
  final GlobalKey _coinKey = GlobalKey();
  final GlobalKey<EffectsLayerState> _effects = GlobalKey();

  /// Residents walking right now, and the ids whose destination copy is
  /// hidden until they land.
  final List<_Flight> _flights = [];
  final Set<int> _hidden = {};

  GameController get c => widget.controller;
  bool get _still => reduceMotion(context);

  /// Sparkles in the burst when an unknown person is revealed.
  static const int revealSparkles = 8;

  @override
  void initState() {
    super.initState();
    _lastPhase = c.game.phase;
    c.addListener(_onChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first level on this screen enters; later ones start in _onChange.
    if (_entranceGame == null) _beginEntrance();
  }

  /// A level has started on this screen: it comes in (at once under reduced
  /// motion), once the screen itself has finished arriving.
  void _beginEntrance() {
    _entranceGame = c.game;
    _routeWait?.removeStatusListener(_routeStatus);
    _routeWait = null;
    if (_still) {
      _entrance.value = 1;
      return;
    }
    _entrance.value = 0;
    final arriving = ModalRoute.of(context)?.animation;
    if (arriving == null || arriving.status == AnimationStatus.completed) {
      _entrance.forward(from: 0);
    } else {
      _routeWait = arriving..addStatusListener(_routeStatus);
    }
  }

  /// The route animation the entrance is waiting on, if any.
  Animation<double>? _routeWait;

  void _routeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeWait?.removeStatusListener(_routeStatus);
    _routeWait = null;
    if (mounted && _entrance.value == 0) _entrance.forward(from: 0);
  }

  @override
  void didUpdateWidget(PlayScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      _seq++;
      _lastPhase = c.game.phase;
      _seenReveal = c.revealSerial;
      _revealedId = null;
      _snapHome();
      _slam
        ..stop()
        ..value = 0;
      _sentRating = null;
      _slamRating = null;
      _flights.clear();
      _hidden.clear();
      c.addListener(_onChange);
      _beginEntrance();
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _seq++;
    _anim.dispose();
    _doors.dispose();
    _shake.dispose();
    _bump.dispose();
    _slam.dispose();
    _routeWait?.removeStatusListener(_routeStatus);
    _entrance.dispose();
    _chime.dispose();
    super.dispose();
  }

  /// Lane count varies per level (3 to 5), so keys are made on demand.
  GlobalKey _laneKey(int i) {
    while (_laneKeys.length <= i) {
      _laneKeys.add(GlobalKey());
    }
    return _laneKeys[i];
  }

  GlobalKey _seatKey(int i) {
    while (_seatKeys.length <= i) {
      _seatKeys.add(GlobalKey());
    }
    return _seatKeys[i];
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  void _onChange() {
    final motions = c.takeMotions();
    final reward = c.takeReward();
    if (!mounted) return;
    final phase = c.hasGame ? c.game.phase : null;
    // A new level (next, retry, restart): everything starts afresh and comes
    // in, with no lift springing back from the last one.
    if (c.hasGame && !identical(c.game, _entranceGame)) {
      _seq++;
      _lastPhase = phase;
      _snapHome();
      _slam
        ..stop()
        ..value = 0;
      _chime
        ..stop()
        ..value = 0;
      _sentRating = null;
      _slamRating = null;
      _flights.clear();
      _hidden.clear();
      _playReveal();
      _beginEntrance();
      setState(() {});
      return;
    }
    if (!_still) _startFlights(motions);
    _playReveal();
    final was = _lastPhase;
    _lastPhase = phase;
    if (phase == was) {
      setState(() {});
      return;
    }
    final seq = ++_seq;
    switch (phase) {
      case Phase.departing:
        _sentRating = c.sentRating;
        _sentCoins = reward;
        _depart(seq);
      case Phase.falling:
        _fall(seq);
      case Phase.playing when was == Phase.departing:
        _arrive(seq);
      case Phase.playing when was == Phase.failed:
        // The repaired lift springs back.
        _doors.value = 1;
        _run(from: CabinMotion.repairDistance, to: 0, duration: CabinMotion.repair, curve: Curves.easeOutBack);
      case Phase.playing:
        _snapHome();
      case Phase.won:
        _snapHome();
        _celebrate();
      case Phase.failed || null:
        break;
    }
    setState(() {});
  }

  /// True while the cabin sequence started at [seq] is still the current one:
  /// a later phase change, a controller swap or dispose makes it stale, and a
  /// stale sequence stops before touching the controllers or the engine.
  bool _live(int seq) => mounted && seq == _seq;

  /// Doors close (after a rider still walking in lands), the score slams in
  /// and the coins fly as the cabin bumps, the cabin rises, and the engine
  /// moves on to the next lift. [GameController.finishSend] runs once, only
  /// after all of that; the slam and the coins play on over the arrival.
  Future<void> _depart(int seq) async {
    if (_flights.isNotEmpty) await Future<void>.delayed(BoardMotion.flight);
    if (!_live(seq)) return;
    await _closeDoors();
    if (!_live(seq)) return;
    _punch();
    if (!_still) await _bump.forward(from: 0).orCancel.catchError((Object _) {});
    if (!_live(seq)) return;
    await _run(from: 0, to: -CabinMotion.riseDistance, duration: CabinMotion.rise, curve: Curves.easeInCubic);
    if (_live(seq)) c.finishSend();
  }

  /// The score slam over the shaft, and coins flying to the coin pill on a
  /// good or perfect trip. Neither plays under reduced motion (the message
  /// line gives the rating on arrival either way).
  void _punch() {
    final rating = _sentRating;
    _sentRating = null;
    if (rating == null || _still) return;
    setState(() {
      _slamRating = rating;
      _slamCoins = _sentCoins;
      _slamRect = _rectOf(_shaftKey);
    });
    _slam.forward(from: 0);
    if (_sentCoins > 0) _coinBurst(_sentCoins);
  }

  /// Let the last rider land, then the cable goes. Still (reduced motion) it
  /// runs without waiting, so no timer is left pending. The doors stay as
  /// they are: nothing delays the crash.
  Future<void> _fall(int seq) async {
    if (!_still) await Future<void>.delayed(BoardMotion.flight);
    if (!_live(seq)) return;
    _crashEffects();
    await _run(
      from: 0,
      to: CabinMotion.fallDistance,
      tiltTo: CabinMotion.fallTilt,
      duration: CabinMotion.fall,
      curve: Curves.easeInQuad,
    );
    if (_live(seq)) c.finishCrash();
  }

  /// The next lift drops in with its doors shut, then opens them.
  Future<void> _arrive(int seq) async {
    _doors.value = 0;
    await _run(from: -CabinMotion.riseDistance, to: 0, duration: CabinMotion.dropIn, curve: Curves.easeOutBack);
    if (!_live(seq)) return;
    // The lift has stopped: the chime light flashes as its doors open.
    if (!_still) _chime.forward(from: 0);
    await _doorsTo(1, CabinMotion.doorOpen);
  }

  /// The leaves travel to the seam, then settle: they bounce back
  /// [Metrics.doorSettle] and meet again, all in [CabinMotion.doorClose].
  /// Still, they shut at once.
  Future<void> _closeDoors() {
    final m = Metrics.of(context);
    return _doorsTo(0, CabinMotion.doorClose, curve: CabinMotion.doorCloseCurve(m.doorSettle / (m.cabinWidth / 2)));
  }

  void _snapHome() {
    _anim.stop();
    _bump
      ..stop()
      ..value = 0;
    _dy = const AlwaysStoppedAnimation(0);
    _tilt = const AlwaysStoppedAnimation(0);
    _doors.value = 1;
  }

  Future<void> _run(
      {required double from, required double to, double tiltTo = 0, required Duration duration, required Curve curve}) {
    final curved = CurvedAnimation(parent: _anim, curve: curve);
    _dy = Tween(begin: from, end: to).animate(curved);
    _tilt = Tween(begin: 0.0, end: tiltTo).animate(curved);
    _anim
      ..duration = _still ? Duration.zero : duration
      ..reset();
    return _anim.forward().orCancel.catchError((Object _) {});
  }

  Future<void> _doorsTo(double target, Duration duration, {Curve curve = CabinMotion.doorCurve}) => _doors
      .animateTo(target, duration: _still ? Duration.zero : duration, curve: curve)
      .orCancel
      .catchError((Object _) {});

  void _startFlights(List<Motion> motions) {
    if (motions.isEmpty) return;
    final m = Metrics.of(context);
    for (final mo in motions) {
      final from = mo.from.fromBench ? _rectOf(_seatKey(mo.from.index)) : _rectOf(_laneKey(mo.from.index));
      final seat = mo.to.seat;
      final to = seat != null ? _rectOf(_seatKey(seat)) : _rectOf(_cabinKey);
      if (from == null || to == null) continue;
      final bench = m.benchFigureFor(c.game.bench.length);
      final fromHeight = mo.from.fromBench ? bench : m.laneFigureFor(c.game.laneCount);
      // Into the lift, they walk to their own spot on the cabin floor.
      final spot = seat != null
          ? null
          : CabinFloor.layout(c.game.riders, m).where((s) => s.resident.id == mo.resident.id).firstOrNull;
      final toHeight = seat != null ? bench : spot?.height ?? m.cabinFigure;
      _hidden.add(mo.resident.id);
      _flights.add(_Flight(
        resident: mo.resident,
        // Bottoms of the figure box: the bottom of a seat, the rider's spot
        // on the cabin floor, or just under the floor tag at the front of a lane.
        from: mo.from.fromBench
            ? from.bottomCenter - Offset(0, 6 * m.scale)
            : from.topCenter + Offset(0, 18 * m.scale + fromHeight),
        to: seat != null
            ? to.bottomCenter - Offset(0, 6 * m.scale)
            : spot != null
                ? to.topLeft + Offset(spot.left + spot.footprint / 2, spot.feet + toHeight * ResidentFigure.belowFeet)
                : to.bottomCenter,
        fromHeight: fromHeight,
        toHeight: toHeight,
      ));
      // A ring of light on the floor where they are arriving, the same for
      // everyone.
      final feet = _flights.last.to;
      _effects.currentState?.add(Burst(
        kind: BurstKind.ring,
        origin: feet,
        delay: BoardMotion.flight * BoardMotion.ringAt,
        radius: BoardMotion.ringRadius * m.scale,
        stroke: BoardMotion.ringStroke * m.scale,
      ));
    }
  }

  void _landed(_Flight f) {
    if (!mounted) return;
    setState(() {
      _flights.remove(f);
      if (!_flights.any((o) => o.resident.id == f.resident.id)) _hidden.remove(f.resident.id);
    });
  }

  /// An unknown person has just reached a lane front: they pop in (see
  /// [QueueLanes]) and a few sparkles fly from them. Nothing is played under
  /// reduced motion, and nothing depends on who they are.
  void _playReveal() {
    // A new level starts with nobody popping, whatever ids it reuses.
    if (c.hasGame && !identical(c.game, _revealGame)) {
      _revealGame = c.game;
      _revealedId = null;
    }
    if (c.revealSerial == _seenReveal) return;
    _seenReveal = c.revealSerial;
    final lane = c.revealedLane;
    if (lane == null || !c.hasGame || lane >= c.game.laneCount) return;
    _revealedId = c.game.frontOf(lane)?.id;
    if (_still) return;
    final rect = _rectOf(_laneKey(lane));
    if (rect == null) return;
    final m = Metrics.of(context);
    _effects.currentState?.add(Burst(
      kind: BurstKind.sparkle,
      origin: rect.topCenter + Offset(0, 18 * m.scale + m.laneFigureFor(c.game.laneCount) * 0.5),
      count: revealSparkles,
    ));
  }

  /// Coin icons fly from the cabin to the coin pill, which pulses as they
  /// land. The slam shows how many coins; the burst only carries them.
  void _coinBurst(int coins) {
    if (_still) return;
    final cabin = _rectOf(_cabinKey);
    final chip = _rectOf(_coinKey);
    if (cabin == null) return;
    _effects.currentState?.add(Burst(
      kind: BurstKind.coins,
      origin: cabin.center,
      target: chip?.center,
      count: coins >= Formulas.perfectTripCoins ? PunchMotion.coinsPerfect : PunchMotion.coinsGood,
      sprite: SpriteArtScope.of(context) ? SpriteCache.instance.icon(GameIcon.coin) : null,
      spriteSize: Metrics.of(context).coinFly,
      onDone: () {
        if (mounted) setState(() => _coinPulse++);
      },
    ));
  }

  void _crashEffects() {
    if (_still) return;
    _shake.forward(from: 0);
    final cabin = _rectOf(_cabinKey);
    if (cabin != null) {
      _effects.currentState?.add(Burst(kind: BurstKind.sparks, origin: cabin.topCenter, count: 22));
    }
  }

  void _celebrate() {
    if (_still) return;
    final stack = _rectOf(_stackKey);
    if (stack == null) return;
    final lastOfVenue = c.game.level.number == c.game.level.venue.lastLevel;
    _effects.currentState?.add(Burst(kind: BurstKind.confetti, origin: stack.topCenter, count: lastOfVenue ? 140 : 70));
  }

  /// Back from the HUD or the system: confirm first when it costs a life.
  Future<void> _leave() async {
    if (c.levelInProgress) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave this level?'),
          content: const Text('You have started it, so leaving costs 1 life.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave · 1 life')),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    c.quitToHome();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final m = Metrics.of(context);
    final slamRating = _slamRating;
    final slamRect = _slamRect;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The message line, in the strip under the cabin: a pill that slides up
    // and fades in on each change.
    final message = Center(
      child: Semantics(
        liveRegion: true,
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: still ? 0 : 220),
          switchInCurve: Curves.easeOutBack,
          // The old line is gone by the half-way point and the new one starts
          // there, so two messages are never readable on top of each other.
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: _HalfwayFade(anim),
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey(c.message),
            padding: EdgeInsets.symmetric(horizontal: 12 * m.scale, vertical: m.messagePillPad),
            decoration: c.message.isEmpty
                ? null
                : BoxDecoration(
                    color: LL.messagePill,
                    borderRadius: BorderRadius.circular(m.messageHeight),
                    border: Border.all(color: LL.messageRim, width: Metrics.messageRim),
                  ),
            // A long line shrinks to fit rather than losing its end.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                c.message,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.brass),
              ),
            ),
          ),
        ),
      ),
    );
    final shaft = AnimatedBuilder(
      key: _shaftKey,
      animation: Listenable.merge([_anim, _doors, _bump, _chime]),
      builder: (context, _) => LiftShaft(
        game: g,
        cabinDy: _dy.value * m.scale,
        cabinTilt: _tilt.value,
        doorOpen: _doors.value,
        cabinBump: _bump.value,
        chime: _chime.isAnimating ? _chime.value : 0,
        cabinKey: _cabinKey,
        hiddenIds: _hidden,
        onTapLift: c.tapLift,
        onScale: g.phase == Phase.playing ? c.useScale : null,
        scaleLeft: c.profile.scales,
        scaleReady: c.canUseScale,
        footer: message,
      ),
    );
    // The level entrance: each part comes in over its slice of one clock.
    Widget enter(Widget part, int start, int ms, {double dy = 0, double scaleFrom = 1}) => Entrance(
          animation: _entrance,
          curve: EntranceMotion.span(start, ms),
          dy: dy,
          scaleFrom: scaleFrom,
          child: part,
        );
    final hud = enter(
      _Hud(c: c, onBack: _leave, coinKey: _coinKey, coinPulse: _coinPulse),
      EntranceMotion.hudStart,
      EntranceMotion.hudMs,
      dy: -EntranceMotion.hudDrop,
    );
    final shaftIn = enter(
      shaft,
      EntranceMotion.shaftStart,
      EntranceMotion.shaftMs,
      dy: EntranceMotion.shaftRise,
      scaleFrom: EntranceMotion.shaftFrom,
    );
    final refused = c.refusedSpot;
    final bench = enter(
      BenchRow(
        game: g,
        onTapSeat: c.tapBench,
        seatKeys: [for (var i = 0; i < g.bench.length; i++) _seatKey(i)],
        hiddenIds: _hidden,
        shakeSerial: refused?.fromBench == true ? c.refuseSerial : 0,
        shakeSeat: refused?.fromBench == true ? refused!.index : null,
      ),
      EntranceMotion.benchStart,
      EntranceMotion.benchMs,
      dy: EntranceMotion.benchRise,
    );
    Widget lanes(bool paintFloor) => QueueLanes(
          game: g,
          paintFloor: paintFloor,
          onTapLane: c.tapQueue,
          laneKeys: [for (var i = 0; i < g.laneCount; i++) _laneKey(i)],
          shakeSerial: refused?.fromBench == false ? c.refuseSerial : 0,
          shakeLane: refused?.fromBench == false ? refused!.index : null,
          coneSerial: c.coneSerial,
          coneLane: c.coneLane,
          swapping: c.armedPower == Power.swap,
          swapFirst: c.swapFirstLane,
          revealedId: _revealedId,
          entrance: _entrance,
        );
    // The lobby floor always reaches the bottom of its area, and scrolls when
    // the queues are longer than the screen (touch, mouse drag, wheel,
    // trackpad); a painted floor stays put under them.
    final lanesArea = LobbyFloor(
      venue: g.level.venue,
      builder: (context, paintFloor) => LaneScroller(child: lanes(paintFloor)),
    );
    final bottomBar = enter(
      PlayBottomBar(c: c),
      EntranceMotion.barStart,
      EntranceMotion.barMs,
      dy: EntranceMotion.barRise,
    );

    final Widget body;
    if (m.twoPane) {
      // Landscape tablets and wide windows: lift, gauge and bench on the left,
      // the lobby lanes filling the right.
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Metrics.twoPaneMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: m.columnWidth,
                child: Column(
                  children: [
                    hud,
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [shaftIn, bench],
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomBar,
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: m.gap, bottom: m.gap),
                  child: lanesArea,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: m.columnWidth),
          child: Column(
            children: [
              hud,
              shaftIn,
              bench,
              Expanded(child: lanesArea),
              bottomBar,
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: WideBackdrop(
          child: SafeArea(
            child: IdleClockScope(
              // A touch finishes the entrance at once: it never holds up play.
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (_entrance.isAnimating) _entrance.value = 1;
                },
                child: Stack(
                  key: _stackKey,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) {
                          final v = _shake.value;
                          final dx = _shake.isAnimating ? math.sin(v * 38) * 9 * (1 - v) : 0.0;
                          return Transform.translate(offset: Offset(dx, dx.abs() * 0.3), child: child);
                        },
                        child: ScrollConfiguration(behavior: const PlayScrollBehavior(), child: body),
                      ),
                    ),
                    for (final f in _flights) _FlightView(key: ObjectKey(f), flight: f, onDone: () => _landed(f)),
                    if (g.phase == Phase.failed)
                      FailSheet(
                        c: c,
                        onHome: () {
                          c.quitToHome();
                          Navigator.of(context).pop();
                        },
                      ),
                    if (g.phase == Phase.won)
                      WinSheet(
                        c: c,
                        onHome: () {
                          c.quitToHome();
                          Navigator.of(context).pop();
                        },
                      ),
                    Positioned.fill(child: EffectsLayer(key: _effects)),
                    // The trip's score over the shaft, above the coins flying out
                    // of it (style frame), until a result sheet comes up.
                    if (slamRating != null && slamRect != null && g.phase != Phase.won && g.phase != Phase.failed)
                      Positioned.fromRect(
                        rect: slamRect,
                        child: AnimatedBuilder(
                          animation: _slam,
                          builder: (context, _) => _slam.isAnimating
                              ? ScoreSlam(rating: slamRating, coins: _slamCoins, progress: _slam.value)
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Flight {
  _Flight(
      {required this.resident, required this.from, required this.to, required this.fromHeight, required this.toHeight});

  final Resident resident;

  /// Feet positions in the play screen's stack.
  final Offset from, to;
  final double fromHeight, toHeight;
}

/// A resident walking on a low arc from a lane or seat to a seat or the
/// cabin, with a little step bob. Same speed for everyone.
class _FlightView extends StatefulWidget {
  const _FlightView({super.key, required this.flight, required this.onDone});

  final _Flight flight;
  final VoidCallback onDone;

  @override
  State<_FlightView> createState() => _FlightViewState();
}

class _FlightViewState extends State<_FlightView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BoardMotion.flight)
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Metrics.of(context).scale;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final f = widget.flight;
        // Ease out into the spot with a hair of overshoot, over a low arc
        // and little step bobs: one walk, identical for every resident.
        final t = MotionCurves.walk.transform(_c.value);
        final h = f.fromHeight + (f.toHeight - f.fromHeight) * t;
        final feet = Offset.lerp(f.from, f.to, t)! - Offset(0, scale * BoardMotion.riseAt(_c.value));
        final w = h / designHeight * ResidentLook.designWidth(f.resident.type, f.resident.cargo);
        return Positioned(
          left: feet.dx - w / 2,
          top: feet.dy - h,
          child: IgnorePointer(child: ResidentFigure.of(f.resident, height: h)),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.onBack, required this.coinKey, required this.coinPulse});

  final GameController c;
  final VoidCallback onBack;

  /// The coin chip, where coin bursts fly to, and how many times it has
  /// pulsed as they landed.
  final GlobalKey coinKey;
  final int coinPulse;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final m = Metrics.of(context);
    final gapBetween = SizedBox(width: m.hudGap);
    Widget round(IconData icon, String label, VoidCallback onPressed) => GlossyButton(
          style: SurfaceStyle.plum,
          onPressed: onPressed,
          tooltip: label,
          semanticsLabel: label,
          width: m.hudRound,
          height: m.hudRound,
          inset: false,
          touch: true,
          child: Icon(icon, size: m.hudRoundIcon, color: LL.cream),
        );
    // Back and settings are the corners; level and trips stay on the left, lives and
    // coins on the right. The round buttons sit in a full touch target, so
    // the row's edge padding is the gutter less that margin: their faces,
    // like every panel below, stop at the gutter.
    return SizedBox(
      height: m.hudHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: m.hudEdge),
        child: Row(
          children: [
            round(Icons.arrow_back_rounded, 'Back to the tower', onBack),
            SizedBox(width: m.hudButtonGap),
            // Each group shrinks before it overflows on the narrowest phones.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Glossy(
                        style: SurfaceStyle.brass,
                        inset: false,
                        height: m.hudPill,
                        padding: EdgeInsets.symmetric(horizontal: m.gap),
                        child: Center(
                          child: Text('Lv ${g.level.number}',
                              style: LL.display.copyWith(fontSize: m.font(19), height: 1, color: LL.ink)),
                        ),
                      ),
                      gapBetween,
                      Semantics(
                        label: 'Trips left ${g.tripsLeft}',
                        child: ExcludeSemantics(child: _Chip(icon: GameIcon.trip, text: '${g.tripsLeft}')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Lives ${c.profile.lives}',
                      child: ExcludeSemantics(child: _Chip(icon: GameIcon.heart, text: '${c.profile.lives}')),
                    ),
                    gapBetween,
                    Semantics(
                      label: 'Coins ${c.profile.coins}',
                      child: ExcludeSemantics(
                        child: Pulse(
                          serial: coinPulse,
                          // Counts to a new total and bounces as it lands.
                          child: CountUp(
                            value: c.profile.coins,
                            builder: (context, shown, widest) =>
                                _Chip(key: coinKey, icon: GameIcon.coin, text: '$shown', widest: '$widest'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: m.hudButtonGap),
            round(Icons.settings_rounded, 'Settings', () => showSettingsSheet(context, c, inLevel: true)),
          ],
        ),
      ),
    );
  }
}

/// A dark HUD pill: an approved icon and a number.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.text, this.widest});

  final GameIcon icon;
  final String text;

  /// The widest the text gets (a counting number): the chip keeps that width.
  final String? widest;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final style = LL.display.copyWith(fontSize: m.font(15), height: 1, color: LL.cream);
    return Glossy(
      style: SurfaceStyle.chip,
      depth: SurfaceDepth.chip,
      inset: false,
      height: m.hudPill,
      padding: EdgeInsets.fromLTRB(m.hudChipGap, 0, m.hudChipGap * 3, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // An ink fallback would vanish on the dark pill.
          ArtIcon(icon, size: m.hudChipIcon, color: ArtIcon.onDark(icon)),
          SizedBox(width: m.hudChipGap),
          if (widest case final w?) StableText(text, widest: w, style: style) else Text(text, style: style),
        ],
      ),
    );
  }
}

/// [parent] squeezed into its second half: 0 until it is half-way, then 0 to 1.
/// The incoming message eases up in that half; the outgoing one, running the
/// same animation backwards, has faded out by the half-way point.
class _HalfwayFade extends Animation<double> with AnimationWithParentMixin<double> {
  _HalfwayFade(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => ((parent.value - 0.5) * 2).clamp(0.0, 1.0).toDouble();
}
