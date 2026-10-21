# Lift Load MVP: PRD

Version 1.2, 2026-10-21. Owner: Subhadip. Living copy of the claude.ai doc "Lift Load MVP — PRD", with the
simulation-driven changes marked v1.1 and the variety pass marked v1.2 (see "v1.2 Variety and depth").

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
  service lift L65, maintenance L67, express L71, power cut L77, bellhop L83, rush hour L87.
- **Venues** (20 levels each): Sunrise Towers (housing society), Skyline Offices, Lakeside Hospital, Bazaar Mall,
  Starlight Hotel. Each has its own lobby look, a prop, and a crowd mix (spawn weights in `lib/game/venue.dart`). The
  hotel runs on past L100.
- **Cargo.** Water can, suitcase, gas cylinder, each a fixed hidden extra weight. Adults carry one 25% of the time once
  unlocked; kids and anyone pushing a chair, pram or trolley never do.
- **Lift kinds (L61+).** Each level repeats a pattern such as normal-normal-old or normal-old-normal-express, at most
  two non-normal kinds, first lift always normal. Old lift: 0.75 × capacity. Service lift: 1.4 × capacity. Express: this
  floor plus the next in rotation. Shown in the NEXT strip and on the cabin.
- **Lobby scenarios (L61+).** At most one per level, never on Super Hard or another debut. Maintenance: one lane is
  coned off for the first 3 trips. Power cut: residents at depth 2 or deeper are shadows (floor tags still shown).
  Rush hour: two waves of 4 residents join after trips 3 and 6.
- **No soft-locks.** Lifts are routed only to residents the player can reach. If only coned-off or not-yet-arrived
  residents remain, the lane opens early or the wave arrives at once. A jam that only the coned-off lane could
  clear also opens the lane early instead of failing.
- **Solver.** The greedy bot now plays through the engine itself, so every rule above is proven solvable for all 100
  levels (`test/generator_test.dart`).

**Queued (not in v1.2):** a best-play solver for tighter Hard levels and stars per level; cabin spots (max riders);
pairs who must ride together; residents in a hurry.

## Monetization

| Placement | Format | Reward | Cap |
| --- | --- | --- | --- |
| Crash fail | Rewarded | Repair: last rider returns to where they stood | 1 per attempt, then 300 coins |
| Out of trips | Rewarded | +2 trips, plus the bench seats the next lift needs if it would arrive jammed | 1 per attempt, then 300 coins |
| Lobby jam | Rewarded | Bench seats enough to dig out the nearest resident for this lift (usually 1) | 1 per attempt, then 300 coins |
| Win | Rewarded | Level coins ×3 | 1 per level |
| Before a Hard level | Rewarded | 2 free Scale uses | 1 per Hard level |
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
