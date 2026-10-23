import 'package:flutter/material.dart';

import '../game/cast.dart';
import '../game/scenario.dart';
import '../game/venue.dart';

/// "Lobby Pop" palette from the concept canvas style guide.
abstract final class LL {
  static const night = Color(0xFF1C1A3F);
  static const facade = Color(0xFF2A2756);
  static const panel = Color(0xFF25234E);
  static const deep = Color(0xFF14132E);
  static const cream = Color(0xFFFFF4E2);
  static const tile = Color(0xFFF4E3C3);
  static const brass = Color(0xFFF5B83D);
  static const brassDark = Color(0xFFB57D12);
  static const mint = Color(0xFF3DDC97);
  static const mintDark = Color(0xFF1F9A66);
  static const mintInk = Color(0xFF0E2A1F);
  static const ink = Color(0xFF1E1B3A);
  static const inkSoft = Color(0xFF4A4060);
  static const lilac = Color(0xFFB9B4E0);
  static const rule = Color(0xFF4A4680);
  static const alarm = Color(0xFFE5484D);
  static const alarmSoft = Color(0xFFFF8A8E);
  static const steel = Color(0xFFD9DDE3);
  static const steelFloor = Color(0xFF9AA1AB);

  /// Contact shadow under a sprite figure: warm near-black (24, 14, 10) at
  /// about 41% (`docs/art/gemini-art-pack.md`, Integration).
  static const contactShadow = Color(0x69180E0A);

  /// Cabin doors: the dim over the interior while they close, and the shadow
  /// on each leaf's seam edge. Near-black, used at low opacity.
  static const doorShade = Color(0xFF0A0812);

  /// The dark plate behind cabin text drawn over the art (deep at about 78%).
  static const cabinPlate = Color(0xC714132E);

  /// The red wash over the cabin art when the cable snaps.
  static const crashTint = Color(0x47E5484D);

  /// The halo around the unknown ghost: the same for everyone.
  static const ghostGlow = Color(0x99A9C8FF);

  // The 3D surface recipe (docs/art/style-frame): each surface has a lit
  // gradient (hi, mid, lo), a dark outline that also forms the thick bottom
  // edge, and a darker drop under that. See [SurfaceStyle].
  static const mintHi = Color(0xFFB6FFDC);
  static const mintLo = Color(0xFF19A56B);
  static const mintEdge = Color(0xFF07402A);
  static const mintDrop = Color(0xFF04200F);
  static const brassHi = Color(0xFFFFE58F);
  static const brassLo = Color(0xFFD88F12);
  static const brassEdge = Color(0xFF5A3A05);
  static const brassDrop = Color(0xFF2A1A02);
  static const creamHi = Color(0xFFFFFFFF);
  static const creamLo = Color(0xFFEAD7B4);
  static const creamEdge = Color(0xFF4A3A20);
  static const creamDrop = Color(0xFF241A0A);
  static const plumHi = Color(0xFF8B86D8);
  static const plumMid = Color(0xFF4A4590);
  static const plumLo = Color(0xFF2F2B66);
  static const plumEdge = Color(0xFF0B0A24);
  static const plumDrop = Color(0xFF05041A);

  /// HUD chips (lives, coins, trips): a dark pill with a faint gloss.
  static const chipHi = Color(0xFF3A3585);
  static const chipMid = Color(0xFF2D2970);
  static const chipLo = Color(0xFF211E52);

  /// An occupied bench seat: warm cream.
  static const seatHi = Color(0xFFFFFAF0);
  static const seatLo = Color(0xFFF0DFBD);

  /// A free seat: a dark well with a lilac rim.
  static const seatWell = Color(0x44000000);
  static const seatWellShade = Color(0x55000000);
  static const seatRim = Color(0xFF5A5592);

  /// A disabled button: flat slate, no gloss, lilac text.
  static const offHi = Color(0xFF6A6696);
  static const offMid = Color(0xFF55517F);
  static const offLo = Color(0xFF433F6B);
  static const offEdge = Color(0xFF1B1938);
  static const offDrop = Color(0xFF0B0A1E);

  /// The light pieces of every surface: the top inner line, the gloss band
  /// (from its top to its bottom) and the shade along the inner bottom.
  static const surfaceHighlight = Color(0xB0FFFFFF);
  static const surfaceGlossTop = Color(0x99FFFFFF);
  static const surfaceGlossBottom = Color(0x10FFFFFF);
  static const surfaceShade = Color(0x33000000);

  /// The warm glow around a picked seat or a seat that can take someone.
  static const pickGlow = Color(0x77F5B83D);

  /// The message pill under the shaft.
  static const messagePill = Color(0x77000000);
  static const messageRim = Color(0x22FFFFFF);

  /// The lane area's scroll cue: the bar, and the shade over the floor's
  /// edge (and where it fades to).
  static const scrollThumb = Color(0xB3FFF6E6);
  static const scrollFade = Color(0x66141330);
  static const scrollFadeClear = Color(0x00141330);

  /// The lit floor display over the cabin: its amber lamp, dark bed and rim.
  static const led = Color(0xFFFFC46B);
  static const displayBed = Color(0xFF0E0C22);
  static const displayRim = Color(0xFF3A3670);

  /// The load gauge (style frame): its plate, the dark bed under the arcs,
  /// the grey zone, the gloss line over the arcs, and the needle's hub.
  static const gaugePlateTop = Color(0xCC14132E);
  static const gaugePlateBottom = Color(0xEE0B0A24);
  static const gaugePlateRim = Color(0x1FFFFFFF);
  static const gaugeBed = Color(0xFF05041A);
  static const gaugeGrey = Color(0xFF8F8AC4);
  static const gaugeGloss = Color(0x59FFFFFF);
  static const gaugeHub = Color(0xFFFFC233);

  /// The warm glow under the selected resident: brass-hi at the core, brass
  /// at about 40% half way out, then nothing (style frame, `.front.sel`).
  static const hopGlowCore = brassHi;
  static const hopGlowMid = Color(0x66F5B83D);
  static const hopGlowEdge = Color(0x00F5B83D);

  /// Premium motion (slice B): the gloss sweep across a released button, the
  /// glow under Send when the load is good to send and under Play at home,
  /// the ring of light where a resident arrives, the chime light on a
  /// lift's top, the flash when an unknown person is revealed, the ride's
  /// speed streaks and a twinkling window.
  static const sweepLight = Color(0xA6FFFFFF);
  static const readyGlow = Color(0xFF3DDC97);
  static const playGlow = Color(0xFFF5B83D);
  static const ringLight = Color(0xFFFFF4E2);
  static const chimeLight = Color(0xFFFFE9B0);
  static const revealFlash = Color(0xFFFFF8E0);
  static const streak = Color(0xFFDCD8FF);
  static const twinkle = Color(0xFFFFF3C4);

  /// The score slam: brass-hi coins with a dark brown outline, a drop and a
  /// brass glow; the rating line in white outlined in deep mint, or lilac
  /// outlined in plum for a half-empty trip (no coins).
  static const slamStroke = Color(0xFF4A2D03);
  static const slamGlow = Color(0xCCF5B83D);
  static const slamSubStroke = Color(0xFF0E5A38);

  /// Text on a painted lobby floor ("Clear"): at least 5:1 on every pixel
  /// of the Sunrise Towers floor (the venue's own lane ink gets 4.3:1 there).
  static const lobbyArtInk = Color(0xFF5E503A);

  /// Over a painted shaft wall, either side of the doorway: deep at about
  /// 40%, so the faded NEXT chips and Scale read over lamps and city lights.
  static const shaftScrim = Color(0x6614132E);

  /// The cones' orange on a closed lane (the painted fallback icon).
  static const cone = Color(0xFFFF8A3D);

  // Baloo 2 for display, Nunito Sans for everything else (bundled, OFL).
  static const displayFont = 'Baloo2';
  static const bodyFont = 'NunitoSans';
  static const display =
      TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -0.2);
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: lilac);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        fontFamily: bodyFont,
        scaffoldBackgroundColor: night,
        colorScheme: const ColorScheme.dark(
          primary: brass,
          onPrimary: ink,
          secondary: mint,
          onSecondary: mintInk,
          surface: facade,
          onSurface: cream,
          error: alarm,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: cream, fontWeight: FontWeight.w600),
        ),
      );
}

/// Each floor has a colour; its label ("2F") is what tells floors apart for
/// anyone who cannot rely on colour, so every tag, chip and display prints it.
class FloorStyle {
  const FloorStyle(this.color, this.dark, {required this.light, required this.edge});
  final Color color;
  final Color dark;

  /// The top of a floor chip's lit gradient, and its outline and bottom
  /// edge (style frame, `.tag` and `.nchip`).
  final Color light;
  final Color edge;

  static FloorStyle of(Floor f) => switch (f) {
        Floor.coral =>
          const FloorStyle(Color(0xFFFF6B5B), Color(0xFFB03A2E), light: Color(0xFFFF9A8C), edge: Color(0xFF8A2A20)),
        Floor.sun =>
          const FloorStyle(Color(0xFFFFC233), Color(0xFFA6740A), light: Color(0xFFFFE07A), edge: Color(0xFF7A5206)),
        Floor.teal =>
          const FloorStyle(Color(0xFF14B8A6), Color(0xFF0B6E64), light: Color(0xFF4BE0CF), edge: Color(0xFF08524A)),
        Floor.blue =>
          const FloorStyle(Color(0xFF4C7DFF), Color(0xFF2747B0), light: Color(0xFF86A6FF), edge: Color(0xFF1C3380)),
        Floor.plum =>
          const FloorStyle(Color(0xFFA066F5), Color(0xFF5B2DB0), light: Color(0xFFC49CFF), edge: Color(0xFF43208A)),
        Floor.leaf =>
          const FloorStyle(Color(0xFF7BD148), Color(0xFF3F7A1C), light: Color(0xFFA8EF7A), edge: Color(0xFF2D5A12)),
      };
}

/// One 3D surface from the style frame: a lit vertical gradient ([hi] at the
/// top, [mid] at 48%, [lo] at the bottom), a dark [edge] that outlines it and
/// forms its thick bottom edge, a darker [drop] under that, a top gloss of
/// [gloss] strength, and the [ink] for text and icons on it. Drawn by
/// `widgets/glossy.dart`; the sizes come from `Metrics.surface`.
@immutable
class SurfaceStyle {
  const SurfaceStyle({
    required this.hi,
    required this.mid,
    required this.lo,
    required this.edge,
    required this.drop,
    required this.ink,
    this.gloss = 1,
  });

  final Color hi, mid, lo, edge, drop, ink;

  /// 0 to 1: how strong the top highlight and gloss band are.
  final double gloss;

  /// Send and the rewarded buttons.
  static const mint =
      SurfaceStyle(hi: LL.mintHi, mid: LL.mint, lo: LL.mintLo, edge: LL.mintEdge, drop: LL.mintDrop, ink: LL.ink);

  /// Primary actions that spend coins or move on; the level pill.
  static const brass =
      SurfaceStyle(hi: LL.brassHi, mid: LL.brass, lo: LL.brassLo, edge: LL.brassEdge, drop: LL.brassDrop, ink: LL.ink);

  /// The dock, Scale and quiet sheet buttons.
  static const cream =
      SurfaceStyle(hi: LL.creamHi, mid: LL.cream, lo: LL.creamLo, edge: LL.creamEdge, drop: LL.creamDrop, ink: LL.ink);

  /// Dark round HUD buttons (back, settings) and dark sheet buttons.
  static const plum =
      SurfaceStyle(hi: LL.plumHi, mid: LL.plumMid, lo: LL.plumLo, edge: LL.plumEdge, drop: LL.plumDrop, ink: LL.cream);

  /// HUD pills: lives, coins, trips.
  static const chip = SurfaceStyle(
      hi: LL.chipHi, mid: LL.chipMid, lo: LL.chipLo, edge: LL.plumEdge, drop: LL.plumDrop, ink: LL.cream, gloss: 0.3);

  /// An occupied bench seat, and the same seat picked.
  static const seat = SurfaceStyle(
      hi: LL.seatHi, mid: LL.seatHi, lo: LL.seatLo, edge: LL.creamEdge, drop: LL.creamDrop, ink: LL.ink, gloss: 0.5);
  static const seatPicked = SurfaceStyle(
      hi: LL.seatHi, mid: LL.seatHi, lo: LL.seatLo, edge: LL.brassDark, drop: LL.brassEdge, ink: LL.ink, gloss: 0.5);

  /// Any button that cannot be pressed: flat slate, so it never reads as live.
  static const off = SurfaceStyle(
      hi: LL.offHi, mid: LL.offMid, lo: LL.offLo, edge: LL.offEdge, drop: LL.offDrop, ink: LL.lilac, gloss: 0);

  /// A floor's chip or tag: its own colour and an ink label.
  static SurfaceStyle floor(Floor f) {
    final s = FloorStyle.of(f);
    return SurfaceStyle(hi: s.light, mid: s.light, lo: s.color, edge: s.edge, drop: LL.plumDrop, ink: LL.ink);
  }

  @override
  bool operator ==(Object other) =>
      other is SurfaceStyle &&
      other.hi == hi &&
      other.mid == mid &&
      other.lo == lo &&
      other.edge == edge &&
      other.drop == drop &&
      other.ink == ink &&
      other.gloss == gloss;

  @override
  int get hashCode => Object.hash(hi, mid, lo, edge, drop, ink, gloss);
}

/// How deep a surface is built: a button, a chip (HUD pills, NEXT chips,
/// sheet rows), a floor tag, or a bench seat. Sizes in `Metrics.surface`.
enum SurfaceDepth { button, chip, tag, seat }

/// How a venue looks: the shaft wall, the lobby floor and its pattern, the
/// sign colour and the prop in the shaft corner.
class VenueStyle {
  const VenueStyle({
    required this.wall,
    required this.floor,
    required this.floorLine,
    required this.pattern,
    required this.accent,
    required this.laneInk,
    required this.prop,
    required this.motif,
    required this.skyTop,
    required this.skyBottom,
  });

  final Color wall;
  final Color floor;
  final Color floorLine;
  final FloorPattern pattern;
  final Color accent;

  /// Text drawn on the lobby floor ("+3 waiting", "Clear").
  final Color laneInk;
  final VenueProp prop;

  /// What is painted faintly on the shaft wall behind the lift.
  final WallMotif motif;

  /// Home-screen sky behind the skyline while this venue is current.
  final Color skyTop;
  final Color skyBottom;

  /// Shaft wall gradient, derived from [wall].
  Color get wallTop => Color.lerp(wall, Colors.white, 0.07)!;
  Color get wallBottom => Color.lerp(wall, Colors.black, 0.28)!;

  static VenueStyle of(Venue v) => switch (v) {
        Venue.society => const VenueStyle(
            wall: LL.facade,
            floor: LL.tile,
            floorLine: Color(0xFFE6CFA6),
            pattern: FloorPattern.tiles,
            accent: LL.brass,
            laneInk: Color(0xFF6B5C44),
            prop: VenueProp.plant,
            motif: WallMotif.windows,
            skyTop: Color(0xFF2B2A6B),
            skyBottom: Color(0xFF6C4A8C),
          ),
        Venue.office => const VenueStyle(
            wall: Color(0xFF2B3445),
            floor: Color(0xFFE3E6EA),
            floorLine: Color(0xFFCDD2D9),
            pattern: FloorPattern.stone,
            accent: Color(0xFF8CC4E8),
            laneInk: Color(0xFF4F5B6B),
            prop: VenueProp.cooler,
            motif: WallMotif.mullions,
            skyTop: Color(0xFF1C3150),
            skyBottom: Color(0xFF4E7BA6),
          ),
        Venue.hospital => const VenueStyle(
            wall: Color(0xFF1F3F3B),
            floor: Color(0xFFE4F1EC),
            floorLine: Color(0xFFC6DDD4),
            pattern: FloorPattern.stripes,
            accent: Color(0xFF7FE0B8),
            laneInk: Color(0xFF3F6157),
            prop: VenueProp.medicalSign,
            motif: WallMotif.signStripe,
            skyTop: Color(0xFF17363A),
            skyBottom: Color(0xFF3E8C7E),
          ),
        Venue.mall => const VenueStyle(
            wall: Color(0xFF3A2350),
            floor: Color(0xFFFBEFE6),
            floorLine: Color(0xFFF0D7C4),
            pattern: FloorPattern.marble,
            accent: Color(0xFFFF9BB0),
            laneInk: Color(0xFF7A5566),
            prop: VenueProp.shoppingBag,
            motif: WallMotif.awnings,
            skyTop: Color(0xFF3A1F4F),
            skyBottom: Color(0xFFC2577A),
          ),
        Venue.hotel => const VenueStyle(
            wall: Color(0xFF3B1F2B),
            floor: Color(0xFFE9D7C0),
            floorLine: Color(0xFFD3B994),
            pattern: FloorPattern.carpet,
            accent: Color(0xFFE2C46A),
            laneInk: Color(0xFF6E4E3A),
            prop: VenueProp.bell,
            motif: WallMotif.wallpaper,
            skyTop: Color(0xFF2A1420),
            skyBottom: Color(0xFF8C4A3A),
          ),
      };
}

enum FloorPattern { tiles, stone, stripes, marble, carpet }

enum VenueProp { plant, cooler, medicalSign, shoppingBag, bell }

enum WallMotif { windows, mullions, signStripe, awnings, wallpaper }

/// How each lift kind's cabin reads at a glance. The sign names the cabin;
/// it never says anything about who weighs what.
class LiftKindStyle {
  const LiftKindStyle(this.cabin, this.sign, this.icon);

  final Color cabin;
  final String sign;

  /// The Material fallback for the kind's approved badge (`ArtIcon.kind`) on
  /// the cabin and the NEXT chips; null for a normal lift.
  final IconData? icon;

  static LiftKindStyle of(LiftKind k) => switch (k) {
        LiftKind.normal => const LiftKindStyle(LL.brass, 'MIND THE LOAD', null),
        LiftKind.old => const LiftKindStyle(Color(0xFFB9824F), 'OLD LIFT · GO EASY', Icons.build_rounded),
        LiftKind.service => const LiftKindStyle(Color(0xFF9AA6BA), 'SERVICE LIFT', Icons.local_shipping_rounded),
        LiftKind.express => const LiftKindStyle(LL.mint, 'EXPRESS · TWO STOPS', Icons.bolt_rounded),
      };
}
