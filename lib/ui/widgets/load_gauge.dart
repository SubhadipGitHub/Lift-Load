import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/gauge_painter.dart';
import '../theme.dart';

/// The load dial with a springy needle and a zone word underneath. No
/// numbers, ever. The needle follows only the load already aboard: it eases to
/// its mark and swings a fixed distance past it and back (the same whatever
/// the distance travelled, [GaugeMotion]); entering the green or red pulses
/// the glow and the word once, and at the limit the glow breathes. Under
/// reduced motion the needle is just there and the glow holds still.
class LoadGauge extends StatefulWidget {
  const LoadGauge({super.key, required this.fraction, required this.zone, this.ghost, this.width = 92});

  /// How strongly the dial glows for the load aboard: not at all in the
  /// grey, softly in the green, more at the limit, fully past it.
  static double glowFor(LoadZone zone) => switch (zone) {
        LoadZone.overload => 1,
        LoadZone.limit => 0.85,
        LoadZone.green => 0.6,
        LoadZone.empty || LoadZone.light => 0,
      };

  final double fraction;
  final LoadZone zone;
  final double? ghost;
  final double width;

  @override
  State<LoadGauge> createState() => _LoadGaugeState();
}

class _LoadGaugeState extends State<LoadGauge> with TickerProviderStateMixin {
  late final AnimationController _needle = AnimationController(vsync: this, duration: GaugeMotion.needle, value: 1);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: GaugeMotion.zonePulse, value: 1);
  late double _from = widget.fraction, _to = widget.fraction;

  double get _shown => GaugeMotion.needleAt(_from, _to, _needle.value);

  /// 0 at rest, up to 1 mid-pulse and back.
  double get _bump => _pulse.value >= 1 ? 0 : Curves.easeInOut.transform(1 - (2 * _pulse.value - 1).abs());

  @override
  void didUpdateWidget(LoadGauge old) {
    super.didUpdateWidget(old);
    final still = reduceMotion(context);
    if (widget.fraction != old.fraction) {
      if (still) {
        _from = _to = widget.fraction;
        _needle.value = 1;
      } else {
        _from = _shown;
        _to = widget.fraction;
        _needle.forward(from: 0);
      }
    }
    // Into the green or red: the glow pulses. Nothing for a drop back to grey.
    if (widget.zone != old.zone && LoadGauge.glowFor(widget.zone) > 0 && !still) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _needle.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final (label, color) = switch (zone) {
      LoadZone.empty => ('Empty', LL.lilac),
      LoadZone.light => ('Light', LL.lilac),
      LoadZone.green => ('Good to send', LL.mint),
      LoadZone.limit => ('At the limit', LL.mint),
      LoadZone.overload => ('OVERLOAD', LL.alarmSoft),
    };
    final m = Metrics.of(context);
    final base = LoadGauge.glowFor(zone);
    // Only the limit breathes, on the shared idle clock.
    final clock = zone == LoadZone.limit ? IdleClock.of(context) : null;
    return Semantics(
      label: 'Lift load: $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LOAD', style: LL.label.copyWith(fontSize: m.font(11))),
          SizedBox(height: 4 * m.scale),
          AnimatedBuilder(
            animation: Listenable.merge([_needle, _pulse, if (clock != null) clock]),
            builder: (context, _) {
              final breath = clock == null ? 0.0 : (PunchMotion.loop(clock.value, GaugeMotion.limitPeriod) - 0.5) * 2;
              return CustomPaint(
                size: Size(widget.width, widget.width * 0.6),
                painter: GaugePainter(
                  fraction: _shown,
                  ghost: widget.ghost,
                  // The glow follows only the load already aboard; the Scale
                  // preview stays a dashed needle.
                  glow: (base + (1 - base) * _bump + GaugeMotion.limitBreath * breath).clamp(0, 1).toDouble(),
                  glowColor: zone == LoadZone.overload ? LL.alarm : LL.mint,
                  over: zone == LoadZone.overload,
                ),
              );
            },
          ),
          SizedBox(height: 4 * m.scale),
          SizedBox(
            width: widget.width * 1.15,
            child: AnimatedBuilder(
              animation: _pulse,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: m.font(12),
                    fontWeight: FontWeight.w800,
                    color: color,
                    // The zone word glows with the dial (style frame, `.lbl`).
                    shadows: color == LL.lilac ? null : [Shadow(color: color, blurRadius: m.gaugeLabelGlow)],
                  ),
                ),
              ),
              builder: (context, child) => Transform.scale(scale: 1 + GaugeMotion.wordPop * _bump, child: child),
            ),
          ),
        ],
      ),
    );
  }
}
