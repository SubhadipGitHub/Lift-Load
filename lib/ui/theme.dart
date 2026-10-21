import 'package:flutter/material.dart';

import '../game/cast.dart';

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

  // Fonts: Baloo 2 (display) and Nunito Sans (body) get bundled in M4.
  // Until then the platform font carries the same weights.
  static const display = TextStyle(fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -0.2);
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: lilac);

  static ThemeData theme() => ThemeData(
        useMaterial3: true,
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

/// Each floor has a colour and a shape; the shape carries the meaning so the
/// game reads in grayscale and for colour-blind players.
class FloorStyle {
  const FloorStyle(this.color, this.dark, this.shape);
  final Color color;
  final Color dark;
  final FloorShape shape;

  static FloorStyle of(Floor f) => switch (f) {
        Floor.coral => const FloorStyle(Color(0xFFFF6B5B), Color(0xFFB03A2E), FloorShape.circle),
        Floor.sun => const FloorStyle(Color(0xFFFFC233), Color(0xFFA6740A), FloorShape.triangle),
        Floor.teal => const FloorStyle(Color(0xFF14B8A6), Color(0xFF0B6E64), FloorShape.square),
        Floor.blue => const FloorStyle(Color(0xFF4C7DFF), Color(0xFF2747B0), FloorShape.diamond),
        Floor.plum => const FloorStyle(Color(0xFFA066F5), Color(0xFF5B2DB0), FloorShape.hexagon),
        Floor.leaf => const FloorStyle(Color(0xFF7BD148), Color(0xFF3F7A1C), FloorShape.plus),
      };
}

enum FloorShape { circle, triangle, square, diamond, hexagon, plus }
