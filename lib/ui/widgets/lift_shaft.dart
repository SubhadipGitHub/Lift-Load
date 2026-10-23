import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/level.dart';
import '../../game/scenario.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/cabin_painter.dart';
import '../painters/lobby_painter.dart';
import '../painters/shaft_painter.dart';
import '../theme.dart';
import 'art_icon.dart';
import 'entrance.dart';
import 'glossy.dart';
import 'load_gauge.dart';
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
    this.cabinBump = 0,
    this.chime = 0,
    this.cabinKey,
    this.hiddenIds = const {},
    this.footer,
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

  /// The bump once the doors shut, 0 to 1 ([PunchMotion.bumpAt]); 0 at rest.
  final double cabinBump;

  /// The chime light as a lift arrives, 0 (none) to 1 (gone): the display and
  /// the top of the cabin flash once ([FloorMotion.chime]).
  final double chime;

  /// Marks the cabin interior, where walking residents land.
  final Key? cabinKey;

  /// Riders still walking in: drawn invisible until they land.
  final Set<int> hiddenIds;

  /// The message line, in a strip along the foot of the panel under the
  /// cabin ([Metrics.messageHeight] tall).
  final Widget? footer;

  /// Finds the display over the cabin, the one place the lift here shows its
  /// floors, and the strip of NEXT chips, in tests.
  static const Key floorDisplayKey = ValueKey('floor-display');
  static const Key nextStripKey = ValueKey('next-strip');

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

    final pad = m.shaftPad;
    final railLeft = pad + m.nextColumn + m.shaftColGap;
    final bump = PunchMotion.bumpAt(cabinBump);
    // The wall: Sunrise Towers' backdrop for this storey band once loaded
    // (and sprite art is on), otherwise the painted wall.
    Widget wall(ui.Image? art, Widget? content) => CustomPaint(
          painter: ShaftPainter(
            style: venue,
            railLeft: railLeft,
            railRight: railLeft + m.cabinWidth,
            art: art,
            floorY: m.cabinTop + m.cabinHeight,
            channel: m.shaftChannel,
            rideDy: cabinDy,
            rideTravel: CabinMotion.riseDistance * s,
            scale: s,
          ),
          child: content,
        );
    return Container(
      height: m.shaftHeight,
      margin: EdgeInsets.symmetric(horizontal: m.gap),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: venue.wall,
        borderRadius: BorderRadius.circular(m.radius),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: _ShaftWall(
        level: game.level,
        builder: wall,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(left: pad, right: pad, bottom: m.messageHeight),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: m.nextColumn,
                      child: Padding(
                        padding: EdgeInsets.only(top: m.shaftTop),
                        child: Column(
                          children: [
                            FittedBox(fit: BoxFit.scaleDown, child: Text('NEXT', style: label)),
                            SizedBox(height: m.nextGap),
                            for (var i = 0; i < upcoming.length; i++) ...[
                              // The lifts after the next one sit back, smaller and fainter.
                              Opacity(
                                opacity: i == 0 ? 1 : Metrics.nextDimOpacity,
                                child: Transform.scale(
                                  scale: i == 0 ? 1 : Metrics.nextDimScale,
                                  child: _NextChip(stop: upcoming[i]),
                                ),
                              ),
                              SizedBox(height: m.nextGap),
                            ],
                            // The venue's prop stands in whatever room the chips leave.
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: m.nextGap),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: Metrics.propSize.width * s,
                                      height: Metrics.propSize.height * s,
                                      child: CustomPaint(painter: VenuePropPainter(venue)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: m.shaftColGap),
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
                            top: 2 * s,
                            child: Center(
                                child: _FloorDisplay(
                              key: floorDisplayKey,
                              floors: game.liftFloors,
                              alarm: crashed,
                              chime: chime,
                            )),
                          ),
                          Positioned(
                            left: 0,
                            top: m.cabinTop,
                            child: Transform.translate(
                              offset: Offset(0, cabinDy),
                              child: Transform.rotate(
                                angle: cabinTilt,
                                // The bump: down and squashed on its floor, then back.
                                child: Transform(
                                  alignment: Alignment.bottomCenter,
                                  transform: Matrix4.identity()
                                    ..translateByDouble(0, bump.dy * s, 0, 1)
                                    ..scaleByDouble(bump.sx, bump.sy, 1, 1),
                                  child: _Cabin(
                                    game: game,
                                    crashed: crashed,
                                    hint: hint,
                                    doorOpen: doorOpen,
                                    interiorKey: cabinKey,
                                    hiddenIds: hiddenIds,
                                    chime: chime,
                                    onTap: onTapLift,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: m.shaftColGap),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: m.shaftTop),
                        child: Column(
                          children: [
                            // On a short panel the gauge shrinks before the Scale button does.
                            Flexible(
                              child: _GaugePlate(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: LoadGauge(
                                    fraction: game.loadFraction,
                                    zone: game.zone,
                                    ghost: game.ghostLoad == null ? null : game.ghostLoad! / game.capacity,
                                    width: m.gaugeWidth,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: m.nextGap * 2),
                            _ScaleButton(left: scaleLeft, ready: scaleReady, onPressed: onScale),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (footer != null)
              Positioned(left: m.gap, right: m.gap, bottom: 0, height: m.messageHeight, child: footer!),
          ],
        ),
      ),
    );
  }
}

/// Builds the shaft wall: with sprite art on it listens for the backdrops to
/// load and hands over this level's (null for a venue without one, or one
/// that failed), so the painted wall stays the fallback.
class _ShaftWall extends StatelessWidget {
  const _ShaftWall({required this.level, required this.builder, required this.child});

  final Level level;
  final Widget Function(ui.Image? art, Widget? child) builder;
  final Widget child;

  @override
  Widget build(BuildContext context) => SpriteArtScope.of(context)
      ? ListenableBuilder(
          listenable: SpriteCache.instance,
          builder: (context, child) => builder(SpriteCache.instance.shaftBackdrop(level), child),
          child: child,
        )
      : builder(null, child);
}

/// The lit indicator above the cabin: an arrow and the floor(s) this lift
/// serves, like the panel over a real lift door. It is the only place the
/// lift here shows its floors; each label is lit in its floor's colour, so
/// it matches the tags on the people waiting. When the lift changes the old
/// floors slide up and out as the new ones slide in ([FloorMotion.roll]), and
/// when it arrives the lamp flashes once ([chime], 0 to 1).
class _FloorDisplay extends StatefulWidget {
  const _FloorDisplay({super.key, required this.floors, required this.alarm, this.chime = 0});

  final List<Floor> floors;
  final bool alarm;
  final double chime;

  @override
  State<_FloorDisplay> createState() => _FloorDisplayState();
}

class _FloorDisplayState extends State<_FloorDisplay> with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(vsync: this, duration: FloorMotion.roll, value: 1);

  /// The floors that were showing before the last change.
  List<Floor> _was = const [];

  @override
  void didUpdateWidget(_FloorDisplay old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.floors, widget.floors) && !reduceMotion(context)) {
      _was = old.floors;
      _roll.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final alarm = widget.alarm;
    final led = alarm ? LL.alarmSoft : LL.led;
    final size = m.font(Metrics.floorDisplayFont);
    TextStyle lit(Color c) => TextStyle(
          fontFamily: LL.displayFont,
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: 1,
          color: c,
          shadows: [Shadow(color: c.withValues(alpha: 0.8), blurRadius: 6)],
        );
    Widget floorsText(List<Floor> floors) => Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < floors.length; i++) ...[
                if (i > 0) TextSpan(text: '\u00B7', style: lit(led)),
                TextSpan(text: floors[i].label, style: lit(FloorStyle.of(floors[i]).light)),
              ],
            ],
          ),
        );
    final flash = widget.chime <= 0 || widget.chime >= 1 ? 0.0 : math.sin(math.pi * widget.chime);
    return ExcludeSemantics(
      child: Transform.scale(
        scale: 1 + FloorMotion.chimePop * flash,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 9 * m.scale, vertical: 3 * m.scale),
          decoration: BoxDecoration(
            color: LL.displayBed,
            borderRadius: BorderRadius.circular(m.displayRadius),
            border: Border.all(color: LL.displayRim, width: Metrics.displayRim),
            boxShadow: flash == 0
                ? null
                : [
                    BoxShadow(
                      color: LL.chimeLight.withValues(alpha: FloorMotion.chimeGlow * flash),
                      blurRadius: FloorMotion.chimeBlur * m.scale,
                    ),
                  ],
          ),
          child: alarm
              ? Text.rich(TextSpan(text: '! !', style: lit(led)))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(TextSpan(text: '\u25B2 ', style: lit(led))),
                    AnimatedBuilder(
                      animation: _roll,
                      builder: (context, _) {
                        final now = floorsText(widget.floors);
                        if (_roll.value >= 1) return now;
                        // Old floors up and out, new ones up from below.
                        final t = Curves.easeInOutCubic.transform(_roll.value);
                        final travel = size * FloorMotion.rollTravel;
                        return ClipRect(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: t,
                                child: Transform.translate(offset: Offset(0, travel * (1 - t)), child: now),
                              ),
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 1 - t,
                                  child: Transform.translate(
                                    offset: Offset(0, -travel * t),
                                    child: OverflowBox(
                                      maxWidth: double.infinity,
                                      child: floorsText(_was),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The dark plate behind the load gauge (style frame, `.gauge`).
class _GaugePlate extends StatelessWidget {
  const _GaugePlate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final radius = BorderRadius.circular(m.gaugePlateRadius);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: LL.gaugeBed, width: Metrics.gaugePlateRim),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [LL.gaugePlateTop, LL.gaugePlateBottom],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: LL.gaugePlateRim, width: Metrics.messageRim),
      ),
      padding: EdgeInsets.symmetric(vertical: m.gaugePlatePadding, horizontal: m.gaugePlatePadding / 2),
      child: child,
    );
  }
}

/// One upcoming lift: a glossy chip in its floor's colour with the floor's
/// label, and a badge on the corner for its kind. An express is split
/// between its two floors. [LiftGame.upcomingLifts] starts after the lift
/// that is here, so the first chip is the next lift, never this one.
class _NextChip extends StatelessWidget {
  const _NextChip({required this.stop});
  final LiftStop stop;

  @override
  Widget build(BuildContext context) {
    final first = FloorStyle.of(stop.floors.first);
    final last = FloorStyle.of(stop.floors.last);
    final express = stop.floors.length > 1;
    final m = Metrics.of(context);
    return Semantics(
      label:
          '${stop.kind == LiftKind.normal ? 'Lift' : '${stop.kind.name} lift'} to ${GameController.floorList(stop.floors)}',
      child: SizedBox.square(
        dimension: m.nextChip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Glossy(
              style: SurfaceStyle.floor(stop.floors.first),
              depth: SurfaceDepth.chip,
              inset: false,
              radius: m.nextChipRadius,
              width: m.nextChip,
              height: m.nextChip,
              faceGradient: express
                  ? LinearGradient(
                      colors: [first.light, first.color, last.light, last.color],
                      stops: const [0, 0.5, 0.5, 1],
                    )
                  : null,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stop.floors.map((f) => f.label).join(' '),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: m.font(express ? Metrics.nextExpressFont : Metrics.nextFont),
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: LL.ink,
                    ),
                  ),
                ),
              ),
            ),
            if (stop.kind != LiftKind.normal)
              Positioned(
                right: -m.kindBadge / 3,
                top: -m.kindBadge / 3,
                child: _KindBadge(kind: stop.kind, size: m.kindBadge),
              ),
          ],
        ),
      ),
    );
  }
}

/// A lift kind's approved badge on a small dark disc (the disc lets the
/// Material fallback read on any colour).
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.size});

  final LiftKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: LL.cabinPlate, shape: BoxShape.circle),
        child: ArtIcon.kind(kind, size: size * Metrics.kindBadgeArt, color: LL.cream),
      );
}

/// The cabin: a tap target that shows who is riding. With sprite art on and
/// this kind's images loaded it draws the approved interior, the riders, then
/// the two door leaves over them, with the floor pill (and the kind's sign)
/// on top; otherwise the painted cabin. Either way the riders' feet sit at
/// [Metrics.cabinFeetLine] and nothing drawn depends on load.
class _Cabin extends StatelessWidget {
  const _Cabin({
    required this.game,
    required this.crashed,
    required this.hint,
    required this.doorOpen,
    required this.interiorKey,
    required this.hiddenIds,
    required this.onTap,
    this.chime = 0,
  });

  final LiftGame game;
  final bool crashed;
  final bool hint;
  final double doorOpen;
  final Key? interiorKey;
  final Set<int> hiddenIds;
  final VoidCallback onTap;

  /// The chime light as this lift arrives (0 none to 1 gone).
  final double chime;

  /// How long the hint glow and the crash colours take to change.
  static const Duration _chromeFade = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final kind = LiftKindStyle.of(game.liftKind);
    return Semantics(
      button: true,
      label: '${game.liftKind == LiftKind.normal ? 'Lift' : kind.sign} to ${GameController.floorList(game.liftFloors)} '
          'with ${game.riders.length} riders. Tap to board the selected resident.',
      child: GestureDetector(
        onTap: game.phase == Phase.playing ? onTap : null,
        child: SpriteArtScope.of(context)
            ? ListenableBuilder(
                listenable: SpriteCache.instance,
                builder: (context, _) => switch (SpriteCache.instance.cabin(game.liftKind)) {
                  final art? => _art(context, art),
                  null => _painted(context),
                },
              )
            : _painted(context),
      ),
    );
  }

  /// The riders in a row, feet [bottom] above the bottom of their stack
  /// (less the part of the figure box below the feet).
  Widget _riders(Metrics m, double bottom) => Positioned(
        left: 0,
        right: 0,
        bottom: bottom - m.cabinFigure * ResidentFigure.belowFeet,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          // Shrinking a full cabin keeps the feet on the line.
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final r in game.riders)
                Align(
                  widthFactor: 0.68,
                  child: Opacity(
                    opacity: hiddenIds.contains(r.id) ? 0 : 1,
                    child: LandSettle(
                      hidden: hiddenIds.contains(r.id),
                      child: IdleSway(
                        seed: r.id,
                        amplitude: 0.5,
                        builder: (context, blink) => ResidentFigure.of(r, height: m.cabinFigure, blink: blink),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  /// The chime light as the lift stops: a soft wash falling from the top of
  /// the cabin, brightest as the lamp above flashes.
  Widget _wash() => chime <= 0 || chime >= 1
      ? const SizedBox.shrink()
      : Positioned.fill(
          child: IgnorePointer(
            child: FractionallySizedBox(
              alignment: Alignment.topCenter,
              heightFactor: FloorMotion.chimeWashDepth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      LL.chimeLight.withValues(alpha: FloorMotion.chimeWash * math.sin(math.pi * chime)),
                      LL.chimeLight.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

  /// The interior dims as the doors close.
  Widget _dim() => IgnorePointer(
        child: ColoredBox(color: LL.doorShade.withValues(alpha: CabinMotion.closedDim * (1 - doorOpen.clamp(0, 1)))),
      );

  /// What sets this lift apart: the kind's badge beside its sign, on dark
  /// plates so it reads on any interior. Null for a normal lift, whose
  /// ("Mind the load") is decoration the art replaces. The floors this lift
  /// serves are not repeated here: the display above the cabin shows them.
  Widget? _kindRow(Metrics m, {required bool plated}) {
    if (game.liftKind == LiftKind.normal) return null;
    final kind = LiftKindStyle.of(game.liftKind);
    final s = m.scale;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KindBadge(kind: game.liftKind, size: m.cabinKindBadge),
          SizedBox(width: 4 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2 * s),
            decoration: plated ? BoxDecoration(color: LL.cabinPlate, borderRadius: BorderRadius.circular(999)) : null,
            child: Text(
              kind.sign,
              style: TextStyle(
                fontSize: 10 * m.textScale,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: plated ? LL.cream : const Color(0xFF5B6270),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _emptyText => hint ? 'Tap to board' : 'Empty';

  /// The dark lines either side of the rim: the kind's colour, deepened.
  static Color _rimShade(LiftKindStyle kind) => Color.lerp(kind.cabin, LL.ink, 0.72)!;

  /// The approved art: interior, riders, dim, leaves, then the chrome that
  /// carries game information on dark plates so it reads on any interior.
  Widget _art(BuildContext context, CabinArt art) {
    final m = Metrics.of(context);
    final s = m.scale;
    final kind = LiftKindStyle.of(game.liftKind);
    final radius = BorderRadius.circular(m.cabinRadius);
    final plate = BoxDecoration(color: LL.cabinPlate, borderRadius: BorderRadius.circular(999));
    return AnimatedContainer(
      duration: _chromeFade,
      width: m.cabinWidth,
      height: m.cabinHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          const BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
          if (hint) BoxShadow(color: kind.cabin.withValues(alpha: 0.5), spreadRadius: 4 * s, blurRadius: 6),
          BoxShadow(color: _rimShade(kind), spreadRadius: m.cabinRimLine),
        ],
      ),
      // The rim (style frame): the kind's colour between two dark lines.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: crashed ? LL.alarm : kind.cabin, width: m.cabinRim),
      ),
      child: ClipRRect(
        key: interiorKey,
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: CabinArtPainter(art.interior)),
            if (game.riders.isEmpty)
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 3 * s),
                  decoration: plate,
                  child: Text(
                    _emptyText,
                    style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.cream),
                  ),
                ),
              ),
            _riders(m, m.cabinFeetInset),
            if (doorOpen < 1) _dim(),
            _wash(),
            if (crashed) const IgnorePointer(child: ColoredBox(color: LL.crashTint)),
            if (doorOpen < 1)
              CustomPaint(
                painter: CabinLeavesPainter(left: art.left, right: art.right, open: doorOpen, seam: m.doorSeam),
              ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: _rimShade(kind), width: m.cabinRim + m.cabinRimLine),
                ),
              ),
            ),
            if (_kindRow(m, plated: true) case final row?)
              Positioned(left: m.cabinChromeTop, right: m.cabinChromeTop, top: m.cabinChromeTop, child: row),
          ],
        ),
      ),
    );
  }

  /// The painted cabin (sprite art off, or this kind's images missing).
  Widget _painted(BuildContext context) {
    final kind = LiftKindStyle.of(game.liftKind);
    final m = Metrics.of(context);
    final s = m.scale;
    return AnimatedContainer(
      key: interiorKey,
      duration: _chromeFade,
      width: m.cabinWidth,
      height: m.cabinHeight,
      padding: EdgeInsets.all(m.cabinPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: crashed
              ? const [LL.alarmSoft, LL.alarm]
              : [Color.lerp(kind.cabin, Colors.white, 0.25)!, kind.cabin, Color.lerp(kind.cabin, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(m.cabinRadius),
        boxShadow: [
          const BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
          if (hint) BoxShadow(color: kind.cabin.withValues(alpha: 0.5), spreadRadius: 4 * s, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
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
                      // A normal lift's own sign ("Mind the load") is plain
                      // lettering on the painted wall.
                      child: _kindRow(m, plated: false) ??
                          FittedBox(
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
                    if (game.riders.isEmpty)
                      Center(
                        child: Text(
                          _emptyText,
                          style: TextStyle(
                            fontSize: m.font(12),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF4A5060),
                          ),
                        ),
                      ),
                    // This stack sits inside the cabin's padding.
                    _riders(m, m.cabinFeetInset - m.cabinPadding),
                    if (doorOpen < 1) Positioned.fill(child: _dim()),
                    _wash(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scale: previews the selected resident as a dashed needle on the gauge.
/// A cream glossy pill with the approved scale icon and the uses left.
class _ScaleButton extends StatelessWidget {
  const _ScaleButton({required this.left, required this.ready, required this.onPressed});

  final int left;
  final bool ready;
  final VoidCallback? onPressed;

  /// Faded while a tap would not preview anyone.
  static const double idleOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final size = m.scaleButton;
    final usable = onPressed != null && ready && left > 0;
    // As wide as the gauge plate above it.
    return LayoutBuilder(
      builder: (context, box) => Opacity(
        opacity: usable ? 1 : idleOpacity,
        child: GlossyButton(
          key: const ValueKey('scale'),
          style: SurfaceStyle.cream,
          disabledStyle: SurfaceStyle.cream,
          onPressed: onPressed,
          semanticsLabel: 'Scale: preview where the selected resident would put the needle, $left left',
          width: box.hasBoundedWidth ? math.max(size.width, box.maxWidth) : size.width,
          height: size.height,
          padding: EdgeInsets.symmetric(horizontal: 4 * m.scale),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ArtIcon(GameIcon.scale, size: m.scaleIcon),
                SizedBox(width: 3 * m.scale),
                Text('Scale', style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.ink)),
                SizedBox(width: 4 * m.scale),
                Glossy(
                  style: SurfaceStyle.brass,
                  depth: SurfaceDepth.tag,
                  inset: false,
                  padding: EdgeInsets.symmetric(horizontal: 6 * m.scale, vertical: 1),
                  child: Text('$left', style: LL.display.copyWith(fontSize: m.font(12), color: LL.ink)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
