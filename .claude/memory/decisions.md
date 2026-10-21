# Decision log

Newest first. One line of decision, one line of why. Reopen a decision only with new evidence.

## 2026-10-21 · continues always work

- **Jam continue adds as many seats as the nearest match needs, not a flat 1.** One seat could re-jam at once with
  the ad already spent. The count is shown on the button before the player pays.
- **+2 trips also adds those seats when the handed-over lift would arrive jammed.** Otherwise the ad led straight
  into a second fail.

## 2026-10-21 · v1.2 variety pass

- **Variety in two waves: content in 1–60, rules in World 2 (61–100).** Gate A must still measure weight guessing;
  lift kinds and scenarios would confound it.
- **Five venues of 20 levels, each with a crowd mix and look.** Owner asked for environment variety; spawn weights keep
  every unlocked type present so the cast stays learnable.
- **New types: guard 96 (L23), wheelchair 118 (L43), puffer teen 48 (L45, inverse liar), pram 84 (L63), bellhop 124
  (L83).** Each sits in a band clear of its look-alikes; the puffer teen deliberately looks heavy.
- **Cargo is an additive hidden weight (water can 20 L13, suitcase 12 L21, gas cylinder 30 L37).** Extends the
  learning curve past L20 without breaking "one type, one weight". Props avoid the shapes of type accessories.
- **Lift kinds as a visible repeating schedule (old 0.75×, service 1.4×, express two floors).** Planning against the
  NEXT strip is the new brain; a fixed pattern per level keeps it fair.
- **Scenarios: maintenance, power cut, rush hour; one per level at most.** Never on Super Hard or another debut.
- **Lifts route only to reachable residents.** A locked lane or a pending wave could otherwise soft-lock an empty lift.
- **The solver plays through the engine.** One implementation of the rules; the bot cannot drift from the game.
- **Queued, not built: best-play solver, trap Hard levels, stars, cabin spots, pairs, hurry residents.**

## 2026-10-21

- **Trips = solver par + slack, not Σ⌈W/0.85C⌉ + slack.** Python and Dart simulation: the weight formula
  under-counted by 20–30% from 4 floors up, making late levels unwinnable.
- **Bench 5 seats from 4 floors (4 below), −1 on Hard.** With 3–4 seats the bot jammed on up to 85% of 6-floor
  layouts; with this rule every level 1–60 generates on the first few seeds.
- **Uncle unlocks at L26, not L25.** L25 is Super Hard; a new type must debut on a breather.
- **Flutter, not Capacitor + plain JS.** Owner's call on the PRD comment thread. Cost: the concept JS was ported to
  Dart (engine, figure builder). Benefit: first-party ads/billing plugins, cheap iOS later.
- **No game engine (no Flame).** UI puzzle with one animated cabin; widgets + CustomPainter cover it.
- **Weights hidden; gauge shows zones only.** Owner's design change after the first concept; replaces "exact fill".
- **No Undo; Scale booster instead.** Undo would let players read weights off the needle for free.
- **Push-your-luck send.** Player chooses when to send; grey / green / perfect scoring; trip budget caps waste.
- **Fonts and audio deferred to M4.** The build workspace could not reach Google Fonts; platform font carries the
  weights until Baloo 2 and Nunito Sans are bundled.
- **Platform folders (android/, web/) not committed yet.** No Flutter SDK in the authoring workspace; generate with
  `flutter create` (see CLAUDE.md) and commit them on first local run.
