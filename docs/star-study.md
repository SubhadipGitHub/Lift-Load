# Star study (PRD v1.8, C. Combo and stars)

Run on 2026-10-30 against the levels on main (the Gate A build). Reproduce with
`dart run tool/star_study.dart 1 100 40` (about 90 s) and `dart run tool/star_study.dart prove 1 10` for the
exhaustive check. Nothing under `lib/` changed.

## Question

PRD v1.8 proposes 3 stars for a win where every send is green or better and at least `⌈sends/3⌉` are perfect, and
says the threshold must be checked against a best-play solver so that 3 stars is always reachable with full
knowledge. Is it?

## Method

The study uses three players, all playing through `LiftGame`, so lift kinds, express floors, coned lanes, late
arrivals and jams apply as the player meets them.

The best player is a search that sees every hidden weight. For each lift, it enumerates exact fills from the lane
fronts and bench, digging up to three blockers. Across lifts, it keeps a beam of the 40 best partial runs, ranked once
toward fewest greys and once toward fewest people left. The greedy solver's own fill is always a candidate, so best
play is never worse than the shipped solver. It is a strong lower bound, not a proven optimum. At beam 150, the best
perfect count moved on 19 of 30 sampled levels, by up to 2 either way.

The greedy player is the shipped `Solver` strategy. The blind player is the bot from `tool/blind_study.dart`. It
knows the cast's weights but aims only at people it can see, which makes it the nearest stand-in for a practised
human.

Separately, a counting check finds floors whose total weight cannot be split into trips that are all green. A floor
that holds 1.46 lift loads needs two trips, and two green trips need at least 1.5. Such a floor forces a grey send
whatever the order. An exhaustive tap-by-tap search (`prove`) confirms the result on levels 1 to 10.

## Findings

**The rule as specced is unreachable on every level.** No player, including best play, earns 3 stars on any of the 100
levels. This is structural, not a threshold to tune:

- On 33 levels (21 of them in World 1), at least one floor's weight cannot split into all-green trips. A grey send is
  forced from the first tap. The exhaustive search proves this on levels 1, 2, 4, 7, 8, 9 and 10.
- Where all green is possible on paper, lane order and a small bench usually prevent it. On L3 and L6 the exhaustive
  search finds an all-green win, but with at most 1 and 0 perfects, below the `⌈sends/3⌉` bar.
- Grey sends are part of how these levels play. Best play sends grey on 33% of its lifts and perfect on 22%. The
  blind bot sends grey on 48% and perfect on 11%.

Looser "few greys" variants do not rescue it. Allowing a grey on up to a third of sends with `⌈sends/4⌉` perfects
gives best play 3 stars on only 32% of levels and the blind bot 5%. Every rule that asks for no greys or few greys is
either unreachable by construction or out of reach for anyone who cannot see weights.

**A per-level perfect target works.** Take P as a share of the most perfects best play reaches on that level (at
least 1). 3 stars is a win with at least P perfects. Share of all 100 levels:

| P | best 3★ | greedy 3★ | blind 3★ | blind 2★+, PRD 2★ rule | blind 2★+, perfects-only 2★ |
| --- | --- | --- | --- | --- | --- |
| all of best | 100% | 15% | 13% | 76% | 39% |
| ¾ of best | 100% | 40% | 31% | 77% | 54% |
| ⅔ of best | 100% | 47% | 33% | 78% | 59% |
| ½ of best | 100% | 62% | 48% | 78% | 62% |

The blind bot wins 79 of the 100 levels.

3 stars is reachable on every level by construction, because P comes from a run that exists. The PRD's 2-star rule
(a spare trip, or the perfect bar) is nearly automatic: the blind bot earns it on 77 of its 79 wins, because the trip
budget is par plus slack.

## Recommendation (signed off by the owner 2026-10-30; PRD v1.8 C amended)

- **3 stars:** win with at least P perfect lifts, where P = ⌊⅔ × best-play perfects⌋, minimum 1. Show it on the level
  intro and win sheet as "3 stars: P perfect lifts".
- **2 stars:** win with at least ⌈P/2⌉ perfect lifts. Drop the spare-trip clause.
- **1 star:** win.
- Drop "every send green" from stars. A grey send already costs the combo, so it should not be punished twice.

With these rules, the blind bot's 79 wins split into about 33 three-star, 26 two-star and 20 one-star clears. That is
a real spread, and it leaves a reason to replay on most levels.

## What the build needs (slice 3)

- **Star table.** P per level has to be known before play, but the best-play search takes about 1 s per level on a
  desktop, which is too slow for the generator at runtime. Ship a `Formulas` table of P for levels 1 to 100, written by
  this tool as the most perfects over several search settings. Add a `generator_test` check that the table matches
  the levels, so a generator change cannot silently break 3 stars.
- **Daily challenge.** It is seeded on device, so it has no table entry. Either run the search in an isolate when the
  daily opens, or use a cheaper target such as the greedy solver's perfects. This is open.
- **Economy.** Replays pay coins until the first 3-star clear. With 3 stars on about 4 in 10 practised wins, more
  replays pay than under the old rule, which paid on none. The coin effect is small, because base coins dominate a
  replay, but `tool/economy_v18.dart` should count it when slice 3 lands.
- **Gate A check.** The blind bot is not a human. If Gate A shows humans land far fewer perfects than the bot, lower
  the share from ⅔ to ½ rather than change the rule.
