import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/scenario.dart';
import '../../game/venue.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/lobby_painter.dart';
import '../theme.dart';
import 'art_icon.dart';
import 'entrance.dart';
import 'glossy.dart';
import 'punch.dart';
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
    final label = LL.label.copyWith(fontSize: m.font(11), height: 1.1);
    final seats = game.bench.length;
    final perRow = Metrics.benchPerRow(seats);
    final figure = m.benchFigureFor(seats);
    return Padding(
      padding: EdgeInsets.fromLTRB(m.benchInset, m.benchTop, m.benchInset, m.benchBottom),
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
          SizedBox(height: m.benchLabelGap),
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
    final radius = m.seatRadius;
    final height = m.seatHeight;
    Widget seat(double breath) {
      if (r != null) {
        // Occupied: a cream glossy seat; picked, its rim turns brass and glows,
        // and the resident hops on a warm glow.
        return Glossy(
          style: selected ? SurfaceStyle.seatPicked : SurfaceStyle.seat,
          depth: SurfaceDepth.seat,
          inset: false,
          radius: radius,
          height: height,
          glow: selected ? LL.pickGlow : null,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: hidden ? 0 : 1,
                  // A walker landing squashes and springs back, the same for all.
                  child: LandSettle(
                    hidden: hidden,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SelectedHop(
                        active: selected,
                        child: HopGlow(
                          active: selected,
                          child: IdleSway(
                            seed: r.id,
                            builder: (context, blink) => ResidentFigure.of(r, height: figure, blink: blink),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The tag sits in the corner, so the figure gets the seat's height.
              Positioned(
                left: m.seatTag,
                top: m.seatTag,
                child: FloorTag(floor: r.floor, compact: true, scale: m.scale),
              ),
            ],
          ),
        );
      }
      // Free: a dark well. One that can take the selection glows brass and
      // breathes ([breath] 0 to 1).
      return AnimatedContainer(
        duration: seatHint ? Duration.zero : motionMs(context, 150),
        height: height,
        decoration: BoxDecoration(
          color: seatHint ? LL.brass.withValues(alpha: 0.13) : null,
          gradient: seatHint
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [LL.seatWellShade, LL.seatWell],
                ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: seatHint ? LL.brass.withValues(alpha: 0.55 + 0.45 * breath) : LL.seatRim,
            width: Metrics.seatBorder,
          ),
          boxShadow: seatHint
              ? [
                  BoxShadow(
                    color: LL.pickGlow.withValues(alpha: LL.pickGlow.a * (0.6 + 0.4 * breath)),
                    blurRadius: m.seatGlow + (m.seatGlowBreath - m.seatGlow) * breath,
                  ),
                ]
              : null,
        ),
        child: seatHint
            ? Center(
                child: Text(
                  'Seat',
                  style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.brass),
                ),
              )
            : null,
      );
    }

    return Semantics(
      button: true,
      label: r == null ? 'Empty bench seat' : 'Bench: ${GameController.describe(r)}',
      selected: selected,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        // A free seat that can take the selection breathes; still, it holds
        // at full glow.
        child: Breathe(active: seatHint, builder: (context, breath) => seat(breath)),
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
    this.paintFloor = true,
    this.entrance,
  });

  final LiftGame game;
  final ValueChanged<int> onTapLane;

  /// The level entrance (0 to 1, [EntranceMotion]): while it runs, each
  /// person rises into place in their turn. Null, or at 1, they are just there.
  final Animation<double>? entrance;

  /// Paint the venue's floor colour and pattern; off when a [LobbyFloor]
  /// below already shows the venue's painted floor.
  final bool paintFloor;

  /// The lobby floor's corners: rounded on top where it runs under the
  /// bottom bar, all round in the two-pane layout.
  static BorderRadius floorRadius(Metrics m) =>
      m.twoPane ? BorderRadius.circular(m.radius) : BorderRadius.vertical(top: Radius.circular(m.radius));

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
    // On a painted floor the ink is a shade darker: the art keeps 4.3:1 for
    // the old ink, this clears 4.5:1 on every pixel of it.
    final ink = TextStyle(
        fontSize: m.font(11), fontWeight: FontWeight.w800, color: paintFloor ? style.laneInk : LL.lobbyArtInk);
    final pending = game.pendingArrivals;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: m.gap),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: paintFloor ? style.floor : null,
        borderRadius: floorRadius(m),
      ),
      child: CustomPaint(
        painter: paintFloor ? FloorPatternPainter(style) : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(m.lanePadding, m.laneTop, m.lanePadding, 4 * m.scale),
          child: Column(
            children: [
              if (pending.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 6 * m.scale),
                  child: _Banner(
                    icon: ArtIcon.scenario(Scenario.rushHour, size: Metrics.bannerIcon * m.scale),
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
                                    lane: lane,
                                    depth: i,
                                    entrance: entrance,
                                    child: _Pop(
                                      pop: i == 0 && person.id == revealedId,
                                      builder: (context, ghost) => Shake(
                                        serial: i == 0 && lane == shakeLane ? shakeSerial : 0,
                                        child: _QueueSlot(
                                          resident: person,
                                          depth: i,
                                          front: i == 0 && playing && !game.isLaneLocked(lane),
                                          selected: i == 0 && game.selection == Selection.queue(lane),
                                          pickable: swapping && i == 0 && playing && !game.isLaneLocked(lane),
                                          picked: swapping && i == 0 && swapFirst == lane,
                                          figure: figure,
                                          ghost: ghost,
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
                                    lane: lane,
                                    depth: i,
                                    entrance: entrance,
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

/// The lobby floor under the lanes. With sprite art on and the venue's
/// painted floor loaded, the floor stays fixed in the lane area while the
/// queues scroll over it (a perspective floor that slid with the lanes would
/// read as the room moving); [builder] is told to leave the lanes'
/// own floor off. Otherwise the lanes paint the venue's floor and pattern,
/// as before.
class LobbyFloor extends StatelessWidget {
  const LobbyFloor({super.key, required this.venue, required this.builder});

  final Venue venue;

  /// Builds the lanes; `paintFloor` is false while the painted floor shows.
  final Widget Function(BuildContext context, bool paintFloor) builder;

  @override
  Widget build(BuildContext context) {
    if (!SpriteArtScope.of(context)) return builder(context, true);
    return ListenableBuilder(
      listenable: SpriteCache.instance,
      builder: (context, _) {
        final image = SpriteCache.instance.lobbyFloor(venue);
        if (image == null) return builder(context, true);
        final m = Metrics.of(context);
        return Stack(
          children: [
            Positioned.fill(
              left: m.gap,
              right: m.gap,
              child: ClipRRect(
                borderRadius: QueueLanes.floorRadius(m),
                child: CustomPaint(painter: LobbyFloorPainter(image)),
              ),
            ),
            builder(context, false),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final Widget icon;
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
          icon,
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
            borderRadius: BorderRadius.circular(Metrics.of(context).innerRadius),
          ),
          child: Builder(builder: (context) {
            final m = Metrics.of(context);
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 14 * m.scale),
                ArtIcon.scenario(Scenario.maintenance, size: Metrics.coneIcon * m.scale),
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
    this.ghost,
  });

  final Resident resident;
  final int depth;
  final bool front, selected;

  /// Figure height, the same for every lane in this lobby.
  final double figure;
  final VoidCallback onTap;

  /// Swap targeting: this front can be picked, and has been picked first.
  final bool pickable, picked;

  /// A reveal in progress: the unknown ghost lies over the figure and fades
  /// out as this goes from 0 to 1.
  final Animation<double>? ghost;

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
        // Selected: the front hops, and stands on a warm glow.
        child: SelectedHop(
          active: selected,
          child: AnimatedContainer(
            duration: motionMs(context, 150),
            margin: EdgeInsets.only(bottom: 2 * m.scale),
            constraints: const BoxConstraints(minWidth: Metrics.minTouch, minHeight: Metrics.minTouch),
            padding: EdgeInsets.fromLTRB(m.slotPadding, 3 * m.scale, m.slotPadding, 1 * m.scale),
            transform: Matrix4.translationValues(0, selected ? -m.selectedLift : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(m.innerRadius),
              // Clear is white at no alpha, not black, so the card fades in
              // through white rather than a grey.
              color: selected || picked
                  ? LL.cream
                  : front
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0),
              // Swap targeting: a mint frame says "pick me", a thick brass one "picked".
              border: Border.all(
                color: selected || picked
                    ? LL.brass
                    : pickable
                        ? LL.mintDark
                        : front
                            ? const Color(0xFFD9C29A)
                            : const Color(0x00D9C29A),
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
                    child: HopGlow(
                      active: selected,
                      child: _Dissolve(
                        ghost: ghost,
                        height: figure,
                        child: IdleSway(
                          seed: resident.id,
                          builder: (context, blink) => ResidentFigure.of(resident, height: figure, blink: blink),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An unknown person who has just reached the front is revealed: the figure
/// pops in on a soft spring ([RevealMotion]), the unknown ghost over it
/// dissolves (see [_Dissolve]) and a flash of light crosses the slot. The same
/// for everyone, and nothing at all for anyone else or under reduced motion.
class _Pop extends StatefulWidget {
  const _Pop({required this.pop, required this.builder});

  final bool pop;

  /// Builds the slot; [ghost] runs 0 to 1 while the ghost dissolves (null
  /// when there is no reveal).
  final Widget Function(BuildContext context, Animation<double>? ghost) builder;

  @override
  State<_Pop> createState() => _PopState();
}

class _PopState extends State<_Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: RevealMotion.flash);
  late final CurvedAnimation _ghost = CurvedAnimation(parent: _c, curve: Interval(0, _ghostEnd, curve: Curves.easeIn));
  bool _started = false;

  /// Where the ghost's dissolve ends, as a share of the whole reveal.
  static double get _ghostEnd => RevealMotion.ghost.inMicroseconds / RevealMotion.flash.inMicroseconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.pop && !reduceMotion(context)) {
      _c.forward(from: 0);
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _ghost.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final popEnd = RevealMotion.pop.inMicroseconds / RevealMotion.flash.inMicroseconds;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value >= 1 ? 1.0 : MotionCurves.pop.transform((_c.value / popEnd).clamp(0, 1).toDouble());
        final scale = RevealMotion.popFrom + (1 - RevealMotion.popFrom) * v;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: widget.builder(context, _c.value >= 1 ? null : _ghost),
            ),
            if (_c.value < 1)
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _FlashPainter(_c.value))),
              ),
          ],
        );
      },
    );
  }
}

/// The light that crosses a freshly revealed person: a soft white disc that
/// swells from the middle of the slot and fades.
class _FlashPainter extends CustomPainter {
  const _FlashPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final out = Curves.easeOutCubic.transform(t);
    final r = size.shortestSide * RevealMotion.flashRadius * (0.35 + 0.65 * out);
    final alpha = RevealMotion.flashAlpha * math.pow(1 - t, 1.6).toDouble();
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [LL.revealFlash.withValues(alpha: alpha), LL.revealFlash.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_FlashPainter old) => old.t != t;
}

/// The unknown ghost laid over a figure, fading out as [ghost] runs to 1, so
/// the shadow dissolves into the real person. With no reveal it is the figure.
class _Dissolve extends StatelessWidget {
  const _Dissolve({required this.ghost, required this.height, required this.child});

  final Animation<double>? ghost;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = ghost;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        child,
        if (g != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(g),
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: ResidentFigure.unknown(height: height)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Moves a lane slot into place with a soft spring when its resident steps up
/// the queue (the nearest the front first, [BoardMotion.stepStagger] ms
/// apart), or when someone first comes into view at the back; and, while the
/// level entrance runs, rises into place in its turn ([EntranceMotion.person]).
/// Still under reduced motion.
class _StepIn extends StatefulWidget {
  const _StepIn({super.key, required this.lane, required this.depth, required this.entrance, required this.child});

  final int lane, depth;
  final Animation<double>? entrance;
  final Widget child;

  @override
  State<_StepIn> createState() => _StepInState();
}

class _StepInState extends State<_StepIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  /// Slots to travel, in units of this slot's own height (positive = from below).
  double _from = 0;
  bool _fadeIn = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The entrance carries everyone in at the start of a level; later,
    // someone new appearing at the back of the visible queue walks in.
    final entering = (widget.entrance?.value ?? 1) < 1;
    if (widget.depth > 0 && !entering && !reduceMotion(context)) {
      _from = 0.6;
      _fadeIn = true;
      _play(widget.depth);
    } else {
      _c.value = 1;
    }
  }

  /// One spring, started [BoardMotion.stepStagger] * [depth] ms late.
  void _play(int depth) {
    final delay = BoardMotion.stepStagger * depth;
    final total = BoardMotion.stepMs + delay;
    _c
      ..duration = Duration(milliseconds: total)
      ..forward(from: 0);
    _curve = Interval(delay / total, 1, curve: MotionCurves.soft);
  }

  Curve _curve = MotionCurves.soft;

  @override
  void didUpdateWidget(_StepIn old) {
    super.didUpdateWidget(old);
    if (widget.depth < old.depth && !reduceMotion(context)) {
      _from = (old.depth - widget.depth).toDouble();
      _fadeIn = false;
      _play(widget.depth);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrance = widget.entrance;
    final rise = EntranceMotion.personRise * Metrics.of(context).scale;
    final turn = EntranceMotion.person(widget.lane, widget.depth);
    return AnimatedBuilder(
      animation: entrance == null ? _c : Listenable.merge([_c, entrance]),
      child: widget.child,
      builder: (context, child) {
        final t = _curve.transform(_c.value);
        final e = entrance == null ? 1.0 : turn.transform(entrance.value);
        return Opacity(
          opacity: ((_fadeIn ? t : 1.0) * e).clamp(0, 1).toDouble(),
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, rise * (1 - e)),
            child: FractionalTranslation(translation: Offset(0, _from * (1 - t)), child: child),
          ),
        );
      },
    );
  }
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
