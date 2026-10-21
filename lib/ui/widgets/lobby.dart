import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../../game/scenario.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/lobby_painter.dart';
import '../theme.dart';
import 'resident_figure.dart';

/// Bench seats: tap a seated resident to select them, tap an empty seat to
/// park the selected queue resident.
class BenchRow extends StatelessWidget {
  const BenchRow({
    super.key,
    required this.game,
    required this.onTapSeat,
    this.seatKeys = const [],
    this.hiddenIds = const {},
    this.shakeSerial = 0,
    this.shakeSeat,
  });

  final LiftGame game;
  final ValueChanged<int> onTapSeat;

  /// One key per seat, so walks can find where a seat is on screen.
  final List<Key> seatKeys;

  /// Residents still walking onto the bench: drawn invisible until they land.
  final Set<int> hiddenIds;

  /// A refused bench resident shakes their head.
  final int shakeSerial;
  final int? shakeSeat;

  @override
  Widget build(BuildContext context) {
    final playing = game.phase == Phase.playing;
    final seating = playing && game.selection != null && !game.selection!.fromBench;
    final m = Metrics.of(context);
    final label = LL.label.copyWith(fontSize: m.font(11));
    return Padding(
      padding: EdgeInsets.fromLTRB(m.gap + 2 * m.scale, 0, m.gap + 2 * m.scale, 8 * m.scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LOBBY BENCH', style: label),
              Text('${game.benchUsed}/${game.bench.length}', style: label),
            ],
          ),
          SizedBox(height: 5 * m.scale),
          Row(
            children: [
              for (var i = 0; i < game.bench.length; i++) ...[
                if (i > 0) SizedBox(width: (game.bench.length > 6 ? 4 : 8) * m.scale),
                Expanded(
                  child: Shake(
                    serial: i == shakeSeat ? shakeSerial : 0,
                    child: _Seat(
                      key: i < seatKeys.length ? seatKeys[i] : null,
                      resident: game.bench[i],
                      selected: game.selection == Selection.bench(i),
                      seatHint: seating && game.bench[i] == null,
                      hidden: game.bench[i] != null && hiddenIds.contains(game.bench[i]!.id),
                      enabled: playing,
                      onTap: () => onTapSeat(i),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    super.key,
    required this.resident,
    required this.selected,
    required this.seatHint,
    required this.hidden,
    required this.enabled,
    required this.onTap,
  });

  final Resident? resident;
  final bool selected, seatHint, hidden, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = resident;
    final m = Metrics.of(context);
    final Color bg;
    final Color border;
    if (selected) {
      bg = LL.cream;
      border = LL.brass;
    } else if (r != null) {
      bg = LL.cream;
      border = Colors.transparent;
    } else if (seatHint) {
      bg = LL.brass.withValues(alpha: 0.12);
      border = LL.brass;
    } else {
      bg = Colors.transparent;
      border = const Color(0xFF5A5592);
    }
    final clock = seatHint ? IdleClock.of(context) : null;
    // While breathing the border changes every frame, so it must not tween.
    Widget seat(Color border) => AnimatedContainer(
          duration: clock == null ? motionMs(context, 150) : Duration.zero,
          height: m.seatHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14 * m.scale),
            border: Border.all(color: border, width: 2),
          ),
          child: r != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloorTag(floor: r.floor, compact: true, scale: m.scale),
                    Flexible(
                      child: Opacity(
                        opacity: hidden ? 0 : 1,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: IdleSway(
                            seed: r.id,
                            builder: (context, blink) => ResidentFigure.of(r, height: m.benchFigure, blink: blink),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : seatHint
                  ? Center(
                      child: Text(
                        'Seat',
                        style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.brass),
                      ),
                    )
                  : null,
        );
    return Semantics(
      button: true,
      label: r == null ? 'Empty bench seat' : 'Bench: ${GameController.describe(r)}',
      selected: selected,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        // A free seat that can take the selection breathes its border.
        child: clock == null
            ? seat(border)
            : ValueListenableBuilder<double>(
                valueListenable: clock,
                builder: (context, t, _) =>
                    seat(border.withValues(alpha: 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 2 * math.pi / 1.1)))),
              ),
      ),
    );
  }
}

/// The four queues on the lobby floor. Only the front of each lane can be
/// selected; up to four residents per lane are drawn, the rest are counted.
/// The floor takes the venue's look, and the lobby scenario shows here:
/// cones on a closed lane, shadows in a power cut, the next rush-hour wave.
class QueueLanes extends StatelessWidget {
  const QueueLanes({
    super.key,
    required this.game,
    required this.onTapLane,
    this.laneKeys = const [],
    this.shakeSerial = 0,
    this.shakeLane,
    this.coneSerial = 0,
    this.coneLane,
  });

  final LiftGame game;
  final ValueChanged<int> onTapLane;

  /// One key per lane column, so walks can find where a lane is on screen.
  final List<Key> laneKeys;

  /// A refused lane front shakes their head; tapped cones wobble.
  final int shakeSerial;
  final int? shakeLane;
  final int coneSerial;
  final int? coneLane;

  @override
  Widget build(BuildContext context) {
    final playing = game.phase == Phase.playing;
    final lanes = game.queues;
    final style = VenueStyle.of(game.level.venue);
    final powerCut = game.level.scenario == Scenario.powerCut;
    final m = Metrics.of(context);
    final visible = m.visibleDepth;
    final ink = TextStyle(fontSize: m.font(11), fontWeight: FontWeight.w800, color: style.laneInk);
    final pending = game.pendingArrivals;
    final wave = pending.isEmpty ? 0 : pending.where((a) => a.afterTrip == pending.first.afterTrip).length;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: m.gap),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: style.floor,
        borderRadius:
            m.twoPane ? BorderRadius.circular(m.radius) : BorderRadius.vertical(top: Radius.circular(m.radius)),
      ),
      child: CustomPaint(
        painter: FloorPatternPainter(style),
        child: Padding(
          padding: EdgeInsets.fromLTRB(6 * m.scale, 8 * m.scale, 6 * m.scale, 4 * m.scale),
          child: Column(
            children: [
              if (wave > 0)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * m.scale),
                  child: _Banner(
                    icon: Icons.groups_rounded,
                    text: '+$wave arriving after trip ${pending.first.afterTrip}',
                  ),
                ),
              if (powerCut)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * m.scale),
                  child: const _Banner(icon: Icons.flashlight_on_rounded, text: 'Power cut: only the front is lit'),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var lane = 0; lane < lanes.length; lane++)
                    Expanded(
                      child: Stack(
                        key: lane < laneKeys.length ? laneKeys[lane] : null,
                        children: [
                          Column(
                            children: [
                              for (var i = 0; i < lanes[lane].length && i < visible; i++)
                                // Keyed by resident, so each one slides up as the
                                // queue moves rather than the figures swapping.
                                _StepIn(
                                  key: ValueKey(lanes[lane][i].id),
                                  depth: i,
                                  child: Shake(
                                    serial: i == 0 && lane == shakeLane ? shakeSerial : 0,
                                    child: _QueueSlot(
                                      resident: lanes[lane][i],
                                      depth: i,
                                      front: i == 0 && playing && !game.isLaneLocked(lane),
                                      selected: i == 0 && game.selection == Selection.queue(lane),
                                      dimmed: powerCut && i >= Formulas.powerCutDepth,
                                      onTap: () => onTapLane(lane),
                                    ),
                                  ),
                                ),
                              if (lanes[lane].length > visible)
                                Text('+${lanes[lane].length - visible} waiting', style: ink),
                              if (lanes[lane].isEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 18 * m.scale),
                                  child: Text('Clear', style: ink.copyWith(fontSize: m.font(12))),
                                ),
                            ],
                          ),
                          if (game.isLaneLocked(lane))
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => onTapLane(lane),
                                child: Shake(
                                  serial: lane == coneLane ? coneSerial : 0,
                                  distance: 8,
                                  child: _Cones(tripsLeft: game.tripsUntilLaneOpens),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * m.scale, vertical: 4 * m.scale),
      decoration: BoxDecoration(color: LL.ink, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * m.scale, color: LL.brass),
          SizedBox(width: 5 * m.scale),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: m.font(11), fontWeight: FontWeight.w800, color: LL.cream),
            ),
          ),
        ],
      ),
    );
  }
}

/// Maintenance cones over a closed lane, with the trips left until it opens.
class _Cones extends StatelessWidget {
  const _Cones({required this.tripsLeft});

  final int tripsLeft;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Lane closed for maintenance, opens in $tripsLeft ${tripsLeft == 1 ? 'trip' : 'trips'}',
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xB31E1B3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Builder(builder: (context) {
            final m = Metrics.of(context);
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 14 * m.scale),
                Icon(Icons.construction_rounded, size: 30 * m.scale, color: const Color(0xFFFF8A3D)),
                SizedBox(height: 4 * m.scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Opens in\n$tripsLeft ${tripsLeft == 1 ? 'trip' : 'trips'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: m.font(11), fontWeight: FontWeight.w800, color: LL.cream, height: 1.2),
                  ),
                ),
              ],
            );
          }),
        ),
      );
}

class _QueueSlot extends StatelessWidget {
  const _QueueSlot({
    required this.resident,
    required this.depth,
    required this.front,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final Resident resident;
  final int depth;
  final bool front, selected, dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = front ? 1.0 : (0.88 - depth * 0.12).clamp(0.5, 1.0).toDouble();
    final m = Metrics.of(context);
    final who = dimmed ? 'Someone going to ${resident.floor.label}' : GameController.describe(resident);
    return Semantics(
      button: front,
      selected: selected,
      label: '$who${front ? '' : ', waiting in queue'}',
      child: GestureDetector(
        onTap: front ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(bottom: 2 * m.scale),
          constraints: const BoxConstraints(minWidth: Metrics.minTouch, minHeight: Metrics.minTouch),
          padding: EdgeInsets.fromLTRB(8 * m.scale, 3 * m.scale, 8 * m.scale, 1 * m.scale),
          transform: Matrix4.translationValues(0, selected ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? LL.cream
                : front
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.transparent,
            border: Border.all(
              color: selected
                  ? LL.brass
                  : front
                      ? const Color(0xFFD9C29A)
                      : Colors.transparent,
              width: selected ? 3 : 2,
            ),
          ),
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloorTag(floor: resident.floor, compact: true, scale: m.scale),
                SizedBox(height: 1 * m.scale),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: IdleSway(
                    seed: resident.id,
                    builder: (context, blink) =>
                        ResidentFigure.of(resident, height: m.laneFigure, dimmed: dimmed, blink: blink && !dimmed),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides a lane slot into place when its resident moves up the queue (or
/// first comes into view), instead of snapping. Still under reduced motion.
class _StepIn extends StatefulWidget {
  const _StepIn({super.key, required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  State<_StepIn> createState() => _StepInState();
}

class _StepInState extends State<_StepIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));

  /// Slots to travel, in units of this slot's own height (positive = from below).
  double _from = 0;
  bool _fadeIn = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Someone new appearing at the back of the visible queue walks in.
    if (widget.depth > 0 && !reduceMotion(context)) {
      _from = 0.6;
      _fadeIn = true;
      _c.forward(from: 0);
    } else {
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(_StepIn old) {
    super.didUpdateWidget(old);
    if (widget.depth < old.depth && !reduceMotion(context)) {
      _from = (old.depth - widget.depth).toDouble();
      _fadeIn = false;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          return Opacity(
            opacity: _fadeIn ? t : 1,
            child: FractionalTranslation(translation: Offset(0, _from * (1 - t)), child: child),
          );
        },
      );
}
