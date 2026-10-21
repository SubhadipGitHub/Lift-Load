import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../game_controller.dart';
import '../theme.dart';
import '../widgets/lift_shaft.dart';
import '../widgets/lobby.dart';
import '../widgets/result_sheets.dart';

/// The level screen. Owns the cabin animations: when the engine enters
/// [Phase.departing] or [Phase.falling], this screen animates the cabin and
/// then tells the controller the animation finished.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);
  Animation<double> _dy = const AlwaysStoppedAnimation(0);
  Animation<double> _tilt = const AlwaysStoppedAnimation(0);
  Phase? _lastPhase;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _lastPhase = c.game.phase;
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    _anim.dispose();
    super.dispose();
  }

  void _onChange() {
    final phase = c.hasGame ? c.game.phase : null;
    final was = _lastPhase;
    _lastPhase = phase;
    if (phase == was) {
      setState(() {});
      return;
    }
    switch (phase) {
      case Phase.departing:
        _run(from: 0, to: -300, ms: 500, curve: Curves.easeInCubic).then((_) => c.finishSend());
      case Phase.falling:
        _run(from: 0, to: 340, tiltTo: -0.09, ms: 1000, curve: Curves.easeInQuad).then((_) => c.finishCrash());
      case Phase.playing when was == Phase.departing || was == Phase.failed:
        // A new lift drops in from above, or the repaired lift springs back.
        _run(from: was == Phase.departing ? -300 : 120, to: 0, ms: 450, curve: Curves.easeOutBack);
      case Phase.playing:
        _snapHome();
      case Phase.won || Phase.failed || null:
        if (phase == Phase.won) _snapHome();
    }
    setState(() {});
  }

  void _snapHome() {
    _anim.stop();
    _dy = const AlwaysStoppedAnimation(0);
    _tilt = const AlwaysStoppedAnimation(0);
  }

  Future<void> _run({required double from, required double to, double tiltTo = 0, required int ms, required Curve curve}) {
    final curved = CurvedAnimation(parent: _anim, curve: curve);
    _dy = Tween(begin: from, end: to).animate(curved);
    _tilt = Tween(begin: 0.0, end: tiltTo).animate(curved);
    _anim
      ..duration = Duration(milliseconds: ms)
      ..reset();
    return _anim.forward().orCancel.catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Stack(
              children: [
                Column(
                  children: [
                    _Hud(c: c, onBack: () {
                      c.quitToHome();
                      Navigator.of(context).pop();
                    }),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => LiftShaft(
                        game: g,
                        cabinDy: _dy.value,
                        cabinTilt: _tilt.value,
                        onTapLift: c.tapLift,
                        onSend: c.send,
                      ),
                    ),
                    SizedBox(
                      height: 32,
                      child: Center(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            c.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: LL.brass),
                          ),
                        ),
                      ),
                    ),
                    BenchRow(game: g, onTapSeat: c.tapBench),
                    Expanded(
                      child: SingleChildScrollView(
                        child: QueueLanes(game: g, onTapLane: c.tapQueue),
                      ),
                    ),
                    _Toolbar(c: c),
                  ],
                ),
                if (g.phase == Phase.failed)
                  FailSheet(
                    c: c,
                    onHome: () {
                      c.quitToHome();
                      Navigator.of(context).pop();
                    },
                  ),
                if (g.phase == Phase.won) WinSheet(c: c),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.c, required this.onBack});

  final GameController c;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to the tower',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: LL.cream),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
              decoration: BoxDecoration(color: LL.brass, borderRadius: BorderRadius.circular(999)),
              child: Text('Lv ${g.level.number}', style: LL.display.copyWith(fontSize: 19, color: LL.ink)),
            ),
            const SizedBox(width: 8),
            Text('Trips left ${g.tripsLeft}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: LL.lilac)),
            const Spacer(),
            _Chip(icon: Icons.favorite_rounded, color: LL.alarm, text: '${c.profile.lives}'),
            const SizedBox(width: 6),
            _Chip(icon: Icons.monetization_on_rounded, color: LL.brass, text: '${c.profile.coins}'),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
        decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final playing = c.game.phase == Phase.playing;
    Widget tool({required IconData icon, required String label, required VoidCallback? onTap, String? tooltip}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Tooltip(
              message: tooltip ?? label,
              child: FilledButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 20),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: LL.facade,
                  foregroundColor: LL.cream,
                  disabledBackgroundColor: LL.facade.withValues(alpha: 0.5),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        );
    return Container(
      height: 66,
      color: LL.deep,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          tool(
            icon: Icons.scale_rounded,
            label: 'Scale · ${c.profile.scales}',
            tooltip: 'Preview where the selected resident would put the needle',
            onTap: playing ? c.useScale : null,
          ),
          tool(icon: Icons.restart_alt_rounded, label: 'Restart', onTap: playing ? c.startLevel : null),
        ],
      ),
    );
  }
}
