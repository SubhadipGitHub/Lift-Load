import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/engine.dart';
import '../game_controller.dart';
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
                    ResidentFigure(type: r.type, height: 52),
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
class QueueLanes extends StatelessWidget {
  const QueueLanes({super.key, required this.game, required this.onTapLane});

  static const int visible = 4;

  final LiftGame game;
  final ValueChanged<int> onTapLane;

  @override
  Widget build(BuildContext context) {
    final playing = game.phase == Phase.playing;
    final lanes = game.queues;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      decoration: const BoxDecoration(
        color: LL.tile,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var lane = 0; lane < lanes.length; lane++)
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < lanes[lane].length && i < visible; i++)
                    _QueueSlot(
                      resident: lanes[lane][i],
                      depth: i,
                      front: i == 0 && playing,
                      selected: i == 0 && game.selection == Selection.queue(lane),
                      onTap: () => onTapLane(lane),
                    ),
                  if (lanes[lane].length > visible)
                    Text(
                      '+${lanes[lane].length - visible} waiting',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B5C44)),
                    ),
                  if (lanes[lane].isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 18),
                      child: Text('Clear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B5C44))),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QueueSlot extends StatelessWidget {
  const _QueueSlot({required this.resident, required this.depth, required this.front, required this.selected, required this.onTap});

  final Resident resident;
  final int depth;
  final bool front, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = front ? 1.0 : (0.88 - depth * 0.12).clamp(0.5, 1.0).toDouble();
    return Semantics(
      button: front,
      selected: selected,
      label: '${GameController.describe(resident)}${front ? '' : ', waiting in queue'}',
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
                ResidentFigure(type: resident.type, height: 54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
