import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../layout.dart';
import '../painters/gauge_painter.dart';
import '../theme.dart';

/// The load dial with a springy needle (overshoot sells the weight landing)
/// and a zone word underneath. No numbers, ever.
class LoadGauge extends StatelessWidget {
  const LoadGauge({super.key, required this.fraction, required this.zone, this.ghost, this.width = 92});

  final double fraction;
  final LoadZone zone;
  final double? ghost;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (zone) {
      LoadZone.empty => ('Empty', LL.lilac),
      LoadZone.light => ('Light', LL.lilac),
      LoadZone.green => ('Good to send', LL.mint),
      LoadZone.limit => ('At the limit', LL.mint),
      LoadZone.overload => ('OVERLOAD', LL.alarmSoft),
    };
    final m = Metrics.of(context);
    return Semantics(
      label: 'Lift load: $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LOAD', style: LL.label.copyWith(fontSize: m.font(11))),
          SizedBox(height: 4 * m.scale),
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, f, _) => CustomPaint(
              size: Size(width, width * 0.6),
              painter: GaugePainter(
                fraction: f,
                ghost: ghost,
                glow: switch (zone) {
                  LoadZone.overload => 1,
                  LoadZone.limit => 0.8,
                  LoadZone.green => 0.35,
                  LoadZone.empty || LoadZone.light => 0,
                },
                glowColor: zone == LoadZone.overload ? LL.alarm : LL.mint,
              ),
            ),
          ),
          SizedBox(height: 4 * m.scale),
          SizedBox(
            width: width * 1.15,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
