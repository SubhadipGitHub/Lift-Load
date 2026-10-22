import 'package:flutter/widgets.dart';

/// Tracks whether a finger is down on its child and hands that to [builder],
/// so a surface can show itself pressed (a glossy button sinks onto its
/// bottom edge). It only listens to pointers; the child keeps its own taps.
/// [down] is always false under reduced motion, so nothing moves.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, bool down) builder;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
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
