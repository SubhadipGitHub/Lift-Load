# Progress log

Update at the end of every session and before switching domains (skill: `session-checkpoint`). Keep the last five
entries; fold older ones into "Earlier".

## 2026-10-22 · Gemini art pack (PRs #6, #7, #8, merged)

**Done**
- Tooling: `tool/art/art_pack.json` (style bible plus 53 prompts), `gemini_art.py` (generate, prompts, process, sheet),
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

**Cast status** (originals live with the owner; `/art/` is git-ignored)
- Approved: schoolkid (style anchor), gym regular (second take), uncle, puffer teen, aunty, office woman, guard,
  wheelchair patient, bellhop, parent with the pram, student (11 of 14 residents).
- Redo, prompts already tightened on main: grandpa (no belly), office man (sturdier adult), rider (sturdier).
- All 14 residents have been sent once. Still to make: the 3 redos, then 3 cargo props, four lift kinds (interior and
  doors), five venues (lobby floor and shaft wall), home skylines, store art, icon, and blink frames last (optional).

**Open**
- Art ships after Gate A only: the heavy-types metric measures the current silhouettes. Integration needs PRD v1.5.
- The guard's navy shirt and peaked cap read a little like a police officer; no insignia or text, so left alone.

**Next**
1. Owner redoes the grandpa, office man and rider, and sends the student and the three vehicle residents.
2. When all 14 are approved: props, blink frames, scenes, then PRD v1.5 (sprite-backed figures with the painter as
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
