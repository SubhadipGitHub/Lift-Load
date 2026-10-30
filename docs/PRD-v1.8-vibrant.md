# PRD v1.8: vibrant and fun

Status: signed off by the owner 2026-10-28, with the style board and the answers under "Owner decisions". Stars
amended and signed off 2026-10-30 (C, from the star study). Designed
while Gate A runs; nothing under `lib/` or `assets/` changes until the Gate A result is in, and the build order below
is re-ranked by what testers said.

## Problem

The game plays as designed but looks and feels samey:

- Every building is the same deep indigo night. Only Sunrise Towers has painted backdrops; the other four venues use
  the old painted look.
- A level is one loop: guess, fill, send. Nothing builds across trips, nothing asks to be replayed, and nothing brings
  a player back tomorrow.
- Riders stand in one overlapping row in the cabin, scaled down when it fills, which looks like a list, not a lift.

## Rule 3 is the boundary

Weight stays hidden. No position, scale, animation, reaction, badge, sound or score in this PRD may vary with a
hidden weight. Every new effect keys only on what the player can already see:

- the gauge zone;
- the trip result (grey, green, perfect);
- a resident's look;
- their floor;
- a visible badge.

Tests guard it (see Verification).

## Success criteria

1. **Colour worlds:** a screenshot of each of the five venues reads as a different place at a glance. Lane text and
   tags keep at least 4.3:1 contrast on every new backdrop.
2. **Cabin floor:** riders stand on the cabin floor in a front and a back row. The player can choose the row, and a
   full cabin never shrinks its riders.
3. **Something to chase:** at least one of combo, stars or daily is used by 60% of players in a session (analytics).
   Stars give a reason to replay: at least 15% of 3-star-able levels are replayed by day 7, read at Gate B.
4. **The core holds:**
   - Gate A metrics re-run on 5 testers stay within 10 points.
   - The weight-aware solver clears every level 1 to 100 under the new rules.
   - The blind bot's clear rate per band moves by no more than 10 points.
5. **The economy holds:** coin income per level rises by at most 25%, and power and ad pull is rebalanced in
   `Formulas`. The monetization-auditor passes it.
6. **Size and motion:** the web build stays under 25 MB. Every new animation is still under reduce-motion, and
   there is no layout overflow on the 14 responsive sizes.

## Scope

### A. Venue colour worlds (visual only)

Each venue gets a world palette. `VenueStyle` in `lib/ui/theme.dart` grows to carry:

- a sky gradient;
- a wall tint;
- a floor;
- an accent;
- particle and confetti colours.

The dark chrome (HUD, dock, sheets, surfaces) stays as it is, so contrast and the 3D surface recipe hold.

| Venue | Levels | Palette | Feel |
| --- | --- | --- | --- |
| Sunrise Towers | 1–20 | coral #FF7A59, sun gold #FFC233, sky peach | warm morning in a home society |
| Skyline Offices | 21–40 | teal #14B8A6, glass blue #4C9DFF, steel | bright weekday glass and plants |
| Lakeside Hospital | 41–60 | mint #3DDC97, clean white, soft aqua | calm, airy, sunlit |
| Bazaar Mall | 61–80 | candy pink #FF5FA2, violet #A066F5, neon | busy, festive, shop lights |
| Starlight Hotel | 81–100 | royal gold #F5B83D, burgundy #8E2A4A, night blue | grand, evening, chandeliers |

- **Backdrops:** each venue gets three shaft-wall bands and one lobby floor, the same set Sunrise has. That is 16 new
  images for the four other venues, plus Sunrise regenerated brighter to match its palette. The prompts are in
  `tool/art/art_pack.json` (`bg_<venue>_*`, `_v2` for Sunrise).
- **Home:** the skyline map buildings take their venue colours.
- **Floor colours must stay readable on every wall:**
  - The NEXT chips, floor tags and the floor display use the six floor colours (coral, sun, teal, blue, plum, leaf).
  - Several venue walls share a hue with one of them: the office wall is teal, the hospital wall mint (near leaf), and
    the mall wall pink and violet (near coral and plum).
  - So walls stay mid-tone and a little desaturated behind the shaft panel, and chips keep their dark outline.
  - A test checks every floor colour against every venue wall at 3:1 or better for the chip shape.
  - The style board (`docs/art/venue-worlds/palette-board.png`, from `tool/art/make_venue_board.py`) is a
    saturated mock, not the final wall tone.
- **Juice that keys only on visible results:**
  - confetti in venue colours on a perfect send;
  - riders cheer on a perfect, wave on a green and shrug on a grey, the same for every type;
  - a brighter burst on boarding;
  - an idle emote now and then in the lobby, random per resident id and never per type.

### B. The cabin floor: front and back rows

This is the owner's request: people and items stand on the cabin floor, in front or behind, so the cabin feels
natural.

- **Drawing:** the cabin floor is drawn in depth with two rows.
  - The back row stands higher on screen, at a fixed 0.86 scale and dimmed 10%.
  - The front row is full size.
  - Riders keep their order within a row. Items (cargo, pram, wheelchair, trolley) stand on the floor beside their
    owner.
- **Choosing a row:** tapping the upper half of the cabin boards into the back row, the lower half into the front row.
  If the chosen row is full, the rider goes to the other row. Screen readers get "Board, back row" and "Board, front
  row".
- **Cabin spots** (the mechanic; it reopens rule 2):
  - Each row has a visible number of spots per lift kind:
    - normal: 3 + 3;
    - old: 2 + 2;
    - service: 4 + 4;
    - express: 3 + 3.
  - Wide figures (pram, wheelchair, trolley) take two spots.
  - A full cabin refuses more riders with "No room left in the lift", so space becomes a visible limit beside the
    hidden weight.
  - Empty spots show as faint floor marks.
- **Smooth exit** (express lifts only, World 2): when every rider for the far floor stands in the back row, the trip
  pays +3 coins.
- **Never a weight cue:** a rider's offset and scale depend only on row and slot. Weight never chooses a row or a
  slot.

### C. Combo and stars (scoring; reopens rule 6)

- **Combo:**
  - Back-to-back sends in the green or better build a combo of ×1, ×1.5, ×2 and ×3 (the cap). It multiplies trip
    coins.
  - A grey send resets it, and a crash ends the level as now.
  - A combo meter sits by Send. The score slam shows the multiplier.
- **Stars per level** (amended 2026-10-30 after the star study, `docs/star-study.md`):
  - Each level has a perfect target P = ⌊⅔ × the most perfect lifts best play reaches on it⌋, minimum 1.
  - 1 star: win.
  - 2 stars: win with at least ⌈P/2⌉ perfect lifts.
  - 3 stars: win with at least P perfect lifts.
  - The level intro and win sheet show the target ("3 stars: P perfect lifts"). P counts lifts, never weight.
  - Grey sends do not cost stars; they already reset the combo.
  - P comes from a best-play search (`tool/star_study.dart`), run offline and shipped as a `Formulas` table for
    levels 1 to 100. Because P comes from a run that exists, 3 stars is always reachable with full knowledge. A
    `generator_test` check keeps the table in step with the levels. The daily challenge needs its own target (open).
  - Why not the first rule (every send green plus `⌈sends/3⌉` perfects): best play reached it on 0 of 100 levels. On
    33 levels a floor's weight cannot split into all-green trips, so a grey send is forced.
- **Where stars show:** on the win sheet, and as gold windows on the Home skyline.
- **Replays:**
  - Tapping a cleared level on the map replays it for stars and coins.
  - Replays never move progress and cost no life. They pay coins until the level's first 3-star clear, then
    nothing.
- **Profile v3** adds `stars` (level to 0–3) and `bestCombo`, with the same tolerant migration as v2.

### D. Resident personalities (reopens rule 1's "who you see")

Traits are visible badges on a resident of any type. They never change weight, and they live on `Resident` in the
game layer.

- **VIP:** a gold sash. Delivered on a perfect trip, a VIP tips +10 coins. On a green trip there is no tip.
- **In a hurry:**
  - A clock badge with N trips left that ticks down at each send.
  - Delivered before it runs out, the resident tips +6 coins.
  - At 0 the badge greys and the tip is lost. The level never fails for it (rule 8 is unchanged).
  - A hurry resident never starts unknown.
- **Generation:** at most 2 traits per level, never on a Super Hard level.

### E. Pairs and families (reopens rules 1 and 2)

- A pair (2) or a family (3, which may include a pram) is drawn with a visible tether, shares one floor, and stands
  together in one lane.
- **Moving as one unit:** selecting any member selects the group. They board, bench and swap as one unit. They need
  that many bench seats and cabin spots, and their combined weight stays hidden (the Scale previews the group as one
  ghost needle).
- **Unknown people:** no member of a group is ever unknown.
- **Powers:** Express delivers the whole group or refuses.
- **Engine:** the solver, the generator and `tool/blind_study.dart` handle units, and `Formulas.trips` slack is
  retuned from a solver study.

### F. Daily challenge and the golden lift

- **Daily challenge:**
  - It opens after level 10 and is a level seeded from the device date.
  - It draws only on content the player has unlocked.
  - The first attempt is free and pays coins by stars (30 / 60 / 100).
  - A daily-streak calendar on Home shows a 7-day run, and day 7 pays one free power use.
  - There is no backend; changing the device clock is accepted as cheating nobody needs to stop.
- **Golden lift:**
  - Some lifts in the NEXT strip are golden, known in advance.
  - A perfect on a golden lift pays double, a green pays normal, and its capacity is unchanged.
  - It is a scoring flag, not a lift kind, so rule 10's "visible in advance" covers it in levels 1–60.

### Out

- Timed events (a weekend with double coins). They need remote config, which comes with M3 Firebase.
- New resident types.
- Changes to weights.
- Changes to the four powers.
- New venues.

## Rule amendments (CLAUDE.md "Locked game rules")

- **Rule 1, added:** "Some residents wear a visible trait badge (VIP, in a hurry). Pairs and families stand together
  in one lane with a tether and move as one unit; none of a group is ever unknown."
- **Rule 2, added:** "The lift has a visible number of spots per lift kind in a front and a back row; wide figures take
  two; a full lift refuses more riders. The player picks the row."
- **Rule 6, replaced:** "Send needs ≥ 1 rider, uses one trip, and scores grey 0 / green +6 / ≥ 95% perfect +11 coins,
  times the combo (×1, ×1.5, ×2, ×3, reset by a grey send), plus VIP and hurry tips, doubled on a perfect golden lift."
  The coin values come from the economy model (see Economy).
- **Rule 8, note:** a missed hurry badge loses a tip; it never fails a level.
- **Rule 10, note:** the golden lift is a scoring flag shown in the NEXT strip, allowed in levels 1–60.

## Debut schedule

Each debut lands on its own breather level, never a multiple of 10 or 25. That is checked against `Debut.at` and the
free levels today.

| Level | Debut | Why there |
| --- | --- | --- |
| 1 | cabin rows, combo, stars | presentation and scoring, taught by the UI from the start |
| 22 | cabin spots | after the first 20 levels of pure weight guessing |
| 24 | VIP | early, as a simple bonus |
| 31 | pairs | after the office cast settles |
| 35 | in a hurry | after pairs, so the bench and seats are understood |
| 44 | golden lift | late World 1, when combos matter |
| 51 | families | the hospital world, prams arrive at 63 in World 2 |
| after L10 | daily challenge | a Home feature, not a level |

## Economy

Combo, tips, the daily and the golden lift all add coins. The cap is at most 25% more coins per level, so powers and
rewarded ads stay worth reaching for.

**The model.** `tool/economy_v18.dart` plays levels 1–100 with the blind bot from `tool/blind_study.dart`, rates each
send by its fill, then prices the same play under today's rules and under v1.8.
- The rating rule reproduces the engine's own trip coins on every level the bot wins (79 of 100).
- The tips and the golden lift are expected values. The assumptions are one VIP per level from 24, one hurry resident
  per level from 35 (70% on time), and one golden lift in six from 44.
- The daily challenge is per day, not per level, so it is left out, as are the smooth-exit coins.

| Coins per won level | 1–20 | 21–40 | 41–60 | 61–80 | 81–100 | All |
| --- | --- | --- | --- | --- | --- | --- |
| Today | 74 | 143 | 137 | 147 | 188 | 131 |
| v1.8, combo cap ×3 | +71% | +62% | +42% | +45% | +58% | **+55%** |
| v1.8, combo cap ×2 | +45% | +42% | +33% | +34% | +43% | +39% |

**Decision.** The combo stays at ×3, per the owner's rule: ×2 only if `Formulas` cannot hold the cap, and it can.
- Trip coins go from green 8 and perfect 15 to **green 6 and perfect 11**. That lands at **+23%** overall.
- A lone green pays a little less than today. A run of greens pays more, which is the point of the combo.
- Power prices (150) and the coin continue (300) stay as they are for now. The monetization-auditor reviews them with
  the real build, and the model reruns after any change to levels or `Formulas`.

**The bot is skilled, so read this as an upper bound.** It knows the cast's weights. Players who send fewer greens
build fewer combos, and their increase will be smaller. Gate B analytics (`combo_peak`, coins per level) replace these
numbers with real ones.

## Analytics

New events, all added to `docs/analytics.md`:

- `combo_peak` (level, peak);
- `stars_earned` (level, stars, replay);
- `vip_delivered` (level, tipped);
- `hurry_missed` (level);
- `group_boarded` (level, size);
- `cabin_full_refused` (level);
- `row_chosen` (level, row);
- `daily_start` and `daily_result` (date, stars, streak);
- `golden_perfect` (level).

## Constraints

- Rule 3 above.
- Widgets call only `GameController`. There is no `.kg` or "kg" in `lib/ui` or `lib/services`.
- Every number lives in `Formulas`, every size in `Metrics`, and every colour in `theme.dart`.
- Each debut is on its own breather level (`test/generator_test.dart`).
- Reduce-motion stills every new animation.
- No real brand, place or person names in art or text.

## Plan

1. **Sign-off on this PRD** and on the colour-world style board (`docs/art/venue-worlds/palette-board.png`).
2. **During Gate A, nothing shipped:**
   - the owner generates the venue backdrops from the new prompts;
   - they are processed and approved into `docs/art/approved/`;
   - the economy model is extended and run.
3. **After Gate A:** re-rank the slices by the result. For example, if the heavy-types metric misses, the cast cues
   come first. Then build one PR per slice, each with screenshots:
   1. colour worlds and juice;
   2. cabin rows and spots;
   3. combo and stars, with the best-play solver and Profile v3;
   4. VIP and hurry;
   5. pairs and families;
   6. daily challenge and the golden lift.
4. **A 5-tester re-run** of the Gate A metrics on the new build, then Gate B planning.

## Verification

- **Engine:** tests for spots, rows, combo, stars, traits, groups, daily seeding and the golden lift.
  `test/generator_test.dart` stays green, the level table is regenerated, and the solver and blind-bot studies run for
  every rule change.
- **Weight guards:**
  - a widget test that rider offset and scale depend on row and slot only (two residents of different weight in the
    same slot draw identically);
  - reactions depend on the trip result only;
  - badges never vary with weight.
- **Contrast:** a test per venue palette for lane text and tags (4.3:1 or better), and every floor colour against
  every venue wall (3:1 or better).
- **Layout:** the responsive sweep over 14 sizes, 3 to 5 lanes, both hands and 1.3x text.
- **Visual:** release web build screenshots of each venue at 450x800 and 1280x720, against the style board.
- **Kit:** `test/gate_a_dry_run_test.dart` still green, so the tester kit keeps working for the re-run.

## Owner decisions (2026-10-28, "go with your recommendations")

1. **Replays** cost no life and never move progress. They pay coins until the level's first 3-star clear, and nothing
   after it, so a cleared level cannot be farmed.
2. **Pairs and families** always move as one unit: select, board, bench, swap and Express together.
3. **Combo cap** is ×3. The economy model (Plan, step 2) can lower it to ×2 only if the 25% coin cap cannot be held
   by `Formulas` changes alone. That would come back to the owner.
4. **Cabin spots:** rows and spot marks show from level 1. A full cabin starts refusing riders at level 22 (the
   debut).
5. **Daily challenge** opens after level 10, paying 30 / 60 / 100 coins by stars, with a free power use on day 7 of a
   streak.
6. **Stars** (2026-10-30, after `docs/star-study.md`): 3 stars for at least P perfect lifts, 2 stars for at least
   ⌈P/2⌉, with P = ⌊⅔ × best-play perfects⌋ (minimum 1) per level. This replaces "every send green". If Gate A shows
   people land far fewer perfects than the blind bot, the share drops to ½; the rule does not change.
