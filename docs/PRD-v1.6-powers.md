# PRD addendum v1.6: Power options

Status: DRAFT, waiting for the owner's sign-off. Nothing here is built. Date 2026-10-22. Owner: Subhadip.
This addendum reopens docs/PRD.md and the locked rules in CLAUDE.md (rule 9 directly, rules 2, 6 and 8 by interaction).
Read with docs/PRD.md; where they differ, this document wins once it is signed off and merged into the PRD.

## Problem

Today a player has one active aid, the Scale, and a set of rescues that only appear on the fail sheet (Repair, +2 trips,
extra seats). The owner wants more agency during a level, and a stronger reason to spend coins and watch rewarded ads,
without touching the core: guessing a stranger's weight from their look, then risking one more rider. Four powers are
proposed beside the Scale: Swap, +2 seats, +1 trip and Express. The risk to manage is that powers become a way to skip
the guess, which would hollow out the one thing the MVP exists to prove.

## What exists today (from the code)

- **Scale.** The player starts with 3 (`Formulas.startingScales`), buys more at 120 coins, and uses one to preview the
  selected resident as a dashed ghost needle (`LiftGame.previewScale`, `GameController.useScale`). The ad placement
  "before a Hard level" grants 2 free Scale uses. A Scale bundle is 15 for ₹199.
- **Rescues on the fail sheet.** Out of trips offers +2 trips (rewarded ad, or 300 coins), a lobby jam offers bench
  seats (same), a crash offers Repair. These are not powers: they appear after the failure and cost an ad or 300 coins.
- **Engine hooks that already fit.** The bench is a growable list, `tripsTotal` is mutable, and the lanes are plain
  lists, so none of the four powers needs a new data structure.

## Success criteria

| Metric | Target | How measured |
| --- | --- | --- |
| Hard first-attempt win rate, attempts with no power used | 45–55% (unchanged) | `level_win` / `level_fail` split by `powers_used` |
| Hard first-attempt win rate, all attempts | no more than 20 points above the unassisted rate | same |
| Players who use at least one power by level 20 | at least 40% | `power_used` |
| Rewarded views per DAU | at least 2.5 (unchanged) | AdMob + Firebase |
| Crashes testers call unfair | at most 1 in 5 (unchanged) | exit question |
| Weight leak | zero | architecture and widget tests (below) |

If the all-attempts rate climbs more than 20 points above the unassisted one, the powers are too strong: cut stock, raise
prices or cap uses per level before launch.

## Scope

In: the four powers, their stock, unlock levels, shop prices, the rewarded refill, analytics, tests, a solver study, and
the bottom power dock from the layout frame (claude.ai artifact H19rviJHr3VVSfCVd3J51f). The Scale stays and moves onto
the gauge plate. Restart moves into the pause menu behind the gear, with the existing confirm and life rule.

Out: new currencies, power-ups that cost lives, timed or cooldown powers, drag-to-board, any power that changes
capacity, any power that shows a number for weight.

## The powers

Stock is per player (`Profile`), not per level. Every new power starts at 2 ("by default 2"); the Scale keeps its 3.
A power is spent only when its effect completes. Cancelling a half-finished Swap spends nothing.

| Power | Effect | How it is used | Cap per level | Unlock |
| --- | --- | --- | --- | --- |
| Swap | Swaps the front residents of two lanes | Tap Swap, then two lanes. Not for an empty or coned-off lane | 2 | L11 |
| +2 seats | Adds two bench seats until the level ends | One tap | 1 | L14 |
| +1 trip | Adds one trip to this level's budget | One tap | 1 | L19 |
| Express | Delivers the selected resident straight to their floor, with no seat, no trip and no capacity used | Select a lane front or bench resident, tap Express | 1 | L29 |
| Scale | Unchanged: previews the selected resident on the gauge | Select, tap Scale | none | L1 |

Unlock levels are proposals. Each must land on a breather and clear every existing debut (types 9, 17, 23, 26, 33, 41,
43, 45, 49, 63, 83, cargo 13, 21, 37, and the World 2 kinds and scenarios), so they teach on an easy level. The
level-designer fixes the exact numbers and `test/generator_test.dart` gets a check for them.

**Restart and the level end.** A restart resets every power effect (the extra seats, the extra trip) and does not refund
spent stock. Express counts as a delivery for the win condition, so a level can be won with a resident delivered by
Express. It scores nothing for the trip it skipped.

**Interaction with the fail-sheet rescues.** They stay as they are, and they stay the paid, post-failure path. The
in-level +1 trip is deliberately cheaper per trip than the 300-coin rescue (150 coins for 1 trip, against 300 for 2), so
a player who plans ahead is rewarded over one who waits to fail. When a power's stock is 0 and it is tapped, a small
sheet offers one rewarded ad for 1 use, or the coin price.

## Rules this changes

Locked rule 9 becomes: "No Undo (it would reveal weights). The Scale previews one resident as a dashed ghost needle.
Swap, +2 seats, +1 trip and Express change the lobby, never reveal a weight." Rule 2 gains an exception: Express delivers
a resident without boarding the lift. Rule 6 is unchanged, but +1 trip raises the budget it draws on. Rule 8 is
unchanged: the fails still apply, they are only delayed. Rule 1 is unchanged: Swap acts on lane fronts, and only fronts
and bench residents can be selected. The architecture rules hold: every number lives in `Formulas`, rewarded rewards
are granted only when the SDK reports the reward earned, and `lib/ui` and `lib/services` never read `.kg`.

## Economy (proposed, to be tuned with the simulation)

| Item | Coin price | Notes |
| --- | --- | --- |
| Swap | 100 | |
| +2 seats | 120 | |
| +1 trip | 150 | half the per-trip price of the 300-coin rescue |
| Express | 200 | the strongest power, priced as such |
| Scale | 120 | unchanged |

A level pays about 50–100 coins, so a power costs one to three levels of play. Rewarded ads: the placement "before a
Hard level" changes from "2 free Scale uses" to "2 free uses of one power of the player's choice, from Scale, Swap and
+1 trip" (Express and +2 seats are left out, so the strongest ones are never free). A new placement `powerRefill`
gives 1 use of the empty power, capped at 3 a day, inside the existing total of 12 rewarded views a day.
IAP: the Scale bundle stays; a Powers bundle (6 of each new power) is proposed at ₹249 for Gate B testing. Interstitial
rules are untouched, and a payer who removed ads sees no interstitial and still gets rewarded refills.

## Engine, services and UI changes

- `Formulas`: the unlock levels, prices, starting stock, per-level caps and the seat count (+2).
- `LiftGame` (lib/game/engine.dart): `swapFronts(laneA, laneB)`, `addSeats(n)`, `addTrip()`, `expressDeliver()`, each
  returning a bool, emitting a new event (`SwapEvent`, `SeatsAddedEvent`, `TripAddedEvent`, `ExpressEvent`) and
  recording per-level use so caps hold. Pure Dart, no Flutter import.
- `Profile`: a stock map for the four powers, saved as profile version 2 with a migration that gives existing saves 2
  of each. `ad_policy.dart` gains `powerRefill`.
- `GameController`: `usePower(power)`, a Swap targeting mode (tap Swap, then two lanes; tap Swap again to cancel),
  analytics, messages and the stock-empty sheet.
- UI: the power dock (four 54 px round buttons with count badges, then Send), the Scale on the gauge plate, a second
  bench row when seats exceed five, Restart in the pause menu. Figures grow 60% as already agreed. Icons: Swap and
  Express still need art (a Gemini sheet, `icons_powers`).
- Audio and feedback: a short distinct cue per power; none may vary with any resident's weight.

## Gate A

Gate A has not started. Its Hard-level metric (45–55% first-attempt win rate) was set for a game with only the Scale and
the fail-sheet rescues, and free powers would push it up and cloud it. Recommendation: build the powers behind a
`powersEnabled` constant, run Gate A with them off (the Scale stays), and turn them on for Gate B with the split metrics
above. The restyle and the new layout can ship in the Gate A build, with the dock showing the Scale only. The
alternative, running Gate A with powers on, needs `gate_a_report.dart` to split attempts by `powers_used` and a longer
test, and it measures a game that has not been tuned yet.

## Analytics

New events: `power_used` (`power`, `level`, `left`), `power_empty_tapped`, `power_refill_ad`, `power_bought`
(`power`, `coins`). `level_win`, `level_fail` and `level_abandon` gain `powers_used` (a count). docs/analytics.md is
updated with the build.

## Tests and the solver study

- Engine tests per power: valid and invalid use (empty or coned-off lane, no selection, cap reached), state after, the
  event, restart reset, and a win reached with Express.
- Profile migration test (a v1 save gains 2 of each); ad policy test for `powerRefill` and the daily total.
- Architecture test: no `.kg` or "kg" in the power UI, and the dock shows counts only.
- Widget tests: 48 dp targets, no overflow from 320 × 568 up, the Swap targeting flow.
- Solver study before any UI: extend the greedy bot to spend one power per level and report, per level band, the win
  rate with and without it. The bench and trip budgets that `Formulas.trips` and `Formulas.bench` compute from the
  solver's par do not change.
- `dart run tool/simulate.dart` and the level table are regenerated and compared; `test/generator_test.dart` stays green.

## Plan

1. Sign-off on this addendum (and on the open questions below).
2. Engine, `Formulas`, `Profile` and `ad_policy` changes with their tests, no UI.
3. Solver study; tune stock, prices and caps from it.
4. UI: the dock, Swap targeting, the bench row, Restart in the menu, icons, audio.
5. monetization-auditor and code-reviewer pass on the diff.
6. Gate A with powers off; Gate B with powers on.

## Open questions

- Express: is "deliver the selected resident straight to their floor" what you meant by "send people by lift"?
- "By default 2": is that the starting stock of each power (assumed), the +2 seats, or a per-level allowance?
- Caps per level (Swap 2, the others 1): too tight, too loose?
- Unlock levels and prices above: confirm or change.
- Gate A with powers off (recommended), or on?
- A left-handed option that mirrors the bottom bar: include now or later?
- Should the Scale stay on the gauge plate, or does it come out entirely? The recommendation is to keep it: it is the only
  thing that teaches weights.
