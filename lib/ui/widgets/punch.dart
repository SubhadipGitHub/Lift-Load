/// The punch on Send and the small life in the lobby (style frame, "Punch"):
/// the score slam over the shaft, the coin pill's pulse, a free seat
/// breathing and the selected resident's hop on a warm glow. Timings and
/// amplitudes live in [PunchMotion], sizes in [Metrics], colours in [LL].
/// Nothing here moves under reduced motion, and nothing says anything about
/// a weight: the slam shows the trip's rating and coins, which the message
/// line already gives.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../layout.dart';
import '../motion.dart';
import '../theme.dart';

/// The trip's score at [progress] (0 to 1 of [PunchMotion.slam]): the coins
/// ("+15") over the rating ("PERFECT LOAD!"); a half-empty trip shows only
/// its rating, quieter. Decorative: the message line announces the rating.
class ScoreSlam extends StatelessWidget {
  const ScoreSlam({super.key, required this.rating, required this.coins, required this.progress});

  final TripRating rating;
  final int coins;
  final double progress;

  static String label(TripRating rating) => switch (rating) {
        TripRating.perfect => 'PERFECT LOAD!',
        TripRating.good => 'GOOD TRIP',
        TripRating.halfEmpty => 'HALF-EMPTY TRIP',
      };

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final f = PunchMotion.slamAt(progress);
    final rewarded = coins > 0;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Center(
          child: Transform.translate(
            offset: Offset(0, -m.slamRise * f.rise),
            child: Opacity(
              opacity: f.opacity,
              child: Transform.scale(
                scale: f.scale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rewarded)
                        _Outlined(
                          '+$coins',
                          size: m.slamFont,
                          fill: LL.brassHi,
                          stroke: LL.slamStroke,
                          width: m.slamStroke,
                          shadows: [
                            Shadow(color: LL.brassDrop, offset: Offset(0, m.slamDrop)),
                            Shadow(color: LL.slamGlow, blurRadius: m.slamGlow),
                          ],
                        ),
                      _Outlined(
                        label(rating),
                        size: m.slamSubFont,
                        fill: rewarded ? LL.creamHi : LL.lilac,
                        stroke: rewarded ? LL.slamSubStroke : LL.plumEdge,
                        width: m.slamSubStroke,
                        letterSpacing: m.slamSubFont * Metrics.slamSubTracking,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Display text with a thick outline painted under its fill.
class _Outlined extends StatelessWidget {
  const _Outlined(
    this.text, {
    required this.size,
    required this.fill,
    required this.stroke,
    required this.width,
    this.letterSpacing = 0,
    this.shadows = const [],
  });

  final String text;
  final double size, width, letterSpacing;
  final Color fill, stroke;
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    final base = LL.display.copyWith(fontSize: size, letterSpacing: letterSpacing);
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            shadows: shadows,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(text, style: base.copyWith(color: fill)),
      ],
    );
  }
}

/// Grows [child] a little and back each time [serial] changes (the coin pill
/// when the flying coins land). Still under reduced motion.
class Pulse extends StatelessWidget {
  const Pulse({super.key, required this.serial, required this.child});

  final int serial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (serial == 0 || reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(serial),
      tween: Tween(begin: 0, end: 1),
      duration: PunchMotion.pillPulse,
      builder: (context, v, child) =>
          Transform.scale(scale: 1 + (PunchMotion.pillPulseScale - 1) * math.sin(math.pi * v), child: child),
      child: child,
    );
  }
}

/// A free bench seat that can take the selected resident: [builder] gets the
/// breath (0 to 1) for its glow, and the seat grows by up to
/// [PunchMotion.seatBreatheScale] with it. Inactive, or under reduced motion,
/// it holds still at full glow.
class Breathe extends StatelessWidget {
  const Breathe({super.key, required this.active, required this.builder});

  final bool active;
  final Widget Function(BuildContext context, double breath) builder;

  @override
  Widget build(BuildContext context) {
    final clock = active ? IdleClock.of(context) : null;
    if (clock == null) return builder(context, 1);
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, t, _) {
        final breath = PunchMotion.loop(t, PunchMotion.seatBreathe);
        return Transform.scale(
          scale: 1 + PunchMotion.seatBreatheScale * breath,
          child: builder(context, breath),
        );
      },
    );
  }
}

/// The selected resident hops [PunchMotion.hopHeight] once per
/// [PunchMotion.hop], starting from rest when selected. Inactive, or under
/// reduced motion, it holds still.
class SelectedHop extends StatefulWidget {
  const SelectedHop({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<SelectedHop> createState() => _SelectedHopState();
}

class _SelectedHopState extends State<SelectedHop> {
  /// The idle clock's time when this hop started, so it lifts off from rest.
  double? _start;

  @override
  Widget build(BuildContext context) {
    final clock = widget.active ? IdleClock.of(context) : null;
    if (clock == null) {
      _start = null;
      return widget.child;
    }
    _start ??= clock.value;
    final height = PunchMotion.hopHeight * Metrics.of(context).scale;
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      child: widget.child,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -height * PunchMotion.loop(t - _start!, PunchMotion.hop)),
        child: child,
      ),
    );
  }
}

/// The warm glow under the selected resident (style frame,
/// `.front.sel::before`), painted behind [child] and a little past its box.
class HopGlow extends StatelessWidget {
  const HopGlow({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => active ? CustomPaint(painter: const HopGlowPainter(), child: child) : child;
}

class HopGlowPainter extends CustomPainter {
  const HopGlowPainter();

  /// The glow's oval for a figure box of [size].
  static Rect ovalFor(Size size) => Rect.fromLTRB(
        -size.width * Metrics.hopGlowSide,
        size.height * Metrics.hopGlowTop,
        size.width * (1 + Metrics.hopGlowSide),
        size.height * (1 + Metrics.hopGlowBelow),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final oval = ovalFor(size);
    canvas.drawOval(
      oval,
      Paint()
        ..shader = const RadialGradient(
          colors: [LL.hopGlowCore, LL.hopGlowMid, LL.hopGlowEdge],
          stops: Metrics.hopGlowStops,
        ).createShader(oval),
    );
  }

  @override
  bool shouldRepaint(HopGlowPainter old) => false;
}
