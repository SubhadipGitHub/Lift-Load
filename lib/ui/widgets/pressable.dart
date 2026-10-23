import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../motion.dart';

/// Tracks whether a finger is down on its child and hands that to [builder],
/// so a surface can show itself pressed (a glossy button sinks onto its
/// bottom edge). It only listens to pointers; the child keeps its own taps.
/// [down] is always false under reduced motion, so nothing moves.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, this.enabled = true, this.onRelease});

  final Widget Function(BuildContext context, bool down) builder;
  final bool enabled;

  /// A finger that went down on this is lifted (or cancelled).
  final VoidCallback? onRelease;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down || !mounted) return;
    final released = _down && !down;
    setState(() => _down = down);
    if (released && widget.enabled) widget.onRelease?.call();
  }

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) _down = false;
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: widget.builder(context, _down && widget.enabled && !still),
    );
  }
}

/// Squashes its child slightly while a finger is down, so buttons feel
/// physical. No motion when the platform asks for reduced motion.
class PressScale extends StatelessWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  /// How fast a pressed control goes down and comes back.
  static const Duration pressDuration = Duration(milliseconds: 90);

  @override
  Widget build(BuildContext context) => Pressable(
        enabled: enabled,
        builder: (context, down) => AnimatedScale(
          scale: down ? 0.95 : 1,
          duration: pressDuration,
          curve: Curves.easeOut,
          child: child,
        ),
      );
}

/// The springy press: while [down] the child shrinks to
/// [ButtonMotion.pressedScale] and, let go, springs back past 1 and rests. A
/// transform only, so the touch target and the layout never change. With
/// [down] always false (reduced motion) it holds still at 1.
class PressSpring extends StatefulWidget {
  const PressSpring({super.key, required this.down, required this.child});

  final bool down;
  final Widget child;

  @override
  State<PressSpring> createState() => _PressSpringState();
}

class _PressSpringState extends State<PressSpring> with SingleTickerProviderStateMixin {
  /// 1 pressed, 0 at rest; below 0 is the overshoot.
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: widget.down ? 1 : 0);

  @override
  void didUpdateWidget(PressSpring old) {
    super.didUpdateWidget(old);
    if (old.down == widget.down) return;
    if (widget.down) {
      _c.animateTo(1, duration: ButtonMotion.pressIn, curve: Curves.easeOut);
    } else {
      _c.animateWith(SpringSimulation(ButtonMotion.release, _c.value, 0, 0));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) =>
            Transform.scale(scale: 1 - (1 - ButtonMotion.pressedScale) * _c.value, child: child),
      );
}
