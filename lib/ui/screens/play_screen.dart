import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/resident_painter.dart';
import '../theme.dart';
import '../widgets/effects.dart';
import '../widgets/lift_shaft.dart';
import '../widgets/lobby.dart';
import '../widgets/pressable.dart';
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

  /// Where things are on screen, for walks and effects.
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _laneKeys = List.generate(4, (_) => GlobalKey());
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
      _lastPhase = c.game.phase;
      _snapHome();
      _flights.clear();
      _hidden.clear();
      c.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _anim.dispose();
    _doors.dispose();
    _shake.dispose();
    super.dispose();
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
    final phase = c.hasGame ? c.game.phase : null;
    final was = _lastPhase;
    _lastPhase = phase;
    if (phase == was) {
      setState(() {});
      return;
    }
    switch (phase) {
      case Phase.departing:
        if (reward > 0) _coinBurst(reward);
        _doorsTo(0, 180).then((_) => _run(from: 0, to: -300, ms: 500, curve: Curves.easeInCubic)).then((_) {
          if (mounted) c.finishSend();
        });
      case Phase.falling:
        // Let the last rider land, then the cable goes.
        void drop() {
          if (!mounted) return;
          _crashEffects();
          _run(from: 0, to: 340, tiltTo: -0.09, ms: 1000, curve: Curves.easeInQuad).then((_) {
            if (mounted) c.finishCrash();
          });
        }

        if (_still) {
          drop();
        } else {
          Future<void>.delayed(const Duration(milliseconds: flightMs), drop);
        }
      case Phase.playing when was == Phase.departing:
        // The next lift drops in, then opens its doors.
        _doors.value = 0;
        _run(from: -300, to: 0, ms: 450, curve: Curves.easeOutBack).then((_) => _doorsTo(1, 180));
      case Phase.playing when was == Phase.failed:
        // The repaired lift springs back.
        _doors.value = 1;
        _run(from: 120, to: 0, ms: 450, curve: Curves.easeOutBack);
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

  void _snapHome() {
    _anim.stop();
    _dy = const AlwaysStoppedAnimation(0);
    _tilt = const AlwaysStoppedAnimation(0);
    _doors.value = 1;
  }

  Future<void> _run(
      {required double from, required double to, double tiltTo = 0, required int ms, required Curve curve}) {
    final curved = CurvedAnimation(parent: _anim, curve: curve);
    _dy = Tween(begin: from, end: to).animate(curved);
    _tilt = Tween(begin: 0.0, end: tiltTo).animate(curved);
    _anim
      ..duration = Duration(milliseconds: _still ? 0 : ms)
      ..reset();
    return _anim.forward().orCancel.catchError((Object _) {});
  }

  Future<void> _doorsTo(double target, int ms) =>
      _doors.animateTo(target, duration: Duration(milliseconds: _still ? 0 : ms)).orCancel.catchError((Object _) {});

  void _startFlights(List<Motion> motions) {
    if (motions.isEmpty) return;
    final m = Metrics.of(context);
    for (final mo in motions) {
      final from = mo.from.fromBench ? _rectOf(_seatKey(mo.from.index)) : _rectOf(_laneKeys[mo.from.index]);
      final seat = mo.to.seat;
      final to = seat != null ? _rectOf(_seatKey(seat)) : _rectOf(_cabinKey);
      if (from == null || to == null) continue;
      final fromHeight = mo.from.fromBench ? m.benchFigure : m.laneFigure;
      final toHeight = seat != null ? m.benchFigure : m.cabinFigure;
      _hidden.add(mo.resident.id);
      _flights.add(_Flight(
        resident: mo.resident,
        // Feet positions: the bottom of a seat, the cabin floor, or just under
        // the floor tag at the front of a lane.
        from: mo.from.fromBench
            ? from.bottomCenter - Offset(0, 6 * m.scale)
            : from.topCenter + Offset(0, 18 * m.scale + fromHeight),
        to: to.bottomCenter - Offset(0, (seat != null ? 6 : 14) * m.scale),
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

  void _coinBurst(int coins) {
    if (_still) return;
    final cabin = _rectOf(_cabinKey);
    final chip = _rectOf(_coinKey);
    if (cabin == null) return;
    _effects.currentState?.add(Burst(
      kind: BurstKind.coins,
      origin: cabin.center,
      target: chip?.center,
      count: coins >= 15 ? 14 : 8,
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
        onSend: c.send,
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
                decoration: BoxDecoration(
                  color: c.message.isEmpty ? null : const Color(0x401E1B3A),
                  borderRadius: BorderRadius.circular(999),
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
    final bench = BenchRow(
      game: g,
      onTapSeat: c.tapBench,
      seatKeys: [for (var i = 0; i < g.bench.length; i++) _seatKey(i)],
      hiddenIds: _hidden,
      shakeSerial: c.refused?.fromBench == true ? c.refuseSerial : 0,
      shakeSeat: c.refused?.fromBench == true ? c.refused!.index : null,
    );
    final lanes = QueueLanes(
      game: g,
      onTapLane: c.tapQueue,
      laneKeys: _laneKeys,
      shakeSerial: c.refused?.fromBench == false ? c.refuseSerial : 0,
      shakeLane: c.refused?.fromBench == false ? c.refused!.index : null,
      coneSerial: c.coneSerial,
      coneLane: c.coneLane,
    );
    // The lobby floor always reaches the bottom of its area, and scrolls when
    // the queues are longer than the screen.
    final lanesArea = LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: lanes),
      ),
    );
    final toolbar = _Toolbar(c: c);

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
                    toolbar,
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
              toolbar,
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
                if (g.phase == Phase.won) WinSheet(c: c),
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
          final w = h / 120 * ResidentLook.designWidth(f.resident.type, f.resident.cargo);
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
    return SizedBox(
      height: m.hudHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8 * m.scale),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to the tower',
              onPressed: onBack,
              iconSize: 24 * m.textScale,
              visualDensity: m.form == FormFactor.compactPhone ? VisualDensity.compact : null,
              icon: const Icon(Icons.arrow_back_rounded, color: LL.cream),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12 * m.scale, vertical: 1),
                  decoration: BoxDecoration(color: LL.brass, borderRadius: BorderRadius.circular(999)),
                  child: Text('Lv ${g.level.number}', style: LL.display.copyWith(fontSize: m.font(19), color: LL.ink)),
                ),
              ),
            ),
            SizedBox(width: 8 * m.scale),
            Expanded(
              child: Text(
                'Trips left ${g.tripsLeft}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.lilac),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => showSettingsSheet(context, c),
              iconSize: 22 * m.textScale,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.settings_rounded, color: LL.lilac),
            ),
            // Lives and coins shrink before they overflow on the narrowest phones.
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chip(icon: Icons.favorite_rounded, color: LL.alarm, text: '${c.profile.lives}'),
                    SizedBox(width: 6 * m.scale),
                    _Chip(
                      key: coinKey,
                      icon: Icons.monetization_on_rounded,
                      color: LL.brass,
                      text: '${c.profile.coins}',
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

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(7 * m.scale, 4 * m.scale, 10 * m.scale, 4 * m.scale),
      decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16 * m.textScale, color: color),
          SizedBox(width: 5 * m.scale),
          Text(text, style: TextStyle(fontSize: m.font(13), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final playing = c.game.phase == Phase.playing;
    final m = Metrics.of(context);
    Widget tool({required IconData icon, required String label, required VoidCallback? onTap, String? tooltip}) =>
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5 * m.scale),
            child: Tooltip(
              message: tooltip ?? label,
              child: PressScale(
                enabled: onTap != null,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: Icon(icon, size: 20 * m.textScale),
                  label: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: m.font(13))),
                  style: FilledButton.styleFrom(
                    backgroundColor: LL.facade,
                    foregroundColor: LL.cream,
                    disabledBackgroundColor: LL.facade.withValues(alpha: 0.5),
                    minimumSize: Size.fromHeight(m.toolbarHeight - 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * m.scale)),
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      height: m.toolbarHeight,
      color: LL.deep,
      padding: EdgeInsets.symmetric(horizontal: 8 * m.scale),
      child: Row(
        children: [
          tool(
            icon: Icons.scale_rounded,
            label: 'Scale · ${c.profile.scales}',
            tooltip: 'Preview where the selected resident would put the needle',
            onTap: playing ? c.useScale : null,
          ),
          tool(
            icon: Icons.restart_alt_rounded,
            label: c.levelInProgress
                ? (m.form == FormFactor.compactPhone ? 'Restart −1♥' : 'Restart · 1 life')
                : 'Restart',
            tooltip: c.levelInProgress ? 'Start over. You have made moves, so this costs 1 life' : 'Start over',
            onTap: playing && c.canRestart ? c.restart : null,
          ),
        ],
      ),
    );
  }
}
