# PRD v1.7: restyle and art integration

Status: DRAFT, waiting for the owner's sign-off. Date: 2026-10-22.

## Problem

The art and the look you approved are not in the game. Main runs the v1.6 rules and layout, but:

- Residents are still drawn by `ResidentPainter` at the old size: 80 dp in the cabin, 54 in a lane, 52 on the bench.
- The cabins are plain shapes and the doors do not slide.
- The lobby and shaft use the old flat backgrounds.
- Buttons are flat, and Send is brass rather than the glossy mint in the frames.
- Icons are Material placeholders.
- Unknown people are grey silhouettes.

The approved files are 66 WebP images in `docs/art/approved/`, about 1.7 MB, and nothing ships them. The style frame
(`docs/art/style-frame/`) and layout frame (`docs/art/layout-frame/`) are the look you signed off. This build makes the
game match them.

## What exists (from the code)

- `ResidentFigure` wraps `ResidentPainter`. Sway, blink, walks and the reveal pop already work on any child widget.
- `Metrics` (`lib/ui/layout.dart`) holds every size. The figure sizes are `cabinFigure`, `laneFigure` and `benchFigure`.
- `lift_shaft.dart` and `cabin_painter.dart` draw the shaft and cabin. Send runs a departure animation.
- `effects.dart` has the particle bursts. `pressable.dart` gives the press feedback.
- The approved art:
  - the whole cast (all 14 types) and the 3 cargo props;
  - 4 cabin interiors with 8 door leaves;
  - Sunrise Towers: 3 shaft backdrops and 1 lobby floor, plus the in-code walls and floors;
  - the unknown ghost;
  - 24 icons.

## Success criteria

1. A side-by-side of the play screen next to the style frame reads as the same game. That covers the cast sprites,
   glossy 3D buttons and chips, a mint Send, the approved icons, the Sunrise backdrops, the cabin art and the ghost.
2. Figures are 60% larger: about 128 dp in the cabin, 86 in a lane and 83 on the bench at 390 wide. They step down only
   where the screen width forces it.
3. Send plays the punch from the style frame:
   - the doors close in 420 ms;
   - the cabin bumps;
   - the trip score slams in;
   - coins fly to the counter.
   A free seat breathes and the selected resident hops on a warm glow. All of it is still under reduce-motion.
4. No layout overflow on the 14 responsive sizes, with 3, 4 and 5 lanes, both hands and 1.3x text. Every touch
   target stays at least 48 dp.
5. No weight cue anywhere. A sprite's size, pose or prop never changes with load, and nothing on a door, chip or
   icon suggests weight.
6. The web build stays under 25 MB, and the art adds at most about 4 MB.
7. All existing tests stay green, with new tests for the sprite path, doors and backdrops.

## Scope

In:

- Asset pipeline: copy the approved WebP into `assets/art/` and declare them in `pubspec.yaml`. One `ArtAssets` table
  maps type, cargo, lift kind, venue and icon to a path. There are no paths in widgets.
- Sprite residents in `ResidentFigure`, with the parametric painter kept as the fallback.
  - The contact shadow is painted in code to the spec in `docs/art/gemini-art-pack.md`: width 0.62, height 0.20,
    about 41% warm near-black, blurred.
  - In the cabin, the feet sit at 90% of the cabin height.
- Figures +60% through `Metrics`. The lane width is shared out so that 5 lanes still fit 320 dp. Figures shrink only
  as far as needed, never below today's sizes.
- The unknown ghost sprite, with its glow and opacity in code, replacing the grey silhouette.
- Cabin interior art per lift kind, cover-cropped to 196 x 214 units.
- Two door leaves that close on Send and open on arrival:
  - 420 ms ease-in-out, with a 2 px settle;
  - a seam shadow on each leaf;
  - the interior dimmed by 12% while the doors are closed.
- Sunrise Towers backdrops:
  - the shaft wall changes by storey band;
  - the lobby floor gets the approved tile, lifted where needed so lane text keeps 4.3:1 contrast.
- 3D surface recipe in `theme.dart`, applied to every button, chip, tag, seat and the HUD pills:
  - dark outline;
  - lit gradient;
  - thick bottom edge;
  - top gloss;
  - press-down.
  Send becomes the mint button from the frames. The gauge gets its glow.
- The approved icons replace Material icons for heart, coin, scale, trip, seat, restart, play, lock, hourglass, star,
  trophy, cable snap, the floor badges, lift kinds and scenarios. +1 trip and +2 seats use the trip and seat icons.
  Swap and Express stay as placeholders until their art exists.
- The punch on Send, the seat breathe and the selected hop, as listed in the success criteria.

Out:

- New art. This build is integration only.
  - Office, hospital, mall and hotel have no backdrops yet, so they keep today's painted lobby and shaft. They still
    get the cast, cabins, icons and surfaces.
  - The Swap and Express icons stay placeholders.
- The home screen skyline and the store screen, which have no approved art.
- Sound changes.
- Engine, rules, economy and level changes.

## Constraints

- Widgets still call only `GameController`. No `.kg`, no "kg", and no waiting count (`test/architecture_test.dart`).
- Every size comes from `Metrics` and every colour from `theme.dart`. There are no magic numbers.
- Reduce-motion stills every new animation.
- The sprites are 6 px per design unit, so they hold up to about 1.5x on a tablet. The fallback painter covers any
  missing image.
- The `icon_scene_powercut` art is unused now that the scenario is gone. It is not shipped.

## Plan

Five slices. Each one is pushed with screenshots at 390 x 844, normal and left-handed, so you can see it before the
next starts.

1. **Assets and sprite cast:** the asset table, sprite residents with contact shadows, the ghost sprite, figures +60%
   with lane fitting, and the responsive sweep.
2. **Cabins and doors:** interiors per kind, the two-leaf doors, and Send sequenced as doors close, lift moves, doors
   open.
3. **Surfaces and icons:** the 3D recipe on every button and chip, mint Send, the approved icons in the HUD, dock,
   sheets, NEXT chips and floor tags, and the gauge glow.
4. **Sunrise backdrops and punch:** the shaft wall by band, the lobby floor, the cabin bump, the score slam, the coin
   fly, the seat breathe and the selected hop.
5. **Proof:** web build, side-by-side contact sheet against the style frame, size check, code-reviewer pass.

## Decisions for you

1. **Rollout.** On by default, with a `useSpriteArt` switch kept for one release so a tester build can compare the old
   and new looks. Recommended: on by default.
2. **The other four venues.** They have no backdrops yet. Recommended: ship the restyle now with their current
   backgrounds, and generate their backdrops in code with `make_venues.py`, as was done for Sunrise Towers. The
   alternative is to wait for Gemini art.
3. **Figure size on 5-lane levels at 320 dp.** +60% does not fit five lanes on the narrowest phones. Recommended:
   figures shrink just enough to fit there, and stay at +60% everywhere else.

## Open questions

None beyond the three decisions above.
