/// The pieces of the polish pass's staged motion that are only transforms and
/// fades: a part of a screen that slides, scales and fades in over its slice
/// of a shared animation (the level entrance, the home screen), and a figure
/// that squashes and springs back where a walker lands. Timings live in
/// `motion.dart`, distances are design units (times `Metrics.scale`), and
/// nothing here reads who is on screen.
library;

import 'package:flutter/widgets.dart';

import '../layout.dart';
import '../motion.dart';

/// Slides [child] [dy] design units (positive starts below, negative above),
/// scales it up from [scaleFrom] about [alignment], and fades it in, all on
/// [curve] (an [Interval] over [animation], which may overshoot). At 1 it is
/// the child, drawn as is. The layout never changes: only the paint does, and
/// a touch lands where the child is drawn.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.animation,
    required this.curve,
    required this.child,
    this.dy = 0,
    this.scaleFrom = 1,
    this.alignment = Alignment.center,
    this.fade = true,
  });

  final Animation<double> animation;
  final Curve curve;
  final double dy;
  final double scaleFrom;
  final Alignment alignment;
  final bool fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = Metrics.of(context).scale;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = curve.transform(animation.value);
        final moved = Transform(
          alignment: alignment,
          transform: Matrix4.identity()
            ..translateByDouble(0, dy * scale * (1 - t), 0, 1)
            ..scaleByDouble(scaleFrom + (1 - scaleFrom) * t, scaleFrom + (1 - scaleFrom) * t, 1, 1),
          child: child,
        );
        return fade ? Opacity(opacity: t.clamp(0, 1).toDouble(), alwaysIncludeSemantics: true, child: moved) : moved;
      },
    );
  }
}

/// Squashes [child] when [hidden] turns false (a walker has landed in this
/// spot) and springs it back: the same squash, stretch and spring for every
/// resident ([BoardMotion]), about the bottom of the child. Holds still when
/// motion is reduced.
class LandSettle extends StatefulWidget {
  const LandSettle({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  State<LandSettle> createState() => _LandSettleState();
}

class _LandSettleState extends State<LandSettle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: BoardMotion.land, value: 1);

  @override
  void didUpdateWidget(LandSettle old) {
    super.didUpdateWidget(old);
    if (old.hidden && !widget.hidden && !reduceMotion(context)) _c.forward(from: 0);
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
        builder: (context, child) {
          final left = 1 - MotionCurves.pop.transform(_c.value);
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..scaleByDouble(1 + BoardMotion.landStretch * left, 1 - BoardMotion.landSquash * left, 1, 1),
            child: child,
          );
        },
      );
}
