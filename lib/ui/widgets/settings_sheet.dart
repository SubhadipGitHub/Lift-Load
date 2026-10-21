import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../theme.dart';

/// Sound, music and vibration switches, saved in the profile.
Future<void> showSettingsSheet(BuildContext context, GameController c) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: LL.cream,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Settings',
                      textAlign: TextAlign.center, style: LL.display.copyWith(fontSize: 26, color: LL.ink)),
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon, color: LL.ink),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: LL.ink)),
        value: value,
        activeThumbColor: LL.mintDark,
        onChanged: onChanged,
      );
}
