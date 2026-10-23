/// A slow swell with a soft glow behind it: Send when the load aboard is
/// good to send, and Play on the home screen. It rides the shared idle clock
/// (no ticker of its own) and holds still, with no glow, when inactive or
/// when motion is reduced. The glow and the swell are drawn around the child,
/// so the layout and the touch target never change.
library;

import 'package:flutter/widgets.dart';

import '../layout.dart';
import '../motion.dart';

class GlowPulse extends StatelessWidget {
  const GlowPulse({
    super.key,
    required this.active,
    required this.color,
    required this.radius,
    required this.period,
    required this.scale,
    required this.blur,
    required this.glow,
    this.spread = 0,
    required this.child,
  });

  /// Swelling now (and the idle clock is running).
  final bool active;
  final Color color;

  /// Corner radius of the glow, to match the child's face.
  final double radius;

  /// Seconds per swell, the swell's growth (a share of the size), and the
  /// glow's blur and spread in design units.
  final double period, scale, blur, spread;

  /// The glow's peak alpha, as a share of [color]'s.
  final double glow;
  final Widget child;

  /// Whether a pulse would play now: active, with motion on.
  static bool playing(BuildContext context, bool active) => active && IdleClock.of(context) != null;

  @override
  Widget build(BuildContext context) {
    final clock = active ? IdleClock.of(context) : null;
    final m = Metrics.of(context);
    return AnimatedBuilder(
      animation: clock ?? const AlwaysStoppedAnimation<double>(0),
      child: child,
      builder: (context, child) {
        final k = clock == null ? 0.0 : PunchMotion.loop(clock.value, period);
        return Transform.scale(
          scale: 1 + scale * k,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: clock == null
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: color.a * glow * (0.25 + 0.75 * k)),
                                blurRadius: blur * m.scale,
                                spreadRadius: spread * m.scale,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              child!,
            ],
          ),
        );
      },
    );
  }
}
