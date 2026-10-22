import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/scenario.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/cabin_painter.dart';
import '../painters/floor_shape_painter.dart';
import '../painters/lobby_painter.dart';
import '../painters/shaft_painter.dart';
import '../theme.dart';
import 'load_gauge.dart';
import 'pressable.dart';
import 'resident_figure.dart';

/// The shaft panel: upcoming lifts, the cabin (a tap target that shows who
/// is riding), and the load gauge with the Scale booster under it. Send lives
/// in the bottom bar.
class LiftShaft extends StatelessWidget {
  const LiftShaft({
    super.key,
    required this.game,
    required this.cabinDy,
    required this.cabinTilt,
    required this.onTapLift,
    required this.onScale,
    required this.scaleLeft,
    required this.scaleReady,
    this.doorOpen = 1,
    this.cabinKey,
    this.hiddenIds = const {},
  });

  final LiftGame game;
  final double cabinDy;
  final double cabinTilt;
  final VoidCallback onTapLift;

  /// The Scale booster on the gauge plate: its handler (null while the lift
  /// is moving), the uses left, and whether a tap would preview someone now.
  final VoidCallback? onScale;
  final int scaleLeft;
  final bool scaleReady;

  /// Cabin doors: 0 closed, 1 open. Driven by the send animation.
  final double doorOpen;

  /// Marks the cabin interior, where walking residents land.
  final Key? cabinKey;

  /// Riders still walking in: drawn invisible until they land.
  final Set<int> hiddenIds;

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

    final pad = 10 * s;
    final railLeft = pad + m.nextColumn + 8 * s;
    return Container(
      height: m.shaftHeight,
      margin: EdgeInsets.symmetric(horizontal: m.gap),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: venue.wall,
        borderRadius: BorderRadius.circular(m.radius),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: CustomPaint(
        painter: ShaftPainter(style: venue, railLeft: railLeft, railRight: railLeft + m.cabinWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
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
                    // Twin hoist cables: snapped and swinging after an overload.
                    for (final dx in [-9.0, 7.0])
                      Positioned(
                        left: m.cabinWidth / 2 + dx * s,
                        top: 0,
                        child: Transform.rotate(
                          angle: crashed ? (dx < 0 ? 0.35 : -0.25) : 0,
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 2.4 * s,
                            height: (crashed ? 12 : 30) * s,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6E6A9E), Color(0xFFB3AFE0)]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 3 * s,
                      child: Center(child: _FloorDisplay(floors: game.liftFloors, alarm: crashed)),
                    ),
                    Positioned(
                      left: 0,
                      top: 30 * s,
                      child: Transform.translate(
                        offset: Offset(0, cabinDy),
                        child: Transform.rotate(
                          angle: cabinTilt,
                          child: _Cabin(
                            game: game,
                            crashed: crashed,
                            hint: hint,
                            doorOpen: doorOpen,
                            interiorKey: cabinKey,
                            hiddenIds: hiddenIds,
                            onTap: onTapLift,
                          ),
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
                      _ScaleButton(left: scaleLeft, ready: scaleReady, onPressed: onScale),
                    ],
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

/// The lit indicator above the shaft: an arrow and the floor(s) this lift
/// serves, like the panel over a real lift door.
class _FloorDisplay extends StatelessWidget {
  const _FloorDisplay({required this.floors, required this.alarm});

  final List<Floor> floors;
  final bool alarm;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final led = alarm ? LL.alarmSoft : const Color(0xFFFFC46B);
    return ExcludeSemantics(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8 * m.scale, vertical: 4 * m.scale),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0C22),
          borderRadius: BorderRadius.circular(6 * m.scale),
          border: Border.all(color: const Color(0xFF3A3670), width: 1.5),
        ),
        child: Text(
          alarm ? '! !' : '▲ ${floors.map((f) => f.label).join('·')}',
          style: TextStyle(
            fontFamily: LL.displayFont,
            fontSize: m.font(13),
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 1,
            color: led,
            shadows: [Shadow(color: led.withValues(alpha: 0.8), blurRadius: 6)],
          ),
        ),
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
  const _Cabin({
    required this.game,
    required this.crashed,
    required this.hint,
    required this.doorOpen,
    required this.interiorKey,
    required this.hiddenIds,
    required this.onTap,
  });

  final LiftGame game;
  final bool crashed;
  final bool hint;
  final double doorOpen;
  final Key? interiorKey;
  final Set<int> hiddenIds;
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
          padding: EdgeInsets.all(m.cabinPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: crashed
                  ? const [LL.alarmSoft, LL.alarm]
                  : [
                      Color.lerp(kind.cabin, Colors.white, 0.25)!,
                      kind.cabin,
                      Color.lerp(kind.cabin, Colors.black, 0.18)!
                    ],
            ),
            borderRadius: BorderRadius.circular(16 * s),
            boxShadow: [
              const BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
              if (hint) BoxShadow(color: kind.cabin.withValues(alpha: 0.5), spreadRadius: 4 * s, blurRadius: 6),
            ],
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
                  key: interiorKey,
                  borderRadius: BorderRadius.circular(10 * s),
                  child: CustomPaint(
                    painter: CabinInteriorPainter(alarm: crashed),
                    foregroundPainter: CabinDoorsPainter(open: doorOpen),
                    child: Stack(
                      children: [
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
                        // Feet at the cabin's feet line, mid-floor.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: m.cabinFeetInset - m.cabinFigure * ResidentFigure.belowFeet,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            // Shrinking a full cabin keeps the feet on the line.
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final r in riders)
                                  Align(
                                    widthFactor: 0.68,
                                    child: Opacity(
                                      opacity: hiddenIds.contains(r.id) ? 0 : 1,
                                      child: IdleSway(
                                        seed: r.id,
                                        amplitude: 0.5,
                                        builder: (context, blink) =>
                                            ResidentFigure.of(r, height: m.cabinFigure, blink: blink),
                                      ),
                                    ),
                                  ),
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

/// Scale: previews the selected resident as a dashed needle on the gauge.
class _ScaleButton extends StatelessWidget {
  const _ScaleButton({required this.left, required this.ready, required this.onPressed});

  final int left;
  final bool ready;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final size = m.scaleButton;
    final usable = onPressed != null && ready && left > 0;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      label: 'Scale: preview where the selected resident would put the needle, $left left',
      child: ExcludeSemantics(
        child: PressScale(
          enabled: onPressed != null,
          child: Opacity(
            opacity: usable ? 1 : 0.6,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Material(
                color: LL.cream,
                shape: StadiumBorder(side: BorderSide(color: LL.brassDark, width: 2 * m.scale)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onPressed,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6 * m.scale),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.scale_rounded, size: 18 * m.textScale, color: LL.ink),
                          SizedBox(width: 4 * m.scale),
                          Text('Scale',
                              style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.ink)),
                          SizedBox(width: 5 * m.scale),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6 * m.scale, vertical: 1),
                            decoration: BoxDecoration(color: LL.brass, borderRadius: BorderRadius.circular(999)),
                            child: Text('$left', style: LL.display.copyWith(fontSize: m.font(12), color: LL.ink)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
