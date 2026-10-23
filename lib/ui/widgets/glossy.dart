/// The 3D surface from the style frame (`docs/art/style-frame`, `.g3d`): a
/// dark outline, a lit vertical gradient, a thick darker bottom edge with a
/// drop under it, a white line inside the top, a gloss band, and a shade
/// inside the bottom. Pressed, the face sinks onto its edge.
///
/// Two ways to sit in a layout:
/// - inset (buttons): the outline and the edge are inside the box, so the
///   whole box stays the touch target and nothing paints outside it;
/// - outset (tags, chips, seats): the box is the face, as in the frame, and
///   the outline and edge paint around it without changing the layout.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../motion.dart';
import '../theme.dart';
import 'pressable.dart';

/// One surface. Colours come from a [SurfaceStyle], sizes from
/// [Metrics.surface] for its [depth].
class Glossy extends StatelessWidget {
  const Glossy({
    super.key,
    required this.style,
    this.depth = SurfaceDepth.button,
    this.radius,
    this.inset = true,
    this.pressed = false,
    this.faceGradient,
    this.glow,
    this.sweep,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.child,
  });

  final SurfaceStyle style;
  final SurfaceDepth depth;

  /// Corner radius of the face; null makes a pill (a circle when square).
  final double? radius;

  /// Inset keeps the outline and edge inside the box (buttons); outset paints
  /// them around it (tags, chips, seats).
  final bool inset;

  /// The face is down on its edge (a finger on a button).
  final bool pressed;

  /// Replaces the lit gradient (an express NEXT chip is split in two floors).
  final Gradient? faceGradient;

  /// A soft glow around the outline (a picked seat).
  final Color? glow;

  /// A band of light crossing the face, 0 (not yet in) to 1 (gone): the
  /// gloss sweep when a button is let go. Null draws none.
  final double? sweep;

  final double? width, height;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    final size = m.surface(depth);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: pressed ? 1 : 0),
      duration: PressScale.pressDuration,
      curve: Curves.easeOut,
      child: child == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(color: style.ink),
              child: IconTheme.merge(data: IconThemeData(color: style.ink), child: child!),
            ),
      builder: (context, t, child) => CustomPaint(
        painter: GlossyPainter(
          style: style,
          size: size,
          press: t,
          radius: radius,
          inset: inset,
          faceGradient: faceGradient,
          glow: glow,
          glowBlur: m.seatGlow,
          sweep: sweep,
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: GlossyPainter.faceInsets(size, inset: inset).add(padding),
            child:
                t == 0 || child == null ? child : Transform.translate(offset: Offset(0, size.press * t), child: child),
          ),
        ),
      ),
    );
  }
}

/// Paints a [Glossy]. Everything is drawn from the face's rounded rectangle.
class GlossyPainter extends CustomPainter {
  const GlossyPainter({
    required this.style,
    required this.size,
    this.press = 0,
    this.radius,
    this.inset = true,
    this.faceGradient,
    this.glow,
    this.glowBlur = 0,
    this.sweep,
  });

  final SurfaceStyle style;
  final SurfaceSize size;

  /// 0 up, 1 fully pressed.
  final double press;
  final double? radius;
  final bool inset;
  final Gradient? faceGradient;
  final Color? glow;
  final double glowBlur;

  /// See [Glossy.sweep].
  final double? sweep;

  /// Where the face sits inside the box at rest: inset by the outline and,
  /// below, the edge and drop; outset, the box is the face.
  static EdgeInsets faceInsets(SurfaceSize s, {required bool inset}) =>
      inset ? EdgeInsets.fromLTRB(s.outline, s.outline, s.outline, s.outline + s.edge + s.drop) : EdgeInsets.zero;

  /// The face's rectangle in a box of [box]; pressing moves it down onto its
  /// edge, which shrinks by as much, so nothing grows past the bottom.
  static Rect faceRect(Size box, SurfaceSize s, double press, {required bool inset}) =>
      faceInsets(s, inset: inset).deflateRect(Offset.zero & box).shift(Offset(0, s.press * press));

  @override
  void paint(Canvas canvas, Size box) {
    final face = faceRect(box, size, press, inset: inset);
    if (face.isEmpty) return;
    final r = math.min(radius ?? double.infinity, face.shortestSide / 2);
    final faceR = RRect.fromRectAndRadius(face, Radius.circular(r));
    final outline = faceR.inflate(size.outline);
    final edge = math.max(0.0, size.edge - size.press * press);
    final drop = size.drop * (1 - press / 2);
    if (glow case final g?) {
      canvas.drawRRect(
        outline.shift(Offset(0, edge / 2)),
        Paint()
          ..color = g
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur),
      );
    }
    if (drop > 0) canvas.drawRRect(outline.shift(Offset(0, edge + drop)), Paint()..color = style.drop);
    if (edge > 0) canvas.drawRRect(outline.shift(Offset(0, edge)), Paint()..color = style.edge);
    if (size.outline > 0) canvas.drawRRect(outline, Paint()..color = style.edge);
    final gradient = faceGradient ??
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.hi, style.mid, style.lo],
          stops: const [0, 0.48, 1],
        );
    canvas.drawRRect(faceR, Paint()..shader = gradient.createShader(face));
    final facePath = Path()..addRRect(faceR);
    if (size.shade > 0) {
      canvas.drawPath(
        Path.combine(PathOperation.difference, facePath, Path()..addRRect(faceR.shift(Offset(0, -size.shade)))),
        Paint()..color = LL.surfaceShade,
      );
    }
    if (style.gloss <= 0) return;
    Color fade(Color c) => c.withValues(alpha: c.a * style.gloss);
    canvas.drawPath(
      Path.combine(PathOperation.difference, facePath, Path()..addRRect(faceR.shift(Offset(0, size.highlight)))),
      Paint()..color = fade(LL.surfaceHighlight),
    );
    final band = Rect.fromLTWH(
      face.left + face.width * Metrics.glossInset,
      face.top + face.height * Metrics.glossTop,
      face.width * (1 - 2 * Metrics.glossInset),
      face.height * Metrics.glossHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(math.min(r, band.shortestSide / 2))),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fade(LL.surfaceGlossTop), fade(LL.surfaceGlossBottom)],
        ).createShader(band),
    );
    _sweep(canvas, face, faceR);
  }

  /// The gloss sweep: a slanted band of light, soft at both sides, crossing
  /// the face from left to right, clipped to it.
  void _sweep(Canvas canvas, Rect face, RRect faceR) {
    final t = sweep;
    if (t == null || t <= 0 || t >= 1) return;
    final band = face.width * ButtonMotion.sweepWidth;
    final slant = face.height * ButtonMotion.sweepSlant;
    final x = face.left - band - slant + (face.width + 2 * band + slant) * Curves.easeInOut.transform(t);
    final box = Rect.fromLTRB(x, face.top, x + band + slant, face.bottom);
    canvas
      ..save()
      ..clipRRect(faceR)
      ..drawPath(
        Path()
          ..moveTo(box.left + slant, box.top)
          ..lineTo(box.right, box.top)
          ..lineTo(box.right - slant, box.bottom)
          ..lineTo(box.left, box.bottom)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            colors: [LL.sweepLight.withValues(alpha: 0), LL.sweepLight, LL.sweepLight.withValues(alpha: 0)],
          ).createShader(box),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlossyPainter old) =>
      old.style != style ||
      old.size != size ||
      old.press != press ||
      old.radius != radius ||
      old.inset != inset ||
      old.faceGradient != faceGradient ||
      old.glow != glow ||
      old.glowBlur != glowBlur ||
      old.sweep != sweep;
}

/// A tappable [Glossy]: it sinks while pressed, and with no [onPressed] it
/// turns to the flat slate [SurfaceStyle.off] so it never reads as live.
/// The whole box is the touch target, at least [Metrics.minTouch] square
/// when [touch] is set (a small round HUD button inside a full target).
class GlossyButton extends StatefulWidget {
  const GlossyButton({
    super.key,
    required this.style,
    required this.onPressed,
    required this.child,
    this.width,
    this.height,
    this.radius,
    this.depth = SurfaceDepth.button,
    this.padding = EdgeInsets.zero,
    this.semanticsLabel,
    this.tooltip,
    this.touch = false,
    this.inset = true,
    this.selected,
    this.disabledStyle = SurfaceStyle.off,
  });

  final SurfaceStyle style;

  /// Drawn while [onPressed] is null: slate unless the button dims itself.
  final SurfaceStyle disabledStyle;
  final VoidCallback? onPressed;
  final Widget child;
  final double? width, height;
  final double? radius;
  final SurfaceDepth depth;
  final EdgeInsetsGeometry padding;

  /// Read by screen readers instead of the text inside.
  final String? semanticsLabel;
  final String? tooltip;

  /// Grow the touch target to [Metrics.minTouch] around a smaller face.
  final bool touch;

  /// See [Glossy.inset]; a round button is outset so its face stays round.
  final bool inset;
  final bool? selected;

  bool get enabled => onPressed != null;

  /// The surface drawn now: [style], or [disabledStyle] while disabled.
  SurfaceStyle get surface => enabled ? style : disabledStyle;

  @override
  State<GlossyButton> createState() => _GlossyButtonState();
}

class _GlossyButtonState extends State<GlossyButton> with SingleTickerProviderStateMixin {
  /// The gloss sweep, once each time a finger is lifted off the button.
  late final AnimationController _sweep = AnimationController(vsync: this, duration: ButtonMotion.sweep);

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _released() {
    if (!reduceMotion(context) && mounted) _sweep.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    Widget face(bool down) => AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) => Glossy(
            style: w.surface,
            depth: w.depth,
            radius: w.radius,
            inset: w.inset,
            pressed: down,
            sweep: _sweep.isAnimating ? _sweep.value : null,
            width: w.width,
            height: w.height,
            padding: w.padding,
            child: Center(child: w.child),
          ),
        );
    Widget body = Pressable(
      enabled: w.enabled,
      onRelease: _released,
      builder: (context, down) => PressSpring(
        down: down,
        child: w.touch
            ? SizedBox(
                width: math.max(w.width ?? 0, Metrics.minTouch),
                height: math.max(w.height ?? 0, Metrics.minTouch),
                child: Center(child: face(down)),
              )
            : face(down),
      ),
    );
    body = GestureDetector(behavior: HitTestBehavior.opaque, onTap: w.onPressed, child: body);
    if (w.semanticsLabel != null) body = ExcludeSemantics(child: body);
    body = Semantics(
      container: true,
      button: true,
      enabled: w.enabled,
      selected: w.selected,
      label: w.semanticsLabel,
      onTap: w.semanticsLabel != null ? w.onPressed : null,
      child: body,
    );
    return w.tooltip == null ? body : Tooltip(message: w.tooltip, child: body);
  }
}

/// The up arrow on Send (style frame, `#i-up`): a white chevron with a dark
/// outline, in a 32 x 24 design box.
class SendGlyphPainter extends CustomPainter {
  const SendGlyphPainter({required this.outline, required this.fill});

  final Color outline, fill;

  static const Size design = Size(32, 24);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / design.width, size.height / design.height);
    canvas
      ..save()
      ..translate((size.width - design.width * s) / 2, (size.height - design.height * s) / 2)
      ..scale(s);
    final path = Path()
      ..moveTo(3, 19)
      ..lineTo(16, 6)
      ..lineTo(29, 19);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas
      ..drawPath(path, stroke(outline, 8))
      ..drawPath(path, stroke(fill, 4.6))
      ..restore();
  }

  @override
  bool shouldRepaint(SendGlyphPainter old) => old.outline != outline || old.fill != fill;
}
