# Progress log

Update at the end of every session and before switching domains (skill: `session-checkpoint`). Keep the last five
entries; fold older ones into "Earlier".

## 2026-10-21 · M1 scaffold

**Done**
- Concept canvas (style guide, asset sheet, interactive Play slice, logic) and PRD v1.1 signed off with Flutter.
- Pure-Dart engine: cast with hidden weights, formulas, state machine with events, greedy solver, seeded generator.
- Flutter UI: Home, Play (cabin send and crash animations, springy gauge, bench, lanes), Fail and Win sheets.
- Services: ad policy (interstitial gating, rewarded caps), stub ads, debug analytics, profile save, haptics.
- Tests: engine, generator (levels 1–60 solvable), ad policy, play-screen widget, architecture guards.
- CI: analyze, test, level table, web build artifact.

**Not verified yet**
- The code was written without a Flutter SDK (blocked in the authoring workspace). First CI run is the first
  compile. Expect small fixes.

**Next**
1. Get CI green; commit `android/` and `web/` from `flutter create`.
2. Play the browser build; tune feel (needle spring, cabin timings, lane depth).
3. M2: tester build to 10–15 people, level table review, onboarding tips on type debuts.

## Earlier

Nothing yet.
