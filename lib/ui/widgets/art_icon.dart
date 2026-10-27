import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/scenario.dart';
import '../art_assets.dart';
import '../theme.dart';
import 'resident_figure.dart';

/// An approved icon at [size], or its Material fallback when sprite art is
/// off (`Profile.useSpriteArt`), before the images load, or when this one
/// failed. Decorative: screen readers get the label of the control it sits
/// on. Every icon in the game that has art goes through here.
class ArtIcon extends StatelessWidget {
  /// One of the [GameIcon]s; [color] tints the fallback only.
  ArtIcon(GameIcon icon, {super.key, required this.size, Color? color})
      : path = ArtAssets.icon(icon),
        fallback = fallbackOf(icon),
        fallbackColor = color ?? fallbackColorOf(icon);

  /// A lift kind's badge (not the normal lift, which has none).
  ArtIcon.kind(LiftKind kind, {super.key, required this.size, Color? color})
      : assert(kind != LiftKind.normal),
        path = ArtAssets.kindIcon(kind)!,
        fallback = LiftKindStyle.of(kind).icon!,
        fallbackColor = color ?? LL.ink;

  /// A lobby scenario's icon.
  ArtIcon.scenario(Scenario scenario, {super.key, required this.size, Color? color})
      : path = ArtAssets.scenarioIcon(scenario),
        fallback = switch (scenario) {
          Scenario.maintenance => Icons.construction_rounded,
          Scenario.rushHour => Icons.groups_rounded,
        },
        fallbackColor = color ??
            switch (scenario) {
              Scenario.maintenance => LL.cone,
              Scenario.rushHour => LL.brass,
            };

  final String path;
  final double size;
  final IconData fallback;
  final Color fallbackColor;

  /// The Material icon each [GameIcon] replaced, kept as its fallback.
  static IconData fallbackOf(GameIcon icon) => switch (icon) {
        GameIcon.heart => Icons.favorite_rounded,
        GameIcon.coin => Icons.monetization_on_rounded,
        GameIcon.scale => Icons.scale_rounded,
        GameIcon.trip => Icons.elevator_rounded,
        GameIcon.seat => Icons.event_seat_rounded,
        GameIcon.restart => Icons.restart_alt_rounded,
        GameIcon.play => Icons.play_circle_fill_rounded,
        GameIcon.lock => Icons.lock_rounded,
        GameIcon.hourglass => Icons.hourglass_empty_rounded,
        GameIcon.star => Icons.star_rounded,
        GameIcon.trophy => Icons.emoji_events_rounded,
        GameIcon.cableSnap => Icons.link_off_rounded,
        GameIcon.swap => Icons.swap_horiz_rounded,
        GameIcon.express => Icons.bolt_rounded,
      };

  static Color fallbackColorOf(GameIcon icon) => switch (icon) {
        GameIcon.heart || GameIcon.cableSnap => LL.alarm,
        GameIcon.coin || GameIcon.star || GameIcon.trophy => LL.brass,
        GameIcon.hourglass => LL.brassDark,
        GameIcon.play => LL.mintInk,
        GameIcon.lock => LL.inkSoft,
        GameIcon.scale ||
        GameIcon.trip ||
        GameIcon.seat ||
        GameIcon.restart ||
        GameIcon.swap ||
        GameIcon.express =>
          LL.ink,
      };

  /// The fallback tint for [icon] on a dark surface: its own colour, or
  /// cream where that would be ink.
  static Color onDark(GameIcon icon) => fallbackColorOf(icon) == LL.ink ? LL.cream : fallbackColorOf(icon);

  Widget _fallback() => Icon(fallback, size: size, color: fallbackColor);

  Widget _image(ui.Image image) => RawImage(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: SpriteArtScope.of(context)
              ? ListenableBuilder(
                  listenable: SpriteCache.instance,
                  builder: (context, _) => switch (SpriteCache.instance.image(path)) {
                    final image? => _image(image),
                    null => _fallback(),
                  },
                )
              : _fallback(),
        ),
      );
}
