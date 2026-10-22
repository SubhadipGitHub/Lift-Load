import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../layout.dart';
import '../theme.dart';
import 'power_dock.dart';
import 'glossy.dart';

/// The bottom bar of the play screen: the power dock and Send. Right-handed
/// play puts the dock on the left and Send at the right edge, where the thumb
/// rests; [Profile.leftHanded] mirrors both. Nothing else on the screen moves.
class PlayBottomBar extends StatelessWidget {
  const PlayBottomBar({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final left = c.profile.leftHanded;
    final powers = PowerDock.unlocked(c).length;
    final dock = powers == 0 ? null : PowerDock(c: c);
    final dockWidth = powers == 0 ? 0.0 : powers * m.dockButton + (powers - 1) * m.dockGap;
    return Container(
      height: m.bottomBarHeight,
      padding: EdgeInsets.fromLTRB(m.barPadding, 6 * m.scale, m.barPadding, 0),
      decoration: BoxDecoration(
        color: LL.deep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(m.radius)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth - (dock == null ? 0 : dockWidth + m.gap);
          final sendWidth = math.max(
            math.min(dock == null ? m.sendWidthSolo : m.sendWidth, room),
            Metrics.minTouch,
          );
          final send = SendButton(enabled: c.game.canSend, onPressed: c.send, width: sendWidth);
          // Right-handed: dock, then Send. Left-handed: the mirror image.
          final children = <Widget>[
            if (dock != null) dock,
            const Spacer(),
            send,
          ];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: left ? children.reversed.toList() : children,
          );
        },
      ),
    );
  }
}

/// The mint glossy key that sends the lift (style frame): an up arrow and
/// the word. With nobody aboard it turns to flat slate, so it never reads as
/// live.
class SendButton extends StatelessWidget {
  const SendButton({super.key, required this.enabled, required this.onPressed, required this.width});

  final bool enabled;
  final VoidCallback onPressed;
  final double width;

  /// Finds the button in tests.
  static const Key buttonKey = ValueKey('send');

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final surface = enabled ? SurfaceStyle.mint : SurfaceStyle.off;
    return GlossyButton(
      key: buttonKey,
      style: SurfaceStyle.mint,
      onPressed: enabled ? onPressed : null,
      width: width,
      height: m.sendHeight,
      radius: m.buttonRadius,
      semanticsLabel: 'Send',
      padding: EdgeInsets.symmetric(horizontal: m.gap / 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: m.sendGlyph,
              painter: SendGlyphPainter(outline: surface.edge, fill: enabled ? LL.creamHi : LL.lilac),
            ),
            SizedBox(width: m.gap / 2),
            Text(
              'Send',
              style: TextStyle(
                fontFamily: LL.displayFont,
                fontSize: m.font(22),
                fontWeight: FontWeight.w800,
                height: 1,
                color: surface.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
