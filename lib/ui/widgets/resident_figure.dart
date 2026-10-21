import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../painters/floor_shape_painter.dart';
import '../painters/resident_painter.dart';
import '../theme.dart';

/// A resident drawn at [height] logical pixels. Width is half the height,
/// plus room for a vehicle or [cargo].
class ResidentFigure extends StatelessWidget {
  const ResidentFigure({
    super.key,
    required this.type,
    this.cargo = Cargo.none,
    this.height = 52,
    this.dimmed = false,
    this.blink = false,
  });

  /// Draws [r] with their cargo.
  ResidentFigure.of(Resident r, {Key? key, double height = 52, bool dimmed = false, bool blink = false})
      : this(key: key, type: r.type, cargo: r.cargo, height: height, dimmed: dimmed, blink: blink);

  final ResidentType type;
  final Cargo cargo;
  final double height;

  /// Power cut: draw a generic shadow instead of the resident.
  final bool dimmed;

  /// Eyes closed for this frame.
  final bool blink;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: height / 120 * ResidentLook.designWidth(type, cargo, dimmed: dimmed),
        height: height,
        child: CustomPaint(painter: ResidentPainter(type, cargo: cargo, dimmed: dimmed, blink: blink)),
      );
}

/// The floor tag shown above a waiting resident: shape + floor label.
class FloorTag extends StatelessWidget {
  const FloorTag({super.key, required this.floor, this.compact = false, this.scale = 1});

  final Floor floor;
  final bool compact;

  /// Layout scale from [Metrics].
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = FloorStyle.of(floor);
    final k = scale;
    return Container(
      height: (compact ? 14 : 20) * k,
      padding: EdgeInsets.symmetric(horizontal: (compact ? 5 : 8) * k),
      decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(10 * k)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: (compact ? 8 : 11) * k,
            child: CustomPaint(painter: FloorShapePainter(style.shape, Colors.white)),
          ),
          SizedBox(width: (compact ? 2 : 3) * k),
          Text(
            floor.label,
            style: TextStyle(fontSize: (compact ? 9 : 12) * k, fontWeight: FontWeight.w800, color: LL.ink, height: 1),
          ),
        ],
      ),
    );
  }
}
