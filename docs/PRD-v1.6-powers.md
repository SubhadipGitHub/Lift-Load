# PRD addendum v1.6: Power options, unknown residents, lane variety, left-handed bar

Status: DRAFT v3.1. The owner's comments of 2026-10-22 are folded in, including "no waiting count". It still needs an explicit "signed off" before
docs/PRD.md and CLAUDE.md are edited and before any build. Date 2026-10-22. Owner: Subhadip.
This addendum reopens docs/PRD.md and the locked rules in CLAUDE.md: rule 1 (unknown residents and lane count), rule 9
(powers), rule 10 (the power cut scenario is removed) and, by interaction, rules 2, 6, 7 and 8. Where it differs from
docs/PRD.md, this document wins once signed off and merged.

## Problem

Today a player has one active aid, the Scale, plus rescues that only appear on the fail sheet, and difficulty rises only
through floors, residents and trip slack. The owner wants more agency and more reasons to spend coins or watch rewarded
ads, and more ways for difficulty to grow with the level, without touching the core: guessing a stranger's weight from
their look, then risking one more rider. Four powers are added beside the Scale (Swap, +2 seats, +1 trip, Express). As
levels rise, some people in the queue are unknown until they reach the front, lane counts vary, and liars get more
common. The bottom bar can be mirrored for left-handed play. The risk is that powers become a way to skip the guess, and
that unknown people make levels feel unfair.

## What exists today (from the code)

- **Scale.** The player starts with 3 (`Formulas.startingScales`), buys more at 120 coins, and uses one to preview the
  selected resident as a dashed ghost needle (`LiftGame.previewScale`, `GameController.useScale`). The ad placement
  "before a Hard level" grants 2 free Scale uses. A Scale bundle is 15 for ₹199.
- **Rescues on the fail sheet.** Out of trips offers +2 trips (rewarded ad, or 300 coins), a lobby jam offers bench
  seats (same), a crash offers Repair.
- **Queue.** Four lanes. Each shows its first `visibleDepth` residents (3 on compact phones, 4 on phones) with look and
  floor tag. Only the front is selectable. The World 2 "power cut" scenario shadows depth 2 and beyond; it is removed
  by this addendum.
- **A waiting count.** Each lane prints "+N waiting" under its visible people (`lobby.dart`), and the rush hour banner
  prints "+N arriving after trip M". Both are removed by this addendum (see "No waiting count").
- **Liars.** The puffer-jacket teen (looks heavy, is light, unlocks L45) and the gym regular (looks light, is heavy,
  unlocks L49).
- **Engine hooks that fit.** The bench is a growable list, `tripsTotal` is mutable, the lanes are plain lists.

## Success criteria

| Metric | Target | How measured |
| --- | --- | --- |
| Hard first-attempt win rate, attempts with no power used | 45–55% (unchanged) | `level_win` / `level_fail` split by `powers_used` |
| Hard first-attempt win rate, all attempts | no more than 20 points above the unassisted rate | same |
| Testers who clear levels 1–10 in one sitting | at least 70% (unchanged; unknown people start at level 11) | session log |
| Players who use at least one power by level 20 | at least 40% | `power_used` |
| Rewarded views per DAU | at least 2.5 (unchanged) | AdMob + Firebase |
| Crashes testers call unfair | at most 1 in 5 (unchanged) | exit question |
| Unknown people called unfair | at most 1 in 5 | new exit question |
| Any number of people waiting shown to the player | none | widget test |
| Weight leak | zero | architecture and widget tests |

If the all-attempts rate climbs more than 20 points above the unassisted one, the powers are too strong: cut stock,
raise prices or cap uses. If unknown people are called unfair, lower the unknown share curve or raise its start level.

## Scope

In: the four powers, their stock, unlock levels, prices and rewarded refill; unknown residents with a ghost asset;
variable lane count; more liars; removing the power cut scenario; the bottom power dock from the layout frame
(claude.ai artifact H19rviJHr3VVSfCVd3J51f); a left-handed mirror of the bottom bar; the Scale on the gauge plate;
Restart in the pause menu; analytics; tests; a solver study.

Out: new currencies, powers that cost lives, timed or cooldown powers, drag-to-board, any power that changes capacity,
any power or UI that shows a number for weight.

## The powers

Stock is per player (`Profile`). **Every new power starts at 0**; the Scale keeps its 3. A power is bought with coins or
earned by watching one rewarded ad, one use each. It is spent only when its effect completes, so cancelling a
half-finished Swap spends nothing.

| Power | Effect | How it is used | Cap per level | Unlock |
| --- | --- | --- | --- | --- |
| Swap | Swaps the front residents of two lanes | Tap Swap, then two lanes. Not for an empty or coned-off lane | 2 | L14 |
| +2 seats | Adds two bench seats until the level ends | One tap | 1 | L19 |
| +1 trip | Adds one trip to this level's budget | One tap | 1 | L27 |
| Express | Delivers the selected resident straight to their floor, with no seat, no trip and no capacity used | Select a lane front or bench resident, tap Express | 1 | L29 |
| Scale | Unchanged: previews the selected resident on the gauge | Select, tap Scale | none | L1 |

Caps and unlock levels are proposals the owner has not objected to; they are configurable. Each unlock lands on a
breather and clears every other debut (types 9, 17, 23, 26, 33, 41, 43, 45, 49, 63, 83, cargo 13, 21, 37, unknown
people 11, the lane variety 16, and the World 2 kinds and scenarios). The level-designer fixes the exact numbers and
`test/generator_test.dart` gets a check.

**Getting more.** Tapping a power with 0 left opens a small sheet: "Watch an ad" (1 use) or the coin price. Both are
configurable.

**Restart and the level end.** A restart resets every power effect (extra seats, extra trip) and does not refund spent
stock. Express counts as a delivery for the win condition. It scores nothing for the trip it skipped.

## Unknown residents

Early levels are unchanged: every person in a queue shows their look and floor tag. From level 11, some people behind a
lane's front are **unknown**. An unknown person is drawn as the same glowing ghost silhouette for everyone: one asset,
one size, no look, no floor tag, no variation. It cannot be selected. When the lane steps forward and the ghost reaches
the front, the real person is revealed with a short effect (the ghost brightens, flips to the person, and a sparkle
plays), and from then on they are a normal front resident. A lane's first person at the start of a level is always known,
and bench residents are always known.

**How many.** `unknownShare(level)` is the chance that a person behind the front is unknown: 0 below level 11, then
proposed `min(0.15 + 0.01 × (L − 11), 0.6)`. Which people are unknown is seeded by the level, so a level plays the same
every time. Level 11 is a breather that guarantees at least three unknown people, so the new thing is seen enough.

**The ghost asset.** A Gemini prompt for it is on the prompt page (`unknown_ghost`, attached to the schoolkid for
style). It must be exactly the same for every unknown person and of average build, so it can never hint at weight or
height. The see-through look and glow are added in code.

**Rules and engine.** Locked rule 1 becomes: "Three to five lanes of residents (four before level 16). Only each
lane's front shows who it is and can be selected; some people behind a front are unknown until they reach it." The
engine keeps the true identity and a per-resident `unknown` flag set by the generator. What the UI receives for an
unknown person has no type, cargo or floor, so nothing in `lib/ui` can leak it. The solver still plays through the
engine with full information, so par is unchanged, and the study below adds an information-limited bot.

## No waiting count

The player is never told how many people are waiting. The "+N waiting" text under each lane is removed on every level,
and so is the number in the rush hour banner, which becomes "A crowd arrives after trip 3" (the trip stays; the head
count goes). A lane draws at most its `visibleDepth` people, known or ghost, and nothing beyond that, so the silhouettes
never promise a length: a lane with three people drawn may have three or thirty. An empty lane still reads "Clear". The
bench caption ("2/5") is the player's own seats, not a queue, and stays. A widget test fails if any lane or banner text
contains a digit that counts residents.

## More ways to raise difficulty

Each is a `Formulas` function of the level and a generator input, so the level designer can tune them.

- **Lane count.** Four lanes below level 16. From level 16 the count varies by level between 3 and 5 on phones (6 on
  tablets later), seeded, so the layout is not always the same. Five lanes fit on a 390 px screen in the layout frame
  (try the 5 lanes toggle). This is the owner's "unknown number of queue columns"; the PRD reads it as "varies per
  level". Tell me if it should mean something else.
- **Unknown share and lane length spread.** The unknown share above, and lane lengths that spread apart as levels rise
  (proposed ±3 residents around the lane average from level 16, no lane empty at the start).
- **Liars.** After the puffer teen (L45) and the gym regular (L49) unlock, their weights in the venue mix rise with the
  level (`liarWeight(level)`), so more of the lobby looks like what it is not. More kinds of liar are a later idea (for
  example a sealed box of unknown contents).
- **Trip slack** shrinks on Hard levels as it does today. It rises by 1 on normal levels from level 11 until Gate A
  data says the unknown people are fair.

## Power cut scenario removed

The World 2 lobby scenario "power cut" is removed. Maintenance and rush hour stay. Locked rule 10 becomes: "World 2
(L61+) variety is always visible in advance: lift kinds (old, service, express) in the NEXT strip, the one lobby
scenario (maintenance, rush hour) on the lobby floor. Levels 1–60 use neither." Code to remove: the enum value in
`lib/game/scenario.dart`, its banner and dimming in `lib/ui/widgets/lobby.dart`, `Formulas.powerCutDepth`, its cases in
the generator and its tests, and its mention in docs/analytics.md. The power cut icon (`icon_scene_powercut`) is not
shipped. Levels that used the scenario become normal levels.

## Left-handed bottom bar

A "Left-handed" switch in the settings sheet, saved in the profile, default off. It mirrors the bottom bar only: Send
moves to the left edge and the four powers to its right. Nothing else on the screen moves. On two-pane tablet layouts
the bar follows the same switch.

## Rules this changes

Rule 1 and rule 10 as above. Rule 9 becomes: "No Undo (it would reveal weights). The Scale previews one resident as a
dashed ghost needle. Swap, +2 seats, +1 trip and Express change the lobby, never reveal a weight." Rule 2 gains an
exception: Express delivers a resident without boarding the lift. Rule 6 is unchanged, but +1 trip raises the budget it
draws on. Rules 7 and 8 are unchanged: the next lift still serves the next floor with reachable residents, and the fails
still apply, they are only delayed. The architecture rules hold: every number lives in `Formulas`, rewarded rewards are
granted only when the SDK reports the reward earned, and `lib/ui` and `lib/services` never read `.kg`.

## Economy (configurable)

| Setting | Default | Notes |
| --- | --- | --- |
| Coin price of each power | 150 | One value per power in `Formulas`, ready for Firebase Remote Config at M3 |
| Ad uses per rewarded view | 1 | |
| `powerRefill` daily cap | 6 | Inside the existing total of 12 rewarded views a day |
| Starting coins | 300 | Unchanged, so a new player can buy two powers at once |
| Scale price | 120 | Unchanged |

A level pays about 50–100 coins, so a power costs two to three levels of play. At 150 coins, +1 trip costs the same per
trip as the 300-coin rescue (+2 trips); the rescue stays the after-the-fact path. The placement "before a Hard level"
(2 free Scale uses) is unchanged. IAP: the Scale bundle stays; a Powers bundle (6 of each new power) is proposed at ₹249
for Gate B testing. Interstitial rules are untouched, and a payer who removed ads still gets rewarded refills.

## Engine, services and UI changes

- `Formulas`: unlock levels, per-power prices, ad uses, caps, the seat count, `unknownShare`, `laneCount`, lane spread,
  `liarWeight`, and the extra normal-level slack. `powerCutDepth` is deleted.
- `LiftGame` (lib/game/engine.dart): `swapFronts(laneA, laneB)`, `addSeats(n)`, `addTrip()`, `expressDeliver()`, each
  returning a bool, emitting a new event and recording per-level use so caps hold; a reveal event when an unknown
  person reaches the front. Pure Dart, no Flutter import.
- Generator: unknown flags, lane count and spread from the `Formulas` functions; every level still proven solvable by
  the solver.
- `Profile`: a stock map for the four powers (0 each) and `leftHanded`, saved as profile version 2 with a migration.
  `ad_policy.dart` gains `powerRefill`.
- `GameController`: `usePower(power)`, a Swap targeting mode, the get-more sheet, analytics.
- UI: the power dock, the Scale on the gauge plate, ghosts (no counts) in the lanes with the reveal effect, a variable
  number of lanes, a second bench row when seats exceed five, the settings switch, Restart in the pause menu. Figures
  grow 60%. Art still needed: the ghost (prompt ready) and icons for Swap and Express (a Gemini sheet, `icons_powers`).
- Audio and feedback: a short distinct cue per power and for a reveal; none may vary with any resident's weight.

## Gate A

The owner's call is to run Gate A with the powers on. Starting stock is 0 and starting coins are 300, so powers will be
rare in levels 1–10 and mostly earned through ads. Unknown people start at level 11 and lane variety at level 16, so
both fall inside the 60 levels Gate A covers. What this requires:
- A `powersEnabled` constant stays, so the powers can be turned off if the data is muddy.
- In tester mode the ads service is a stub, so "Watch an ad" grants one use after a short fake ad, with the daily cap
  of 12 still applied, and the log marks it `stub`.
- `level_win`, `level_fail` and `level_abandon` gain `powers_used`; `level_start` gains `lanes` and `unknown_share`.
  `tool/gate_a_report.dart` reports the Hard-level first-attempt win rate unassisted and all-attempts, power use by
  type, and the unknown-people fairness answers.
- A new optional exit question in tester mode: "Did the unknown people in the queue feel fair?"

**Risk to accept knowingly.** Gate A now measures the restyle, the new layout, the unknown people, lane variety and the
powers at the same time. If a metric misses, the cause cannot be separated. The build tag and `powers_used` help, and
the constants (`powersEnabled`, `unknownShare`, `laneCount`) are the levers for a follow-up run.

## Analytics

New events: `power_used` (`power`, `level`, `left`), `power_empty_tapped`, `power_refill_ad`, `power_bought`
(`power`, `coins`), `unknown_revealed` (`level`, `lane`), `left_handed_set`. `level_win`, `level_fail` and
`level_abandon` gain `powers_used` (a count). docs/analytics.md is updated with the build.

## Tests and the solver study

- Engine tests per power: valid and invalid use (empty or coned-off lane, no selection, cap reached), state after, the
  event, restart reset, and a win reached with Express.
- Unknown tests: the UI-facing queue never exposes an unknown person's type, cargo or floor; a reveal happens exactly
  when the person reaches the front; the unknown share and lane count stay within bounds; every generated level stays
  solvable.
- Profile migration test (a v1 save gains 0 of each power and `leftHanded` false); ad policy test for `powerRefill`,
  its cap and the daily total.
- Architecture test: no `.kg` or "kg" in the power UI; the dock shows power stock only. Widget test: no lane or banner
  text shows a number of waiting residents.
- Widget tests: 48 dp targets, no overflow from 320 × 568 up with 3, 4 and 5 lanes, the Swap targeting flow, the
  mirrored bar.
- Solver study before any UI: a bot that spends one power per level, and an information-limited bot that sees only the
  fronts and the bench, each reporting win rate per level band. `Formulas.trips` and `Formulas.bench` still come from
  the full-information par.
- `dart run tool/simulate.dart` and the level table are regenerated and compared; `test/generator_test.dart` stays green.

## Plan

1. Sign-off on this addendum.
2. Engine, `Formulas`, `Profile`, generator and `ad_policy` changes with their tests, no UI; remove the power cut.
3. Solver study; tune slack, unknown share, lane variety, stock caps and prices from it.
4. UI: dock, Swap targeting, ghosts and reveal, variable lanes, mirrored bar, bench row, settings, Restart in the menu,
   icons, ghost asset, audio.
5. monetization-auditor and code-reviewer pass on the diff.
6. Gate A with powers on, then Gate B.

## Open questions

- "Unknown number of queue columns": is "the lane count varies per level, from 3 to 5" what you meant?
- Accept the proposed unknown share curve (starts at level 11 at 15%, up to 60%), the lane spread, the liar weighting
  and the extra normal-level slack, to be tuned by the solver study?
- Accept the caps per level and the unlock levels above?
