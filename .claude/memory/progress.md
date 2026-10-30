# Progress log

Update at the end of every session and before switching domains (skill: `session-checkpoint`). Keep the last five
entries; fold older ones into "Earlier".

## 2026-10-30 · Star study for PRD v1.8 C (branch star-study)

**Done**
- `tool/star_study.dart`: a best-play beam search with full knowledge, through `LiftGame`, plus the greedy and blind
  bots, a forced-grey count per floor and an exhaustive `prove` mode. Write-up in `docs/star-study.md`.
- Finding: the specced 3-star rule (every send green, perfects >= ceil(sends/3)) is reached on 0 of 100 levels, even
  by best play. On 33 levels a floor's weight cannot split into all-green trips, so a grey is forced. Best play sends
  33% grey, the blind bot 48%.
- Owner signed off the amendment; PRD v1.8 C and decisions.md updated. 3 stars = win with >= P perfects,
  P = floor(2/3 x best-play perfects), min 1; 2 stars = >= ceil(P/2). Blind bot: 33 three-star, 26 two-star,
  20 one-star of 79 wins.

**Open**
- Slice 3 needs a P table in `Formulas` (written by the tool), a generator_test guard, and a daily-challenge target.

## 2026-10-30 · v1.8 colour-world backdrops, intake (branch art-venue-worlds, PR #30)

**Done**
- All 20 backdrops approved into `docs/art/approved/` (not shipped), all centre-third-empty with detail at the sides and
  no text: Sunrise v2 (4, lobby 4.5:1), Skyline Offices (4, lobby 4.5:1), Lakeside Hospital (4, lobby 4.6:1), Bazaar Mall
  (4, lobby 4.6:1) and Starlight Hotel (4, lobby 4.5:1). Hospital `shaft_high` was re-rolled once: the first take drew a dial with
  coloured zones and chip stacks (a load-gauge look-alike), so its prompt now forbids dials, gauges, buttons and chips.

**Open**
- No prompts left. Hotel mid was re-rolled once: the first take had a flat mustard wall, so its prompt now demands burgundy. The hotel lobby has a thin wall strip with chandelier bulbs along its top edge and six soft light pools: crop or cover the top 9% in the build.
- The coral side walls are bright (luminance about 0.33): cream labels such as NEXT would sit near 3:1. Build with a
  light dark wash over shaft walls (PRD v1.8, floor-colour/wall contrast test), not a re-roll.

## 2026-10-28 · PRD v1.8 "vibrant and fun" draft and colour-world art prep (branch prd-v18-vibrant)

**Done**
- `docs/PRD-v1.8-vibrant.md` (DRAFT): colour worlds, cabin floor rows plus cabin spots, combo and stars, VIP and
  hurry traits, pairs and families, daily challenge and golden lift. It also covers rule amendments (CLAUDE.md rules
  1, 2, 6, 8, 10), the debut schedule (rows/combo/stars L1, spots L22, VIP L24, pairs L31, hurry L35, golden L44,
  families L51, daily after L10, all free breathers today), economy (at most +25% coins/level), analytics and 5 open
  questions.
- 20 backdrop prompts in `tool/art/art_pack.json`: 3 shaft bands plus a lobby floor for office, hospital, mall and
  hotel, and a brighter Sunrise set (`bg_society_v2_*`). The hospital prompts forbid cross symbols.
- `tool/art/make_venue_board.py` writes `docs/art/venue-worlds/palette-board.png`, a palette mock per venue.
- Board finding, written into the PRD: the office (teal), hospital (mint) and mall (pink/violet) walls share hues
  with floor colours. Walls stay mid-tone and a little desaturated, chips keep outlines, and a 3:1 chip-vs-wall test is
  planned.

- Owner signed off the PRD and the board, and took the recommendations on the 5 open questions.
- Economy model `tool/economy_v18.dart`: the v1.8 extras add +55% coins per won level at the ×3 combo. With trip
  coins at green 6 / perfect 11 the total is +23%, inside the 25% cap; the PRD's rule 6 text now uses these numbers.

**Open**
- The economy numbers come from a skilled bot (an upper bound); the monetization-auditor reviews prices with the build.
- Owner generates the 20 backdrops during Gate A; they are processed into `docs/art/approved/` only, nothing shipped.
- Build waits for the Gate A result; slices are re-ranked by it.

## 2026-10-27 · Swap and Express icons in the dock (branch power-icons)

**Done**
- Owner's `icons_powers` sheet processed (`icon_swap.webp`: indigo trading arrows, `icon_express.webp`: gold bolt with
  speed streaks, 256 px, 15 + 13 KB). No green left in either, both read at 24 px, and the gold bolt is clearly not the
  blue express-lift badge. Approved into `docs/art/approved/` and shipped in `assets/art/`.
- `GameIcon.swap` and `GameIcon.express` (Material fallbacks `swap_horiz` and `bolt`); `PowerIcon` now draws all four
  powers through `ArtIcon`. The dock was checked in the release web build with stock and with none. New test in
  `surfaces_test` (images in the dock, Material when the switch is off). 457 green.
- The first image the owner sent was the lifts sheet again, not this one; it was not processed.

**Open**
- The Swap icon is two indigo arrows trading places and reads a little like a refresh icon. It is indigo, in the dock, and
  the pause menu's restart is the cream ring, so the two should not be confused; watch for it in Gate A.
- This is a visible change to the tester build: land it before inviting testers.

## 2026-10-27 · Gate A dry run with bots (branch gate-a-dryrun)

**Done**
- `test/gate_a_dry_run_test.dart`: three bots (careful, sloppy with crashes and an abandon, power buyer) play real
  generated levels 1-20 through `GameController` with the tester log on, export as a tester would, and
  `GateAReport` reads the files. Asserts the four gate rows, crashes and their fairness answers, heavy-types and
  unknown-people answers once per tester, empty-tap and use and buy counts for powers, no `Exception`, no "kg" in the
  export, no dropped events. It found no bug in the kit.
- Reading the printed report: levels 1-20 played through, the Hard rows (L10, L20) show up, the unassisted split reads,
  and a level the bots only started (21) shows a row with no decided first attempts, which is expected.

**Open**
- This checks the kit, not the game: the bots are scripted, so the report's rates mean nothing. Gate A needs people.
- Swap and Express icons still wait for the `icons_powers` image.

## 2026-10-27 · Gate A with powers on: the kit, and the Swap/Express icon sheet (branch gate-a-powers)

**Done**
- The tester build now logs power use for the report: `power_used`, `power_bought`, `power_refill_ad` (stub),
  `power_empty_tapped` join the kept events; `level_*` events already carried `powers_used`, `lanes`, `unknown_share`.
- New optional exit question (PRD v1.6 "Gate A"): "Did the unknown people in the queue feel fair?" (Fair / Unfair /
  Skip) on the first win from level 13 on a level with unknown people, never on the heavy-types win (`exit_unknown_fair`,
  `GameController.askUnknownFair`, `UnknownFairCard`).
- `tool/gate_a_report.dart`: Hard first-attempt win rate over every first attempt (the gate number, unchanged) and over
  first attempts that used no power; a Powers block (use by type, testers using, first level, coin buys, stub-ad refills,
  taps while empty); unknown-people fairness (no target of its own; read beside the crash number). Files from before the
  powers still read.
- Tests: `gate_a_test` +9 (question rules, skip, never on the heavy win, log keeps the power events, controller to log,
  report sums and an old file, the sheet). 456 total. `docs/gate-a.md` and `docs/analytics.md` updated.
- `icons_powers` added to `art_pack.json` (Swap: indigo trading arrows; Express: gold bolt, so it is not mistaken for
  the blue express-lift badge). Not generated: the owner makes the image by hand.

**Open**
- Gate A itself needs 10 to 15 people and is the owner's to run; nothing here measures it. The Pages build is the tester
  build (CI `--dart-define=TESTER=true`), which publishes from main when this merges.
- Swap and Express icon wiring waits for the image: add `GameIcon.swap` and `GameIcon.express` to the sprite table,
  use `ArtIcon` in `power_dock.dart`, ship the two files (the "assets/art holds exactly the table" tests must stay green).
- The art restyle shipped before Gate A (the owner's call), against the art pack's original "ship after Gate A" rule;
  the PRD addendum accepts that Gate A measures the restyle, the layout, unknown people and the powers together.

## 2026-10-26 · Wide-screen backdrop (branch wide-backdrop)

**Done**
- `widgets/wide_backdrop.dart`: `WideBackdrop` puts the cover art behind the Play screen on a two-pane layout (landscape
  window, tablet or phone on its side) or a tablet standing up, under a 40% navy scrim; phones standing up get the flat
  page and never load the image. Follows `useSpriteArt`, fades in (not under reduce-motion), flat page on load failure,
  `ExcludeSemantics` and `IgnorePointer`. Art in `assets/cover/` (outside the sprite table, not preloaded);
  `ArtAssets.coverArt`. Decoded at 1280 / 720 px wide.
- `test/wide_backdrop_test.dart` (9 tests); 447 green with the existing suite, analyze clean. Release web build checked in
  headless Chromium at 1280x720, 1700x900 and 820x1180.
- First pass at a 68% scrim hid the art; 40% reads and the labels keep their contrast on it.

**Open**
- Home keeps its own sky (its skyline is the progress map). Settings, store and result sheets sit above the backdrop.
- On a 1280x720 window the buildings fall behind the lanes panel, so the visible art is sky and a lawn silhouette; the
  skyline shows from about 1500 px wide and on tablets standing up.
- Phone-in-landscape (844x390) now decodes a 1280 px image (3.7 MB); not measured on a device.

## 2026-10-26 · Play feature graphic (branch play-graphic)

**Done**
- `tool/art/make_feature_graphic.py` builds `docs/store/feature_graphic_1024x500.png` (401 KB, RGB, no alpha) from the
  approved landscape cover: cropped to the Play aspect (top offset 110 of 1080), a soft night wash on the left, the app
  icon tile, "Lift Load" in Baloo 2 800 and the manifest tagline "Guess who fits. Mind the cable." in Nunito Sans.
  Deterministic; reruns from the approved files. The garbled hotel sign is illegible at this size.

**Open**
- This is a stopgap: it has no characters. The manifest's `store_key_art` (lobby, crowd squeezing into the lift) is the
  better store hero if the owner generates it; this script can take it as the background instead of the cover.
- Five phone screenshots, 1080x1920 RGB PNG (9:16), in `docs/store/screenshots/`: tap to board (L12), the green zone with the
  mint Send (L12), powers dock and unknown ghosts (L30), World 2 five lanes with pram and wheelchair (L77), home map.
  Taken from the release web build (`flutter build web --release --no-web-resources-cdn`) in headless Chromium at 450x800
  CSS px, 2.4x, sprite art on, with a seeded save (640 coins, powers stocked). No win screen: it needs a scripted full
  play-through. The 512 px Play icon is `web/icons/Icon-512.png`.
- Nothing is uploaded: publishing to Play Console needs the owner's explicit "proceed".

## 2026-10-26 · Boot splash from the cover art (branch splash-cover)

**Done**
- `web/index.html` boot splash is now the approved cover art, cover-cropped: portrait art on viewports taller than wide,
  landscape art on wide ones (`web/splash/portrait.webp`, `landscape.webp`, copies of `docs/art/approved/home_skyline_*`).
  The app icon bobs in the calm sky (top third in portrait, left half in landscape); both images are preloaded by
  media query. On `flutter-first-frame` the splash fades out over 350 ms and is removed; reduce-motion skips the bob
  and the fade.
- Checked in headless Chromium at 390x844, 1280x720 and 820x1180 with the Flutter bootstrap stubbed; the removal on
  first frame was confirmed. Not checked against a real Flutter boot (the build was not run for this change).

**Open**
- Splash adds 184 KB to the web build. The Android native splash comes with M3 and needs its own asset.
- Wide-screen backdrop and Play feature graphic from the cover art are still unbuilt.

## 2026-10-23 · App icon and cover art (branch art-icon-cover)

**Done**
- Owner sent the app icon, cover art portrait and cover art landscape. Processed with `gemini_art.py process`, approved
  into `docs/art/approved/` as `app_icon.webp` (1024), `home_skyline_portrait.webp` (1080x1920), `home_skyline_landscape.webp`
  (1920x1080), 44 + 91 + 92 KB. Not shipped in `assets/` yet.
- `_remove_sparkle` left a faint diamond outline on dark smooth art; it now refills the sparkle footprint from its ring
  when the ring is flat (std < 6), else keeps the exact un-blend. Checked contrast-stretched: no trace on all three.
- `make_icons.py` cuts the web icons (192/512, maskable, favicon) from the approved icon when it exists, PIL cabin is the
  fallback. The lift sits inside the middle 62% of the frame, so the full-bleed file is maskable-safe as is.

**Open**
- Cover art is not wired into the game. The Home skyline is a progress map (lit windows per level) and the cover art
  would not replace it; candidate uses are boot splash, tablet/wide backdrop, Play feature graphic (1024x500 crop of
  the landscape). Needs the owner's pick (a PRD note before building).
- The hotel tower sign in both covers carries garbled lettering ("TAGLOIDAT"); tiny at phone size, but a tell on a store
  graphic. Reroll or paint over before it goes on the store listing.
- Android launcher icons come with M3 (`android/` is generated then): foreground/background split from this icon.

## 2026-10-23 · PRD v1.7 polish pass, slice A: layout and clean-up (branch polish-layout)

**Done**
- The queue scrolls with touch, mouse drag, trackpad, stylus and wheel (`widgets/lane_scroller.dart`: `PlayScrollBehavior`,
  `LaneScroller`), soft bounce, a thin bar in the gutter and top and bottom edge fades while more lies that way. A drag
  never selects; a tap still does. `Metrics.visibleDepth` is untouched (3 to 5 drawn), so queue length still never shows.
- Lanes get 381 dp of 844 (45.1%) at 390x844, up from 301 (35.6%): the message line moved into a strip at the foot of
  the shaft panel (`LiftShaft.footer`), the cabin is 190 dp tall (same aspect), bench seats are one 64 dp height empty or
  full with the floor tag in the seat's corner, the bar is 80 dp, the HUD 48. The backdrop doorway is now centred on the
  cabin (`ShaftPainter.doorLoose`, side columns share the spare width) and the floor row repeats under the cabin.
- One gutter (`Metrics.gap`) from HUD to bar, panel radius 22, inner radius 14 (`Metrics.innerRadius`), HUD pills as tall
  as the round buttons, right group and settings at the right edge, Send as tall as a dock button, Scale as wide as the
  gauge plate.
- Floor shapes are gone (`FloorShape`, `floor_shape_painter.dart`): tags, NEXT chips and the display carry colour and
  the "2F" label. The cabin's floor pill is gone; the display above the cabin is the one indicator (labels lit in each
  floor's colour). The NEXT strip already started after the current lift (`upcomingLifts`), now asserted in a test.
- Tests: `polish_a_test` (scroll gestures, lane share and per-size no-regression table, shared edges, single indicator,
  no shapes, source guards). 357 green.

**Open**
- A lane-area share of 45% is only reached at 390x844 and taller phones; 320x568 gets 31% (up from 21%).
- Two-pane tablets still centre the shaft and bench with empty space above and below (as before).
- The scroll range is short by design (3 to 5 people per lane); the owner's open question on showing whole queues stands.
- Slice B (premium motion) not started.

## 2026-10-22 · PRD v1.7 restyle slice 4: Sunrise backdrops and punch (branch restyle-slice4)

**Done**
- Backdrops (Sunrise Towers only): `bg_society_shaft_{ground,mid,high}` and `bg_society_lobby` in `assets/art`, through
  `ArtAssets.shaftBackdrop` / `lobbyFloor` and `SpriteCache` (preloaded with the rest). `ShaftBand` picks the wall by
  storey in the 20-level building (`ShaftBand.firstStorey` = 1, 8, 15: 1-7 ground, 8-14 mid, 15-20 high; repeats past
  100 too). `ShaftPainter.placement` fits the wall so its doorway (`ArtAssets.shaftDoorway`) spans the cabin and its
  rail channels and meets the cabin's floor, then grows only as needed to cover the panel; a 40% deep side scrim
  (`LL.shaftScrim`) keeps the faded NEXT chips and Scale readable over lamps and city lights. Lobby floor: cover-fit and
  fixed in the lane area while the queues scroll over it (`LobbyFloor`); "Clear" uses `LL.lobbyArtInk` there (5.2:1 on
  every pixel; the venue ink only reaches 4.29:1). Painted walls and floors stay for other venues, switch off, or a
  failed image. The procedural `society_wall_*` / `society_floor_*` alternates are not shipped.
- Punch (`widgets/punch.dart`, timings in `PunchMotion`): cabin bump 140 ms after the doors shut (the only addition to
  the send, so +140 ms), score slam (`ScoreSlam`: "+15 / PERFECT LOAD!", "+8 / GOOD TRIP", "HALF-EMPTY TRIP") above the
  coin fly, coins from the cabin to the coin pill as the approved coin icon, and the pill pulses when they land
  (`Burst.onDone`); free seats breathe (`Breathe`) only while a lane resident is selected; the selected front or bench
  resident hops on a warm glow (`SelectedHop`, `HopGlow`). Rating via `GameController.sentRating`, coins via
  `takeReward`. Reduced motion: no bump, slam, coins or hop; the glows hold still.
- Tests: `backdrop_test` (bands, venues, placement, fixed floor, fallbacks, alternates not shipped), `punch_test`
  (slam text and coins per rating, none on a crash, coin fly only on good/perfect, bump order, finishSend once, breathe
  and hop only when selected, reduced motion), a punch sweep in `responsive_test` (14 sizes, 3/4/5 lanes, both hands,
  1.3x), an architecture guard on `punch.dart`. 308 green.

**Open**
- Web build 46.15 MB before, 46.29 MB after (+0.14 MB).
- Coin pill pulses but its number does not change until the level is won (trip coins bank on win, as before).
- The selected card's lift (3 units) now scales with the screen (`Metrics.selectedLift`) so lift plus hop fits
  `Metrics.laneTop` at 320 wide.

## 2026-10-22 · PRD v1.7 restyle slice 3: surfaces and icons (branch restyle-slice3)

**Done**
- 3D surface recipe from the style frame: `SurfaceStyle` (mint, brass, cream, plum, chip, seat, off, per floor) and
  `SurfaceDepth` in `theme.dart`, sizes in `Metrics.surface`, drawn by `widgets/glossy.dart` (`Glossy`,
  `GlossyButton`, `SendGlyphPainter`). Inset for buttons (whole box is the touch target), outset for tags, chips,
  seats and round buttons (layout unchanged). Press-down through `Pressable` (`pressable.dart`), still under
  reduce-motion. Disabled buttons turn flat slate.
- Applied: mint Send with the up arrow, dock, Scale, HUD (back, settings, level, trips, lives, coins), NEXT chips with a
  kind badge on the corner, floor tags and cabin pills, bench seats, fail/win/get-more sheet buttons, settings rows,
  home stats and Play. Cabin rim is the kind colour between two dark lines; gauge has a plate, dark bed, gloss line and
  a glow tied to the engine's zone (never the Scale ghost or the springing needle).
- Icons: 17 approved icons in `assets/art` through `ArtAssets.icon` / `kindIcon` / `scenarioIcon`, drawn by
  `widgets/art_icon.dart` with the Material fallback when the switch is off or an image fails. Floor badges are not
  shipped: on a floor-coloured tag they vanish, so tags keep the painted white glyph. Power cut not shipped.
- Tests: `surfaces_test` (icons decode and match the table, fallbacks, Send mint vs slate, press-down, face geometry,
  floor and seat surfaces, lock on a capped power, glow ignores the ghost); responsive sweep checks every glossy button
  and the back and settings targets on play, sheets and home. 271 green.

**Open**
- Web build 45.88 MB before, 46.15 MB after (+0.27 MB).
- Not in this slice: lane cards and lobby floor (slice 4), the Send ring pulse, a dark get-more sheet as in the layout
  frame (sheets stay cream), the empty dock badge still reads "0".
- The old-lift badge (a pocket watch) is the weakest icon at 22 dp.

## 2026-10-22 · PRD v1.7 restyle slice 2: cabins and doors (branch restyle-slice2)

**Done**
- `assets/art/`: the 4 cabin interiors and 8 door leaves (about 530 KB). `ArtAssets.cabinInterior` / `cabinDoor`,
  `SpriteCache.cabin(kind)` returns the three images only when all loaded; otherwise that kind keeps the painted cabin.
- `_Cabin` (`widgets/lift_shaft.dart`): art mode draws the interior cover-cropped to the full 196 x 214 cabin
  (`CabinArtPainter`), riders at `Metrics.cabinFeetLine`, a dim, the two leaves (`CabinLeavesPainter`, clipped, seam
  shadow fading as they open), then the floor pills, the kind badge and sign on dark plates. The normal lift's
  "MIND THE LOAD" and the drawn grille/floor are dropped in art mode. Painted fallback unchanged.
- `CabinMotion` (`motion.dart`) holds every cabin timing: close 420 ms ease-in-out with an 80 ms settle (leaves bounce
  back `Metrics.doorSettle`, 2 units, and meet again) as one curve, rise 500, drop-in 450, open 360, fall 1000;
  dim 12%. Send: close, rise, `finishSend`, drop in shut, open. Crash leaves the doors open.
- Tests: `cabin_doors_test` (assets per kind, leaf geometry, art per kind, close-then-rise-then-finishSend once,
  settle, reduced motion snaps, crash, switch off, one failed image); responsive sweep covers all four kinds. 258 green.

**Open**
- Web build 45.35 MB before, 45.88 MB after (+0.53 MB).
- The cabin rim is a plain kind-coloured border; the 3D rim from the style frame belongs to slice 3.

## 2026-10-22 · PRD v1.7 restyle slice 1: assets and sprite cast (branch restyle-slice1)

**Done**
- `assets/art/`: the 14 resident sprites, 3 cargo props and the ghost (about 480 KB). `lib/ui/art_assets.dart` holds
  the only paths (`ArtAssets`) and `SpriteCache` (loaded once in `main`, waits up to 3 s for the first frame).
- `ResidentFigure` draws `SpriteFigurePainter` (`painters/sprite_painter.dart`) when `Profile.useSpriteArt` (saved,
  default on, no UI) is on and the images loaded; `ResidentPainter` otherwise, or for a sprite that failed. Same box
  either way. Cargo sprites stand right-aligned in the painter's cargo strip (no resident sprite includes a prop).
  Contact shadow per sprite and per prop; feet on y 116 of 120. Ghost: one sprite, glow and 0.85 opacity in code.
- Figures +60% (`Metrics`: cabin 128, lane 86, bench 83), fitted to lane and seat width against the widest figure
  box (90 units), never below the v1.6 sizes. Seat height follows the bench figure. Cabin feet at 90% of its height.
- Tests: `sprite_art_test` (every asset decodes, sprite and shadow for every type and cargo, fallback, ghost size,
  feet line), the responsive sweep runs with sprites and checks fitted sizes, profile flag. 244 green.

**Open**
- Empty bench seats are now 105 dp tall at 390 wide; the lanes area shrinks accordingly (it scrolls).
- Web build 44.8 MB before, 45.3 MB after; CanvasKit alone is 37 MB, so the PRD's 25 MB web target is not met by the
  baseline either (it reads as an APK budget).

## 2026-10-22 · PRD v1.6 UI slice 1 (branch ui-powers-v16, stacked on engine-powers-v16)

**Done**
- Bottom bar (`widgets/play_bar.dart`): power dock on the left, Send on the right, mirrored when `profile.leftHanded`.
  `widgets/power_dock.dart`: one round button per unlocked power with a stock badge (0 reads empty), armed state for Swap,
  `PowerIcon` is the single sprite slot (Material icon placeholders). `widgets/power_sheets.dart`: get-more sheet with
  "Spend 150 coins" and an explicit "Watch an ad" naming its reward; one-line reasons when a button is off.
- Send left the shaft; Scale moved onto the gauge plate; Restart moved from the toolbar into the settings sheet (in a level
  only; confirm when it costs a life). Settings gained "Left-handed layout".
- Lanes: Swap targeting frames (mint = pickable, brass = picked); reveal pop plus a sparkle burst (`BurstKind.sparkle`),
  both off under reduce-motion. Lane keys are made on demand (they were fixed at 4, a latent crash on 5 lanes).
- Bench wraps into two even rows above five seats (the +2 seats power makes 6 to 7 routine).
- Controller: one message fix (a capped power said "needs two lanes"; now "Already used on this level").
- Tests: `power_dock_test`, responsive sweep with the dock at 3, 4 and 5 lanes, left-handed, sheets, 14 sizes.

**Open**
- Swap and Express icons, ghost art, glossy 3D restyle of the new buttons, Express has no walk animation (the person
  vanishes), audio cues per power and reveal, the empty badge shows "0" where the frame had "+".
- Landscape phones (twoPane under 700 high) drop the dock labels to keep the bar slim.

## 2026-10-22 · PRD v1.6 engine (branch engine-powers-v16, stacked on the art PR)

**Done**
- Signed off: powers (Swap L14, +2 seats L19, +1 trip L27, Express L29; stock 0; 150 coins or 1 ad), unknown
  residents from L11, 3 to 5 lanes from L16, no waiting count, power cut removed, left-handed bar.
- Engine and generator: `Power`, unknown and reveal (`visibleLanes`, `frontOf`), four powers with caps, Express
  re-routing a stranded lift, lane count and spread, liar boost from L45, +1 normal slack from L11.
- Services and controller: `RewardedPlacement.powerRefill` (6 a day inside the 12), Profile v2 (powers, `leftHanded`,
  v1 saves load with zero stock), controller power API (arm and pick for Swap, spend on success, coin buy, ad refill),
  analytics `power_used`, `power_empty_tapped`, `power_refill_ad`, `power_bought`, `powers_used`, `lanes`,
  `unknown_share` (docs/analytics.md).
- Tests: 190 green; new `powers_test`, `controller_powers_test`, `profile_test`, refill cap, and architecture guards
  (UI never reads `.queues` or `unknownIds`, never shows a waiting count).

**Open**
- No UI yet for the dock, Swap targeting, ghost art, reveal effect, mirrored bar, bench second row, settings switch,
  Restart in the pause menu. Powers are reachable only through `GameController`.
- Solver study not run: a bot spending one power per level, and an information-limited bot (it cannot see unknowns).
  Slack, unknown share, lane spread, caps and price are untuned until then.
- Art: Swap and Express icons, backdrops for office, hospital, mall, hotel.

**Review (two read-only reviewers, a fuzz run of 3600 games)**
- Fixed: a crash no longer reveals the person behind the rider (and the lane shows them unknown while the lift falls);
  Express is refused when it would jam the lobby; refills gated on unlock and phase; tolerant power parsing.
- Open for the owner: (a) 6 refill ads plus 3 life plus 1 chest leave 2 of 12 daily views for continues, so reserve
  the last 2 for fail sheets?; (b) unknown people's floors leak through the NEXT strip and the jam sheet's "+N seats";
  (c) +1 trip cannot rescue an out-of-trips fail because the fail sheet comes first (spend owned stock there, or hint
  at the last trip).

**Solver study (`dart run tool/blind_study.dart 11 100`, levels 11-100, real trip budgets)**
- Three bots: full-information (the shipped solver, clears all 90), a blind bot that digs only toward people it can
  see and explores otherwise, and the blind bot with one +1 trip and one +2 seats.
- Unknown share capped at 0.6: blind 53/90, with powers 69/90. Capped at 0.35: blind 69/90, with powers 81/90.
  Capped at 0.25: blind 74/90, with powers 82/90. Adopted 0.35 (`Formulas.unknownMax`).
- Caveat: the blind bot explores crudely (benches the front of the lane with most unknowns), so it fails early jams a
  person would avoid. Read the numbers as a ranking of settings, not a human clear rate. Gate A gives the real one.
- Not yet studied: Swap and Express use, lane spread, liar boost, the extra slack.

**Next**
1. Level-designer pass on the remaining knobs; adjust `Formulas`, regenerate the level table.
2. UI per docs/PRD-v1.6-powers.md; monetization-auditor and code-reviewer on the diff.
3. Gate A with powers on.

## 2026-10-22 · Gemini art pack (PRs #6, #7, #8 merged; handoff prep on branch ccr-445849fc-sjvxbg)

**Done**
- Tooling: `tool/art/art_pack.json` (style bible plus 53 prompts, now 49 after the doors left the pack), `gemini_art.py` (generate, prompts, process, sheet),
  a prompt page with copy buttons and a done-tracker (claude.ai artifact 9H2UEdWaxV8uhzUsKttGGo), and
  `docs/art/gemini-art-pack.md`. The owner has no API key: they make each image by hand in the Gemini app from the
  page and send it here for review.
- Review loop per image: key out the green, measure the face colour against the `ResidentLook` skin hex (tolerance
  about 25 per channel), compare torso and leg widths with the design weight order, and check the cut-out at 2x on the
  lobby and night colours.
- Keyer fixes found on real images: Gemini's backdrop is about (35, 183, 27), not #00FF00, so thresholds now come from
  the image border; a 4 px rim despill removes the green outline on pale clothes; the app's corner watermark is dropped
  as a small island; green bounce light on glossy greys (the wheelchair's metal came back teal) is neutralised.
- Every resident prompt now carries a skin tone and hex read from `ResidentLook`.

**Lifts and venues (second session)**
- Approved: `cabin_normal_interior` (style anchor for the other cabins), committed in `docs/art/approved/`. Steel and brass,
  no text, numbers or buttons, no weight cue. Gemini's sparkle watermark sat on the right jamb; scenes are not
  watermark-stripped by `process`, so it was filled by hand in the raw (original with the owner). Caveats: the image
  keeps an outer door frame and a strip of corridor floor, and two bright brass verticals on the back wall sit behind
  where residents stand. Crop in about 8% each side and 4% at the bottom at integration. The other three interior
  prompts now say "no outer door frame, no corridor floor" (this anchor was made before that wording).
- Integration gate: `python3 tool/art/compose_check.py <scene>` stands approved residents and cargo on a scene at game
  scale (cabin 196 x 214 units, so a 4:5 scene loses about 12% vertically). Run it before approving every cabin and
  venue. First run on the anchor: style, scale and colour hold. Fixed since: watermark replaced by the mirrored left corner (the
  scene is symmetric), feet line moved to 90% of the cabin height, and a contact-shadow spec prototyped in the script and
  written into the Integration section of the art doc (the painter itself is integration work, after Gate A).
- Decision: the seven remaining cabin assets are now 1:1 in `art_pack.json` (the anchor stays 4:5). The game cabin is
  196 x 214 units, so a square crops only the sides, which also trims any frame. The prompt page artifact (version 6) is updated to
  match. Each cabin's doors now attach their own interior as the reference (`reference` plus a doors-specific
  `reference_note` in `art_pack.json`); the other interiors take no reference so each kind keeps its own materials.
- Approved: `cabin_old_interior` (dark wood, bare bulb; deep-brown skin on dark wood is the weakest contrast, check the gym
  regular at integration) and `cabin_service_interior` (galvanised steel, quilted pad, side grab rails; wide dented
  metal surround, crop in about 8%). Sparkle watermark removed from all three (mirrored left corner). `compose_check`
  now trims the sides of a square scene instead of the top.
- Express interior: first take rejected (clear glass showing a second room, read as a corridor). Second take approved with the
  opaque-frosted-back-wall prompt: chrome, blue LED edge strip, dark floor, distinct from the three warm cabins. Watch
  the bright back panel: pale clothes (white shirt, light-blue hospital top, blanket) have the least contrast there;
  dim the panel about 15% at integration if it bites. All four interiors are approved; the doors are next.
- Doors: Gemini doors came back unusable (no independent leaves, no matching seam), and the doors must animate, so they
  are rendered in code by `tool/art/make_doors.py` as a left and right leaf per kind (432 x 944 px each, the right is
  the mirror), committed in `docs/art/approved/` (8 files, about 150 KB). The four Gemini door prompts were removed from
  `art_pack.json` and the prompt page. Closing-motion spec is in the art doc, Integration, "Doors". Not final art:
  this is a procedural look that matches each cabin's palette; the owner reviews it and can ask for a redo.
- Sunrise Towers (society) is drawn in code, not Gemini (owner's call): `tool/art/make_venues.py` makes five shaft walls
  (storey bands: levels 1-4, 5-8, 9-12, 13-16, 17-20) and three tileable lobby floors (tile, marble, wood), committed
  in `docs/art/approved/` (8 files, 150 KB). Floors pass a 4.3:1 contrast check against the lane ink; walls keep to the
  facade colour with detail only in the right band. Mock-ups in `art/review/venue_society_*.png`. Society cards removed
  from `art_pack.json` and the prompt page.
- Restyle (owner: "not looking good, make it Pixar-styled, punchy"; Gate A not started; reskin only; proceed with a style
  frame): the style frame is claude.ai artifact 6cNa4q66cj9FRUUKPfbA1z (source `docs/art/style-frame/index.html`, images
  from `docs/art/approved/`). It shows the same layout with glossy outlined 3D buttons, chips, tags, gauge and a Send
  that closes the doors and bursts coins, plus a toggle for larger figures. Finding: a figure box is 120 design units,
  so the game's 80 dp cabin figure makes the tallest resident 69 dp (32% of the cabin) and 47 dp in a lane; earlier
  `compose_check` composites were 1.5x too large (fixed; `--figure`). Recommendation to the owner: figures +60%, which
  is the one change beyond a reskin. Owner approved the direction and figures +60% (Gate A not started, reskin only). Production has started: icon set.
- Icon set DONE: four 3:2 sheets of six (`icons_hud`, `icons_floors`, `icons_results`, `icons_lifts`), all approved; 24 icons at
  256 px in `docs/art/approved/icon_*.webp`. `gemini_art.py` gained a sheet splitter (cuts on solid pixels, joins parts within
  about 12 px, drops ghosts), a colour-distance magenta keyer for the floor sheet (a hue test ate the plum badge), a `retint`
  (plum to #A066F5), and an exact Gemini-sparkle remover (`tool/art/sparkle_alpha.png`; the sparkle sits 120 px in from the
  bottom-right corner at every size, so the earlier hand patches on cabins and the star are no longer needed). Lift kinds read
  apart at a glance (pocket watch, toolbox, blue bolt on chrome).
- Backdrops (owner: backdrops first, then the spec): four Gemini prompts for Sunrise Towers, `bg_society_shaft_{ground,mid,high}`
  (3:2, centre third empty, detail in the side fifths, dark and calm) and `bg_society_lobby` (4:3, pale floor; `process` prints its
  lane-ink contrast). Review each on the real layout with `python3 tool/art/compose_screen.py --shaft .. --lobby ..`. Prompt
  page version 11. Result: the three shafts (ground, mid, high) are APPROVED and in `docs/art/approved/bg_society_shaft_*.webp`: calm empty
  recess behind the cabin, sconces/windows/plants at the sides, dark and low contrast, sparkle removed. On the real layout the
  NEXT chips (3-14% of the width) and the gauge and Send column (74-98%) cover most of the side bands, so the visible detail
  is the gap beside the cabin and the right band between the gauge plate and Send (y 29-60%); fine, it reads as atmosphere.
  The lobby floor was REJECTED: terracotta checkerboard (median luminance 0.42, lane-ink contrast 1.1:1), a plant in the corner
  under lane 4's text, strong perspective. Prompt rewritten (near top-down, one pale cream, nothing on it). `_remove_sparkle`
  now tries several strengths and keeps the smoothest patch (a dark ghost appeared on the dark shaft). Waiting on the new
  lobby image; the other venues follow once Sunrise looks right.
- Layout (owner: "improve the placement of the queue, lift, Send, boosters and lobby waiting slots, more natural and
  user friendly"): layout frame is claude.ai artifact H19rviJHr3VVSfCVd3J51f (source `docs/art/layout-frame/index.html`),
  as-built beside proposed, with thumb-reach and tap-order overlays. NOTE: my first style frame had the bench and queue
  swapped; the real order (play_screen.dart) is HUD, shaft, message, bench, lanes, toolbar, and lane fronts are at the TOP.
  Findings: Send is in the shaft's right column (about y 210-280 of 844, the hardest reach) while Scale and Restart own the
  easy bottom strip; Restart costs a life. Proposal: Send moves to a wide bottom-right button showing the rider count, Scale
  becomes a round booster beside it, Restart moves into the pause menu with a confirm, order stays lift, bench, queue; queue
  front big (+60%) with smaller, dimmer ones behind; bench becomes a bench (rail, taller seats); gauge takes the freed column
  and gets a rider count. Open: left-handed mirror, drag-to-board. Update: owner said no rider count, and wants power options in place of the Scale: swap queue, +2 waiting slots for
  the round (every power defaults to 2), +1 lift trip, and "send people by lift" (assumed: Express ride, deliver the selected
  resident straight to their floor with no seat or trip). Mocked as a four-button power dock plus a wide Send. Pushed back
  once: the Scale is the only thing that teaches weights (locked rule 9), so it stays but moves onto the gauge plate, where it
  previews the needle. THESE POWERS REOPEN docs/PRD.md (rule 9, jam and out-of-trips fails, solver and generator, prices and
  rewarded-ad rewards via ad_policy, monetization-auditor): no engine or lib/ work until the owner signs a PRD change.
  PRD change written: `docs/PRD-v1.6-powers.md` (DRAFT v2; PRD.md and CLAUDE.md are NOT yet edited, waiting for an explicit
  "signed off"). Owner's answers folded in: Express as defined; new powers start at 0 stock, bought with 500 coins (configurable)
  or 1 ad = 1 use; Gate A with powers ON; left-handed mirror now; Scale stays on the gauge; AND a new rule: the queue behind each
  lane front is hidden (identical dim silhouettes, no look, no floor tag, count only), lanes longer and more uneven with level.
  Flagged: this reopens locked rule 1, makes the power cut scenario redundant, raises difficulty (slack +1 until Gate A), and the
  500-coin price makes the 300-coin fail rescue the cheaper path. Layout frame updated (v3): silhouettes, empty powers with + and
  a get-more sheet, mirror toggle.
  v3 of the addendum (owner's second round): the queue is NOT always hidden. Early levels show everyone; from L11 a growing
  share behind the front are unknown ghosts (one identical glowing silhouette, revealed on reaching the front); lane count varies
  (3-5 from L16), lane spread and liar weight rise; the power cut scenario is REMOVED (rule 10 reworded); powers cost 150 coins
  (configurable) or 1 ad. New Gemini asset `unknown_ghost` (prompt on the prompt page, version 13). Unlock plan: unknown L11,
  lane variety L16, Swap L14, +2 seats L19, +1 trip L27, Express L29. Frame v5 shows ghosts, 5 lanes, 150-coin sheet.
  Addendum v3.1: owner said the waiting count must never be shown: "+N waiting" under each lane and the number in the rush hour
  banner are removed; a lane draws at most visibleDepth people (known or ghost), so nothing promises a length; widget test added.
  Frame v6 drops the counts. SIGNED OFF by the owner 2026-10-22 (lane count varies 3-5; all proposals accepted). Folded into docs/PRD.md (v1.6 section),
  CLAUDE.md (rules 1, 2, 9, 10 and architecture rules) and .claude/memory/decisions.md. NOTHING BUILT: engine step 2 of the plan
  (Formulas, LiftGame powers, unknown flags, lane count, Profile v2, ad_policy powerRefill, remove the power cut) is next, but this
  session's brief fences lib/ and assets/, so it needs the owner's go (or a new session). Old: two questions left (lane-count meaning, accept the curves/caps/unlocks). (Earlier recommendation of Gate A with powers off was overruled by the owner: on.)
  Icons still to make for Swap and Express (swap is an inline SVG in the mock; Express borrows the bolt). Waiting on the owner's
  verdict (this widens "reskin only"
  to include layout, which the owner has now asked for).
- APPROVED 2026-10-22: `unknown_ghost` (violet and blue glass figure, average build, ghost tail; keyed by colour distance with the green
  pulled back, 218 x 576 px, `docs/art/approved/unknown_ghost.webp`; opacity and glow are added in code) and `bg_society_lobby` (pale
  cream tile floor, soft light pool; `process` lifts only the too-dark pixels toward pale so lane ink clears 4.3:1; the first
  checkerboard take was rejected). Sunrise Towers art is complete: three shafts, lobby floor. Next art: the other four venues,
  `icons_powers` (Swap, Express).
- Next in the restyle, after the backdrops:  the integration spec for lib/ (figures +60%, contact
  shadows, door leaves, icons in place of Material icons, 3D button recipe, punch). No lib/ work until the owner says go.
- Next: decide whether office, hospital, mall and hotel get the same in-code treatment (recommended: yes, same script,
  each with its own palette and storey bands) or stay with Gemini.

**Handoff for a new session**
- The 17 approved processed sprites are committed in `docs/art/approved/` (about 0.5 MB, not shipped). Raw images stay
  with the owner; `/art/` is still git-ignored.
- `gemini_art.py review [--dir docs/art/approved]` now reproduces the per-image checks: face colour against the card's
  skin hex (limit 40, lit skin renders lighter), torso, leg and area widths, green-pixel counts, build order against
  the new `design_build` field in `art_pack.json` (the approved cast scores rho 0.87; the wheelchair shows 12 green
  pixels, the known rim), and 2x cream and night sheets in `art/review/`. The numbers assist the sheets, they do not
  replace looking.
- To resume: the owner sends the next images (lifts, venues, home, store, icon). Save each to `art/raw/<id>.png`, run
  `process` then `review`, and copy each approved sprite into `docs/art/approved/`. Scenes are cover-cropped by
  `process` but `review` only measures residents so far; check scenes on the sheet by eye.
- Prompt page: claude.ai artifact 9H2UEdWaxV8uhzUsKttGGo (copy buttons and the done-tracker).

**Cast status** (originals live with the owner; `/art/` is git-ignored)
- All 14 residents approved: schoolkid (style anchor), puffer teen, student, office woman, grandpa (second take),
  office man (second take), aunty, pram parent, rider (second take), gym regular (second take), guard, uncle,
  wheelchair patient, bellhop. In design weight order they read left to right as intended; the two deliberate liars
  mislead only as designed.
- Rider note: the second take reads about as heavy as the guard (wide jacket and legs, less belly) where the design has
  him a rank lighter. Accepted: Gate A tests the parametric cast, not this art. Re-check at integration against the
  Gate A overloads-by-type table.
- Cargo props approved: water can, suitcase, gas cylinder. They process at the painter's own heights (28.5, 36 and 39.5
  design units, 6 px per unit), so they sit in true proportion beside the residents.
- Still to make: four lift kinds (all done: interiors from Gemini, doors in code), four more venues (lobby floor and shaft wall; society is done in code), home skylines, store
  art, icon, and blink frames last (optional).

**Open**
- Art ships after Gate A only: the heavy-types metric measures the current silhouettes. Integration needs PRD v1.5.
- The guard's navy shirt and peaked cap read a little like a police officer; no insignia or text, so left alone.

**Next**
1. Owner makes and sends the lifts, venues and home art.
2. When everything is approved: blink frames, then PRD v1.5 (sprite-backed figures with the painter as
   fallback, raster cabins, flag, size budget) after the Gate A decision.
3. Gate A dry run and invites (see the v1.4 entry below).

## 2026-10-21 · v1.4 Gate A kit (branch ccr-445849fc-sjvxbg)

**Done**
- PRD v1.4 signed off: tester mode in the Pages build (`--dart-define=TESTER=true`), cap at L60, crash-fairness tap,
  heavy-types question after L15, on-device tester log with Send results (download or code), report tool.
- `attempt` on level events and `continues` on wins, in every build; profile stores attempts per level.
- `tool/gate_a_report.dart` prints the four gate metrics, per-level detail, overloads, mean fill and the free-text
  answers. `docs/gate-a.md` covers the invite, the observation script and the decision rules.
- Checked end to end in Chromium: tester build, Send results download, report on the file. 138 tests green.
- Also merged earlier today: PR #4 (polish review fixes: Android audio focus, music state, stale cabin sequences).

**Open**
- Who the 10–15 testers are (PRD open question) and when invites go out.
- Pacing from L32 on (72 residents, 24–33 trips) means most testers stop around L15–25; Hard data mostly L10/20/25.

**Next**
1. Done: the Gate A kit merged as PR #5, so Pages now carries the tester build.
2. Owner plays L1–5 on a phone and sends a results file as a dry run.
3. Send invites; collect files into an uncommitted `results/`; run the report; record the decision.

## 2026-10-21 · v1.3 polish pass (branch ccr-445849fc-sjvxbg, PR #3)

**Done**
- PRD v1.3 signed off in chat: responsive layout, art, motion, sound and music, landscape on tablets. No rule changes.
- Layout: `Metrics` sizes everything from the 390×844 design across compact phone, phone, tablet portrait and two-pane
  (tablet landscape, wide windows). Text scale clamped to 1.3; touch targets ≥ 48. The 320×568 overflow is gone.
- Art: Baloo 2 and Nunito Sans bundled; outlined cast with blinks; steel cabin with doors and floor display; venue
  shaft walls; gauge bezel and glow (still no ticks); home sky.
- Motion: one idle clock (off under reduce-motion), walk flights, lane step-ups, doors, crash shake and sparks, coin
  bursts, confetti. All fixed-duration per resident, so nothing reveals weight.
- Audio: 17 synthesized cues and five venue loops (`tool/audio/synth.py`), `AudioService` on audioplayers, settings
  sheet with sound, music and haptics, `setting_changed` analytics.
- Web shell committed: lift-cabin icons (`tool/icons/make_icons.py`), manifest, boot splash. Checked in Chromium at
  phone and tablet-landscape sizes; all cues load in under 2 s after the cue-loading fix.
- Tests: 111 green locally (responsive sweep of 14 sizes, motion, audio and settings).

**Open**
- Sound mix and music volume (0.35) are untested on a real phone speaker.
- Android launcher icon waits for M3 (`android/` still generated).
- Local `dart format` reflows three `lib/game` files to the repo's 120-column width; left unstaged, not in the PR.

**Next**
1. Owner plays the PR #3 web build on a phone and a tablet (rotate the tablet; toggle sound and music).
2. Merge PR #3, then Gate A with levels 1–60.
3. Queued depth from v1.2 (best-play solver, trap Hard levels, stars, cabin spots, pairs, hurry residents).

## 2026-10-21 · v1.2 variety pass (branch ccr-445849fc-sjvxbg)

**Done**
- PRD v1.2 signed off in chat: venues, five new types, cargo, World 2 lift kinds and scenarios. CLAUDE.md rules 2, 3,
  4, 7 amended, rule 10 added.
- Engine: per-trip capacity, express floors, coned-off lane, rush-hour arrivals, reachable-only routing (no
  soft-locks). Solver now plays through the engine.
- Generator: 100 levels, venue spawn weights, cargo, one debut per level with ≥ 3 sightings.
- UI: venue floors, walls and props; five new looks (seated wheelchair, pram, trolley), cargo props, power-cut
  shadow; lift-kind cabins and NEXT chips; cones and rush-hour banner; Home skyline map; building-complete banner.
- Tests: 50 green locally (Flutter 3.47.7): variety engine tests, generator 1–100, every venue × kind × scenario
  renders without overflow, shadow-width guard.

**Open**
- Art is parametric and checked only in test screenshots; needs a look on a real device.
- Tuning of World 2 (old lift share, scenario frequency) is untested with people.

**Next**
1. Play the PR web build at L13, L23, L43, L45, L61, L65, L67, L71, L77, L87.
2. Gate A with levels 1–60.
3. Queued depth: best-play solver, trap Hard levels, stars, cabin spots, pairs, hurry residents.

## Earlier

M1 scaffold (2026-10-21): concept canvas, PRD v1.1, pure-Dart engine, Flutter Home/Play/sheets, services, CI; 24 of 27 tests green on the first CI run, widget-test fixes followed.
