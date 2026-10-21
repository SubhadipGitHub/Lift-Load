import 'package:flutter/material.dart';

import '../../game/engine.dart';
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
    return Semantics(
      label: 'Lift load: $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('LOAD', style: LL.label),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, f, _) => CustomPaint(
              size: Size(width, width * 0.6),
              painter: GaugePainter(fraction: f, ghost: ghost),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
