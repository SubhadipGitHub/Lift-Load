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
/// by [seed], plus a blink every few seconds. The child is rebuilt with the
/// current blink state; the sway is a transform over a repaint boundary, so
/// figures repaint only when a blink starts or ends.
class IdleSway extends StatelessWidget {
  const IdleSway({super.key, required this.seed, required this.builder, this.amplitude = 1});

  final int seed;
  final double amplitude;
  final Widget Function(BuildContext context, bool blink) builder;

  @override
  Widget build(BuildContext context) {
    final clock = IdleClock.of(context);
    if (clock == null) return builder(context, false);
    final phase = (seed * 0.618) % 1.0;
    final blinkEvery = 3.2 + (seed * 0.37) % 2.6;
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      builder: (context, t, _) {
        final sway = math.sin((t / 2.9 + phase) * 2 * math.pi) * 0.022 * amplitude;
        final bob = (math.sin((t / 1.6 + phase) * 2 * math.pi) + 1) * 0.6 * amplitude;
        final blink = (t + phase * blinkEvery) % blinkEvery < 0.13;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(0, -bob, 0, 1)
            ..rotateZ(sway),
          child: RepaintBoundary(child: builder(context, blink)),
        );
      },
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
