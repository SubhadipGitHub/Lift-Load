import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../../game/powers.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../theme.dart';
import 'pressable.dart';
import 'power_sheets.dart';

/// Player-facing words for each power. Nothing here mentions a weight.
extension PowerCopy on Power {
  /// The label under its dock button.
  String get dockLabel => switch (this) {
        Power.swap => 'Swap',
        Power.seats => '+${Formulas.powerSeats} seats',
        Power.trip => '+${Formulas.powerTrips} trip',
        Power.express => 'Express',
      };

  /// What one refill grants, after the "+1": "+1 Swap", "+1 Seats".
  String get rewardName => switch (this) {
        Power.swap => 'Swap',
        Power.seats => 'Seats',
        Power.trip => 'Trip',
        Power.express => 'Express',
      };

  /// One line on what it does, for the get-more sheet and accessibility.
  String get blurb => switch (this) {
        Power.swap => 'Trade the front people of two lanes.',
        Power.seats => '${Formulas.powerSeats} more bench seats until this level ends.',
        Power.trip => '${Formulas.powerTrips} more trip for this level.',
        Power.express => 'Send the selected person straight to their floor, with no seat and no trip.',
      };
}

/// SPRITE SLOT. The one place a power's picture is chosen. Material icons are
/// placeholders until the Swap and Express art exists; replace the body of
/// this widget (for example with an `Image.asset` per power) and nothing else
/// in the dock or the sheet needs to change.
class PowerIcon extends StatelessWidget {
  const PowerIcon(this.power, {super.key, required this.size, required this.color});

  final Power power;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(
        switch (power) {
          Power.swap => Icons.swap_horiz_rounded,
          Power.seats => Icons.event_seat_rounded,
          Power.trip => Icons.elevator_rounded,
          Power.express => Icons.bolt_rounded,
        },
        size: size,
        color: color,
      );
}

/// One round button per unlocked power: icon, short label and a stock badge
/// (0 reads as empty). A tap with stock acts, or arms Swap; a tap on an empty
/// power opens the get-more sheet; a tap on a blocked one explains why in the
/// message line.
class PowerDock extends StatelessWidget {
  const PowerDock({super.key, required this.c});

  final GameController c;

  /// The powers shown: only the ones this level has unlocked.
  static List<Power> unlocked(GameController c) => [
        for (final p in Power.values)
          if (c.powerUnlocked(p)) p
      ];

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final powers = unlocked(c);
    return Semantics(
      container: true,
      label: 'Power options',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, p) in powers.indexed) ...[
            if (i > 0) SizedBox(width: m.dockGap),
            _PowerButton(c: c, power: p),
          ],
        ],
      ),
    );
  }
}

enum _State { ready, armed, blocked, empty, capped }

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.c, required this.power});

  final GameController c;
  final Power power;

  bool get _playing => c.hasGame && c.game.phase == Phase.playing;
  bool get _capped => c.game.powerUses(power) >= Formulas.powerCap(power);

  _State get _state {
    if (c.armedPower == power) return _State.armed;
    if (_capped) return _State.capped;
    if (c.powerStock(power) <= 0) return _State.empty;
    if (!_playing || !c.powerUsable(power)) return _State.blocked;
    return _State.ready;
  }

  /// Why the button does nothing right now, in one short line.
  String get _why => switch (_state) {
        _State.capped => 'Used up on this level',
        _State.blocked when !_playing => 'Wait for the lift',
        _State.blocked => switch (power) {
            Power.swap => 'Needs two lanes with people',
            Power.express => 'Select someone first',
            Power.seats || Power.trip => 'Not available right now',
          },
        _State.ready || _State.armed || _State.empty => '',
      };

  String get _label {
    final stock = c.powerStock(power);
    final name = '${power.dockLabel}: ${power.blurb}';
    return switch (_state) {
      _State.armed => '$name Armed. Tap again to cancel.',
      _State.empty => '$name None left. Tap to get more.',
      _State.capped => '$name $_why.',
      _State.blocked => '$name $stock left. $_why.',
      _State.ready => '$name $stock left.',
    };
  }

  void _tap(BuildContext context) {
    if (!_playing || c.adInFlight) return;
    final offerRefill = c.powerStock(power) <= 0 && !_capped;
    c.usePower(power);
    if (offerRefill) showGetMoreSheet(context, c, power);
  }

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final state = _state;
    final d = m.dockButton;
    final armed = state == _State.armed;
    final dim = state == _State.empty || state == _State.capped || state == _State.blocked;
    final stock = c.powerStock(power);
    final empty = stock <= 0;
    return Semantics(
      key: ValueKey('power-${power.name}'),
      button: true,
      selected: armed,
      enabled: _playing,
      label: _label,
      onTap: () => _tap(context),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tap(context),
          child: PressScale(
            enabled: _playing,
            child: SizedBox(
              width: d,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: d,
                    height: d,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: motionMs(context, 120),
                          width: d,
                          height: d,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: armed ? LL.brass : LL.cream.withValues(alpha: dim ? 0.6 : 1),
                            border: Border.all(color: armed ? LL.cream : LL.brassDark, width: armed ? 3 : 2),
                            boxShadow: [BoxShadow(color: LL.rule, offset: Offset(0, 3 * m.scale))],
                          ),
                          child: Center(child: PowerIcon(power, size: d * 0.52, color: LL.ink)),
                        ),
                        Positioned(
                          right: -4 * m.scale,
                          top: -5 * m.scale,
                          child: Container(
                            constraints: BoxConstraints(minWidth: 22 * m.scale, minHeight: 22 * m.scale),
                            padding: EdgeInsets.symmetric(horizontal: 4 * m.scale),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: empty ? LL.deep : LL.brass,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: empty ? LL.lilac : LL.brassDark, width: 2),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$stock',
                                style: LL.display.copyWith(fontSize: m.font(12), color: empty ? LL.lilac : LL.ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (m.dockLabels) SizedBox(height: 4 * m.scale),
                  if (m.dockLabels)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        power.dockLabel,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: m.font(10),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: armed ? LL.brass : LL.lilac,
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
