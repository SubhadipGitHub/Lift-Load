import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../painters/floor_shape_painter.dart';
import '../theme.dart';
import 'load_gauge.dart';
import 'resident_figure.dart';

/// The shaft panel: upcoming lifts, the cabin (a tap target that shows who
/// is riding), and the load gauge with the Send button.
class LiftShaft extends StatelessWidget {
  const LiftShaft({
    super.key,
    required this.game,
    required this.cabinDy,
    required this.cabinTilt,
    required this.onTapLift,
    required this.onSend,
  });

  final LiftGame game;
  final double cabinDy;
  final double cabinTilt;
  final VoidCallback onTapLift;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final crashed = game.phase == Phase.falling || (game.phase == Phase.failed && game.failKind == FailKind.crash);
    final selected = game.selected;
    final hint = game.phase == Phase.playing && selected != null && selected.floor == game.liftFloor;
    final upcoming = game.upcomingFloors(3);

    return Container(
      height: 262,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  const Text('NEXT', style: LL.label),
                  const SizedBox(height: 7),
                  for (var i = 0; i < upcoming.length; i++) ...[
                    Opacity(opacity: i == 0 ? 1 : 0.55, child: _NextChip(floor: upcoming[i])),
                    const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 196,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cable: snapped after an overload.
                Positioned(
                  left: 96,
                  top: 0,
                  child: Transform.rotate(
                    angle: crashed ? 0.32 : 0,
                    alignment: Alignment.topCenter,
                    child: Container(width: 4, height: crashed ? 14 : 30, color: const Color(0xFF8F8AC4)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 30,
                  child: Transform.translate(
                    offset: Offset(0, cabinDy),
                    child: Transform.rotate(
                      angle: cabinTilt,
                      child: _Cabin(game: game, crashed: crashed, hint: hint, onTap: onTapLift),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  LoadGauge(
                    fraction: game.loadFraction,
                    zone: game.zone,
                    ghost: game.ghostLoad == null ? null : game.ghostLoad! / game.capacity,
                  ),
                  const SizedBox(height: 10),
                  _SendButton(enabled: game.canSend, onPressed: onSend),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextChip extends StatelessWidget {
  const _NextChip({required this.floor});
  final Floor floor;

  @override
  Widget build(BuildContext context) {
    final s = FloorStyle.of(floor);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(dimension: 13, child: CustomPaint(painter: FloorShapePainter(s.shape, Colors.white))),
          Text(floor.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LL.ink)),
        ],
      ),
    );
  }
}

class _Cabin extends StatelessWidget {
  const _Cabin({required this.game, required this.crashed, required this.hint, required this.onTap});

  final LiftGame game;
  final bool crashed;
  final bool hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = FloorStyle.of(game.liftFloor);
    final riders = game.riders;
    return Semantics(
      button: true,
      label: 'Lift to ${game.liftFloor.label} with ${riders.length} riders. Tap to board the selected resident.',
      child: GestureDetector(
        onTap: game.phase == Phase.playing ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 196,
          height: 214,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: crashed ? LL.alarm : LL.brass,
            borderRadius: BorderRadius.circular(16),
            boxShadow: hint ? [BoxShadow(color: LL.brass.withValues(alpha: 0.45), spreadRadius: 4)] : null,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
                decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: 12, child: CustomPaint(painter: FloorShapePainter(style.shape, Colors.white))),
                    const SizedBox(width: 5),
                    Text('Up to ${game.liftFloor.label}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LL.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: LL.steel,
                    child: Stack(
                      children: [
                        Positioned(left: 0, right: 0, bottom: 0, height: 14, child: Container(color: LL.steelFloor)),
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 8,
                          child: Text(
                            'MAX 4 PERSONS',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: Color(0xFF5B6270)),
                          ),
                        ),
                        if (riders.isEmpty)
                          Center(
                            child: Text(
                              hint ? 'Tap to board' : 'Empty',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4A5060)),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final r in riders)
                                Align(widthFactor: 0.68, child: ResidentFigure(type: r.type, height: 80)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          width: 92,
          height: 76,
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: LL.brass,
              disabledBackgroundColor: LL.brass,
              foregroundColor: LL.ink,
              disabledForegroundColor: LL.ink,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_rounded, size: 26),
                SizedBox(height: 2),
                Text('Send', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1)),
              ],
            ),
          ),
        ),
      );
}
