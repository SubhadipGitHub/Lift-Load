import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/cast.dart';
import '../../game/debuts.dart';
import '../../game/formulas.dart';
import '../../game/scenario.dart';
import '../../game/venue.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../motion.dart';
import '../painters/sky_painter.dart';
import '../theme.dart';
import '../widgets/resident_figure.dart';
import '../widgets/result_sheets.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/tester_sheets.dart';
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
    final m = Metrics.of(context);
    final stats = Row(
      children: [
        _Stat(icon: Icons.favorite_rounded, color: LL.alarm, text: '${p.lives}'),
        SizedBox(width: 6 * m.scale),
        Expanded(
          child: Text(
            next == null ? '' : 'next in ${_countdown(next)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: m.font(12), color: LL.lilac, fontWeight: FontWeight.w700),
          ),
        ),
        _Stat(icon: Icons.monetization_on_rounded, color: LL.brass, text: '${p.coins}'),
        SizedBox(width: 6 * m.scale),
        _Stat(icon: Icons.scale_rounded, color: LL.brass, text: '${p.scales}'),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => showSettingsSheet(context, c),
          iconSize: 24 * m.textScale,
          icon: const Icon(Icons.settings_rounded, color: LL.lilac),
        ),
      ],
    );
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Lift '),
              TextSpan(text: 'Load', style: LL.display.copyWith(fontSize: m.font(58), color: LL.brass)),
            ]),
            style: LL.display.copyWith(fontSize: m.font(58), color: LL.cream),
          ),
        ),
        SizedBox(height: 4 * m.scale),
        Text(
          'Fill every lift. Never overload it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: m.font(15), fontWeight: FontWeight.w700, color: LL.lilac),
        ),
        if (c.testerLog case final log? when c.tester.enabled) ...[
          SizedBox(height: 8 * m.scale),
          TesterChip(log: log),
        ],
      ],
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.winStreak >= 2)
          Padding(
            padding: EdgeInsets.only(bottom: 10 * m.scale),
            child: Text(
              'Win streak ${p.winStreak}',
              style: TextStyle(fontSize: m.font(14), fontWeight: FontWeight.w800, color: LL.brass),
            ),
          ),
        if (c.testComplete)
          PrimaryButton(
            label: 'Test complete · Send results',
            height: 62 * m.scale,
            onPressed: () => showResultsSheet(context, c),
          )
        else
          _Pulse(
            active: hasLives,
            child: PrimaryButton(
              label: hasLives ? 'Play · Level ${p.level}' : 'Out of lives',
              height: 62 * m.scale,
              onPressed: hasLives ? _play : null,
            ),
          ),
        if (!hasLives && c.canAdForLife) ...[
          SizedBox(height: 10 * m.scale),
          RewardedButton(
            label: c.adInFlight ? 'Loading ad…' : 'Watch ad · +1 life',
            onPressed: c.adInFlight ? null : c.adForLife,
          ),
        ],
        SizedBox(height: 10 * m.scale),
        if (!c.testComplete)
          Text(
            _nextHint(p.level),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: m.font(12), color: LL.lilac, fontWeight: FontWeight.w700),
          ),
        if (c.tester.enabled && c.testerLog != null && !c.testComplete)
          TextButton(
            onPressed: () => showResultsSheet(context, c),
            child: Text('Send results so far',
                style: TextStyle(fontSize: m.font(13), color: LL.cream, fontWeight: FontWeight.w800)),
          ),
      ],
    );
    final map = _VenueMap(level: p.level);

    final Widget body;
    if (m.twoPane) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Metrics.twoPaneMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * m.scale, vertical: 12 * m.scale),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    stats,
                    const Spacer(),
                    title,
                    SizedBox(height: 24 * m.scale),
                    actions,
                    const Spacer(),
                  ],
                ),
              ),
              SizedBox(width: 24 * m.scale),
              Expanded(child: map),
            ],
          ),
        ),
      );
    } else {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: m.columnWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * m.scale),
          child: Column(
            children: [
              SizedBox(height: 12 * m.scale),
              stats,
              SizedBox(height: 18 * m.scale),
              title,
              Expanded(child: map),
              actions,
              SizedBox(height: 20 * m.scale),
            ],
          ),
        ),
      );
    }
    final sky = VenueStyle.of(Venue.of(p.level));
    return Scaffold(
      body: IdleClockScope(
        child: Builder(builder: (context) {
          final clock = IdleClock.of(context);
          final content = SafeArea(child: Center(child: body));
          if (clock == null) return CustomPaint(painter: SkyPainter(style: sky), child: content);
          // Clouds drift across in a minute; stars twinkle every few seconds.
          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<double>(
                    valueListenable: clock,
                    builder: (context, t, _) =>
                        CustomPaint(painter: SkyPainter(style: sky, drift: (t / 60) % 1, twinkle: (t / 4) % 1)),
                  ),
                ),
              ),
              content,
            ],
          );
        }),
      ),
    );
  }

  String _nextHint(int level) {
    final d = Formulas.difficulty(level);
    switch (Debut.at(level)) {
      case TypeDebut(:final type):
        return 'New resident today: ${type.displayName}';
      case CargoDebut(:final cargo):
        return 'New today: residents carrying a ${cargo.displayName}';
      case LiftDebut(:final kind):
        return 'New today: the ${kind.name} lift';
      case ScenarioDebut(:final scenario):
        return 'New today: ${_scenarioName(scenario)}';
      case UnknownDebut():
        return 'New today: mystery people in the queue';
      case LaneDebut():
        return 'New today: a different number of lanes';
      case PowerDebut(:final power):
        return GameController.powerTip(power);
      case null:
        break;
    }
    return switch (d) {
      Difficulty.hard => 'Hard level: one spare trip',
      Difficulty.superHard => 'Super Hard level: one spare trip, one extra floor',
      Difficulty.breather => 'Breather level: three spare trips',
      Difficulty.normal => 'Two spare trips',
    };
  }
}

String _scenarioName(Scenario s) => switch (s) {
      Scenario.maintenance => 'lane maintenance',
      Scenario.rushHour => 'rush hour',
    };

/// A slow breathing scale that invites a tap. Still under reduced motion.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.child, required this.active});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final clock = active ? IdleClock.of(context) : null;
    if (clock == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: clock,
      child: child,
      builder: (context, t, child) =>
          Transform.scale(scale: 1 + 0.025 * (0.5 + 0.5 * math.sin(t * 2 * math.pi / 1.8)), child: child),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(8 * m.scale, 5 * m.scale, 12 * m.scale, 5 * m.scale),
      decoration: BoxDecoration(color: LL.facade, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18 * m.textScale, color: color),
          SizedBox(width: 6 * m.scale),
          Text(text, style: TextStyle(fontSize: m.font(14), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Home map: the five buildings as a skyline. Each window is one level and
/// lights up once cleared; the current building is outlined, with a few of
/// its regulars waiting out front.
class _VenueMap extends StatelessWidget {
  const _VenueMap({required this.level});

  final int level;

  static const _heights = [0.62, 0.86, 0.74, 0.56, 1.0];
  static const _regulars = {
    Venue.society: [ResidentType.aunty, ResidentType.kid, ResidentType.officeM, ResidentType.uncle],
    Venue.office: [ResidentType.officeW, ResidentType.guard, ResidentType.officeM, ResidentType.student],
    Venue.hospital: [ResidentType.grandpa, ResidentType.wheelchair, ResidentType.puffer, ResidentType.rider],
    Venue.mall: [ResidentType.aunty, ResidentType.pram, ResidentType.kid, ResidentType.puffer],
    Venue.hotel: [ResidentType.bellhop, ResidentType.officeW, ResidentType.gym, ResidentType.officeM],
  };

  @override
  Widget build(BuildContext context) {
    final current = Venue.of(level);
    final inVenue = (level - current.firstLevel + 1).clamp(1, Venue.levelsPerVenue);
    final m = Metrics.of(context);
    return LayoutBuilder(builder: (context, outer) {
      // Short screens drop the regulars first, so the skyline keeps room.
      final showRegulars = outer.maxHeight >= 150 * m.scale + 110;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 14 * m.scale),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (i, v) in Venue.values.indexed) ...[
                      if (i > 0) SizedBox(width: 6 * m.scale),
                      Expanded(
                        child: _Building(
                          venue: v,
                          height: box.maxHeight * _heights[i],
                          cleared: (level - v.firstLevel).clamp(0, Venue.levelsPerVenue),
                          current: v == current,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(height: 6 * m.scale, color: LL.rule),
            SizedBox(height: 8 * m.scale),
            if (showRegulars)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in _regulars[current]!)
                    if (t.unlockLevel <= level) ResidentFigure(type: t, height: 58 * m.scale),
                ],
              ),
            SizedBox(height: 6 * m.scale),
            Text(
              current.displayName.toUpperCase(),
              style: LL.label.copyWith(fontSize: m.font(11), color: VenueStyle.of(current).accent),
            ),
            SizedBox(height: 2 * m.scale),
            Text(
              'Level $inVenue of ${Venue.levelsPerVenue} in this building',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: m.font(12), fontWeight: FontWeight.w700, color: LL.lilac),
            ),
          ],
        ),
      );
    });
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.venue, required this.height, required this.cleared, required this.current});

  final Venue venue;
  final double height;

  /// Levels of this venue already cleared (0–20).
  final int cleared;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final style = VenueStyle.of(venue);
    const rows = Venue.levelsPerVenue ~/ 2;
    return Semantics(
      label: '${venue.displayName}: $cleared of ${Venue.levelsPerVenue} levels cleared',
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.wallTop, style.wall, style.wallBottom],
          ),
          boxShadow: current ? [BoxShadow(color: style.accent.withValues(alpha: 0.35), blurRadius: 14)] : null,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(color: current ? style.accent : LL.rule, width: current ? 2.5 : 1),
        ),
        child: Column(
          verticalDirection: VerticalDirection.up,
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 2; c++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: r * 2 + c < cleared ? const Color(0xFFFFD98A) : LL.deep.withValues(alpha: 0.6),
                            boxShadow:
                                r * 2 + c < cleared ? const [BoxShadow(color: Color(0x66FFD98A), blurRadius: 3)] : null,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
