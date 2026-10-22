import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../../game/powers.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../theme.dart';
import 'art_icon.dart';
import 'glossy.dart';
import 'power_sheets.dart';
import 'pressable.dart';

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

/// SPRITE SLOT. The one place a power's picture is chosen. +2 seats and +1
/// trip use the approved seat and trip icons ([ArtIcon], which falls back to
/// Material when sprite art is off); Swap and Express keep Material
/// placeholders until their art exists. [color] tints placeholders and
/// fallbacks only.
class PowerIcon extends StatelessWidget {
  const PowerIcon(this.power, {super.key, required this.size, required this.color});

  final Power power;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => switch (power) {
        Power.seats => ArtIcon(GameIcon.seat, size: size, color: color),
        Power.trip => ArtIcon(GameIcon.trip, size: size, color: color),
        Power.swap => Icon(Icons.swap_horiz_rounded, size: size, color: color),
        Power.express => Icon(Icons.bolt_rounded, size: size, color: color),
      };
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

  /// A power that cannot act right now is faded; an empty one only a little,
  /// since a tap still offers more.
  static const double dimOpacity = 0.55;
  static const double emptyOpacity = 0.88;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final state = _state;
    final d = m.dockButton;
    final armed = state == _State.armed;
    final opacity = switch (state) {
      _State.empty => emptyOpacity,
      _State.capped || _State.blocked => dimOpacity,
      _State.ready || _State.armed => 1.0,
    };
    final stock = c.powerStock(power);
    final empty = stock <= 0;
    final badgeText = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '$stock',
        style: LL.display.copyWith(fontSize: m.font(12), color: empty ? LL.lilac : LL.ink),
      ),
    );
    final badgeBox = BoxConstraints(minWidth: m.dockBadge, minHeight: m.dockBadge);
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
          child: Pressable(
            enabled: _playing,
            builder: (context, down) => SizedBox(
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
                        Opacity(
                          opacity: opacity,
                          child: Glossy(
                            style: armed ? SurfaceStyle.brass : SurfaceStyle.cream,
                            // Outset keeps the face round; its edge paints into the label gap.
                            inset: false,
                            pressed: down,
                            glow: armed ? LL.pickGlow : null,
                            width: d,
                            height: d,
                            child: Center(child: PowerIcon(power, size: d * Metrics.dockIconShare, color: LL.ink)),
                          ),
                        ),
                        Positioned(
                          right: -m.dockBadgeOffset,
                          top: -m.dockBadgeOffset,
                          child: empty
                              ? Container(
                                  constraints: badgeBox,
                                  padding: EdgeInsets.symmetric(horizontal: m.dockBadgePad),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: LL.deep,
                                    borderRadius: BorderRadius.circular(m.dockBadge),
                                    border: Border.all(color: LL.lilac, width: Metrics.gaugePlateRim),
                                  ),
                                  child: badgeText,
                                )
                              : Glossy(
                                  style: SurfaceStyle.brass,
                                  depth: SurfaceDepth.tag,
                                  inset: false,
                                  child: Container(
                                    constraints: badgeBox,
                                    padding: EdgeInsets.symmetric(horizontal: m.dockBadgePad),
                                    alignment: Alignment.center,
                                    child: badgeText,
                                  ),
                                ),
                        ),
                        // Used up on this level: a lock, whatever stock is left.
                        if (state == _State.capped)
                          Positioned(
                            left: -m.dockBadgeOffset,
                            bottom: -m.dockBadgeOffset,
                            child: ArtIcon(GameIcon.lock, size: m.dockLock),
                          ),
                      ],
                    ),
                  ),
                  if (m.dockLabels) SizedBox(height: m.dockLabelGap),
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
