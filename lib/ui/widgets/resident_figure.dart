import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../painters/floor_shape_painter.dart';
import '../painters/resident_painter.dart';
import '../theme.dart';

/// A resident drawn at [height] logical pixels (width is half the height).
class ResidentFigure extends StatelessWidget {
  const ResidentFigure({super.key, required this.type, this.height = 52});

  final ResidentType type;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: height / 2,
        height: height,
        child: CustomPaint(painter: ResidentPainter(type)),
      );
}

/// The floor tag shown above a waiting resident: shape + floor label.
class FloorTag extends StatelessWidget {
  const FloorTag({super.key, required this.floor, this.compact = false});

  final Floor floor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FloorStyle.of(floor);
    return Container(
      height: compact ? 14 : 20,
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8),
      decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: compact ? 8 : 11,
            child: CustomPaint(painter: FloorShapePainter(style.shape, Colors.white)),
          ),
          SizedBox(width: compact ? 2 : 3),
          Text(
            floor.label,
            style: TextStyle(fontSize: compact ? 9 : 12, fontWeight: FontWeight.w800, color: LL.ink, height: 1),
          ),
        ],
      ),
    );
  }
}
