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
