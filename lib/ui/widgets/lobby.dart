import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
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
    final seats = game.bench.length;
    final perRow = Metrics.benchPerRow(seats);
    final figure = m.benchFigureFor(seats);
    return Padding(
      padding: EdgeInsets.fromLTRB(m.benchInset, 0, m.benchInset, 8 * m.scale),
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
          // One row up to five seats; more (the +2 seats power) split into two even
          // rows, so a seat never gets narrower than a touch target.
          for (var row = 0; row * perRow < game.bench.length; row++) ...[
            if (row > 0) SizedBox(height: 8 * m.scale),
            Row(
              children: [
                for (var col = 0; col < perRow; col++) ...[
                  if (col > 0) SizedBox(width: m.seatGap),
                  Expanded(
                    child: row * perRow + col < game.bench.length
                        ? _seat(row * perRow + col, playing, seating, figure)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _seat(int i, bool playing, bool seating, double figure) => Shake(
        serial: i == shakeSeat ? shakeSerial : 0,
        child: _Seat(
          key: i < seatKeys.length ? seatKeys[i] : null,
          resident: game.bench[i],
          selected: game.selection == Selection.bench(i),
          seatHint: seating && game.bench[i] == null,
          hidden: game.bench[i] != null && hiddenIds.contains(game.bench[i]!.id),
          enabled: playing,
          figure: figure,
          onTap: () => onTapSeat(i),
        ),
      );
}

class _Seat extends StatelessWidget {
  const _Seat({
    super.key,
    required this.resident,
    required this.selected,
    required this.seatHint,
    required this.hidden,
    required this.enabled,
    required this.figure,
    required this.onTap,
  });

  final Resident? resident;
  final bool selected, seatHint, hidden, enabled;

  /// Figure height, the same for every seat on this bench.
  final double figure;
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
          height: m.seatHeightFor(figure),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14 * m.scale),
            border: Border.all(color: border, width: Metrics.seatBorder),
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
                            builder: (context, blink) => ResidentFigure.of(r, height: figure, blink: blink),
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

/// The queues on the lobby floor (three to five). Only the front of each lane
/// can be selected; a few residents per lane are drawn and nothing says how
/// many more wait. The floor takes the venue's look, and the lobby scenario
/// shows here: cones on a closed lane, the next rush-hour wave.
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
    this.swapping = false,
    this.swapFirst,
    this.revealedId,
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

  /// Swap is armed: every open lane with someone at the front can be picked,
  /// and [swapFirst] is the lane picked first.
  final bool swapping;
  final int? swapFirst;

  /// The person who has just stepped up from unknown: they pop in.
  final int? revealedId;

  @override
  Widget build(BuildContext context) {
    final playing = game.phase == Phase.playing;
    final lanes = game.visibleLanes;
    final style = VenueStyle.of(game.level.venue);
    final m = Metrics.of(context);
    final visible = m.visibleDepth;
    final figure = m.laneFigureFor(lanes.length);
    final ink = TextStyle(fontSize: m.font(11), fontWeight: FontWeight.w800, color: style.laneInk);
    final pending = game.pendingArrivals;
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
          padding: EdgeInsets.fromLTRB(m.lanePadding, 8 * m.scale, m.lanePadding, 4 * m.scale),
          child: Column(
            children: [
              if (pending.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * m.scale),
                  child: _Banner(
                    icon: Icons.groups_rounded,
                    text: 'A crowd arrives after trip ${pending.first.afterTrip}',
                  ),
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
                                if (lanes[lane][i] case final person?)
                                  // Keyed by resident, so each one slides up as the
                                  // queue moves rather than the figures swapping.
                                  _StepIn(
                                    key: ValueKey(person.id),
                                    depth: i,
                                    child: _Pop(
                                      pop: i == 0 && person.id == revealedId,
                                      child: Shake(
                                        serial: i == 0 && lane == shakeLane ? shakeSerial : 0,
                                        child: _QueueSlot(
                                          resident: person,
                                          depth: i,
                                          front: i == 0 && playing && !game.isLaneLocked(lane),
                                          selected: i == 0 && game.selection == Selection.queue(lane),
                                          pickable: swapping && i == 0 && playing && !game.isLaneLocked(lane),
                                          picked: swapping && i == 0 && swapFirst == lane,
                                          figure: figure,
                                          onTap: () => onTapLane(lane),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  // Unknown: the same ghost for everyone, no look and no floor tag. The
                                  // lobby never learns who it is until they reach the front.
                                  _StepIn(
                                    key: ValueKey('unknown-$lane-$i'),
                                    depth: i,
                                    child: _UnknownSlot(depth: i, figure: figure),
                                  ),
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
    required this.figure,
    required this.onTap,
    this.pickable = false,
    this.picked = false,
  });

  final Resident resident;
  final int depth;
  final bool front, selected;

  /// Figure height, the same for every lane in this lobby.
  final double figure;
  final VoidCallback onTap;

  /// Swap targeting: this front can be picked, and has been picked first.
  final bool pickable, picked;

  @override
  Widget build(BuildContext context) {
    final opacity = front ? 1.0 : (0.88 - depth * 0.12).clamp(0.5, 1.0).toDouble();
    final m = Metrics.of(context);
    final who = GameController.describe(resident);
    return Semantics(
      button: front,
      selected: selected,
      label: '$who${front ? '' : ', waiting in queue'}${picked ? ', picked for swap' : ''}',
      child: GestureDetector(
        onTap: front ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(bottom: 2 * m.scale),
          constraints: const BoxConstraints(minWidth: Metrics.minTouch, minHeight: Metrics.minTouch),
          padding: EdgeInsets.fromLTRB(m.slotPadding, 3 * m.scale, m.slotPadding, 1 * m.scale),
          transform: Matrix4.translationValues(0, selected ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected || picked
                ? LL.cream
                : front
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.transparent,
            // Swap targeting: a mint frame says "pick me", a thick brass one "picked".
            border: Border.all(
              color: selected || picked
                  ? LL.brass
                  : pickable
                      ? LL.mintDark
                      : front
                          ? const Color(0xFFD9C29A)
                          : Colors.transparent,
              width: selected || picked || pickable ? Metrics.slotBorder : Metrics.slotBorderThin,
            ),
            boxShadow: [
              if (picked) BoxShadow(color: LL.brass.withValues(alpha: 0.55), blurRadius: 10, spreadRadius: 1),
              if (pickable && !picked) BoxShadow(color: LL.mint.withValues(alpha: 0.35), blurRadius: 8),
            ],
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
                    builder: (context, blink) => ResidentFigure.of(resident, height: figure, blink: blink),
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

/// Scales a person in when they have just been revealed (an unknown person
/// reaching the front). No motion under reduced motion, and no effect for
/// anyone else.
class _Pop extends StatelessWidget {
  const _Pop({required this.pop, required this.child});

  final bool pop;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: pop ? 0.55 : 1, end: 1),
        duration: motionMs(context, 320),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(scale: v, alignment: Alignment.bottomCenter, child: child),
        child: child,
      );
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

/// An unknown person waiting behind the front of a lane: the same ghost shape for
/// everyone (a generic shadow, never their own outline), no floor tag, not tappable.
class _UnknownSlot extends StatelessWidget {
  const _UnknownSlot({required this.depth, required this.figure});

  final int depth;
  final double figure;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Semantics(
      label: 'Someone you cannot see yet, waiting in the queue',
      child: Opacity(
        opacity: (0.8 - depth * 0.1).clamp(0.4, 0.8).toDouble(),
        child: Container(
          margin: EdgeInsets.only(bottom: 2 * m.scale),
          constraints: const BoxConstraints(minWidth: Metrics.minTouch, minHeight: Metrics.minTouch),
          padding: EdgeInsets.fromLTRB(m.slotPadding, 3 * m.scale, m.slotPadding, 1 * m.scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: (Metrics.compactTagHeight + 1) * m.scale),
              FittedBox(fit: BoxFit.scaleDown, child: ResidentFigure.unknown(height: figure)),
            ],
          ),
        ),
      ),
    );
  }
}
