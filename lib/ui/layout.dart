/// Responsive sizing. Every screen reads its dimensions from [Metrics] instead
/// of hard-coded pixels, so the same widgets fit a 320 × 568 phone and a
/// 1366 × 1024 tablet.
///
/// The design was drawn at 390 × 844 (scale 1). Phones scale with the
/// screen; tablets in portrait get one wider column; landscape tablets and
/// wide windows get two panes (lift and bench left, lanes right).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum FormFactor { compactPhone, phone, tabletPortrait, twoPane }

class Metrics {
  const Metrics._(this.size, this.form, this.scale);

  factory Metrics.from(Size size) {
    final w = size.width, h = size.height;
    final shortest = math.min(w, h);
    final landscape = w > h * 1.15 && w >= 700;
    final FormFactor form;
    if (landscape) {
      form = FormFactor.twoPane;
    } else if (shortest >= tabletShortestSide) {
      form = FormFactor.tabletPortrait;
    } else if (w < 360 || h < 680) {
      form = FormFactor.compactPhone;
    } else {
      form = FormFactor.phone;
    }
    final double scale = switch (form) {
      // The left pane carries the fixed-height stack (HUD to toolbar), about
      // 600 design units tall; the lanes take the full height on the right.
      FormFactor.twoPane => (math.min(_paneWidth(w) / _designWidth, h / 600)).clamp(0.6, 1.5).toDouble(),
      FormFactor.tabletPortrait => (math.min(math.min(w, tabletColumn) / _designWidth, h / _designHeight) * 1.05)
          .clamp(1.0, 1.5)
          .toDouble(),
      FormFactor.compactPhone || FormFactor.phone =>
        (math.min(w / _designWidth, h / _designHeight)).clamp(0.78, 1.15).toDouble(),
    };
    return Metrics._(size, form, scale);
  }

  /// Metrics for the screen this widget is on.
  static Metrics of(BuildContext context) => Metrics.from(MediaQuery.sizeOf(context));

  static const double _designWidth = 390;
  static const double _designHeight = 844;

  /// Tablets: the shortest side, in logical pixels, from which a device may
  /// rotate and gets tablet layouts.
  static const double tabletShortestSide = 600;
  static const double phoneColumn = 520;
  static const double tabletColumn = 760;
  static const double twoPaneMaxWidth = 1400;

  /// Smallest comfortable touch target (Material guidance).
  static const double minTouch = 48;

  final Size size;
  final FormFactor form;

  /// Multiplier on the 390 × 844 design sizes.
  final double scale;

  bool get twoPane => form == FormFactor.twoPane;
  bool get isTablet => form == FormFactor.tabletPortrait || (twoPane && size.shortestSide >= tabletShortestSide);

  static double _paneWidth(double width) => math.min(width, twoPaneMaxWidth) * 0.46;

  /// Width of the column holding HUD, shaft, bench and toolbar.
  double get columnWidth => switch (form) {
        FormFactor.twoPane => _paneWidth(size.width),
        FormFactor.tabletPortrait => math.min(size.width, tabletColumn),
        FormFactor.compactPhone || FormFactor.phone => math.min(size.width, phoneColumn),
      };

  /// Text grows more gently than shapes so tablets do not shout.
  double get textScale => scale.clamp(0.9, 1.25).toDouble();
  double font(double base) => base * textScale;

  double get gap => 12 * scale;
  double get radius => 22 * scale;
  double get hudHeight => math.max(50 * scale, minTouch);
  double get messageHeight => 32 * textScale;
  double get toolbarHeight => math.max(66 * scale, 56);

  double get shaftHeight => 262 * scale;
  double get nextColumn => 44 * scale;
  double get nextChip => 42 * scale;
  double get cabinWidth => 196 * scale;
  double get cabinHeight => 214 * scale;
  double get cabinFigure => 80 * scale;
  double get gaugeWidth => 92 * scale;
  Size get sendSize => Size(math.max(92 * scale, minTouch), math.max(76 * scale, minTouch));

  double get seatHeight => math.max(74 * scale, minTouch);
  double get benchFigure => 52 * scale;
  double get laneFigure => 54 * scale;

  /// Residents drawn per lane before the rest are counted.
  int get visibleDepth => switch (form) {
        FormFactor.compactPhone => 3,
        FormFactor.phone => 4,
        FormFactor.tabletPortrait => 5,
        FormFactor.twoPane => size.height >= 700 ? 6 : 4,
      };
}
