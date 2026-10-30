# Colour worlds: wiring plan (v1.8 slice 1)

Written 2026-10-30, while the Gate A build is frozen. This is the build plan for PRD v1.8 A ("Venue colour worlds",
`docs/PRD-v1.8-vibrant.md`), so slice 1 can start the day the Gate A report is in. Nothing here changes `lib/` or
`assets/` yet. The numbers come from `python3 tool/art/wall_contrast.py`, run on the 20 approved backdrops in
`docs/art/approved/`.

## What is there today

- **Backdrops.** Only Sunrise Towers has painted backdrops. `ArtAssets.backdropVenues = {Venue.society}`, and its
  files are `bg_society_shaft_<band>.webp` (three storey bands) and `bg_society_lobby.webp`. The other four venues
  fall back to the painted gradient wall and tiled floor.
- **Doorway.** `ShaftPainter.placement` scales and slides each wall so its doorway fits the cabin column and its
  floor meets the cabin's bottom. It uses one doorway rectangle for every wall, `ArtAssets.shaftDoorway` (x 0.277 to
  0.723, y 0.09 to 0.93 of the image).
- **Scrim.** A scrim (`LL.shaftScrim`, `#14132E` at 40%) shades the walls either side of the doorway. The NEXT label
  (`LL.lilac`) and the floor chips sit straight on that wall, while the gauge and the Scale button already sit on
  their own dark surfaces.
- **Lobby floors.** These are graded by the art pipeline so lane text clears 4.3:1. Each venue has its own lane ink
  (`VenueStyle.laneInk`).
- **Venue prop.** A painted prop (`VenuePropPainter`, the pot plant) stands under the NEXT chips on every venue,
  backdrop or not.

## What the measurements say

**1. The new walls do not share the old doorway.** The original Sunrise walls were drawn with the doorway exactly
where `shaftDoorway` says. The 15 new walls (Sunrise v2 and the four other venues) each draw their own opening:
narrower or wider, with lintels at different heights and floors at different lines. The contact sheet
`docs/art/venue-worlds/doorway-check.png` shows each wall with the shipped rectangle in green. With one shared
rectangle, the cabin would stand off-centre in some openings and float above or sink below the drawn floor in others.
Automatic detection of the opening was tried and is not reliable enough (it misreads even the original walls), so
the doorways are measured by hand, once per image.

**2. The new walls are 5 to 10 times brighter, which is the point, but the NEXT column cannot sit on them bare.**
Under the shipped scrim, the side walls' median luminance is 0.06 to 0.25, where the old walls sit at about 0.02.

| Against the side walls (worst wall) | Bare wall, shipped scrim | With a NEXT plate |
| --- | --- | --- |
| NEXT label (lilac), at the wall's bright end (p95) | 1.4:1 (hospital, Sunrise v2) | 6.4:1 or better on every wall |
| Floor chip fill, against the median wall | 1.0:1 (plum on hospital) | 3.6:1 or better on every wall |

Darkening the walls until the bare label reads would take a 72 to 77% wash on 12 of the 15 walls. That would grey out
the colour worlds, which defeats the slice. A dark plate behind the NEXT column fixes it instead, using the colour
the cabin chrome already uses (`LL.cabinPlate`, `#14132E` at 78%). It holds even over pure white: the label stays at
6.3:1 and the weakest chip (blue) at 3.4:1. So the build can test it with constants alone, without decoding images.

**3. The lobby floors are ready.** Each venue's own lane ink on its floor: Sunrise v2 4.4:1, office 4.8:1, hospital
4.8:1, mall 4.4:1, hotel 5.0:1 (need 4.3). Nothing to change.

**4. Sizes.** The 20 new images add about 0.8 MB of WebP. The Sunrise v2 set replaces the old Sunrise set, which
goes, so the net is about 0.7 MB.

## The plan

Two PRs, each green on its own.

### PR 1: walls, doorways and the NEXT plate (looks only)

1. **Assets.**
   - Copy the 20 approved images into `assets/art/`, using the shipped names. Sunrise v2 takes over
     `bg_society_*` (this is a replace: the old files stay in git history).
   - The other venues ship as `bg_office_*`, `bg_hospital_*`, `bg_mall_*` and `bg_hotel_*`.
   - Set `ArtAssets.backdropVenues` to every venue.
2. **A doorway per wall.**
   - Replace `ArtAssets.shaftDoorway` with `ArtAssets.shaftDoorway(Venue, ShaftBand)`, backed by a table of 15
     measured rectangles. `ShaftPainter.placement` already takes the rectangle as its fit target, so the painter
     barely changes.
   - Add a `doorway` mode to `tool/art/wall_contrast.py` that draws a candidate rectangle on a wall, so each
     measurement can be checked by eye.
   - Tests:
     - every shipped wall has a doorway;
     - each rectangle lies inside the image;
     - at the design size, `placement` puts the doorway on the cabin column and its bottom on the cabin floor
       (extending `test/backdrop_test.dart`).
3. **The NEXT plate.**
   - A rounded plate in `LL.cabinPlate` behind the NEXT label and chips, on every venue (owner decision 2), so the
     look does not change between walls.
   - The shipped scrim stays as it is.
   - Test: the label and all six floor colours against the plate composited over white, the worst case, at 4.5:1 for
     the label and 3:1 for the chips. It uses theme constants only.
4. **The painted prop.** The new walls paint their own plants, lamps and decor, so the pot-plant prop is drawn only
   on the painted fallback wall (owner decision 1). Test: with a backdrop loaded, no `VenuePropPainter` is in the tree.
5. **Fallback colours.** Retune the painted fallback `VenueStyle.wall` and `skyTop`/`skyBottom` to each world's hue,
   for a device where an image fails to load. Keep `floor` and `laneInk` as they are (they pass).

### PR 2: palette and juice (looks and feel, keyed only on what the player sees)

1. **Palette.** Add `confetti` and `burst` colours to `VenueStyle` from the PRD palette table, and use them in
   `effects.dart` instead of the fixed `_confettiColors` and `_sparkleColors`.
2. **Juice.**
   - **Venue confetti on a perfect send.** It hangs off the existing `SentEvent` rating.
   - **Rider reactions** after a send: cheer on perfect, wave on green, shrug on grey. They key on `TripRating`
     only, one animation for every type, played under the departing doors, and still under reduce-motion.
   - **A brighter boarding ring.** This is the existing `BurstKind.ring` with venue colour.
   - **A lobby idle emote now and then.** Who emotes is chosen by a hash of the resident id and the idle clock,
     never by type.
3. **Home.** The skyline buildings take their venue's colours (`home_screen.dart`, `sky_painter.dart`).
4. **Rule-3 guards** (new tests, in the style of the existing source guards):
   - the reaction is chosen from the rating alone;
   - emote timing reads only the id and the clock;
   - no new code in `lib/ui` reads `.kg` (the existing architecture test already covers this).

## Verification

- `flutter analyze --no-fatal-infos` and `flutter test`, including the Gate A dry run, so the tester kit keeps
  working.
- `python3 tool/art/wall_contrast.py` reproduces the tables above.
- The responsive sweep (14 sizes, 3 to 5 lanes, both hands, 1.3x text) on one level per venue.
- Screenshots of each venue at 450×800 and 1280×720 from a release web build, compared with
  `docs/art/venue-worlds/palette-board.png`, before the PR is marked ready.

## Owner decisions (2026-10-30, "go with your recommendations")

1. **The pot-plant prop under NEXT** is drawn only on the painted fallback wall. The new walls already paint their own
   plants and lamps.
2. **The NEXT plate** is drawn on every venue, so the HUD keeps one shape across buildings.
