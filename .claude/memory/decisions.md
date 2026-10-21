# Decision log

Newest first. One line of decision, one line of why. Reopen a decision only with new evidence.

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
