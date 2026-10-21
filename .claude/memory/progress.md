# Progress log

Update at the end of every session and before switching domains (skill: `session-checkpoint`). Keep the last five
entries; fold older ones into "Earlier".

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
