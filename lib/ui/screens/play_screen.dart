import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../game_controller.dart';
import '../layout.dart';
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
  void didUpdateWidget(PlayScreen old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
      _lastPhase = c.game.phase;
      _snapHome();
      c.addListener(_onChange);
    }
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

  Future<void> _run(
      {required double from, required double to, double tiltTo = 0, required int ms, required Curve curve}) {
    final curved = CurvedAnimation(parent: _anim, curve: curve);
    _dy = Tween(begin: from, end: to).animate(curved);
    _tilt = Tween(begin: 0.0, end: tiltTo).animate(curved);
    _anim
      ..duration = Duration(milliseconds: ms)
      ..reset();
    return _anim.forward().orCancel.catchError((Object _) {});
  }

  /// Back from the HUD or the system: confirm first when it costs a life.
  Future<void> _leave() async {
    if (c.levelInProgress) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave this level?'),
          content: const Text('You have started it, so leaving costs 1 life.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave · 1 life')),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    c.quitToHome();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final g = c.game;
    final m = Metrics.of(context);
    final shaft = AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => LiftShaft(
        game: g,
        cabinDy: _dy.value * m.scale,
        cabinTilt: _tilt.value,
        onTapLift: c.tapLift,
        onSend: c.send,
      ),
    );
    final message = SizedBox(
      height: m.messageHeight,
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: m.gap),
            child: Text(
              c.message,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: m.font(13), fontWeight: FontWeight.w800, color: LL.brass),
            ),
          ),
        ),
      ),
    );
    final hud = _Hud(c: c, onBack: _leave);
    final bench = BenchRow(game: g, onTapSeat: c.tapBench);
    final lanes = QueueLanes(game: g, onTapLane: c.tapQueue);
    final toolbar = _Toolbar(c: c);

    final Widget body;
    if (m.twoPane) {
      // Landscape tablets and wide windows: lift, gauge and bench on the left,
      // the lobby lanes filling the right.
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Metrics.twoPaneMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: m.columnWidth,
                child: Column(
                  children: [
                    hud,
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(children: [shaft, message, bench]),
                      ),
                    ),
                    toolbar,
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: m.gap, bottom: m.gap),
                  child: SingleChildScrollView(child: lanes),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: m.columnWidth),
          child: Column(
            children: [
              hud,
              shaft,
              message,
              bench,
              Expanded(child: SingleChildScrollView(child: lanes)),
              toolbar,
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: body),
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
    final m = Metrics.of(context);
    return SizedBox(
      height: m.hudHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8 * m.scale),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to the tower',
              onPressed: onBack,
              iconSize: 24 * m.textScale,
              visualDensity: m.form == FormFactor.compactPhone ? VisualDensity.compact : null,
              icon: const Icon(Icons.arrow_back_rounded, color: LL.cream),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12 * m.scale, vertical: 1),
                  decoration: BoxDecoration(color: LL.brass, borderRadius: BorderRadius.circular(999)),
                  child: Text('Lv ${g.level.number}', style: LL.display.copyWith(fontSize: m.font(19), color: LL.ink)),
                ),
              ),
            ),
            SizedBox(width: 8 * m.scale),
            Expanded(
              child: Text(
                'Trips left ${g.tripsLeft}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w800, color: LL.lilac),
              ),
            ),
            SizedBox(width: 6 * m.scale),
            // Lives and coins shrink before they overflow on the narrowest phones.
            Flexible(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Chip(icon: Icons.favorite_rounded, color: LL.alarm, text: '${c.profile.lives}'),
                    SizedBox(width: 6 * m.scale),
                    _Chip(icon: Icons.monetization_on_rounded, color: LL.brass, text: '${c.profile.coins}'),
                  ],
                ),
              ),
            ),
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
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(7 * m.scale, 4 * m.scale, 10 * m.scale, 4 * m.scale),
      decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16 * m.textScale, color: color),
          SizedBox(width: 5 * m.scale),
          Text(text, style: TextStyle(fontSize: m.font(13), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final playing = c.game.phase == Phase.playing;
    final m = Metrics.of(context);
    Widget tool({required IconData icon, required String label, required VoidCallback? onTap, String? tooltip}) =>
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5 * m.scale),
            child: Tooltip(
              message: tooltip ?? label,
              child: FilledButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 20 * m.textScale),
                label: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: m.font(13))),
                style: FilledButton.styleFrom(
                  backgroundColor: LL.facade,
                  foregroundColor: LL.cream,
                  disabledBackgroundColor: LL.facade.withValues(alpha: 0.5),
                  minimumSize: Size.fromHeight(m.toolbarHeight - 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * m.scale)),
                ),
              ),
            ),
          ),
        );
    return Container(
      height: m.toolbarHeight,
      color: LL.deep,
      padding: EdgeInsets.symmetric(horizontal: 8 * m.scale),
      child: Row(
        children: [
          tool(
            icon: Icons.scale_rounded,
            label: 'Scale · ${c.profile.scales}',
            tooltip: 'Preview where the selected resident would put the needle',
            onTap: playing ? c.useScale : null,
          ),
          tool(
            icon: Icons.restart_alt_rounded,
            label: c.levelInProgress ? 'Restart · 1 life' : 'Restart',
            tooltip: c.levelInProgress ? 'Start over. You have made moves, so this costs 1 life' : 'Start over',
            onTap: playing && c.canRestart ? c.restart : null,
          ),
        ],
      ),
    );
  }
}
