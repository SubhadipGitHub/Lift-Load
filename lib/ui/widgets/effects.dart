/// One-shot particle effects drawn over the play screen: crash sparks, coins
/// flying to the coin counter, win confetti, and the sparkle when an unknown
/// person is revealed. Each effect owns a short
/// animation and removes itself when done. None of them runs under reduced
/// motion (the caller skips them).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

enum BurstKind { sparks, coins, confetti, sparkle, ring }

/// A burst at [origin] (screen coordinates inside the effects layer). Coins
/// fly toward [target]; confetti falls across the whole layer.
class Burst {
  Burst({
    required this.kind,
    required this.origin,
    this.target,
    this.count = 18,
    this.label,
    this.sprite,
    this.spriteSize = 0,
    this.onDone,
    this.delay = Duration.zero,
    this.radius = 0,
    this.stroke = 0,
  });

  final BurstKind kind;
  final Offset origin;
  final Offset? target;
  final int count;

  /// Floating text, e.g. "+15", shown with a burst.
  final String? label;

  /// Coins: the approved coin icon, drawn [spriteSize] across, instead of the
  /// painted disc (null keeps the disc: sprite art off, or the icon failed).
  final ui.Image? sprite;
  final double spriteSize;

  /// Called once the burst has played out (the coins have landed).
  final VoidCallback? onDone;

  /// Waits this long before it starts (the ring under a walker's target
  /// begins as they near it).
  final Duration delay;

  /// A ring's reach and line width, in logical pixels.
  final double radius, stroke;

  final int seed = _seeds++;
  static int _seeds = 1;
}

/// Hosts running [Burst]s. Add bursts with [EffectsLayerState.add] through a
/// GlobalKey.
class EffectsLayer extends StatefulWidget {
  const EffectsLayer({super.key});

  @override
  State<EffectsLayer> createState() => EffectsLayerState();
}

class EffectsLayerState extends State<EffectsLayer> {
  final List<Burst> _bursts = [];

  void add(Burst b) => setState(() => _bursts.add(b));

  /// The bursts playing now.
  @visibleForTesting
  List<Burst> get debugBursts => List.unmodifiable(_bursts);

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            for (final b in _bursts)
              Positioned.fill(
                key: ObjectKey(b),
                child: _BurstView(
                  burst: b,
                  onDone: () {
                    setState(() => _bursts.remove(b));
                    b.onDone?.call();
                  },
                ),
              ),
          ],
        ),
      );
}

class _BurstView extends StatefulWidget {
  const _BurstView({required this.burst, required this.onDone});

  final Burst burst;
  final VoidCallback onDone;

  @override
  State<_BurstView> createState() => _BurstViewState();
}

class _BurstViewState extends State<_BurstView> with SingleTickerProviderStateMixin {
  /// How long the burst itself plays, after its delay.
  late final Duration _play = Duration(
    milliseconds: switch (widget.burst.kind) {
      BurstKind.sparks => 650,
      BurstKind.coins => PunchMotion.coinFly.inMilliseconds,
      BurstKind.confetti => 2200,
      BurstKind.sparkle => 520,
      BurstKind.ring => BoardMotion.ring.inMilliseconds,
    },
  );

  late final AnimationController _c = AnimationController(vsync: this, duration: widget.burst.delay + _play)
    ..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  /// 0 to 1 over the burst proper, 0 while it waits.
  double get _t => ((_c.value * _c.duration!.inMicroseconds - widget.burst.delay.inMicroseconds) / _play.inMicroseconds)
      .clamp(0, 1)
      .toDouble();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BurstPainter(widget.burst, _t))),
            if (widget.burst.label != null)
              Positioned(
                left: widget.burst.origin.dx - 40,
                top: widget.burst.origin.dy - 30 - 40 * Curves.easeOut.transform(_t),
                width: 80,
                child: Opacity(
                  opacity: (1 - _t).clamp(0, 1),
                  child: Text(
                    widget.burst.label!,
                    textAlign: TextAlign.center,
                    style: LL.display.copyWith(
                      fontSize: 26,
                      color: LL.brass,
                      shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.b, this.t);

  final Burst b;
  final double t;

  static const _sparkleColors = [LL.cream, LL.brass, LL.mint, LL.lilac];
  static const _confettiColors = [LL.brass, LL.mint, Color(0xFFFF6B5B), Color(0xFF4C7DFF), Color(0xFFA066F5)];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(b.seed);
    if (t <= 0 && b.delay > Duration.zero) return;
    switch (b.kind) {
      case BurstKind.ring:
        // A flat ring of light on the floor where a walker is arriving: it
        // widens and fades, with a faint disc inside it.
        final out = Curves.easeOutCubic.transform(t);
        final rx = b.radius * (0.4 + 0.6 * out);
        final ry = rx * BoardMotion.ringFlat;
        final fade = math.pow(1 - t, 1.5).toDouble();
        final oval = Rect.fromCenter(center: b.origin, width: rx * 2, height: ry * 2);
        canvas
          ..drawOval(
            oval,
            Paint()
              ..shader = RadialGradient(
                colors: [LL.ringLight.withValues(alpha: 0.28 * fade), LL.ringLight.withValues(alpha: 0)],
              ).createShader(oval),
          )
          ..drawOval(
            oval,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = b.stroke
              ..color = LL.ringLight.withValues(alpha: 0.7 * fade),
          );
      case BurstKind.sparks:
        for (var i = 0; i < b.count; i++) {
          final a = -math.pi * (0.1 + 0.8 * rng.nextDouble());
          final v = 120 + rng.nextDouble() * 180;
          final p = b.origin + Offset(math.cos(a) * v * t, math.sin(a) * v * t + 260 * t * t);
          final fade = (1 - t).clamp(0.0, 1.0);
          canvas.drawLine(
            p,
            p - Offset(math.cos(a), math.sin(a) + t) * 8,
            Paint()
              ..color = Color.lerp(const Color(0xFFFFF1A8), const Color(0xFFFF7A2E), t)!.withValues(alpha: fade)
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round,
          );
        }
      case BurstKind.coins:
        final target = b.target ?? b.origin - const Offset(0, 200);
        for (var i = 0; i < b.count; i++) {
          final delay = i / b.count * 0.35;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final spread = Offset((rng.nextDouble() - 0.5) * 90, -40 - rng.nextDouble() * 60);
          // Pop out, then arc to the coin counter.
          final out = Curves.easeOut.transform((local * 2.5).clamp(0, 1));
          final home = Curves.easeInCubic.transform(((local - 0.3) / 0.7).clamp(0, 1));
          final p = Offset.lerp(b.origin + spread * out, target, home)!;
          final shrink = 1 - home * 0.4;
          if (b.sprite case final coin?) {
            canvas.drawImageRect(
              coin,
              Rect.fromLTWH(0, 0, coin.width.toDouble(), coin.height.toDouble()),
              Rect.fromCenter(center: p, width: b.spriteSize * shrink, height: b.spriteSize * shrink),
              Paint()..filterQuality = FilterQuality.medium,
            );
            continue;
          }
          final r = 6.5 * shrink;
          canvas
            ..drawCircle(p, r, Paint()..color = LL.brassDark)
            ..drawCircle(p - const Offset(0.8, 0.8), r * 0.82, Paint()..color = LL.brass)
            ..drawCircle(p - const Offset(2, 2), r * 0.25, Paint()..color = const Color(0xCCFFFFFF));
        }
      case BurstKind.sparkle:
        // A small ring of four-point stars flying outwards and shrinking.
        final out = Curves.easeOutCubic.transform(t);
        for (var i = 0; i < b.count; i++) {
          final a = (i + rng.nextDouble() * 0.6) / b.count * 2 * math.pi;
          final reach = 22 + rng.nextDouble() * 22;
          final p = b.origin + Offset(math.cos(a), math.sin(a)) * (reach * out);
          final r = (3.5 + rng.nextDouble() * 2.5) * (1 - t);
          final c = _sparkleColors[i % _sparkleColors.length].withValues(alpha: (1.3 - t).clamp(0.0, 1.0));
          final star = Path()
            ..moveTo(p.dx, p.dy - r * 2)
            ..quadraticBezierTo(p.dx, p.dy, p.dx + r * 2, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r * 2)
            ..quadraticBezierTo(p.dx, p.dy, p.dx - r * 2, p.dy)
            ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r * 2)
            ..close();
          canvas.drawPath(star, Paint()..color = c);
        }
      case BurstKind.confetti:
        for (var i = 0; i < b.count; i++) {
          final x0 = rng.nextDouble() * size.width;
          final delay = rng.nextDouble() * 0.3;
          final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (local <= 0) continue;
          final fall = local * (size.height + 60) - 30;
          final wobble = math.sin((local * 6 + i) * math.pi) * 18;
          final spin = local * 10 + i;
          final c = _confettiColors[i % _confettiColors.length];
          canvas
            ..save()
            ..translate(x0 + wobble, fall)
            ..rotate(spin)
            ..drawRect(
              const Rect.fromLTWH(-4, -2.5, 8, 5),
              Paint()..color = c.withValues(alpha: (1.2 - local).clamp(0, 1)),
            )
            ..restore();
        }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
