import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../../game/scenario.dart';
import '../game_controller.dart';
import '../painters/lobby_painter.dart';
import '../theme.dart';
import 'resident_figure.dart';

/// Bench seats: tap a seated resident to select them, tap an empty seat to
/// park the selected queue resident.
class BenchRow extends StatelessWidget {
  const BenchRow({super.key, required this.game, required this.onTapSeat});

  final LiftGame game;
  final ValueChanged<int> onTapSeat;

  @override
  Widget build(BuildContext context) {
    final playing = game.phase == Phase.playing;
    final seating = playing && game.selection != null && !game.selection!.fromBench;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LOBBY BENCH', style: LL.label),
              Text('${game.benchUsed}/${game.bench.length}', style: LL.label),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              for (var i = 0; i < game.bench.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Seat(
                    resident: game.bench[i],
                    selected: game.selection == Selection.bench(i),
                    seatHint: seating && game.bench[i] == null,
                    enabled: playing,
                    onTap: () => onTapSeat(i),
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
  const _Seat({required this.resident, required this.selected, required this.seatHint, required this.enabled, required this.onTap});

  final Resident? resident;
  final bool selected, seatHint, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = resident;
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
    return Semantics(
      button: true,
      label: r == null ? 'Empty bench seat' : 'Bench: ${GameController.describe(r)}',
      selected: selected,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 74,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 2),
          ),
          child: r != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloorTag(floor: r.floor, compact: true),
                    FittedBox(fit: BoxFit.scaleDown, child: ResidentFigure.of(r, height: 52)),
                  ],
                )
              : seatHint
                  ? const Center(child: Text('Seat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LL.brass)))
                  : null,
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
  const QueueLanes({super.key, required this.game, required this.onTapLane});

  static const int visible = 4;

  final LiftGame game;
  final ValueChanged<int> onTapLane;

  @override
  Widget build(BuildContext context) {
    final playing = game.phase == Phase.playing;
    final lanes = game.queues;
    final style = VenueStyle.of(game.level.venue);
    final powerCut = game.level.scenario == Scenario.powerCut;
    final ink = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: style.laneInk);
    final pending = game.pendingArrivals;
    final wave = pending.isEmpty ? 0 : pending.where((a) => a.afterTrip == pending.first.afterTrip).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: style.floor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: CustomPaint(
        painter: FloorPatternPainter(style),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
          child: Column(
            children: [
              if (wave > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _Banner(
                    icon: Icons.groups_rounded,
                    text: '+$wave arriving after trip ${pending.first.afterTrip}',
                  ),
                ),
              if (powerCut)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: _Banner(icon: Icons.flashlight_on_rounded, text: 'Power cut: only the front is lit'),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var lane = 0; lane < lanes.length; lane++)
                    Expanded(
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              for (var i = 0; i < lanes[lane].length && i < visible; i++)
                                _QueueSlot(
                                  resident: lanes[lane][i],
                                  depth: i,
                                  front: i == 0 && playing && !game.isLaneLocked(lane),
                                  selected: i == 0 && game.selection == Selection.queue(lane),
                                  dimmed: powerCut && i >= Formulas.powerCutDepth,
                                  onTap: () => onTapLane(lane),
                                ),
                              if (lanes[lane].length > visible) Text('+${lanes[lane].length - visible} waiting', style: ink),
                              if (lanes[lane].isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: Text('Clear', style: ink.copyWith(fontSize: 12)),
                                ),
                            ],
                          ),
                          if (game.isLaneLocked(lane))
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () => onTapLane(lane),
                                child: _Cones(tripsLeft: game.tripsUntilLaneOpens),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: LL.ink, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: LL.brass),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LL.cream),
              ),
            ),
          ],
        ),
      );
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              const Icon(Icons.construction_rounded, size: 30, color: Color(0xFFFF8A3D)),
              const SizedBox(height: 4),
              Text(
                'Opens in\n$tripsLeft ${tripsLeft == 1 ? 'trip' : 'trips'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: LL.cream, height: 1.2),
              ),
            ],
          ),
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
    final who = dimmed ? 'Someone going to ${resident.floor.label}' : GameController.describe(resident);
    return Semantics(
      button: front,
      selected: selected,
      label: '$who${front ? '' : ', waiting in queue'}',
      child: GestureDetector(
        onTap: front ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 1),
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
                FloorTag(floor: resident.floor, compact: true),
                const SizedBox(height: 1),
                ResidentFigure.of(resident, height: 54, dimmed: dimmed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
