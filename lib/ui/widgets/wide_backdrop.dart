import 'package:flutter/material.dart';

import '../art_assets.dart';
import '../layout.dart';
import '../theme.dart';
import 'resident_figure.dart';

/// The cover art behind a wide screen. A tablet or a wide window leaves margins and gaps around the play column;
/// there the night skyline shows through a navy scrim (so every label keeps its contrast) instead of flat navy.
///
/// Only on a wide form ([Metrics.twoPane] or a tablet standing up) and with sprite art on. A phone gets [child] as it
/// is, and the image is not even asked for. The picture is the same whatever is in the lift: it shows nothing of the
/// game. If the image fails to load, the flat page shows, as before.
class WideBackdrop extends StatelessWidget {
  const WideBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    if (!(m.twoPane || m.form == FormFactor.tabletPortrait) || !SpriteArtScope.of(context)) return child;
    final landscape = m.size.width > m.size.height;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: Image.asset(
              ArtAssets.coverArt(landscape: landscape),
              key: Key(landscape ? 'wideBackdropLandscape' : 'wideBackdropPortrait'),
              fit: BoxFit.cover,
              // Standing up, the sky stays behind the HUD and the shaft and the skyline lands around the bench and
              // behind the lanes.
              alignment: landscape ? Alignment.center : Alignment.topCenter,
              // Decoded at the screen's own size, not the file's.
              cacheWidth: landscape ? WideBackdropStyle.landscapeDecodeWidth : WideBackdropStyle.portraitDecodeWidth,
              frameBuilder: (context, image, frame, sync) {
                if (sync || MediaQuery.disableAnimationsOf(context)) return image;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: WideBackdropStyle.fadeIn,
                  curve: Curves.easeOut,
                  child: image,
                );
              },
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(decoration: BoxDecoration(color: WideBackdropStyle.scrim)),
          ),
        ),
        child,
      ],
    );
  }
}

/// How the backdrop is drawn: the scrim over the art and the decode widths.
abstract final class WideBackdropStyle {
  /// Navy over the art: enough that the cream and brass labels on the page keep their contrast, little enough that
  /// the skyline reads.
  static final Color scrim = LL.night.withValues(alpha: 0.4);

  /// The image fades in when it is not ready on the first frame (not under reduce-motion).
  static const Duration fadeIn = Duration(milliseconds: 350);

  static const int landscapeDecodeWidth = 1280;
  static const int portraitDecodeWidth = 720;
}
