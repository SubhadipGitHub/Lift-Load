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
import '../widgets/effects.dart';
import '../widgets/glossy.dart';
import '../widgets/lift_shaft.dart';
import '../widgets/lobby.dart';
import '../widgets/play_bar.dart';
import '../widgets/resident_figure.dart';
import '../widgets/result_sheets.dart';
import '../widgets/settings_sheet.dart';

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
  Animation<double> _dy = const AlwaysStoppedAnimation(0);
  Animation<double> _tilt = const AlwaysStoppedAnimation(0);
  Phase? _lastPhase;

  /// The last reveal this screen has played, and who it was.
  late int _seenReveal = c.revealSerial;
  int? _revealedId;
  LiftGame? _revealGame;

  /// Bumped on every phase change, controller swap and dispose; see [_live].
  int _seq = 0;

  /// Where things are on screen, for walks and effects.
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _laneKeys = [];
  final List<GlobalKey> _seatKeys = [];
  final GlobalKey _cabinKey = GlobalKey();
  final GlobalKey _coinKey = GlobalKey();
  final GlobalKey<EffectsLayerState> _effects = GlobalKey();

  /// Residents walking right now, and the ids whose destination copy is
  /// hidden until they land.
  final List<_Flight> _flights = [];
  final Set<int> _hidden = {};

  GameController get c => widget.controller;
  bool get _still => reduceMotion(context);

  /// Walk duration: the same for every resident (weights stay hidden).
  static const int flightMs = 260;

  /// Sparkles in the burst when an unknown person is revealed.
  static const int revealSparkles = 8;

  @override
  void initState() {
    super.initState();
    _lastPhase = c.game.phase;
    c.addListener(_onChange);
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
      _flights.clear();
      _hidden.clear();
      c.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _seq++;
    _anim.dispose();
    _doors.dispose();
    _shake.dispose();
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
    if (!_still) _startFlights(motions);
    _playReveal();
    final phase = c.hasGame ? c.game.phase : null;
    final was = _lastPhase;
    _lastPhase = phase;
    if (phase == was) {
      setState(() {});
      return;
    }
    final seq = ++_seq;
    switch (phase) {
      case Phase.departing:
        if (reward > 0) _coinBurst(reward);
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

  /// Doors close (after a rider still walking in lands), the cabin rises, and
  /// the engine moves on to the next lift. [GameController.finishSend] runs
  /// once, only after both.
  Future<void> _depart(int seq) async {
    if (_flights.isNotEmpty) await Future<void>.delayed(const Duration(milliseconds: flightMs));
    if (!_live(seq)) return;
    await _closeDoors();
    if (!_live(seq)) return;
    await _run(from: 0, to: -CabinMotion.riseDistance, duration: CabinMotion.rise, curve: Curves.easeInCubic);
    if (_live(seq)) c.finishSend();
  }

  /// Let the last rider land, then the cable goes. Still (reduced motion) it
  /// runs without waiting, so no timer is left pending. The doors stay as
  /// they are: nothing delays the crash.
  Future<void> _fall(int seq) async {
    if (!_still) await Future<void>.delayed(const Duration(milliseconds: flightMs));
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
    if (_live(seq)) await _doorsTo(1, CabinMotion.doorOpen);
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
      final toHeight = seat != null ? bench : m.cabinFigure;
      _hidden.add(mo.resident.id);
      _flights.add(_Flight(
        resident: mo.resident,
        // Bottoms of the figure box: the bottom of a seat, the cabin's feet
        // line, or just under the floor tag at the front of a lane.
        from: mo.from.fromBench
            ? from.bottomCenter - Offset(0, 6 * m.scale)
            : from.topCenter + Offset(0, 18 * m.scale + fromHeight),
        to: seat != null
            ? to.bottomCenter - Offset(0, 6 * m.scale)
            : to.bottomCenter - Offset(0, m.cabinFeetInset - toHeight * ResidentFigure.belowFeet),
        fromHeight: fromHeight,
        toHeight: toHeight,
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

  void _coinBurst(int coins) {
    if (_still) return;
    final cabin = _rectOf(_cabinKey);
    final chip = _rectOf(_coinKey);
    if (cabin == null) return;
    _effects.currentState?.add(Burst(
      kind: BurstKind.coins,
      origin: cabin.center,
      target: chip?.center,
      count: coins >= Formulas.perfectTripCoins ? 14 : 8,
      label: '+$coins',
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
    final shaft = AnimatedBuilder(
      animation: Listenable.merge([_anim, _doors]),
      builder: (context, _) => LiftShaft(
        game: g,
        cabinDy: _dy.value * m.scale,
        cabinTilt: _tilt.value,
        doorOpen: _doors.value,
        cabinKey: _cabinKey,
        hiddenIds: _hidden,
        onTapLift: c.tapLift,
        onScale: g.phase == Phase.playing ? c.useScale : null,
        scaleLeft: c.profile.scales,
        scaleReady: c.canUseScale,
      ),
    );
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The message line: a pill that slides up and fades in on each change.
    final message = SizedBox(
      height: m.messageHeight,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: m.gap),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 0 : 220),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Container(
                key: ValueKey(c.message),
                padding: EdgeInsets.symmetric(horizontal: 12 * m.scale, vertical: 3 * m.scale),
                decoration: c.message.isEmpty
                    ? null
                    : BoxDecoration(
                        color: LL.messagePill,
                        borderRadius: BorderRadius.circular(m.messageHeight),
                        border: Border.all(color: LL.messageRim, width: Metrics.messageRim),
                      ),
                child: Text(
                  c.message,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: m.font(13), fontWeight: FontWeight.w800, color: LL.brass),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final hud = _Hud(c: c, onBack: _leave, coinKey: _coinKey);
    final refused = c.refusedSpot;
    final bench = BenchRow(
      game: g,
      onTapSeat: c.tapBench,
      seatKeys: [for (var i = 0; i < g.bench.length; i++) _seatKey(i)],
      hiddenIds: _hidden,
      shakeSerial: refused?.fromBench == true ? c.refuseSerial : 0,
      shakeSeat: refused?.fromBench == true ? refused!.index : null,
    );
    final lanes = QueueLanes(
      game: g,
      onTapLane: c.tapQueue,
      laneKeys: [for (var i = 0; i < g.laneCount; i++) _laneKey(i)],
      shakeSerial: refused?.fromBench == false ? c.refuseSerial : 0,
      shakeLane: refused?.fromBench == false ? refused!.index : null,
      coneSerial: c.coneSerial,
      coneLane: c.coneLane,
      swapping: c.armedPower == Power.swap,
      swapFirst: c.swapFirstLane,
      revealedId: _revealedId,
    );
    // The lobby floor always reaches the bottom of its area, and scrolls when
    // the queues are longer than the screen.
    final lanesArea = LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: lanes),
      ),
    );
    final bottomBar = PlayBottomBar(c: c);

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
                              children: [shaft, message, bench],
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
              shaft,
              message,
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
        body: SafeArea(
          child: IdleClockScope(
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
                    child: body,
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
              ],
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _PlayScreenState.flightMs),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final f = widget.flight;
          final t = Curves.easeInOut.transform(_c.value);
          final h = f.fromHeight + (f.toHeight - f.fromHeight) * t;
          final feet = Offset.lerp(f.from, f.to, t)! -
              Offset(0, 26 * math.sin(math.pi * t) + 2.5 * math.sin(t * math.pi * 6).abs());
          final w = h / designHeight * ResidentLook.designWidth(f.resident.type, f.resident.cargo);
          return Positioned(
            left: feet.dx - w / 2,
            top: feet.dy - h,
            child: IgnorePointer(child: ResidentFigure.of(f.resident, height: h)),
          );
        },
      );
}

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.onBack, required this.coinKey});

  final GameController c;
  final VoidCallback onBack;

  /// The coin chip, where coin bursts fly to.
  final GlobalKey coinKey;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final m = Metrics.of(context);
    final chipGap = SizedBox(width: m.hudChipGap * 2);
    return SizedBox(
      height: m.hudHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: m.hudChipGap * 2),
        child: Row(
          children: [
            GlossyButton(
              style: SurfaceStyle.plum,
              onPressed: onBack,
              tooltip: 'Back to the tower',
              semanticsLabel: 'Back to the tower',
              width: m.hudRound,
              height: m.hudRound,
              inset: false,
              touch: true,
              child: Icon(Icons.arrow_back_rounded, size: m.hudRoundIcon, color: LL.cream),
            ),
            // Level and trips, then lives and coins: each group shrinks before
            // it overflows on the narrowest phones.
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
                        padding: EdgeInsets.symmetric(horizontal: m.gap, vertical: m.hudChipGap),
                        child: Text('Lv ${g.level.number}',
                            style: LL.display.copyWith(fontSize: m.font(19), color: LL.ink)),
                      ),
                      chipGap,
                      Semantics(
                        label: 'Trips left ${g.tripsLeft}',
                        child: ExcludeSemantics(child: _Chip(icon: GameIcon.trip, text: '${g.tripsLeft}')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GlossyButton(
              style: SurfaceStyle.plum,
              onPressed: () => showSettingsSheet(context, c, inLevel: true),
              tooltip: 'Settings',
              semanticsLabel: 'Settings',
              width: m.hudRound,
              height: m.hudRound,
              inset: false,
              touch: true,
              child: Icon(Icons.settings_rounded, size: m.hudRoundIcon, color: LL.cream),
            ),
            Flexible(
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
                    chipGap,
                    Semantics(
                      label: 'Coins ${c.profile.coins}',
                      child: ExcludeSemantics(
                        child: _Chip(key: coinKey, icon: GameIcon.coin, text: '${c.profile.coins}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dark HUD pill: an approved icon and a number.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.text});

  final GameIcon icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Glossy(
      style: SurfaceStyle.chip,
      depth: SurfaceDepth.chip,
      inset: false,
      padding: EdgeInsets.fromLTRB(m.hudChipGap, m.hudChipGap, m.hudChipGap * 3, m.hudChipGap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // An ink fallback would vanish on the dark pill.
          ArtIcon(icon, size: m.hudChipIcon, color: ArtIcon.onDark(icon)),
          SizedBox(width: m.hudChipGap),
          Text(text, style: LL.display.copyWith(fontSize: m.font(15), color: LL.cream)),
        ],
      ),
    );
  }
}
