# Progress log

Update at the end of every session and before switching domains (skill: `session-checkpoint`). Keep the last five
entries; fold older ones into "Earlier".

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
- Next in the restyle: painted Gemini backdrops (lobby and shaft), then the integration spec for lib/ (figures +60%, contact
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

## 2026-10-21 · M1 scaffold

**Done**
- Concept canvas (style guide, asset sheet, interactive Play slice, logic) and PRD v1.1 signed off with Flutter.
- Pure-Dart engine: cast with hidden weights, formulas, state machine with events, greedy solver, seeded generator.
- Flutter UI: Home, Play (cabin send and crash animations, springy gauge, bench, lanes), Fail and Win sheets.
- Services: ad policy (interstitial gating, rewarded caps), stub ads, debug analytics, profile save, haptics.
- Tests: engine, generator (levels 1–60 solvable), ad policy, play-screen widget, architecture guards.
- CI: analyze, test, level table, web build artifact.

**Verified in CI**
- `flutter analyze` clean on the first run (code was written without a local Flutter SDK).
- 24 of 27 tests pass: engine, generator (levels 1–60 solvable), ad policy, architecture.
- The 3 widget tests failed: HUD row overflow under the test font (fixed: trips label ellipsizes) and a fake-time
  hang on the stub ad's zero-length timer (fixed: no timer for a zero delay).

**Next**
1. Get CI green; commit `android/` and `web/` from `flutter create`.
2. Play the browser build; tune feel (needle spring, cabin timings, lane depth).
3. M2: tester build to 10–15 people, level table review, onboarding tips on type debuts.

## Earlier

Nothing yet.
