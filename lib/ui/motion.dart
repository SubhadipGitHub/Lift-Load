/// Shared motion: one idle clock for every looping animation, and helpers
/// that respect the platform's reduce-motion setting
/// (`MediaQuery.disableAnimations`). With motion reduced nothing loops,
/// nothing shakes and every transition is instant, which also keeps widget
/// tests deterministic.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// True when the platform (or a test) asks for reduced motion.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A duration that collapses to zero under reduced motion.
Duration motionMs(BuildContext context, int ms) => Duration(milliseconds: reduceMotion(context) ? 0 : ms);

/// The cabin's timings and door looks, in one place for the play screen and
/// its tests (PRD v1.7, `docs/art/gemini-art-pack.md`, "Doors, in two
/// leaves"). Send runs: doors close, the cabin rises, the engine moves on, the
/// next cabin drops in, its doors open. A crash leaves the doors as they are.
/// Under reduced motion every step is instant.
abstract final class CabinMotion {
  /// The doors close in this long, ease-in-out, ending with [doorSettle].
  static const Duration doorClose = Duration(milliseconds: 420);

  /// The last part of [doorClose]: the leaves bounce back
  /// [Metrics.doorSettle] from the seam and meet again.
  static const Duration doorSettle = Duration(milliseconds: 80);

  /// The leaves' travel to the seam, before the settle.
  static Duration get doorTravel => doorClose - doorSettle;

  /// The whole close as one curve: [doorCurve] to the seam over
  /// [doorTravel], then a bounce back of [settle] (a fraction of the leaf's
  /// travel) and shut again.
  static Curve doorCloseCurve(double settle) => _DoorClose(
        travel: doorTravel.inMicroseconds / doorClose.inMicroseconds,
        settle: settle,
      );

  /// The next cabin's doors open in this long, ease-in-out, once it stops.
  static const Duration doorOpen = Duration(milliseconds: 360);
  static const Curve doorCurve = Curves.easeInOut;

  /// Closed doors dim the interior (and the riders) by this much; the dim
  /// follows the leaves.
  static const double closedDim = 0.12;

  /// Darkest point of the shadow on each leaf's seam edge, fully closed; it
  /// fades as the doors open.
  static const double seamShadow = 0.45;

  /// The cabin rises out of the shaft, and the next one drops in.
  static const Duration rise = Duration(milliseconds: 500);
  static const Duration dropIn = Duration(milliseconds: 450);

  /// After an overload: the fall, and the repaired cabin springing back.
  static const Duration fall = Duration(milliseconds: 1000);
  static const Duration repair = Duration(milliseconds: 450);

  /// Design units the cabin travels: up and out on a send, down on a crash.
  static const double riseDistance = 300;
  static const double fallDistance = 340;
  static const double fallTilt = -0.09;

  /// Design units below its stop that the repaired cabin springs back from.
  static const double repairDistance = 120;

  /// Send to the next cabin's open doors with motion on (a walker still
  /// landing adds the walk).
  static Duration get sendTotal => doorClose + rise + dropIn + doorOpen;
}

class _DoorClose extends Curve {
  const _DoorClose({required this.travel, required this.settle});

  /// Share of the time spent travelling, and the bounce as a share of the travel.
  final double travel, settle;

  @override
  double transformInternal(double t) {
    if (t <= travel) return CabinMotion.doorCurve.transform(t / travel);
    return 1 - settle * math.sin(math.pi * (t - travel) / (1 - travel));
  }
}

/// Provides seconds since start to [IdleClock.of]. One ticker drives every
/// sway, blink, pulse and drifting cloud below it. It does not tick at all
/// when motion is reduced.
class IdleClockScope extends StatefulWidget {
  const IdleClockScope({super.key, required this.child});

  final Widget child;

  @override
  State<IdleClockScope> createState() => _IdleClockScopeState();
}

class _IdleClockScopeState extends State<IdleClockScope> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier(0);
  late final Ticker _ticker = createTicker((elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6);
  bool _still = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = reduceMotion(context);
    if (_still && _ticker.isActive) _ticker.stop();
    if (!_still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _IdleClock(clock: _still ? null : _seconds, child: widget.child);
}

class _IdleClock extends InheritedWidget {
  const _IdleClock({required this.clock, required super.child});

  final ValueListenable<double>? clock;

  @override
  bool updateShouldNotify(_IdleClock old) => old.clock != clock;
}

abstract final class IdleClock {
  /// Seconds since the nearest [IdleClockScope] started, or null when there
  /// is none or motion is reduced.
  static ValueListenable<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_IdleClock>()?.clock;
}

/// Idle life for a waiting figure: a gentle sway and breathing bob, de-synced
/// by [seed], plus a blink every few seconds. The sway is a transform around
/// a cached child, and the child (the figure) is rebuilt only when a blink
/// starts or ends, so an idle lobby costs a repaint per frame, not a rebuild.
class IdleSway extends StatefulWidget {
  const IdleSway({super.key, required this.seed, required this.builder, this.amplitude = 1});

  final int seed;
  final double amplitude;
  final Widget Function(BuildContext context, bool blink) builder;

  @override
  State<IdleSway> createState() => _IdleSwayState();
}

class _IdleSwayState extends State<IdleSway> {
  ValueListenable<double>? _clock;
  final ValueNotifier<bool> _blink = ValueNotifier(false);

  double get _phase => (widget.seed * 0.618) % 1.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clock = IdleClock.of(context);
    if (clock == _clock) return;
    _clock?.removeListener(_tick);
    _clock = clock;
    _clock?.addListener(_tick);
    if (clock == null) _blink.value = false;
  }

  void _tick() {
    final blinkEvery = 3.2 + (widget.seed * 0.37) % 2.6;
    _blink.value = (_clock!.value + _phase * blinkEvery) % blinkEvery < 0.13;
  }

  @override
  void dispose() {
    _clock?.removeListener(_tick);
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock;
    if (clock == null) return widget.builder(context, false);
    return AnimatedBuilder(
      animation: clock,
      builder: (context, child) {
        final t = clock.value;
        final sway = math.sin((t / 2.9 + _phase) * 2 * math.pi) * 0.022 * widget.amplitude;
        final bob = (math.sin((t / 1.6 + _phase) * 2 * math.pi) + 1) * 0.6 * widget.amplitude;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(0, -bob, 0, 1)
            ..rotateZ(sway),
          child: child,
        );
      },
      child: RepaintBoundary(
        child: ValueListenableBuilder<bool>(
          valueListenable: _blink,
          builder: (context, blink, _) => widget.builder(context, blink),
        ),
      ),
    );
  }
}

/// Plays a short horizontal shake each time [serial] changes (a refused
/// resident shaking their head, the cones wobbling). Still under reduced
/// motion.
class Shake extends StatelessWidget {
  const Shake({super.key, required this.serial, required this.child, this.distance = 6});

  final int serial;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (serial == 0 || reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(serial),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(math.sin(v * math.pi * 5) * distance * (1 - v), 0),
        child: child,
      ),
      child: child,
    );
  }
}
