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

import '../game/cast.dart';
import 'painters/resident_painter.dart';
import 'theme.dart';

/// The parts of a 3D surface, in logical pixels: the dark outline around the
/// face, the thick bottom edge and the drop under it, the white line inside
/// the top, the shade inside the bottom, and how far the face travels down
/// while pressed (`widgets/glossy.dart`).
typedef SurfaceSize = ({double outline, double edge, double drop, double highlight, double shade, double press});

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
      // [_paneStackHeight] design units tall; the lanes take the full height
      // on the right.
      FormFactor.twoPane => (math.min(_paneWidth(w) / _designWidth, h / _paneStackHeight)).clamp(0.6, 1.5).toDouble(),
      FormFactor.tabletPortrait =>
        (math.min(math.min(w, tabletColumn) / _designWidth, h / _designHeight) * 1.05).clamp(1.0, 1.5).toDouble(),
      FormFactor.compactPhone ||
      FormFactor.phone =>
        (math.min(w / _designWidth, h / _designHeight)).clamp(0.78, 1.15).toDouble(),
    };
    return Metrics._(size, form, scale);
  }

  /// Metrics for the screen this widget is on.
  static Metrics of(BuildContext context) => Metrics.from(MediaQuery.sizeOf(context));

  static const double _designWidth = 390;
  static const double _designHeight = 844;
  static const double _paneStackHeight = 600;

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

  /// The one gutter: the HUD, the shaft panel, the bench, the lobby floor and
  /// the bottom bar's buttons all stop this far from the screen's edges.
  double get gap => 12 * scale;

  /// Corner radius of the big panels (shaft, lobby floor, bottom bar) and of
  /// everything set inside them (seats, chips, the gauge plate, lane cards).
  double get radius => 22 * scale;
  double get innerRadius => 14 * scale;
  double get hudHeight => math.max(48 * scale, minTouch);

  /// The message line lives in a strip along the foot of the shaft panel,
  /// under the cabin, so it costs the lanes no height of their own.
  double get messageHeight => 24 * textScale;
  static const double messageRim = 1.5;
  double get messagePillPad => 1.5 * scale;

  /// The bottom bar: the power dock and Send (mirrored for left-handed play).
  /// Tall enough for a 48 px button and its label at the largest text size.
  /// A phone held sideways has no height to spare: the dock drops its labels
  /// (each button keeps its accessibility label) and the bar stays slim, and
  /// sheets lay their buttons side by side.
  bool get shortLandscape => twoPane && size.height < 700;
  bool get dockLabels => !shortLandscape;
  double get bottomBarHeight => dockLabels ? math.max(80 * scale, 78) : 56;
  double get dockButton => math.max(50 * scale, minTouch);
  double get dockGap => 7 * scale;

  /// The bar's room above the buttons (the stock badges hang off their
  /// corners into it).
  double get barTop => 4 * scale;

  /// Send beside a dock, and Send on its own before any power unlocks. Send
  /// is as tall as a dock button, so the two share a top and a baseline.
  double get sendWidth => 128 * scale;
  double get sendWidthSolo => 224 * scale;
  double get sendHeight => dockButton;

  /// The shaft panel: the floor display, the cabin, and the message strip.
  double get shaftHeight => cabinTop + cabinHeight + messageHeight;

  /// The shaft panel's three columns: NEXT, the cabin and the gauge, with
  /// [shaftColGap] between them and [shaftPad] either side. The gauge column
  /// keeps [gaugeColumn] and the NEXT column takes what a wide panel has to
  /// spare (never less than 44), so the cabin stands near the panel's middle.
  double get shaftPad => 10 * scale;
  double get shaftColGap => 8 * scale;
  double get gaugeColumn => 118 * scale;
  double get nextColumn => math.max(
        44 * scale,
        columnWidth - 2 * gap - 2 * shaftPad - cabinWidth - 2 * shaftColGap - gaugeColumn,
      );

  /// The columns beside the cabin start this far from the panel's top; the
  /// NEXT chips are [nextGap] apart, and the venue's prop stands under them.
  double get shaftTop => 10 * scale;
  double get nextGap => 5 * scale;
  static const Size propSize = Size(34, 48);
  double get nextChip => 40 * scale;

  /// The cabin keeps the proportions of its art (196 x 214 design units).
  static const double cabinAspect = 196 / 214;
  double get cabinHeight => 190 * scale;
  double get cabinWidth => cabinHeight * cabinAspect;
  double get cabinPadding => 7 * scale;
  double get cabinFigure => 128 * scale;
  double get gaugeWidth => 92 * scale;

  /// The cabin's top in the shaft, below the floor display; its bottom is
  /// where a backdrop's doorway meets the floor.
  double get cabinTop => 31 * scale;

  /// The darker channel either side of the cabin, where the rails run; a
  /// backdrop's doorway is fitted to the cabin plus this on each side.
  double get shaftChannel => 6 * scale;

  /// Riders stand on the cabin floor in two rows (`widgets/cabin_floor.dart`).
  /// Feet lines as fractions of the cabin's height: the back row just in
  /// front of the back wall, the front row near the floor's front edge. All
  /// four cabin interiors put their floor between 0.80 and 0.97.
  static const double cabinBackFeetLine = 0.855;
  static const double cabinFrontFeetLine = 0.935;

  /// The back row stands this much smaller and darker, for depth.
  static const double cabinBackScale = 0.88;
  static const double cabinBackShade = 0.86;

  /// Riders who walk to the back before the front row starts filling.
  static const int cabinBackSlots = 3;

  /// Each rider starts this far across the one before (of their width), and a
  /// row may use this much of the cabin's width before it shrinks to fit.
  static const double cabinRiderStep = 0.68;
  static const double cabinRowSpan = 0.94;

  /// An item is set down this much (of the cabin's height) in front of its
  /// owner's feet, tucked this much (of its width) in against their legs.
  static const double cabinCargoForward = 0.018;
  static const double cabinCargoTuck = 0.35;

  /// Cabin chrome over the art: the floor pill row's inset from the top.
  double get cabinChromeTop => 7 * scale;

  /// Door leaves: how far each bounces back from the seam as the doors settle
  /// shut, and the width of the shadow on its seam edge.
  double get doorSettle => 2 * scale;
  double get doorSeam => 7 * scale;

  /// The cabin's corner radius, and the rim around the art.
  double get cabinRadius => innerRadius;
  double get cabinRim => 2.5 * scale;

  /// Scale button on the gauge plate.
  Size get scaleButton => Size(math.max(92 * scale, minTouch), math.max(46 * scale, minTouch));

  // The 3D surfaces (style frame, `.g3d`): each depth in design units.
  SurfaceSize surface(SurfaceDepth depth) {
    final (o, e, d, hl, sh, p) = switch (depth) {
      SurfaceDepth.button => (2.5, 4.0, 3.0, 2.0, 5.0, 4.0),
      SurfaceDepth.chip => (2.0, 3.0, 0.0, 2.0, 3.0, 2.0),
      SurfaceDepth.tag => (1.5, 2.0, 0.0, 1.5, 0.0, 0.0),
      SurfaceDepth.seat => (2.0, 4.0, 0.0, 2.0, 0.0, 0.0),
    };
    return (
      outline: o * scale,
      edge: e * scale,
      drop: d * scale,
      highlight: hl * scale,
      shade: sh * scale,
      press: p * scale,
    );
  }

  /// The gloss band over a surface's face, as fractions of the face: its
  /// side inset, its top and its height (style frame, `.g3d::after`).
  static const double glossInset = 0.07;
  static const double glossTop = 0.05;
  static const double glossHeight = 0.38;

  /// Corner radius of the big buttons (Send, the sheets) and of the dock and
  /// Scale buttons' pills.
  double get buttonRadius => 22 * scale;

  /// Send: the up arrow beside its word.
  Size get sendGlyph => Size(26 * scale, 20 * scale);

  /// The HUD: round back and settings buttons (drawn inside a full touch
  /// target), the icons on them and in the lives, coins and trips pills.
  double get hudRound => 36 * scale;
  double get hudRoundIcon => 22 * scale;
  double get hudChipIcon => 24 * scale;
  double get hudChipGap => 3 * scale;

  /// The pills are as tall as the round buttons' faces; the gap between HUD
  /// items; and the round buttons' margin inside their touch target, which
  /// the row's edge padding and the gap after them make up for, so every
  /// visible edge lands on the gutter.
  double get hudPill => hudRound;
  double get hudGap => 8 * scale;
  double get hudButtonMargin => (math.max(hudRound, minTouch) - hudRound) / 2;
  double get hudEdge => math.max(gap - hudButtonMargin, 0);
  double get hudButtonGap => math.max(hudGap - hudButtonMargin, 0);

  /// The icon on a dock button, as a share of the button.
  static const double dockIconShare = 0.62;

  /// The lock on a power used up for this level.
  double get dockLock => 20 * scale;

  /// The stock badge on a dock button: its size, how far it hangs off the
  /// corner, its side padding, and the gap above the button's label (room
  /// for the button's bottom edge).
  double get dockBadge => 22 * scale;
  double get dockBadgeOffset => 4 * scale;
  double get dockBadgePad => 4 * scale;
  double get dockLabelGap => 7 * scale;

  /// The Scale button's icon.
  double get scaleIcon => 24 * scale;

  /// The floor display over the cabin, and the labels on a NEXT chip (an
  /// express prints two floors, so its label is smaller).
  double get displayRadius => 6 * scale;
  static const double displayRim = 1.5;
  static const double floorDisplayFont = 16;
  static const double nextFont = 14;
  static const double nextExpressFont = 11;

  /// A lift kind's badge on the corner of a NEXT chip, and on the cabin.
  double get kindBadge => 22 * scale;
  double get cabinKindBadge => 24 * scale;

  /// The corner radius of a NEXT chip; the lifts after the next one sit
  /// back at this opacity and scale; a kind's art fills this share of its
  /// badge's disc.
  double get nextChipRadius => innerRadius;
  static const double nextDimOpacity = 0.62;
  static const double nextDimScale = 0.88;
  static const double kindBadgeArt = 0.92;

  /// The load gauge's plate: corner, padding and rim.
  double get gaugePlateRadius => innerRadius;
  double get gaugePlatePadding => 6 * scale;
  static const double gaugePlateRim = 2;
  double get gaugeLabelGlow => 10 * scale;

  /// The thin dark lines either side of the cabin's coloured rim.
  double get cabinRimLine => 1.5 * scale;

  /// Bench seats: their corner radius, and the glow around a picked seat or
  /// one that can take the selected resident (it swells to [seatGlowBreath]
  /// as the seat breathes).
  double get seatRadius => innerRadius;
  double get seatGlow => 14 * scale;
  double get seatGlowBreath => 22 * scale;

  /// The warm glow under the selected resident, as fractions of the figure's
  /// box: how far it reaches past each side and below the feet, and where
  /// it starts from the top (style frame, `.front.sel::before`).
  static const double hopGlowSide = 0.12;
  static const double hopGlowBelow = 0.06;
  static const double hopGlowTop = 0.06;

  /// Where the glow's core, its brass ring and its edge sit, from the centre.
  static const List<double> hopGlowStops = [0, 0.45, 0.7];

  /// The score slam (style frame, `.pop`): the coins line and the rating
  /// line under it, their outlines, the drop under the coins, the glow
  /// around them, and how far the slam drifts up as it lands.
  double get slamFont => 38 * textScale;
  double get slamSubFont => 17 * textScale;
  double get slamStroke => 7 * textScale;
  double get slamSubStroke => 5 * textScale;
  double get slamDrop => 6 * scale;
  double get slamGlow => 28 * scale;
  double get slamRise => 18 * scale;

  /// The rating line's letter spacing, as a share of its size.
  static const double slamSubTracking = 0.08;

  /// A coin icon flying to the coin pill.
  double get coinFly => 22 * scale;

  /// Sheets (fail, win, get more, settings): the round badge at the top and
  /// its icon, the icon on a sheet button, the gap between stacked buttons
  /// (room for their bottom edge), and the icon on a settings row.
  static const double sheetBadge = 76;
  static const double sheetBadgeIcon = 50;
  static const double sheetButtonIcon = 26;
  static const double sheetStar = 20;

  /// The power's round badge at the top of the get-more sheet.
  static const double sheetPower = 64;
  static const double sheetButtonGap = 12;
  static const double sheetButtonRadius = 18;
  static const double settingsIcon = 28;

  /// A settings row that cannot be used right now fades to this.
  static const double disabledRow = 0.6;
  static const double sheetRowGap = 10;

  /// The icon on a home-screen stat pill.
  double get statIcon => 22 * scale;

  // Figures. The design sizes are 60% larger than the v1.6 ones; lanes and
  // seats shrink a figure only as far as their width forces, never below the
  // v1.6 size ([_laneFigureFloor], [_benchFigureFloor]).
  double get laneFigure => 86 * scale;

  /// The bench is capped at this share of the lane figure, so its taller seats
  /// do not push the lanes off the screen (owner, 2026-10-22).
  static const double benchToLane = 0.68;
  double get benchFigure => laneFigure * benchToLane;
  double get _laneFigureFloor => 54 * scale;
  double get _benchFigureFloor => 52 * scale;

  /// The widest figure box in design units (a pram or a trolley; those never
  /// carry cargo), so one figure size fits every resident in a lane or seat.
  static final double widestFigure = [
    for (final t in ResidentType.values)
      for (final c in Cargo.values)
        if (t.canCarry || c == Cargo.none) ResidentLook.designWidth(t, c),
  ].reduce(math.max);

  double _fit(double target, double floor, double room) =>
      math.min(target, math.max(floor, room / widestFigure * designHeight));

  /// Contact shadow under a sprite, as fractions: its width of the sprite's
  /// width, its height of its own width, its blur of its own width.
  static const double contactShadowWidth = 0.62;
  static const double contactShadowHeight = 0.20;
  static const double contactShadowBlur = 0.035;

  /// The unknown ghost: its opacity, and its glow's blur as a fraction of its width.
  static const double ghostOpacity = 0.85;
  static const double ghostGlowBlur = 0.08;

  // Lobby lanes: the floor's inset and padding, and each slot's padding and
  // thickest border (Swap targeting), which share a lane's width.
  double get lanePadding => 6 * scale;

  /// The lane area's scroll cue: the bar's thickness and margin, how deep the
  /// edge fades reach, and how far from an edge the content must be before a
  /// fade shows.
  double get scrollBar => 4 * scale;
  double get scrollBarMargin => 4 * scale;
  double get scrollFade => 26 * scale;
  static const double scrollCueEdge = 1;

  /// The lobby floor's room above the lanes, and how far a selected front
  /// rises; the rise plus its hop ([PunchMotion.hopHeight]) fits in that
  /// room, so the hopping front never meets the floor's top edge.
  double get laneTop => 8 * scale;
  double get selectedLift => 3 * scale;
  double get slotPadding => 8 * scale;
  static const double slotBorder = 3;
  static const double slotBorderThin = 2;

  /// The height of a compact floor tag, so an unknown slot lines up with a known one.
  static const double compactTagHeight = 14;
  static const double tagHeight = 20;

  /// Scenario icons on the lobby floor, in design units: the rush-hour
  /// banner's and the cones over a closed lane.
  static const double bannerIcon = 18;
  static const double coneIcon = 34;

  /// Width the lobby lanes share: the column, or the right pane.
  double get lanesWidth => twoPane ? math.min(size.width, twoPaneMaxWidth) - columnWidth : columnWidth;

  /// Figure height in a lobby of [lanes] lanes.
  double laneFigureFor(int lanes) {
    final lane = (lanesWidth - 2 * (gap + lanePadding)) / math.max(lanes, 1);
    return _fit(laneFigure, _laneFigureFloor, lane - 2 * (slotPadding + slotBorder));
  }

  /// Bench seats in one row; beyond this the bench wraps into two even rows.
  static const int benchRowMax = 5;
  static int benchPerRow(int seats) => seats <= benchRowMax ? seats : (seats + 1) ~/ 2;

  /// The bench shares the gutter with everything else; its label row sits
  /// [benchTop] under the shaft and [benchLabelGap] above the seats.
  double get benchInset => gap;
  double get benchTop => 4 * scale;
  double get benchLabelGap => 4 * scale;
  double get benchBottom => 6 * scale;
  double get seatGap => 8 * scale;
  static const double seatBorder = 2;

  /// A seat's floor tag: its inset from the seat's top and left.
  double get seatTag => 4 * scale;

  /// Every seat is this tall, empty or not, so seating someone never moves
  /// the lanes. The floor tag sits in the seat's top corner, beside the
  /// figure rather than above it.
  double get seatHeight => math.max(64 * scale, minTouch);

  /// Figure height on a bench of [seats] seats: the +60% size where the seat
  /// is wide and tall enough, shrunk to fit its width, never below the v1.6
  /// size.
  double benchFigureFor(int seats) {
    final perRow = math.max(benchPerRow(seats), 1);
    final seat = (columnWidth - 2 * benchInset - (perRow - 1) * seatGap) / perRow;
    return math.min(_fit(benchFigure, _benchFigureFloor, seat - 2 * seatBorder), seatHeight - 2 * seatBorder);
  }

  /// Residents drawn per lane before the rest are counted.
  int get visibleDepth => switch (form) {
        FormFactor.compactPhone => 3,
        FormFactor.phone => 4,
        FormFactor.tabletPortrait => 5,
        FormFactor.twoPane => size.height >= 700 ? 6 : 4,
      };
}
