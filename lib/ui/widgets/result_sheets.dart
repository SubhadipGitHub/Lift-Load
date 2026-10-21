import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../../game/formulas.dart';
import '../game_controller.dart';
import '../theme.dart';

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
            child: Padding(
              padding: const EdgeInsets.all(22),
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
      );
}

class RewardedButton extends StatelessWidget {
  const RewardedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.play_circle_fill_rounded, size: 24),
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: LL.mint,
            foregroundColor: LL.mintInk,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.height = 54});

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: LL.brass,
            foregroundColor: LL.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(label, style: LL.display.copyWith(fontSize: 21)),
        ),
      );
}

class _QuietButton extends StatelessWidget {
  const _QuietButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: LL.ink,
            side: const BorderSide(color: Color(0xFFCDB993), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      );
}

class FailSheet extends StatelessWidget {
  const FailSheet({super.key, required this.c, required this.onHome});

  final GameController c;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final kind = c.game.failKind!;
    final (title, body, adLabel) = switch (kind) {
      FailKind.crash => (
          'Overloaded!',
          'The cable snapped and the lift dropped to the basement. The brakes held and everyone is fine.',
          'Watch ad · Repair the lift',
        ),
      FailKind.outOfTrips => (
          'Out of trips',
          'Too many half-empty lifts. Residents are still waiting in the lobby.',
          'Watch ad · +${Formulas.adTripsBonus} trips',
        ),
      FailKind.jam => (
          'Lobby jammed!',
          'The bench is full and nobody waiting can take this lift.',
          'Watch ad · +1 bench seat',
        ),
    };
    return _Overlay(
      label: title,
      children: [
        Text(title, textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 34, color: LL.ink)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4, color: LL.inkSoft)),
        const SizedBox(height: 14),
        if (c.canContinueWithAd) ...[
          RewardedButton(label: c.adInFlight ? 'Loading ad…' : adLabel, onPressed: c.adInFlight ? null : c.continueWithAd),
          const SizedBox(height: 10),
        ],
        if (c.canContinueWithCoins) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: c.adInFlight ? null : c.continueWithCoins,
              style: FilledButton.styleFrom(
                backgroundColor: LL.ink,
                foregroundColor: LL.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('${Formulas.coinContinuePrice} coins · same fix',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _QuietButton(label: 'Retry · uses 1 life', onPressed: c.adInFlight ? null : c.retry),
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
  const WinSheet({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return _Overlay(
      label: 'Tower delivered',
      children: [
        Text('LEVEL ${g.level.number} CLEAR', style: LL.label.copyWith(color: LL.inkSoft)),
        const SizedBox(height: 8),
        Text('Tower delivered!', textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 34, color: LL.ink)),
        const SizedBox(height: 8),
        Text('${g.tripsUsed} trips · ${g.perfects} perfect loads',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: LL.inkSoft)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: LL.ink, borderRadius: BorderRadius.circular(999)),
          child: Text('+${c.tripleClaimed ? g.levelCoins * 3 : g.levelCoins} coins',
              style: LL.display.copyWith(fontSize: 24, color: LL.cream)),
        ),
        const SizedBox(height: 14),
        if (c.canTriple) ...[
          RewardedButton(
            label: c.adInFlight ? 'Loading ad…' : 'Watch ad · ×3 = ${g.levelCoins * 3} coins',
            onPressed: c.adInFlight ? null : c.claimTriple,
          ),
          const SizedBox(height: 10),
        ],
        PrimaryButton(label: 'Continue', onPressed: c.adInFlight ? null : c.nextLevel),
      ],
    );
  }
}
