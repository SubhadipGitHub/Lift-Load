import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/formulas.dart';
import '../game_controller.dart';
import '../theme.dart';
import '../widgets/resident_figure.dart';
import '../widgets/result_sheets.dart';
import 'play_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    // Refresh the life countdown once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      c.profile.regenLives(c.now);
      if (mounted) setState(() {});
    });
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    _tick?.cancel();
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _play() async {
    c.startLevel();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlayScreen(controller: c)));
    if (mounted) setState(() {});
  }

  String _countdown(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = c.profile;
    final next = p.nextLifeIn(c.now);
    final hasLives = p.lives > 0;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Stat(icon: Icons.favorite_rounded, color: LL.alarm, text: '${p.lives}'),
                      if (next != null) ...[
                        const SizedBox(width: 6),
                        Text('next in ${_countdown(next)}', style: const TextStyle(fontSize: 12, color: LL.lilac, fontWeight: FontWeight.w700)),
                      ],
                      const Spacer(),
                      _Stat(icon: Icons.monetization_on_rounded, color: LL.brass, text: '${p.coins}'),
                      const SizedBox(width: 6),
                      _Stat(icon: Icons.scale_rounded, color: LL.brass, text: '${p.scales}'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Lift '),
                      TextSpan(text: 'Load', style: LL.display.copyWith(fontSize: 58, color: LL.brass)),
                    ]),
                    style: LL.display.copyWith(fontSize: 58, color: LL.cream),
                  ),
                  const SizedBox(height: 4),
                  const Text('Fill every lift. Never overload it.',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: LL.lilac)),
                  const Expanded(child: _Lobby()),
                  if (p.winStreak >= 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('Win streak ${p.winStreak}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: LL.brass)),
                    ),
                  PrimaryButton(
                    label: hasLives ? 'Play · Level ${p.level}' : 'Out of lives',
                    height: 62,
                    onPressed: hasLives ? _play : null,
                  ),
                  if (!hasLives && c.canAdForLife) ...[
                    const SizedBox(height: 10),
                    RewardedButton(
                      label: c.adInFlight ? 'Loading ad…' : 'Watch ad · +1 life',
                      onPressed: c.adInFlight ? null : c.adForLife,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(_nextHint(p.level), style: const TextStyle(fontSize: 12, color: LL.lilac, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _nextHint(int level) {
    final d = Formulas.difficulty(level);
    final debut = ResidentType.introducedAt(level);
    if (debut != null) return 'New resident today: ${debut.displayName}';
    return switch (d) {
      Difficulty.hard => 'Hard level: one spare trip',
      Difficulty.superHard => 'Super Hard level: one spare trip, one extra floor',
      Difficulty.breather => 'Breather level: three spare trips',
      Difficulty.normal => 'Two spare trips',
    };
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

/// Home illustration: a lit tower lobby with a few of the cast waiting.
class _Lobby extends StatelessWidget {
  const _Lobby();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: LL.brass, borderRadius: BorderRadius.circular(6)),
                child: const Text('SUNRISE TOWERS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: LL.ink)),
              ),
              const SizedBox(height: 14),
              Container(
                width: 280,
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: const BoxDecoration(
                  color: LL.tile,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ResidentFigure(type: ResidentType.aunty, height: 92),
                    ResidentFigure(type: ResidentType.kid, height: 92),
                    ResidentFigure(type: ResidentType.officeM, height: 92),
                    ResidentFigure(type: ResidentType.uncle, height: 92),
                    ResidentFigure(type: ResidentType.rider, height: 92),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
