import 'package:flutter/widgets.dart';

/// Squashes its child slightly while a finger is down, so buttons feel
/// physical. It only listens to pointers; the child keeps its own taps.
/// No motion when the platform asks for reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !still ? 0.95 : 1,
        duration: Duration(milliseconds: still ? 0 : 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
