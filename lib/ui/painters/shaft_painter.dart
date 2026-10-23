/// The shaft panel's back wall and the guide rails either side of the
/// cabin's column. The wall is the venue's painted backdrop for its storey
/// band when there is one (Sunrise Towers), with the cabin standing in the
/// backdrop's doorway; otherwise a venue-tinted gradient with a faint motif.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art_assets.dart';
import '../motion.dart';
import '../theme.dart';

class ShaftPainter extends CustomPainter {
  const ShaftPainter({
    required this.style,
    required this.railLeft,
    required this.railRight,
    this.art,
    this.floorY = 0,
    this.channel = 6,
    this.rideDy = 0,
    this.rideTravel = 1,
    this.scale = 1,
  });

  final VenueStyle style;

  /// X positions of the cabin column's edges, where the rails run.
  final double railLeft;
  final double railRight;

  /// The painted backdrop, or null for the painted wall.
  final ui.Image? art;

  /// Where the cabin's bottom sits: the backdrop's doorway meets the floor here.
  final double floorY;

  /// The channel either side of the cabin, where the rails run.
  final double channel;

  /// The cabin's offset from its stop while it rides (negative is up), the
  /// distance of a full ride, and the screen's design scale, all in logical
  /// pixels. At 0 the shaft is still; otherwise the backdrop slides against the
  /// ride ([RideMotion.parallax]), the rail brackets run past and faint
  /// streaks fall beside the cabin. Only the cabin's own offset drives it.
  final double rideDy, rideTravel, scale;

  /// How much wider than the cabin column (plus its channels) the doorway may
  /// grow, so the cabin can stand in the middle of it when the column sits
  /// off the panel's centre.
  static const double doorLoose = 1.15;

  /// Where [image] is drawn on a panel of [size]: scaled so its doorway
  /// ([ArtAssets.shaftDoorway]) spans the cabin column and its channels and
  /// stands on [floorY], centred on the column (the doorway grows by up to
  /// [doorLoose] to make that possible), then slid as little as needed to
  /// cover the panel's top and sides. Below [floorY] the image has only a
  /// strip of floor, so a panel taller than that is filled by
  /// [paint] repeating the image's bottom edge.
  static Rect placement(Size image, Size size,
      {required double railLeft, required double railRight, required double floorY, required double channel}) {
    const door = ArtAssets.shaftDoorway;
    final fitDoor = (railRight - railLeft + 2 * channel) / (door.width * image.width);
    final cover = math.max(size.width / image.width, size.height / image.height);
    // The widest the image must be to centre the doorway on the column.
    final mid = (railLeft + railRight) / 2;
    final centred = 2 * math.max(mid, size.width - mid) / image.width;
    final k = math.max(math.max(fitDoor, cover), math.min(centred, fitDoor * doorLoose));
    final w = image.width * k, h = image.height * k;
    final left = (mid - door.center.dx * w).clamp(size.width - w, 0.0).toDouble();
    final top = math.min(floorY - door.bottom * h, 0.0);
    return Rect.fromLTWH(left, top, w, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final image = art;
    if (image != null) {
      final src = Size(image.width.toDouble(), image.height.toDouble());
      final home = placement(src, size, railLeft: railLeft, railRight: railRight, floorY: floorY, channel: channel);
      // The backdrop slides down as the cabin rises, only as far as the image
      // reaches above the panel.
      final at = home.shift(Offset(0, _slide(spare: -home.top)));
      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(image, Offset.zero & src, at, paint);
      // The floor runs on under the cabin: the image's last row, repeated.
      if (at.bottom < h) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, src.height - 1, src.width, 1),
          Rect.fromLTRB(at.left, at.bottom - 1, at.right, h),
          paint,
        );
      }
      // The walls either side of the doorway sit a little in shadow, so the
      // NEXT chips (the later ones faded) and the Scale button read over
      // lamps and city lights.
      final scrim = Paint()..color = LL.shaftScrim;
      canvas
        ..drawRect(Rect.fromLTRB(0, 0, railLeft - channel, h), scrim)
        ..drawRect(Rect.fromLTRB(railRight + channel, 0, w, h), scrim);
    } else {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [style.wallTop, style.wall, style.wallBottom],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      );
      canvas
        ..save()
        ..translate(0, _slide(spare: motifSlack * scale));
      _motif(canvas, size);
      canvas.restore();

      // The shaft itself: a darker channel behind the cabin (the backdrop
      // has its own doorway).
      final shaft = Rect.fromLTRB(railLeft - channel, 0, railRight + channel, h);
      canvas.drawRect(shaft, Paint()..color = const Color(0x33000000));
    }
    final rail = Paint()
      ..color = const Color(0xFF8F8AC4).withValues(alpha: 0.55)
      ..strokeWidth = 3;
    final shine = Paint()
      ..color = const Color(0x40FFFFFF)
      ..strokeWidth = 1;
    for (final x in [railLeft - 3, railRight + 3]) {
      canvas
        ..drawLine(Offset(x, 0), Offset(x, h), rail)
        ..drawLine(Offset(x - 1, 0), Offset(x - 1, h), shine);
      // Rail brackets: they run past as the cabin rides (the whole travel,
      // the nearest layer).
      final run = -rideDy % bracketGap;
      for (var y = 18.0 + run - bracketGap; y < h; y += bracketGap) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 9, height: 3), rail);
      }
    }
    _streaks(canvas, size);
    // Soft vignette at the bottom so the panel sits on the lobby.
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x33000000)],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );
  }

  /// Spacing of the rail brackets, and the room a painted wall's motif may
  /// slide into (design units).
  static const double bracketGap = 46;
  static const double motifSlack = 14;

  /// How far the backdrop has slid for this ride (0 at rest), no further
  /// than [spare] where the image or motif has room.
  double _slide({required double spare}) => (-rideDy * RideMotion.parallax).clamp(0, math.max(0, spare)).toDouble();

  /// Faint streaks falling down the doorway as the cabin rises: positions are
  /// fixed, they move with the cabin's offset and fade with how far it is
  /// from its stop, so they stop when it does.
  void _streaks(Canvas canvas, Size size) {
    if (rideDy == 0 || rideTravel <= 0) return;
    final alpha = RideMotion.streakAlpha *
        Curves.easeOut.transform((rideDy.abs() / (rideTravel * RideMotion.streakFull)).clamp(0, 1).toDouble());
    if (alpha <= 0) return;
    final left = railLeft - channel, width = railRight + channel - left;
    for (var i = 0; i < RideMotion.streaks; i++) {
      final x = left + width * ((i * 0.618034) % 1);
      final length = RideMotion.streakLength * scale * (0.55 + 0.9 * ((i * 0.381966) % 1));
      final pace = 1 + 1.3 * ((i * 0.7548776) % 1);
      final cycle = size.height + length;
      final y = (((i * 0.37) % 1) * cycle - rideDy * pace) % cycle - length;
      final box = Rect.fromLTWH(x, y, 0, length);
      canvas.drawLine(
        box.topCenter,
        box.bottomCenter,
        Paint()
          ..strokeWidth = RideMotion.streakWidth * scale
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LL.streak.withValues(alpha: 0), LL.streak.withValues(alpha: alpha)],
          ).createShader(Rect.fromLTWH(x - 1, y, 2, length)),
      );
    }
  }

  void _motif(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final faint = Paint()..color = style.accent.withValues(alpha: 0.10);
    final line = Paint()
      ..color = style.accent.withValues(alpha: 0.10)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    switch (style.motif) {
      case WallMotif.windows:
        // A grid of lit and unlit flat windows.
        for (var y = 14.0; y < h - 20; y += 34) {
          for (var x = 10.0; x < w - 10; x += 30) {
            final lit = ((x * 7 + y * 3) ~/ 10).isEven;
            canvas.drawRRect(
              RRect.fromLTRBR(x, y, x + 16, y + 20, const Radius.circular(2)),
              Paint()..color = (lit ? const Color(0xFFFFD98A) : style.accent).withValues(alpha: lit ? 0.13 : 0.05),
            );
          }
        }
      case WallMotif.mullions:
        for (var x = 0.0; x < w; x += 26) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), line);
        }
        canvas.drawLine(Offset(0, h * 0.35), Offset(w, h * 0.35), line);
      case WallMotif.signStripe:
        canvas.drawRect(Rect.fromLTWH(0, h * 0.18, w, h * 0.05), faint);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.26, w, h * 0.012), faint);
        for (var x = 16.0; x < w; x += 64) {
          canvas.drawPath(
            Path()
              ..moveTo(x, h * 0.205)
              ..lineTo(x + 10, h * 0.205)
              ..lineTo(x + 10, h * 0.19)
              ..lineTo(x + 18, h * 0.205)
              ..lineTo(x + 10, h * 0.22)
              ..lineTo(x + 10, h * 0.205),
            Paint()..color = style.accent.withValues(alpha: 0.22),
          );
        }
      case WallMotif.awnings:
        for (var x = 0.0; x < w; x += 40) {
          final awning = Path()
            ..moveTo(x, h * 0.1)
            ..lineTo(x + 36, h * 0.1)
            ..lineTo(x + 32, h * 0.17)
            ..quadraticBezierTo(x + 18, h * 0.21, x + 4, h * 0.17)
            ..close();
          canvas.drawPath(awning, Paint()..color = style.accent.withValues(alpha: ((x ~/ 40).isEven) ? 0.14 : 0.07));
        }
      case WallMotif.wallpaper:
        var row = 0;
        for (var y = 10.0; y < h; y += 22, row++) {
          for (var x = row.isEven ? 8.0 : 19.0; x < w; x += 22) {
            canvas.drawCircle(Offset(x, y), 2.2, faint);
          }
        }
        // Wall sconces.
        for (final x in [w * 0.12, w * 0.88]) {
          canvas.drawCircle(
            Offset(x, h * 0.22),
            14,
            Paint()
              ..color = const Color(0x33FFD98A)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }
    }
  }

  @override
  bool shouldRepaint(ShaftPainter old) =>
      old.style != style ||
      old.railLeft != railLeft ||
      old.railRight != railRight ||
      old.art != art ||
      old.floorY != floorY ||
      old.channel != channel ||
      old.rideDy != rideDy ||
      old.rideTravel != rideTravel ||
      old.scale != scale;
}
