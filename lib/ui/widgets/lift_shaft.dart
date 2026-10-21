import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/scenario.dart';
import '../game_controller.dart';
import '../layout.dart';
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
    final m = Metrics.of(context);
    final s = m.scale;
    final label = LL.label.copyWith(fontSize: m.font(11));

    return Container(
      height: m.shaftHeight,
      margin: EdgeInsets.symmetric(horizontal: m.gap),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: venue.wall, borderRadius: BorderRadius.circular(m.radius)),
      padding: EdgeInsets.symmetric(horizontal: 10 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: m.nextColumn,
            child: Padding(
              padding: EdgeInsets.only(top: 14 * s),
              child: Column(
                children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text('NEXT', style: label)),
                  SizedBox(height: 7 * s),
                  for (var i = 0; i < upcoming.length; i++) ...[
                    Opacity(opacity: i == 0 ? 1 : 0.55, child: _NextChip(stop: upcoming[i])),
                    SizedBox(height: 7 * s),
                  ],
                  const Spacer(),
                  SizedBox(width: 34 * s, height: 48 * s, child: CustomPaint(painter: VenuePropPainter(venue))),
                  SizedBox(height: 10 * s),
                ],
              ),
            ),
          ),
          SizedBox(width: 8 * s),
          SizedBox(
            width: m.cabinWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cable: snapped after an overload.
                Positioned(
                  left: m.cabinWidth / 2 - 2 * s,
                  top: 0,
                  child: Transform.rotate(
                    angle: crashed ? 0.32 : 0,
                    alignment: Alignment.topCenter,
                    child: Container(width: 4 * s, height: (crashed ? 14 : 30) * s, color: const Color(0xFF8F8AC4)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 30 * s,
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
              padding: EdgeInsets.only(top: 14 * s),
              child: Column(
                children: [
                  LoadGauge(
                    fraction: game.loadFraction,
                    zone: game.zone,
                    ghost: game.ghostLoad == null ? null : game.ghostLoad! / game.capacity,
                    width: m.gaugeWidth,
                  ),
                  SizedBox(height: 10 * s),
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
    final m = Metrics.of(context);
    return Semantics(
      label:
          '${stop.kind == LiftKind.normal ? 'Lift' : '${stop.kind.name} lift'} to ${GameController.floorList(stop.floors)}',
      child: Container(
        width: m.nextChip,
        height: m.nextChip,
        decoration: BoxDecoration(
          gradient: express
              ? LinearGradient(colors: [
                  s.color,
                  s.color,
                  FloorStyle.of(stop.floors.last).color,
                  FloorStyle.of(stop.floors.last).color
                ], stops: const [
                  0,
                  0.5,
                  0.5,
                  1
                ])
              : null,
          color: express ? null : s.color,
          borderRadius: BorderRadius.circular(12 * m.scale),
          border: kind.icon == null ? null : Border.all(color: kind.cabin, width: 3 * m.scale),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (kind.icon != null)
              Icon(kind.icon, size: 13 * m.scale, color: LL.ink)
            else
              SizedBox.square(
                dimension: 13 * m.scale,
                child: CustomPaint(painter: FloorShapePainter(s.shape, Colors.white)),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stop.floors.map((f) => f.label).join(' '),
                maxLines: 1,
                style: TextStyle(fontSize: (express ? 9 : 11) * m.scale, fontWeight: FontWeight.w800, color: LL.ink),
              ),
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
    final m = Metrics.of(context);
    final s = m.scale;
    return Semantics(
      button: true,
      label: '${game.liftKind == LiftKind.normal ? 'Lift' : kind.sign} to ${GameController.floorList(game.liftFloors)} '
          'with ${riders.length} riders. Tap to board the selected resident.',
      child: GestureDetector(
        onTap: game.phase == Phase.playing ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: m.cabinWidth,
          height: m.cabinHeight,
          padding: EdgeInsets.all(7 * s),
          decoration: BoxDecoration(
            color: crashed ? LL.alarm : kind.cabin,
            borderRadius: BorderRadius.circular(16 * s),
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
                      Icon(kind.icon, size: 16 * s, color: LL.ink),
                      SizedBox(width: 4 * s),
                    ],
                    for (var i = 0; i < game.liftFloors.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      _FloorPill(floor: game.liftFloors[i], prefix: game.liftFloors.length == 1 ? 'Up to ' : ''),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 5 * s),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10 * s),
                  child: Container(
                    color: LL.steel,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 14 * s,
                          child: Container(color: LL.steelFloor),
                        ),
                        Positioned(
                          left: 4 * s,
                          right: 4 * s,
                          top: 8 * s,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              kind.sign,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10 * m.textScale,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: const Color(0xFF5B6270),
                              ),
                            ),
                          ),
                        ),
                        if (riders.isEmpty)
                          Center(
                            child: Text(
                              hint ? 'Tap to board' : 'Empty',
                              style: TextStyle(
                                fontSize: m.font(12),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF4A5060),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 10 * s,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final r in riders)
                                  Align(widthFactor: 0.68, child: ResidentFigure.of(r, height: m.cabinFigure)),
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
    final m = Metrics.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(6 * m.scale, 2 * m.scale, 10 * m.scale, 2 * m.scale),
      decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 12 * m.scale,
            child: CustomPaint(painter: FloorShapePainter(style.shape, Colors.white)),
          ),
          SizedBox(width: 5 * m.scale),
          Text(
            '$prefix${floor.label}',
            style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.ink),
          ),
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
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: m.sendSize.width,
        height: m.sendSize.height,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: LL.brass,
            disabledBackgroundColor: LL.brass,
            foregroundColor: LL.ink,
            disabledForegroundColor: LL.ink,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * m.scale)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_rounded, size: 26 * m.scale),
                SizedBox(height: 2 * m.scale),
                Text('Send', style: TextStyle(fontSize: m.font(17), fontWeight: FontWeight.w800, height: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
