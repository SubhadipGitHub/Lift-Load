import 'package:flutter/material.dart';

import '../../game/formulas.dart';
import '../../game/powers.dart';
import '../../services/ad_policy.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../theme.dart';
import 'glossy.dart';
import 'power_dock.dart';
import 'result_sheets.dart';

/// The small sheet behind an empty power button: spend coins, or watch one
/// ad that the button names. An ad never starts without a tap on its button.
Future<void> showGetMoreSheet(BuildContext context, GameController c, Power power) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: LL.cream,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GetMoreSheet(c: c, power: power),
        ),
      ),
    );

class GetMoreSheet extends StatefulWidget {
  const GetMoreSheet({super.key, required this.c, required this.power});

  final GameController c;
  final Power power;

  @override
  State<GetMoreSheet> createState() => _GetMoreSheetState();
}

class _GetMoreSheetState extends State<GetMoreSheet> {
  /// Shown when an ad ended without a reward.
  String? _note;

  GameController get c => widget.c;
  Power get power => widget.power;

  void _buy() {
    c.buyPowerWithCoins(power);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _watch() async {
    final before = c.powerStock(power);
    setState(() => _note = null);
    await c.adForPower(power);
    if (!mounted) return;
    if (c.powerStock(power) > before) {
      Navigator.of(context).pop();
    } else {
      setState(() => _note = 'The ad did not finish, so there is no reward.');
    }
  }

  /// One short line on why the coin button is off, or null when it is on.
  String? get _coinWhy {
    if (c.canBuyPower(power)) return null;
    return 'Needs ${Formulas.powerCoinPrice(power)} coins. You have ${c.profile.coins}.';
  }

  /// One short line on why the ad button is off, or null when it is on.
  String? get _adWhy {
    if (c.canAdForPower(power)) return null;
    if (c.adInFlight) return 'An ad is loading.';
    if (!c.profile.rewarded.canShow(RewardedPlacement.powerRefill, c.now)) return 'No more ad refills today.';
    return 'Not available right now.';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final price = Formulas.powerCoinPrice(power);
          final busy = c.adInFlight;
          final coinWhy = _coinWhy;
          final adWhy = _adWhy;
          final short = Metrics.of(context).shortLandscape;
          final coinButton = PrimaryButton(
            icon: GameIcon.coin,
            label: 'Spend $price coins',
            onPressed: coinWhy == null && !busy ? _buy : null,
          );
          final adButton = RewardedButton(
            label: busy ? 'Loading ad…' : 'Watch an ad · +${Formulas.powerAdUses} ${power.rewardName}',
            onPressed: adWhy == null ? _watch : null,
          );
          final coinNote = coinWhy == null ? null : _Why(coinWhy);
          final adNote = adWhy == null || busy ? null : _Why(adWhy);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    label: 'Get more ${power.dockLabel}',
                    child: Column(
                      children: [
                        if (!short)
                          Glossy(
                            style: SurfaceStyle.plum,
                            depth: SurfaceDepth.chip,
                            inset: false,
                            width: Metrics.sheetPower,
                            height: Metrics.sheetPower,
                            child: Center(
                              child: PowerIcon(power, size: Metrics.sheetPower * Metrics.dockIconShare, color: LL.cream),
                            ),
                          ),
                        if (!short) const SizedBox(height: 8),
                        Text(power.dockLabel,
                            textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 26, color: LL.ink)),
                        const SizedBox(height: 4),
                        Text(
                          '${power.blurb} You have none left.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, height: 1.35, color: LL.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (short)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: [coinButton, if (coinNote != null) coinNote])),
                        const SizedBox(width: Metrics.sheetButtonGap),
                        Expanded(child: Column(children: [adButton, if (adNote != null) adNote])),
                      ],
                    )
                  else ...[
                    coinButton,
                    if (coinNote != null) coinNote,
                    const SizedBox(height: Metrics.sheetButtonGap),
                    adButton,
                    if (adNote != null) adNote,
                  ],
                  if (_note != null) _Why(_note!),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Not now', style: TextStyle(color: LL.inkSoft, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _Why extends StatelessWidget {
  const _Why(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LL.inkSoft),
        ),
      );
}
