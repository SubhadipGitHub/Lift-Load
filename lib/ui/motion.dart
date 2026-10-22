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
  static Duration get sendTotal => doorClose + PunchMotion.bump + rise + dropIn + doorOpen;
}

/// The punch on Send and the small life in the lobby (style frame, "Punch"):
/// the cabin bump, the score slam, the coin fly and the coin pill's pulse,
/// the free seats breathing and the selected resident's hop. Amplitudes are
/// in design units (times `Metrics.scale`) or plain factors. Under reduced
/// motion none of it plays: the bump, slam and coins are skipped, the seat
/// glow and the hop's glow hold still.
abstract final class PunchMotion {
  /// The cabin bumps once its doors are shut, before it rises: down and a
  /// little squashed at [bumpDownAt], back up past rest at [bumpUpAt], then
  /// still. Short, so a send is only this much slower than before.
  static const Duration bump = Duration(milliseconds: 140);
  static const double bumpDownAt = 0.3;
  static const double bumpUpAt = 0.6;
  static const double bumpDrop = 3;
  static const double bumpRebound = 2;
  static const double bumpStretchX = 0.01;
  static const double bumpSquashY = 0.015;

  /// The bump at [t] (0 to 1): how far down the cabin sits (design units,
  /// negative is up) and its horizontal and vertical scale.
  static ({double dy, double sx, double sy}) bumpAt(double t) {
    if (t <= 0 || t >= 1) return (dy: 0, sx: 1, sy: 1);
    double ease(double x) => Curves.easeInOut.transform(x.clamp(0, 1).toDouble());
    if (t < bumpDownAt) {
      final k = ease(t / bumpDownAt);
      return (dy: bumpDrop * k, sx: 1 + bumpStretchX * k, sy: 1 - bumpSquashY * k);
    }
    if (t < bumpUpAt) {
      final k = ease((t - bumpDownAt) / (bumpUpAt - bumpDownAt));
      return (
        dy: bumpDrop + (-bumpRebound - bumpDrop) * k,
        sx: 1 + bumpStretchX * (1 - k),
        sy: 1 - bumpSquashY * (1 - k),
      );
    }
    final k = ease((t - bumpUpAt) / (1 - bumpUpAt));
    return (dy: -bumpRebound * (1 - k), sx: 1, sy: 1);
  }

  /// The trip's score slams in over the shaft as the cabin bumps: it grows
  /// from [slamFrom] with an overshoot over [slamIn], holds, then fades over
  /// [slamOut] while it drifts up `Metrics.slamRise`. It runs on through the
  /// rise and the next lift's arrival; it never holds up the send.
  static const Duration slamIn = Duration(milliseconds: 320);
  static const Duration slamHold = Duration(milliseconds: 640);
  static const Duration slamOut = Duration(milliseconds: 260);
  static Duration get slam => slamIn + slamHold + slamOut;
  static const double slamFrom = 0.4;

  /// Overshoot for the slam (CSS `cubic-bezier(.3, 1.8, .5, 1)`).
  static const Curve slamCurve = Cubic(0.3, 1.8, 0.5, 1);

  /// The slam at [t] (0 to 1 of [slam]): its scale, opacity, and how far it
  /// has drifted up (0 to 1 of `Metrics.slamRise`).
  static ({double scale, double opacity, double rise}) slamAt(double t) {
    final inEnd = slamIn.inMicroseconds / slam.inMicroseconds;
    final outStart = (slamIn + slamHold).inMicroseconds / slam.inMicroseconds;
    final grow = slamCurve.transform((t / inEnd).clamp(0, 1).toDouble());
    final fade = ((t - outStart) / (1 - outStart)).clamp(0, 1).toDouble();
    return (
      scale: slamFrom + (1 - slamFrom) * grow,
      opacity: (t / inEnd * 2).clamp(0, 1).toDouble() * (1 - Curves.easeIn.transform(fade)),
      rise: Curves.easeOut.transform((t / inEnd).clamp(0, 1).toDouble()),
    );
  }

  /// Coins fly from the cabin to the HUD coin pill on a good or perfect trip;
  /// they all land at the end of [coinFly], and the pill pulses up to
  /// [pillPulseScale] and back over [pillPulse].
  static const Duration coinFly = Duration(milliseconds: 900);

  /// Coins in the flight: more for a perfect trip than a good one.
  static const int coinsPerfect = 14;
  static const int coinsGood = 8;
  static const Duration pillPulse = Duration(milliseconds: 280);
  static const double pillPulseScale = 1.18;

  /// A free seat that can take the selected resident breathes: its glow
  /// swells and it grows by up to [seatBreatheScale], once per [seatBreathe].
  static const double seatBreathe = 1.4;
  static const double seatBreatheScale = 0.03;

  /// The selected resident hops [hopHeight] design units, once per [hop]
  /// seconds, on a warm glow.
  static const double hop = 1.1;
  static const double hopHeight = 5;

  /// 0 to 1 and back, once per [period] seconds, starting at 0 (an
  /// ease-in-out loop like the CSS keyframes).
  static double loop(double seconds, double period) => 0.5 - 0.5 * math.cos(seconds / period * 2 * math.pi);
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
