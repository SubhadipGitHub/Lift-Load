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

/// A damped spring from 0 to 1 as a curve: it starts at rest, overshoots by
/// [overshoot] (a share of the travel) and settles before 1. The same for
/// every use, so two movements with the same curve overshoot the same way.
class SpringCurve extends Curve {
  const SpringCurve({this.rate = 9, this.frequency = 9});

  /// How fast the swing dies out, and how fast it swings (per unit of t).
  final double rate, frequency;

  /// The first peak past 1, as a share of the travel.
  double get overshoot => math.exp(-rate * math.pi / frequency);

  @override
  double transformInternal(double t) =>
      1 - math.exp(-rate * t) * (math.cos(frequency * t) + rate / frequency * math.sin(frequency * t));
}

/// The curves the polish pass shares.
abstract final class MotionCurves {
  /// A soft landing: about 4% past, settled by the end.
  static const SpringCurve soft = SpringCurve(rate: 9, frequency: 9);

  /// A pop: about 16% past.
  static const SpringCurve pop = SpringCurve(rate: 7, frequency: 12);

  /// A walk: quick start, eases into the spot with a hair of overshoot.
  static const Curve walk = Cubic(0.3, 0.55, 0.35, 1.22);
}

/// Screen entrance when a level starts (PRD v1.7 polish pass, slice B): the
/// HUD drops in, the shaft fades and scales in, the bench rises, each lane's
/// people rise with a soft spring (front rows first, lane by lane) and the
/// bottom bar slides up. About [total] from the first frame to the last
/// settle. It never blocks input (a touch finishes it at once) and is skipped
/// under reduced motion. Timings are in ms from the start; distances in
/// design units (times `Metrics.scale`).
abstract final class EntranceMotion {
  static const Duration total = Duration(milliseconds: 700);

  static const int hudStart = 0, hudMs = 320;
  static const int shaftStart = 60, shaftMs = 380;
  static const int benchStart = 200, benchMs = 340;
  static const int barStart = 280, barMs = 360;

  /// A person starts [laneStart] + lane * [laneStagger] + row * [rowStagger]
  /// ms in and takes [personMs]: the front row of each lane first.
  static const int laneStart = 130, laneStagger = 28, rowStagger = 36, personMs = 300;

  static const double hudDrop = 22;
  static const double barRise = 36;
  static const double benchRise = 14;
  static const double shaftRise = 10;
  static const double shaftFrom = 0.95;
  static const double personRise = 20;

  /// The slice of [total] from [startMs] for [ms], eased by [curve].
  static Interval span(int startMs, int ms, [Curve curve = Curves.easeOutCubic]) => Interval(
        startMs / total.inMilliseconds,
        math.min((startMs + ms) / total.inMilliseconds, 1),
        curve: curve,
      );

  /// When the person [row] places back in lane [lane] begins, in ms.
  static int personStart(int lane, int row) => laneStart + lane * laneStagger + row * rowStagger;

  /// The curve one person follows over the entrance.
  static Interval person(int lane, int row) => span(personStart(lane, row), personMs, MotionCurves.soft);

  /// The last person (five lanes, five rows deep) is done inside [total].
  static int get latestEnd => personStart(4, 4) + personMs;
}

/// Buttons: a springy press, a gloss sweep when it is let go, and the ready
/// pulse on Send in the green zone and better.
abstract final class ButtonMotion {
  /// A pressed control shrinks to this and goes down in [pressIn]; let go, it
  /// springs back past 1 (underdamped) and rests.
  static const double pressedScale = 0.95;
  static const Duration pressIn = Duration(milliseconds: 90);
  static const SpringDescription release = SpringDescription(mass: 1, stiffness: 700, damping: 16);

  /// The sweep: a slanted band of light crosses the face once on release.
  static const Duration sweep = Duration(milliseconds: 420);
  static const double sweepWidth = 0.34;
  static const double sweepSlant = 0.5;

  /// Send, ready: one swell per [readyPeriod] seconds. The glow is [readyBlur]
  /// design units soft and swells to [readyGlow] of its colour; the button
  /// grows by up to [readyScale].
  static const double readyPeriod = 1.5;
  static const double readyBlur = 16;
  static const double readySpread = 2;
  static const double readyGlow = 0.9;
  static const double readyScale = 0.022;
}

/// A resident walking from a lane or a seat to a seat or the cabin, and what
/// the target does as they arrive. The same for everyone, whoever it is.
abstract final class BoardMotion {
  /// The walk's length; the engine's state has already moved on.
  static const int flightMs = 260;
  static const Duration flight = Duration(milliseconds: flightMs);

  /// Design units: the height of the arc, and the little step bobs.
  static const double arc = 26;
  static const double bob = 2.5;
  static const int steps = 6;

  /// How high the walker is above the straight line at [t] (0 to 1 of the
  /// walk), in design units: one low arc and the little step bobs, nothing at
  /// either end.
  static double riseAt(double t) =>
      arc * math.sin(math.pi * t) + bob * math.sin(t * math.pi * steps).abs();

  /// On landing the figure squashes by [landSquash] (and widens by
  /// [landStretch]) and springs back, over [land].
  static const Duration land = Duration(milliseconds: 280);
  static const double landSquash = 0.06;
  static const double landStretch = 0.03;

  /// The ring of light under the target starts [ringAt] of the way through
  /// the walk and lasts [ring]; [ringRadius] design units wide at the end,
  /// [ringFlat] as tall as wide.
  static const double ringAt = 0.55;
  static const Duration ring = Duration(milliseconds: 460);
  static const double ringRadius = 36;
  static const double ringFlat = 0.3;
  static const double ringStroke = 2;

  /// People behind a lane front step up: [stepMs] each on a soft spring, the
  /// one nearest the front first, [stepStagger] ms apart.
  static const int stepMs = 320;
  static const int stepStagger = 38;
}

/// The load gauge: the needle's fixed swing, the pulse on a zone change and
/// the breath at the limit. Nothing here scales with how much load arrived.
abstract final class GaugeMotion {
  /// The needle reaches its mark in [arrive] of [needle], then swings
  /// [overshoot] (a fixed share of capacity, in the direction it travelled)
  /// past it and back, whatever the distance.
  static const Duration needle = Duration(milliseconds: 620);
  static const double arrive = 0.55;
  static const double overshoot = 0.03;

  /// The needle at [t] (0 to 1) on its way from [from] to [to].
  static double needleAt(double from, double to, double t) {
    if (t >= 1 || from == to) return to;
    final go = Curves.easeOutCubic.transform((t / arrive).clamp(0, 1).toDouble());
    final swing = t <= arrive ? 0.0 : math.sin(math.pi * (t - arrive) / (1 - arrive));
    return from + (to - from) * go + (to > from ? 1 : -1) * overshoot * swing;
  }

  /// A zone change into the green or red pulses the glow once.
  static const Duration zonePulse = Duration(milliseconds: 560);
  static const double wordPop = 0.1;

  /// At the limit the glow breathes by [limitBreath] every [limitPeriod] s.
  static const double limitPeriod = 1.6;
  static const double limitBreath = 0.12;
}

/// The lift's floor display and the chime when a lift arrives.
abstract final class FloorMotion {
  /// The old floors slide up and out while the new ones slide up in.
  static const Duration roll = Duration(milliseconds: 340);

  /// How far they slide, as a share of the display text's height.
  static const double rollTravel = 1.0;

  /// The chime light on the cabin's top: the display and the cabin's top
  /// edge flash once as the lift stops, over [chime].
  static const Duration chime = Duration(milliseconds: 520);
  static const double chimeGlow = 0.85;
  static const double chimeBlur = 14;
  static const double chimeWash = 0.3;
  static const double chimeWashDepth = 0.34;
  static const double chimePop = 0.07;
}

/// The ride: the backdrop slides against the cabin's travel, the rails'
/// brackets run past and faint streaks fall beside the cabin. All of it
/// follows the cabin's offset, so it stops the moment the cabin does.
abstract final class RideMotion {
  /// The backdrop moves this share of the cabin's travel the other way.
  static const double parallax = 0.14;
  static const int streaks = 11;
  static const double streakLength = 44;
  static const double streakWidth = 1.6;

  /// Peak alpha of a streak at full speed, in the streak colour.
  static const double streakAlpha = 0.5;

  /// The share of the cabin's travel at which the streaks are at full alpha.
  static const double streakFull = 0.5;
}

/// The win and fail sheets: the card springs in, then its parts appear one by
/// one, [stage] ms apart.
abstract final class SheetMotion {
  static const Duration card = Duration(milliseconds: 380);
  static const double cardFrom = 0.8;
  static const int firstAt = 160, stage = 95, partMs = 320;
  static const double partRise = 12;
  static const double titleFrom = 0.7;
  static const Duration total = Duration(milliseconds: 1100);

  /// The coin count on the win sheet starts this long after its pill begins.
  static const int countAfter = 120;

  /// The ms at which part [i] (counting from 0) starts.
  static int startOf(int i) => firstAt + stage * i;

  static Interval part(int i, [Curve curve = Curves.easeOutCubic]) => Interval(
        startOf(i) / total.inMilliseconds,
        math.min((startOf(i) + partMs) / total.inMilliseconds, 1),
        curve: curve,
      );
}

/// A number that counts up (or down) to its new value and bounces.
abstract final class CountMotion {
  static const Duration count = Duration(milliseconds: 700);
  static const Duration bounce = Duration(milliseconds: 320);
  static const double bounceScale = 0.12;

  /// How many ticks a count plays (for the tick cue).
  static const int ticks = 8;
}

/// An unknown person reaching the front: the ghost dissolves into the real
/// figure, which pops in, in a flash of light. The same for everyone.
abstract final class RevealMotion {
  static const Duration pop = Duration(milliseconds: 380);
  static const double popFrom = 0.6;
  static const Duration ghost = Duration(milliseconds: 260);
  static const Duration flash = Duration(milliseconds: 460);
  static const double flashRadius = 0.9;
  static const double flashAlpha = 0.8;
}

/// The home screen: its parts rise in one after another, the Play button
/// breathes with a glow, and cleared windows twinkle.
abstract final class HomeMotion {
  static const Duration total = Duration(milliseconds: 900);
  static const int stage = 90, partMs = 420;
  static const double partRise = 16;
  static const double titleFrom = 0.9;

  static Interval part(int i, [Curve curve = Curves.easeOutCubic]) => Interval(
        stage * i / total.inMilliseconds,
        math.min((stage * i + partMs) / total.inMilliseconds, 1),
        curve: curve,
      );

  /// The coin total waits this long after coming back from a level, then counts.
  static const Duration coinsAfter = Duration(milliseconds: 320);

  /// The Play button: one swell per [playPeriod] s, the scale as before.
  static const double playPeriod = 1.8;
  static const double playScale = 0.025;
  static const double playBlur = 20;
  static const double playGlow = 0.75;

  /// A cleared window twinkles every [twinklePeriod] s, de-synced by its
  /// index; only [twinkleShare] of them light up at once.
  static const double twinklePeriod = 3.4;
  static const double twinkleShare = 0.18;
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
