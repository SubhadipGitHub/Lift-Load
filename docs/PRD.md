# Lift Load MVP: PRD

Version 1.6, 2026-10-22. Owner: Subhadip. Living copy of the claude.ai doc "Lift Load MVP — PRD", with the
simulation-driven changes marked v1.1, the variety pass marked v1.2 (see "v1.2 Variety and depth") and the polish
pass marked v1.3 (see "v1.3 Polish: layout, art, motion, sound"), the Gate A kit marked v1.4 and the powers, unknown
residents and lane variety marked v1.6 (see "v1.6 Powers, unknown residents, lane variety").

## Problem

The MVP must prove one thing: that guessing a stranger's weight from their silhouette, then risking one more rider,
is fun enough to hold 32% of players to day 1. Everything else (meta, events, live ops) waits until that number is
real.

Block and sort puzzles grew 170%+ in revenue last year, while lift puzzles have one scaled title (Elevator Sorting)
not updated since October 2025, and the only weight-based lift game sits at 10K+ downloads. Hidden weight plus a
visible load gauge is a twist none of them ship.

## Success criteria

| Gate | Metric | Target | How measured |
| --- | --- | --- | --- |
| Prototype (10–15 testers) | Testers who clear levels 1–10 in one sitting | ≥ 70% | Session log |
| Prototype | First-attempt win rate on Hard levels | 45–55% | `level_win` / `level_fail` per level |
| Prototype | Testers who can name the "heavy" types unprompted after 15 levels | ≥ 60% | Exit question |
| Prototype | Crashes testers call unfair | ≤ 1 in 5 | Exit question |
| Soft launch (≥ 900 installs per cohort) | D1 / D7 / D30 retention | 32% / 12% / 5% | Firebase cohorts |
| Soft launch | Rewarded views per DAU | ≥ 2.5 | AdMob + Firebase |
| Soft launch | Store reviews mentioning ads | < 5% | Play Console |
| Technical | Cold start on a ₹10K Android phone | < 3 s | Manual, 2 devices |
| Technical | Frame rate during crash and send animations | 60 fps, no drops below 50 | Flutter DevTools |

If Android D1 lands under 28%, onboarding gets fixed before any new content.

## Scope

In: the core loop; 60 generated levels proven solvable by the solver; 9 resident types; 2–6 floors; Home, Play,
Fail (crash, out of trips, jam), Win, Shop, Settings; lives, coins, Scale, Repair, +2 trips, +1 seat; 7-day chest and
win streak; AdMob rewarded and interstitial; Remove Ads and two packs via Play Billing; Firebase Analytics for every
gate metric; offline-first local save.

**v1.2 In:** five venues across levels 1–100; 14 resident types (adds security guard, wheelchair patient, puffer-jacket
teen, parent with pram, bellhop); three cargo props; World 2 (L61–100) lift kinds and lobby scenarios; a venue map on
Home.

Out: metro mode and the Tower Transit hybrid; Tower Race, battle pass, leaderboards, cloud save; VIP and twins
(pairs are queued, see "Queued"); iOS; paid UA before Gate B.

## Locked game rules

See `CLAUDE.md`, "Locked game rules". The concept canvas Play and Logic artboards are the visual reference.

## Level, economy and difficulty formulas

All live in `lib/game/formulas.dart`.

- Floors: k(L) = min(2 + ⌊L/8⌋, 6), +1 on Super Hard.
- Residents: N(L) = min(12 + round(1.5L), 72).
- Capacity: 280 kg below L41, 360 kg from L41. Hidden.
- **v1.1 Trips:** T(L) = par + s, where par is the trips the solver bot needs and s = 2 normal, 1 Hard / Super Hard,
  3 breather. v1.0 used Σ⌈W_f / 0.85C⌉ + s; simulation showed the bot needing 20–30% more trips than that from 4
  floors up, which would have made late levels unwinnable.
- **v1.1 Bench:** 4 seats up to 3 floors, 5 seats from 4 floors, one fewer on Hard / Super Hard. v1.0's 3–4 seats
  jammed up to 85% of generated layouts at 6 floors.
- Coins: 20 + 2⌊L/5⌋ + 8 per green trip + 15 per perfect trip.
- Sawtooth: L mod 10 = 0 Hard, L mod 25 = 0 Super Hard, L mod 10 = 1 breather. Levels that introduce a new type are
  always breathers, and the new type appears at least three times.
- Cast unlocks: schoolkid, office goer (two builds) at L1; aunty L9; student L17; **v1.2** security guard L23; uncle
  L26; grandpa L33; delivery rider L41; **v1.2** wheelchair patient L43; **v1.2** teen in a puffer jacket (the inverse
  liar: looks heavy, is light) L45; gym regular (the "liar") L49; **v1.2** parent with pram L63; bellhop with trolley
  L83.

## v1.2 Variety and depth

Why: by about L20 a player knows all nine fixed weights, and every level looked and played the same. v1.2 extends the
learning curve (more people, cargo) and adds planning against a visible schedule (lift kinds, lobby scenarios). Levels
1–60 keep the core rules so Gate A still measures the weight-guessing thesis; the structural changes live in World 2.

- **Debuts.** One new thing per level, on a breather, never on a multiple of 10 or 25, and seen at least three times:
  water can L13, suitcase L21, guard L23, gas cylinder L37, wheelchair L43, puffer teen L45, old lift L61, pram L63,
  service lift L65, maintenance L67, express L71, bellhop L83, rush hour L87 (v1.6 removes the L77 power cut).
- **Venues** (20 levels each): Sunrise Towers (housing society), Skyline Offices, Lakeside Hospital, Bazaar Mall,
  Starlight Hotel. Each has its own lobby look, a prop, and a crowd mix (spawn weights in `lib/game/venue.dart`). The
  hotel runs on past L100.
- **Cargo.** Water can, suitcase, gas cylinder, each a fixed hidden extra weight. Adults carry one 25% of the time once
  unlocked; kids and anyone pushing a chair, pram or trolley never do.
- **Lift kinds (L61+).** Each level repeats a pattern such as normal-normal-old or normal-old-normal-express, at most
  two non-normal kinds, first lift always normal. Old lift: 0.75 × capacity. Service lift: 1.4 × capacity. Express: this
  floor plus the next in rotation. Shown in the NEXT strip and on the cabin.
- **Lobby scenarios (L61+).** At most one per level, never on Super Hard or another debut. Maintenance: one lane is
  coned off for the first 3 trips. Rush hour: two waves of 4 residents join after trips 3 and 6.
- **No soft-locks.** Lifts are routed only to residents the player can reach. If only coned-off or not-yet-arrived
  residents remain, the lane opens early or the wave arrives at once. A jam that only the coned-off lane could
  clear also opens the lane early instead of failing.
- **Solver.** The greedy bot now plays through the engine itself, so every rule above is proven solvable for all 100
  levels (`test/generator_test.dart`).

## v1.3 Polish: layout, art, motion, sound

Why: the M1 UI used fixed pixel sizes (it overflowed on 320 × 568 phones and showed a phone strip on tablets), the
platform font, flat art, three animations and no audio. v1.3 pulls the M4 polish forward for the tester build. No game
rule changes.

- **Responsive layout.** One `Metrics` object (`lib/ui/layout.dart`) sizes every screen from the device: compact
  phone, phone, tablet portrait, tablet landscape (two panes: lift and bench left, lanes right). Phones stay
  portrait-locked; tablets (shortest side ≥ 600 dp) may rotate. No overflow from 320 × 568 to 1366 × 1024, touch
  targets ≥ 48 dp, system text scale clamped at 1.3.
- **Type.** Baloo 2 (display) and Nunito Sans (body), bundled (SIL OFL).
- **Art.** Outlined, shaded residents with idle sway and blinking; a steel cabin with sliding doors and a floor
  display; shaft walls, rails and cables per venue; a glowing gauge bezel; pressable buttons; a home skyline with sky,
  clouds and lit windows.
- **Motion.** Residents walk from lanes to bench or cabin, lanes step forward, doors close before a send and open on
  arrival, crashes shake and spark, perfect loads burst coins, wins drop confetti. All of it honours the system
  reduce-motion setting.
- **Sound and music.** About 15 synthesized effects and one quiet looping theme per venue (MP3, about 1.1 MB in all),
  generated by `tool/audio/synth.py`. Sound, music and haptics toggles in a settings sheet, saved in the profile.
- **Hidden weight still holds.** The gauge gets no ticks or scale. No sound, animation or visual varies with a
  resident's weight: boarding sounds and walk speed are identical for everyone; the creak follows the gauge zone.

**Queued (not in v1.2):** a best-play solver for tighter Hard levels and stars per level; cabin spots (max riders);
pairs who must ride together; residents in a hurry.

## v1.4 Gate A kit (signed off 2026-10-21)

**Problem.** Gate A needs four numbers from 10–15 testers, and the tester build at
`subhadipgithub.github.io/Lift-Load` cannot produce any of them. Analytics only prints in debug builds, so the
release web build discards every event. No event carries an attempt number, so first-attempt win rate cannot be
derived. Nothing asks the two exit questions, and a tester who clears level 60 walks into World 2, which this gate
must not measure.

**Success criteria for the kit.** Each of the four prototype metrics in "Success criteria" comes out of one
command over the testers' returned files, with no manual counting except grading the free-text "heavy types"
answer. A tester can return their results in under a minute without an account. No personal data is collected.

**Scope.**

- **Tester mode.** It is on in the Pages build through `--dart-define=TESTER=true`, and off by default so the
  Android build is untouched. It does the following:
  - Caps play at level 60 with a "that's the test, thank you" screen.
  - Gives each install a random tester code made of three words; no name or email.
  - Shows a small "Tester build" chip on Home.
- **Attempt and session tracking.** These are added to every build, since M3 Firebase needs them too:
  - `level_start`, `level_win`, `level_fail` and `level_abandon` gain `attempt` (1 on the first try at that level),
    and `level_win` gains `continues`.
  - Sittings: every event the tester log keeps carries a timestamp, and the report splits sittings at 30 minutes
    idle. (Built this way instead of a `session` param on every event: same result, nothing new in the event
    contract.)
- **On-device tester log.** A `TesterLog` analytics sink keeps every event locally, capped at about 5,000 events,
  alongside the existing debug sink.
- **In-game questions,** in tester mode only:
  - After each crash, the fail sheet asks one optional tap: "Was that crash fair?" (Fair / Unfair), logged as
    `crash_fairness`. Asking on the spot is more reliable than asking at the exit.
  - After the level 15 win, a once-only free-text card asks "Which residents do you think are the heaviest?",
    with no choices shown so the answer is unprompted. It is logged as `exit_heavy_types`.
- **Return results.** A "Send results" button on Home, and on the end screen, downloads a JSON file and copies a
  compact code for pasting into WhatsApp or email. It works offline.
- **Report.** `dart run tool/gate_a_report.dart results/*.json` prints:
  - The four gate metrics against their targets.
  - First-attempt win rate per level, with Hard levels flagged.
  - Overloads by type and cargo.
  - Abandons and fails per level.
  - The free-text answers, for grading.
- **Tester brief.** `docs/gate-a.md` covers:
  - The message to send testers: link, add to home screen, about 30 minutes, play in one sitting, then tap Send
    results.
  - An in-person observation script.
  - The owner's run checklist.
  - How each number maps to the go / rework call.

**Constraints.**
- Rules 1–10 are unchanged.
- The log, the export and the report never contain or derive kg. Type and cargo names are fine, because players
  see them.
- There is no backend. Nothing leaves the device unless the tester sends the file.
- Event names are added to `docs/analytics.md`.

**Out of scope.**
- Firebase stays in M3.
- Retuning levels before the test. Measure first.
- A weight-blind solver.

**Known risk.**
- L32–60 are 72 residents and 24–33 trips each, so most testers will stop around L15–25.
- The Hard-level metric will therefore rest mostly on L10, L20 and L25. The levels cleared in one sitting and the
  heavy-types question after L15 are unaffected.
- If Hard first-attempt wins land far below 45%, the slack of one trip over a weight-aware solver's par is the
  first suspect.

## v1.6 Powers, unknown residents, lane variety (signed off 2026-10-22)

Full spec, tests, analytics and plan: `docs/PRD-v1.6-powers.md`. Why: more agency and more reasons to spend coins or
watch rewarded ads, and more ways for difficulty to grow with the level, without touching the core of guessing a weight
from a look. Four powers sit beside the Scale; some people in a queue are unknown until they reach the front; lane
counts vary; the power cut scenario is removed. The queue is never counted for the player.

- **Powers.** All four start at 0 stock and cost 150 coins or one rewarded ad per use (both configurable in `Formulas`).
  Swap (L14, 2 per level) swaps two lane fronts. +2 seats (L19, 1 per level) adds two bench seats for the level. +1 trip
  (L27, 1 per level) adds a trip. Express (L29, 1 per level) delivers the selected resident straight to their floor
  with no seat, trip or capacity used. A restart resets their effects without refunding stock. The Scale is unchanged
  and moves onto the gauge plate.
- **Unknown residents (L11+).** Early levels show every person in a queue. From level 11 a share of the people behind a
  lane's front is unknown: one identical glowing ghost, no look, no floor tag, not selectable, revealed when it reaches
  the front. Proposed share: `min(0.15 + 0.01 × (L − 11), 0.6)`, seeded by the level; level 11 guarantees at least
  three. A lane's first person and bench residents are always known.
- **No waiting count.** The "+N waiting" text and the number in the rush hour banner are removed. A lane draws at most
  its visible depth, so nothing promises a length.
- **Lane variety.** Four lanes up to level 15; from level 16 the count varies by level between 3 and 5 on phones. Lane
  lengths spread (proposed ±3 around the average) and the puffer teen and gym regular weigh more in the crowd mix as
  levels rise. Trip slack on normal levels rises by 1 from level 11 until Gate A data says otherwise.
- **Power cut removed.** World 2 scenarios are maintenance and rush hour.
- **Left-handed bar.** A settings switch mirrors the bottom bar (Send left, powers right). Restart moves into the pause
  menu behind the gear, with the existing confirm and life rule.
- **Gate A runs with the powers on.** Tester ads are a stub; `powersEnabled`, `unknownShare` and `laneCount` are the
  levers if the data is muddy. Events gain `powers_used`, `lanes` and `unknown_share`.
- **Rules changed in CLAUDE.md:** 1 (lanes, unknown people, no count), 2 (Express), 9 (powers), 10 (scenarios).

## Monetization

| Placement | Format | Reward | Cap |
| --- | --- | --- | --- |
| Crash fail | Rewarded | Repair: last rider returns to where they stood | 1 per attempt, then 300 coins |
| Out of trips | Rewarded | +2 trips, plus the bench seats the next lift needs if it would arrive jammed | 1 per attempt, then 300 coins |
| Lobby jam | Rewarded | Bench seats enough to dig out the nearest resident for this lift (usually 1) | 1 per attempt, then 300 coins |
| Win | Rewarded | Level coins ×3 | 1 per level |
| Before a Hard level | Rewarded | 2 free Scale uses | 1 per Hard level |
| Empty power (v1.6) | Rewarded | 1 use of that power (or 150 coins) | 6 per day, inside the total of 12 |
| 0 lives | Rewarded | +1 life | 3 per day |
| Daily chest | Rewarded | Chest ×2 | 1 per day |
| After a win, from L15 | Interstitial | none | ≥ 3 levels and ≥ 180 s apart, max 4 per session, never after a fail, never for payers |

Lives: a fail costs one life when the player retries or leaves. Restarting or leaving a level after the first move
(a seat, a boarding or a send) costs one too, after a confirm; before it, both are free. Total rewarded cap: 12 per day. IAP (test prices): Remove Ads ₹299; Starter Pack ₹99 one-time; Scale bundle ₹199
for 15. Scale costs 120 coins in the shop.

## Constraints and stack

Flutter (Dart), Android for the MVP, Flutter web for tester builds in M1–M2. No game engine: widgets, implicit
animations, CustomPainter. Plugins: google_mobile_ads, in_app_purchase, firebase_analytics, shared_preferences,
HapticFeedback, audioplayers (M3–M4). APK under 25 MB, offline except ads and purchases, Android 8+, no real metro or
brand names.

## Build plan

M1 core loop in Flutter, tested on web (wk 1–2) → M2 generator, solver, 60 levels (wk 3–4) → Gate A prototype test
(wk 5) → M3 Android shell (wk 6–7) → M4 screens, economy, polish (wk 8) → Gate B soft launch (wk 9–12) → scale or
rework (wk 13+). Assumes about 10 hours a week.

## Open questions

- Hours per week available (plan assumes ~10).
- Play Console account: personal or registered entity.
- Soft-launch markets: India plus one Tier-1 (default Canada).
- Name check for "Lift Load" on Play Store and trademarks.
- Who the 10–15 prototype testers are.
- Art: keep the parametric cast through soft launch, or an illustrator pass after Gate A.
