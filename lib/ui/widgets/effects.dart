/// One-shot particle effects drawn over the play screen: crash sparks, coins
/// flying to the coin counter, win confetti, and the sparkle when an unknown
/// person is revealed. Each effect owns a short
/// animation and removes itself when done. None of them runs under reduced
/// motion (the caller skips them).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

enum BurstKind { sparks, coins, confetti, sparkle }

/// A burst at [origin] (screen coordinates inside the effects layer). Coins
/// fly toward [target]; confetti falls across the whole layer.
class Burst {
  Burst({required this.kind, required this.origin, this.target, this.count = 18, this.label});

  final BurstKind kind;
  final Offset origin;
  final Offset? target;
  final int count;

  /// Floating text, e.g. "+15", shown with coin bursts.
  final String? label;

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

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(
          children: [
            for (final b in _bursts)
              Positioned.fill(
                key: ObjectKey(b),
                child: _BurstView(burst: b, onDone: () => setState(() => _bursts.remove(b))),
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: switch (widget.burst.kind) {
        BurstKind.sparks => 650,
        BurstKind.coins => 900,
        BurstKind.confetti => 2200,
        BurstKind.sparkle => 520,
      },
    ),
  )..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

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
            Positioned.fill(child: CustomPaint(painter: _BurstPainter(widget.burst, _c.value))),
            if (widget.burst.label != null)
              Positioned(
                left: widget.burst.origin.dx - 40,
                top: widget.burst.origin.dy - 30 - 40 * Curves.easeOut.transform(_c.value),
                width: 80,
                child: Opacity(
                  opacity: (1 - _c.value).clamp(0, 1),
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
    switch (b.kind) {
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
          final r = 6.5 * (1 - home * 0.4);
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
