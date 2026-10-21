import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/scenario.dart';
import '../game_controller.dart';
import '../painters/floor_shape_painter.dart';
import '../painters/lobby_painter.dart';
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
    final hint = game.phase == Phase.playing && selected != null && game.goesTo(selected.floor);
    final upcoming = game.upcomingLifts(3);
    final venue = VenueStyle.of(game.level.venue);

    return Container(
      height: 262,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: venue.wall, borderRadius: BorderRadius.circular(22)),
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
                    Opacity(opacity: i == 0 ? 1 : 0.55, child: _NextChip(stop: upcoming[i])),
                    const SizedBox(height: 7),
                  ],
                  const Spacer(),
                  SizedBox(width: 34, height: 48, child: CustomPaint(painter: VenuePropPainter(venue))),
                  const SizedBox(height: 10),
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

/// One upcoming lift: its floor colour and label, and a badge for its kind.
/// An express shows both floors.
class _NextChip extends StatelessWidget {
  const _NextChip({required this.stop});
  final LiftStop stop;

  @override
  Widget build(BuildContext context) {
    final s = FloorStyle.of(stop.floors.first);
    final kind = LiftKindStyle.of(stop.kind);
    final express = stop.floors.length > 1;
    return Semantics(
      label: '${stop.kind == LiftKind.normal ? 'Lift' : '${stop.kind.name} lift'} to ${GameController.floorList(stop.floors)}',
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: express
              ? LinearGradient(colors: [s.color, s.color, FloorStyle.of(stop.floors.last).color, FloorStyle.of(stop.floors.last).color], stops: const [0, 0.5, 0.5, 1])
              : null,
          color: express ? null : s.color,
          borderRadius: BorderRadius.circular(12),
          border: kind.icon == null ? null : Border.all(color: kind.cabin, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (kind.icon != null)
              Icon(kind.icon, size: 13, color: LL.ink)
            else
              SizedBox.square(dimension: 13, child: CustomPaint(painter: FloorShapePainter(s.shape, Colors.white))),
            Text(
              stop.floors.map((f) => f.label).join(' '),
              maxLines: 1,
              style: TextStyle(fontSize: express ? 9 : 11, fontWeight: FontWeight.w800, color: LL.ink),
            ),
          ],
        ),
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
    final kind = LiftKindStyle.of(game.liftKind);
    final riders = game.riders;
    return Semantics(
      button: true,
      label: '${game.liftKind == LiftKind.normal ? 'Lift' : kind.sign} to ${GameController.floorList(game.liftFloors)} '
          'with ${riders.length} riders. Tap to board the selected resident.',
      child: GestureDetector(
        onTap: game.phase == Phase.playing ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 196,
          height: 214,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: crashed ? LL.alarm : kind.cabin,
            borderRadius: BorderRadius.circular(16),
            boxShadow: hint ? [BoxShadow(color: kind.cabin.withValues(alpha: 0.45), spreadRadius: 4)] : null,
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (kind.icon != null) ...[
                      Icon(kind.icon, size: 16, color: LL.ink),
                      const SizedBox(width: 4),
                    ],
                    for (var i = 0; i < game.liftFloors.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      _FloorPill(floor: game.liftFloors[i], prefix: game.liftFloors.length == 1 ? 'Up to ' : ''),
                    ],
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
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 8,
                          child: Text(
                            kind.sign,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: Color(0xFF5B6270)),
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final r in riders) Align(widthFactor: 0.68, child: ResidentFigure.of(r, height: 80)),
                              ],
                            ),
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

class _FloorPill extends StatelessWidget {
  const _FloorPill({required this.floor, required this.prefix});

  final Floor floor;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final style = FloorStyle.of(floor);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
      decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 12, child: CustomPaint(painter: FloorShapePainter(style.shape, Colors.white))),
          const SizedBox(width: 5),
          Text('$prefix${floor.label}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LL.ink)),
        ],
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
