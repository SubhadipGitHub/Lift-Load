import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../../game/venue.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../theme.dart';
import 'art_icon.dart';
import 'glossy.dart';
import 'tester_sheets.dart';

/// Dimmed full-screen layer with a centred card.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.children, required this.label});

  final List<Widget> children;
  final String label;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: const Color(0xC20C0B1E),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Semantics(
                  container: true,
                  label: label,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.7, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    builder: (context, s, child) => Transform.scale(scale: s, child: child),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                      decoration: BoxDecoration(color: LL.cream, borderRadius: BorderRadius.circular(26)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: children),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Watch an ad: the mint glossy button with the play icon. Slate while it
/// cannot be pressed.
class RewardedButton extends StatelessWidget {
  const RewardedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SheetButton(
        style: SurfaceStyle.mint,
        icon: GameIcon.play,
        label: label,
        onPressed: onPressed,
        height: SheetButton.tall,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      );
}

/// The main action on a sheet or the home screen: brass glossy.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.height = 54, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final GameIcon? icon;

  @override
  Widget build(BuildContext context) => SheetButton(
        style: SurfaceStyle.brass,
        icon: icon,
        label: label,
        onPressed: onPressed,
        height: height,
        textStyle: LL.display.copyWith(fontSize: 21),
      );
}

/// A full-width glossy button on a sheet: an optional approved icon and a
/// label that shrinks rather than wraps.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.style,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = quiet,
    this.textStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  });

  /// Heights: a rewarded button, and a quiet or secondary one.
  static const double tall = 58;
  static const double quiet = 52;

  final SurfaceStyle style;
  final String label;
  final VoidCallback? onPressed;
  final GameIcon? icon;
  final double height;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final ink = (onPressed == null ? SurfaceStyle.off : style).ink;
    return GlossyButton(
      style: style,
      onPressed: onPressed,
      width: double.infinity,
      height: math.max(height, Metrics.minTouch),
      radius: Metrics.sheetButtonRadius,
      padding: const EdgeInsets.symmetric(horizontal: Metrics.sheetButtonGap),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final i?) ...[
              ArtIcon(i, size: Metrics.sheetButtonIcon, color: ink),
              const SizedBox(width: Metrics.sheetButtonGap / 2),
            ],
            Text(label, style: textStyle.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}

class _QuietButton extends StatelessWidget {
  const _QuietButton({required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final GameIcon? icon;

  @override
  Widget build(BuildContext context) =>
      SheetButton(style: SurfaceStyle.cream, icon: icon, label: label, onPressed: onPressed);
}

class FailSheet extends StatelessWidget {
  const FailSheet({super.key, required this.c, required this.onHome});

  final GameController c;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final kind = c.game.failKind!;
    final seats = c.seatsLabel(c.game.continueSeats);
    final (title, body, adLabel) = switch (kind) {
      FailKind.crash => (
          'Overloaded!',
          'The cable snapped and the lift dropped to the basement. The brakes held and everyone is fine.',
          'Watch ad · Repair the lift',
        ),
      FailKind.outOfTrips => (
          'Out of trips',
          'Too many half-empty lifts. Residents are still waiting in the lobby.',
          'Watch ad · +${Formulas.adTripsBonus} trips${seats.isEmpty ? '' : ' and $seats'}',
        ),
      FailKind.jam => (
          'Lobby jammed!',
          'The bench is full and nobody waiting can take this lift.',
          'Watch ad · $seats',
        ),
    };
    final (icon, tint) = switch (kind) {
      FailKind.crash => (GameIcon.cableSnap, LL.alarm),
      FailKind.outOfTrips => (GameIcon.hourglass, LL.brassDark),
      FailKind.jam => (GameIcon.seat, LL.inkSoft),
    };
    return _Overlay(
      label: title,
      children: [
        _Badge(icon: icon, color: tint),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 34, color: LL.ink)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4, color: LL.inkSoft)),
        const SizedBox(height: 14),
        if (c.askCrashFair) ...[
          CrashFairRow(c: c),
          const SizedBox(height: 12),
        ],
        if (c.canContinueWithAd) ...[
          RewardedButton(
              label: c.adInFlight ? 'Loading ad…' : adLabel, onPressed: c.adInFlight ? null : c.continueWithAd),
          const SizedBox(height: Metrics.sheetButtonGap),
        ],
        if (c.canContinueWithCoins) ...[
          SheetButton(
            style: SurfaceStyle.plum,
            icon: GameIcon.coin,
            label: '${Formulas.coinContinuePrice} coins · same fix',
            onPressed: c.adInFlight ? null : c.continueWithCoins,
          ),
          const SizedBox(height: Metrics.sheetButtonGap),
        ],
        _QuietButton(
          icon: GameIcon.restart,
          label: 'Retry · uses 1 life',
          onPressed: c.adInFlight ? null : c.retry,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: c.adInFlight ? null : onHome,
          child: const Text('Back to the tower', style: TextStyle(color: LL.inkSoft, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class WinSheet extends StatelessWidget {
  const WinSheet({super.key, required this.c, required this.onHome});

  final GameController c;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return _Overlay(
      label: 'Tower delivered',
      children: [
        const _Badge(icon: GameIcon.trophy, color: LL.brass),
        const SizedBox(height: 10),
        Text('LEVEL ${g.level.number} CLEAR', style: LL.label.copyWith(color: LL.inkSoft)),
        const SizedBox(height: 8),
        Text('Tower delivered!', textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 34, color: LL.ink)),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtIcon(GameIcon.star, size: Metrics.sheetStar),
            const SizedBox(width: Metrics.sheetButtonGap / 3),
            Flexible(
              child: Text('${g.tripsUsed} trips · ${g.perfects} perfect loads',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LL.inkSoft)),
            ),
          ],
        ),
        if (g.level.number == g.level.venue.lastLevel) ...[
          const SizedBox(height: 12),
          _BuildingComplete(venue: g.level.venue),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: LL.ink, borderRadius: BorderRadius.circular(999)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ArtIcon(GameIcon.coin, size: Metrics.sheetButtonIcon),
                const SizedBox(width: 6),
                // Counts up to the award; settles, so tests stay deterministic.
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: c.tripleClaimed ? g.levelCoins * 3 : g.levelCoins),
                  duration: Duration(milliseconds: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? 0 : 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) =>
                      Text('+$v coins', style: LL.display.copyWith(fontSize: 24, color: LL.cream)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (c.canTriple) ...[
          RewardedButton(
            label: c.adInFlight ? 'Loading ad…' : 'Watch ad · ×3 = ${g.levelCoins * 3} coins',
            onPressed: c.adInFlight ? null : c.claimTriple,
          ),
          const SizedBox(height: Metrics.sheetButtonGap),
        ],
        if (c.askHeavyTypes) ...[
          HeavyTypesCard(c: c),
          const SizedBox(height: 12),
        ],
        if (c.testComplete) ...[
          const Text(
            "That's the whole test. Thank you for playing!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: LL.ink),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: 'Send results', onPressed: () => showResultsSheet(context, c)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onHome,
            child: const Text('Back to the tower', style: TextStyle(color: LL.inkSoft, fontWeight: FontWeight.w700)),
          ),
        ] else
          PrimaryButton(label: 'Continue', onPressed: c.adInFlight ? null : c.nextLevel),
      ],
    );
  }
}

/// Shown on the win sheet for the last level of a venue.
class _BuildingComplete extends StatelessWidget {
  const _BuildingComplete({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final next = venue.index + 1 < Venue.values.length ? Venue.values[venue.index + 1] : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: LL.ink, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('${venue.displayName} complete!',
              textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 18, color: LL.brass)),
          const SizedBox(height: 4),
          Text(
            next == null
                ? 'Every building delivered. The hotel stays open for more.'
                : 'Next stop: ${next.displayName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LL.cream),
          ),
        ],
      ),
    );
  }
}

/// A round illustration at the top of a sheet: an approved icon on a soft
/// disc of [color].
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final GameIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: Metrics.sheetBadge,
        height: Metrics.sheetBadge,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.08)]),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 3),
        ),
        child: ArtIcon(icon, size: Metrics.sheetBadgeIcon, color: color),
      );
}
