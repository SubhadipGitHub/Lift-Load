import 'package:flutter/material.dart';

import '../../game/engine.dart';
import '../art_assets.dart';
import '../game_controller.dart';
import '../layout.dart';
import '../theme.dart';
import 'art_icon.dart';
import 'glossy.dart';

/// Sound, music, vibration and left-handed switches, saved in the profile.
/// On the play screen ([inLevel]) it also holds Restart, which gives up the
/// attempt, so it is kept out of the thumb's way on the main screen.
Future<void> showSettingsSheet(BuildContext context, GameController c, {bool inLevel = false}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LL.cream,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Settings',
                      textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 26, color: LL.ink)),
                  const SizedBox(height: Metrics.sheetRowGap),
                  _Toggle(
                    icon: Icons.volume_up_rounded,
                    label: 'Sound effects',
                    value: c.profile.soundOn,
                    onChanged: c.setSound,
                  ),
                  _Toggle(
                    icon: Icons.music_note_rounded,
                    label: 'Music',
                    value: c.profile.musicOn,
                    onChanged: c.setMusic,
                  ),
                  _Toggle(
                    icon: Icons.vibration_rounded,
                    label: 'Vibration',
                    value: c.profile.hapticsOn,
                    onChanged: c.setHaptics,
                  ),
                  _Toggle(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Left-handed layout',
                    subtitle: 'Send on the left, powers on the right',
                    value: c.profile.leftHanded,
                    onChanged: c.setLeftHanded,
                  ),
                  if (inLevel && c.hasGame) _RestartRow(c: c),
                ],
              ),
            ),
          ),
        ),
      ),
    );

/// One settings row on a cream glossy tile.
class _Tile extends StatelessWidget {
  const _Tile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Metrics.sheetRowGap),
        child: Glossy(
          style: SurfaceStyle.cream,
          depth: SurfaceDepth.chip,
          inset: false,
          radius: Metrics.sheetButtonRadius,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.value, required this.onChanged, this.subtitle});

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Tile(
        child: SwitchListTile(
          secondary: Icon(icon, color: LL.ink, size: Metrics.settingsIcon),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: LL.ink)),
          subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: LL.inkSoft)),
          value: value,
          activeThumbColor: LL.mintDark,
          onChanged: onChanged,
        ),
      );
}

/// Restart the level. Free before the first move; after it, it costs a life,
/// so it asks first.
class _RestartRow extends StatelessWidget {
  const _RestartRow({required this.c});

  final GameController c;

  Future<void> _restart(BuildContext context) async {
    if (c.levelInProgress) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restart this level?'),
          content: const Text('You have started it, so restarting costs 1 life.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep playing')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restart · 1 life')),
          ],
        ),
      );
      if (go != true || !context.mounted) return;
    }
    Navigator.of(context).pop();
    c.restart();
  }

  @override
  Widget build(BuildContext context) {
    final can = c.game.phase == Phase.playing && c.canRestart;
    final subtitle = !c.levelInProgress
        ? 'Free until your first move'
        : can
            ? 'Costs 1 life, because you have made moves'
            : 'Needs a spare life';
    return Opacity(
      opacity: can ? 1 : Metrics.disabledRow,
      child: _Tile(
        child: ListTile(
          leading: ArtIcon(GameIcon.restart, size: Metrics.settingsIcon),
          title: const Text('Restart level', style: TextStyle(fontWeight: FontWeight.w800, color: LL.ink)),
          subtitle: Text(subtitle, style: const TextStyle(color: LL.inkSoft)),
          enabled: can,
          onTap: can ? () => _restart(context) : null,
        ),
      ),
    );
  }
}
