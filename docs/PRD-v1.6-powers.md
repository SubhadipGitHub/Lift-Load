# PRD addendum v1.6: Power options, hidden queue, left-handed bar

Status: DRAFT v2. The owner's answers of 2026-10-22 are folded in below. It still needs an explicit "signed off" before
docs/PRD.md and CLAUDE.md are edited and before any build. Date 2026-10-22. Owner: Subhadip.
This addendum reopens docs/PRD.md and the locked rules in CLAUDE.md: rule 1 (hidden queue), rule 9 (powers) and, by
interaction, rules 2, 6, 7, 8 and 10. Where it differs from docs/PRD.md, this document wins once signed off and merged.

## Problem

Today a player has one active aid, the Scale, plus rescues that only appear on the fail sheet. The owner wants more
agency and more reasons to spend coins or watch rewarded ads, and more difficulty that grows with the level, without
touching the core: guessing a stranger's weight from their look, then risking one more rider. Four powers are added
beside the Scale (Swap, +2 seats, +1 trip, Express), the queue behind each lane front is hidden, and the bottom bar can
be mirrored for left-handed play. The risk to manage is that powers become a way to skip the guess, and that hiding the
queue makes early levels harsh.

## What exists today (from the code)

- **Scale.** The player starts with 3 (`Formulas.startingScales`), buys more at 120 coins, and uses one to preview the
  selected resident as a dashed ghost needle (`LiftGame.previewScale`, `GameController.useScale`). The ad placement
  "before a Hard level" grants 2 free Scale uses. A Scale bundle is 15 for ₹199.
- **Rescues on the fail sheet.** Out of trips offers +2 trips (rewarded ad, or 300 coins), a lobby jam offers bench
  seats (same), a crash offers Repair. They appear after the failure.
- **Queue.** Each lane shows its first `visibleDepth` residents (3 on compact phones, 4 on phones), each with a look and
  a floor tag. Only the front is selectable. The World 2 "power cut" scenario already shadows depth 2 and beyond.
- **Engine hooks that fit.** The bench is a growable list, `tripsTotal` is mutable, and the lanes are plain lists.

## Success criteria

| Metric | Target | How measured |
| --- | --- | --- |
| Hard first-attempt win rate, attempts with no power used | 45–55% (unchanged; slack is retuned for the hidden queue) | `level_win` / `level_fail` split by `powers_used` |
| Hard first-attempt win rate, all attempts | no more than 20 points above the unassisted rate | same |
| Testers who clear levels 1–10 in one sitting | at least 70% (unchanged, with the queue hidden from level 1) | session log |
| Players who use at least one power by level 20 | at least 40% | `power_used` |
| Rewarded views per DAU | at least 2.5 (unchanged) | AdMob + Firebase |
| Crashes testers call unfair | at most 1 in 5 (unchanged) | exit question |
| Hidden people behind the front called unfair | at most 1 in 5 | new exit question |
| Weight leak | zero | architecture and widget tests |

If the all-attempts rate climbs more than 20 points above the unassisted one, the powers are too strong: cut stock,
raise prices or cap uses before launch. If fewer than 70% clear levels 1–10, raise `hiddenQueueFromLevel` (below).

## Scope

In: the four powers, their stock, unlock levels, prices and rewarded refill; the hidden queue and growing, uneven lane
lengths; the bottom power dock from the layout frame (claude.ai artifact H19rviJHr3VVSfCVd3J51f); a left-handed mirror
of the bottom bar; the Scale on the gauge plate; Restart in the pause menu; analytics; tests; a solver study.

Out: new currencies, powers that cost lives, timed or cooldown powers, drag-to-board, any power that changes capacity,
any power or UI that shows a number for weight.

## The powers

Stock is per player (`Profile`). **Every new power starts at 0** (owner's answer); the Scale keeps its 3. A power is
bought with coins or earned by watching one rewarded ad, one use each. It is spent only when its effect completes, so
cancelling a half-finished Swap spends nothing.

| Power | Effect | How it is used | Cap per level | Unlock |
| --- | --- | --- | --- | --- |
| Swap | Swaps the front residents of two lanes | Tap Swap, then two lanes. Not for an empty or coned-off lane | 2 | L11 |
| +2 seats | Adds two bench seats until the level ends | One tap | 1 | L14 |
| +1 trip | Adds one trip to this level's budget | One tap | 1 | L19 |
| Express | Delivers the selected resident straight to their floor, with no seat, no trip and no capacity used | Select a lane front or bench resident, tap Express | 1 | L29 |
| Scale | Unchanged: previews the selected resident on the gauge | Select, tap Scale | none | L1 |

Caps and unlock levels are proposals the owner has not objected to; they are configurable. Each unlock must land on a
breather and clear every existing debut (types 9, 17, 23, 26, 33, 41, 43, 45, 49, 63, 83, cargo 13, 21, 37, and the
World 2 kinds and scenarios). The level-designer fixes the exact numbers and `test/generator_test.dart` gets a check.

**Getting more.** Tapping a power with 0 left opens a small sheet: "Watch an ad" (1 use) or the coin price. Both are
configurable. The Express sheet and the dock are in the layout frame.

**Restart and the level end.** A restart resets every power effect (extra seats, extra trip) and does not refund spent
stock. Express counts as a delivery for the win condition. It scores nothing for the trip it skipped.

## Hidden queue

Everyone behind a lane's front is hidden. They appear as identical, same-sized dim silhouettes with no look and no floor
tag, they cannot be selected, and only a count says how many wait ("5 waiting"). Up to three silhouettes are drawn per
lane. When the front leaves, the next person steps up and is revealed. Bench residents are unchanged: seated residents
show who they are.

**Lanes grow and vary with the level.** The total already grows (N(L) = min(12 + round(1.5L), 72)). New: lane lengths
spread apart as levels rise, so lanes are uneven and the longest lane is a decision, not a chore. The generator takes
`queueSpread(level)` from `Formulas` (proposed: 0 below level 6, then up to ±3 residents around the lane average,
capped so no lane is empty at the start). The exact curve is tuned with the solver study.

**Consequences, stated plainly.**
- **Locked rule 1** becomes: "Four lanes of residents. Only each lane's front shows who it is and can be selected;
  everyone behind a front is hidden. Bench residents can be selected."
- **The power cut scenario loses its identity.** "Only the front is lit" is now every lobby. The scenario needs a new
  meaning to stay a World 2 variety: recommendation, power cut also hides the floor tag of bench residents until they
  are tapped. This is an open question below.
- **Difficulty rises everywhere.** The solver's par, and so the trip slack, assumed the bot sees the whole queue and a
  human can plan the same way. With the queue hidden a human wastes more trips, so win rates fall. The slack stays in
  `Formulas` and is raised by 1 on normal levels until Gate A data says otherwise.
- **Fairness.** Jams and out-of-trips fails will rise. The seats and trip powers are the player's answer, and the
  exit question above measures whether hidden people feel unfair.
- **Early levels.** The owner's call is to hide the queue from level 1. A constant `hiddenQueueFromLevel` (default 1)
  makes that one line to change if the clear-rate metric misses.
- **Rule 10 holds.** Lift kinds and the lobby scenario stay visible in advance.
- **The solver study** gains an information-limited bot that sees only fronts and the bench, to estimate the human win
  rate. The full-information bot still sets par.

## Left-handed bottom bar

A "Left-handed" switch in the settings sheet, saved in the profile, default off. It mirrors the bottom bar only: Send
moves to the left edge and the four powers to its right. Nothing else on the screen moves. On two-pane tablet layouts
the bar follows the same switch.

## Rules this changes

Locked rule 1 as above. Locked rule 9 becomes: "No Undo (it would reveal weights). The Scale previews one resident as
a dashed ghost needle. Swap, +2 seats, +1 trip and Express change the lobby, never reveal a weight." Rule 2 gains an
exception: Express delivers a resident without boarding the lift. Rule 6 is unchanged, but +1 trip raises the budget it
draws on. Rule 8 is unchanged: the fails still apply, they are only delayed. Rule 10 is unchanged. The architecture
rules hold: every number lives in `Formulas`, rewarded rewards are granted only when the SDK reports the reward earned,
and `lib/ui` and `lib/services` never read `.kg`.

## Economy (configurable)

| Setting | Default | Notes |
| --- | --- | --- |
| Coin price of each power | 500 | One value per power in `Formulas`, ready for Firebase Remote Config at M3 |
| Ad uses per rewarded view | 1 | |
| `powerRefill` daily cap | 6 | Inside the existing total of 12 rewarded views a day |
| Starting coins | 300 | Unchanged, so no power is affordable at the start; ads are the first path |
| Scale price | 120 | Unchanged |

A level pays about 50–100 coins, so a 500-coin power is five to ten levels of play. The placement "before a Hard level"
(2 free Scale uses) is unchanged. IAP: the Scale bundle stays; a Powers bundle (6 of each new power) is proposed at ₹249
for Gate B testing. Interstitial rules are untouched, and a payer who removed ads still gets rewarded refills.

**A pricing conflict to decide.** At 500 coins for +1 trip, the fail-sheet rescue (+2 trips for 300 coins) is cheaper
than the pre-emptive power, so a rational player waits to fail. The same holds for seats. Options: set the rescue price
to match (500), or the power prices lower (about 150 to 300). The defaults follow the owner's 500; both are one-line
changes, and the solver study will show which keeps the economy healthy.

## Engine, services and UI changes

- `Formulas`: unlock levels, per-power prices, ad uses, caps, the seat count, `queueSpread`, `hiddenQueueFromLevel` and
  the extra normal-level slack.
- `LiftGame` (lib/game/engine.dart): `swapFronts(laneA, laneB)`, `addSeats(n)`, `addTrip()`, `expressDeliver()`, each
  returning a bool, emitting a new event and recording per-level use so caps hold. The queue exposes only the front's
  identity plus a count to the UI. Pure Dart, no Flutter import.
- Generator: uneven lane lengths from `queueSpread`; every level still proven solvable by the solver.
- `Profile`: a stock map for the four powers (0 each) and `leftHanded`, saved as profile version 2 with a migration.
  `ad_policy.dart` gains `powerRefill`.
- `GameController`: `usePower(power)`, a Swap targeting mode, the get-more sheet, analytics.
- UI: the power dock, the Scale on the gauge plate, silhouettes and counts in the lanes, a second bench row when seats
  exceed five, the settings switch, Restart in the pause menu. Figures grow 60%. Icons for Swap and Express still need
  art (a Gemini sheet, `icons_powers`).
- Audio and feedback: a short distinct cue per power; none may vary with any resident's weight.

## Gate A

The owner's call is to run Gate A with the powers on. Starting stock is 0 and starting coins are 300, so powers will be
rare in levels 1–10 and mostly earned through ads. What this requires:
- A `powersEnabled` constant stays, so the powers can be turned off if the data is muddy.
- In tester mode the ads service is a stub, so "Watch an ad" grants one use after a short fake ad, with the daily cap
  of 12 still applied, and the log marks it `stub`.
- `level_win`, `level_fail` and `level_abandon` gain `powers_used`. `tool/gate_a_report.dart` reports the Hard-level
  first-attempt win rate unassisted and all-attempts, power use by type, and the hidden-queue fairness answers.
- A new optional exit question in tester mode: "Did the hidden people behind the front feel fair?"

**Risk to accept knowingly.** Gate A now measures the restyle, the new layout, the hidden queue and the powers at the
same time. If a metric misses, the cause cannot be separated. The build tag and `powers_used` help, and the two
constants (`powersEnabled`, `hiddenQueueFromLevel`) are the levers for a follow-up run.

## Analytics

New events: `power_used` (`power`, `level`, `left`), `power_empty_tapped`, `power_refill_ad`, `power_bought`
(`power`, `coins`), `left_handed_set`. `level_win`, `level_fail` and `level_abandon` gain `powers_used` (a count).
docs/analytics.md is updated with the build.

## Tests and the solver study

- Engine tests per power: valid and invalid use (empty or coned-off lane, no selection, cap reached), state after, the
  event, restart reset, and a win reached with Express.
- Queue tests: the UI-facing queue never exposes a hidden resident's type, cargo or floor; spread is within bounds and
  every generated level stays solvable.
- Profile migration test (a v1 save gains 0 of each power and `leftHanded` false); ad policy test for `powerRefill`,
  its cap and the daily total.
- Architecture test: no `.kg` or "kg" in the power UI; the dock shows counts only.
- Widget tests: 48 dp targets, no overflow from 320 × 568 up, the Swap targeting flow, the mirrored bar.
- Solver study before any UI: a bot that spends one power per level, and the information-limited bot, each reporting win
  rate per level band. `Formulas.trips` and `Formulas.bench` still come from the full-information par.
- `dart run tool/simulate.dart` and the level table are regenerated and compared; `test/generator_test.dart` stays green.

## Plan

1. Sign-off on this addendum.
2. Engine, `Formulas`, `Profile`, generator and `ad_policy` changes with their tests, no UI.
3. Solver study; tune slack, spread, stock caps and prices from it.
4. UI: dock, Swap targeting, hidden queue, mirrored bar, bench row, settings, Restart in the menu, icons, audio.
5. monetization-auditor and code-reviewer pass on the diff.
6. Gate A with powers on, then Gate B.

## Open questions

- Power cut: redefine it (recommendation: it also hides bench floor tags until tapped), or retire it for another
  World 2 scenario?
- Pricing conflict: the rescue at 300 coins against powers at 500. Raise the rescue to 500, or lower the powers?
- Hidden from level 1, or from a later level? (Default is level 1, as asked; the clear-rate metric is the check.)
- `queueSpread` curve and the extra normal-level slack: accept the proposals, to be tuned by the solver study?
- Caps per level and unlock levels: accept the proposals above?
