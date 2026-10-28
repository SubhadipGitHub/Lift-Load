# Decision log

Newest first. One line of decision, one line of why. Reopen a decision only with new evidence.

## 2026-10-28 · v1.8 "vibrant and fun" direction (owner's answers)

- **Gate A runs first on today's build; v1.8 is designed in parallel and built after the result.** Mechanics before
  Gate A would muddy what it measures. Nothing under `lib/` or `assets/` changes while testers play.
- **Look: per-venue colour worlds, dark UI chrome kept.** One bold palette per building; the chrome keeps the
  contrast and the surface recipe.
- **Mechanics in scope: combo and stars, resident personalities (VIP, hurry, reactions), pairs and families, daily
  challenge and golden lift, and riders on the cabin floor in a front or back row the player picks (owner's own ask).**
  All keyed to visible information only (rule 3). PRD: `docs/PRD-v1.8-vibrant.md`, DRAFT for sign-off.

## 2026-10-22 · Gemini art pack

- **Describe the look; never name a studio.** CLAUDE.md bans brand names, and Gemini waters down "in the style of".
- **Skin tone and build are in every prompt.** Left unsaid Gemini picks a pale skin and draws adult men lean and
  youthful, which breaks the weight cues. Tones are read from `ResidentLook`; heavier types say how wide they are next
  to a neighbour.
- **A type must read in the same weight order as its design.** A mixed cue costs a redo (grandpa belly, slim office
  man, slim rider); a deliberate liar (gym regular, puffer teen) must mislead only the way the design says.
- **One image per character, never a sprite sheet.** A sheet of 14 leaves each figure a tenth of the resolution.
- **The keyer reads the backdrop from the image border.** Gemini's green is not #00FF00.
- **Art lands after Gate A.** The metric being measured is how well testers learn today's silhouettes.
- **The approved sprites are committed, under `docs/art/approved/`.** Not shipped (outside `assets/`), about 0.5 MB.
  Why: raw images and the review scripts lived only in one container; a new session needs the cast to line new art up
  against. This narrows the earlier "nothing generated is committed" rule to the raw and working files.

## 2026-10-21 · v1.4 Gate A kit

- **Results return on-device, no backend.** Testers download a file or copy a code; Firebase stays in M3. No
  accounts, no personal data, works on the existing Pages link.
- **Ask on the spot, not at the exit.** Crash fairness is a tap on each crash sheet; the heavy-types question comes
  once after the level 15 win, free text, so the answer is unprompted.
- **`attempt` and `continues` in every build.** First-attempt win rate needs them, and M3's Firebase will too.
- **Sittings from timestamps, not a session param.** Same measure, no change to the event contract.
- **No retune before the test.** Measure first; pacing from L32 on is a known risk, recorded in docs/gate-a.md.

## 2026-10-21 · v1.3 polish pass

- **Polish pulled forward from M4 for the tester build.** Owner's call; Gate A testers judge feel as well as rules.
- **Tablets rotate, phones stay portrait.** Landscape tablets get a two-pane layout; phone landscape adds nothing.
- **Effects plus music, all synthesized in-repo.** No licensing, reproducible from `tool/audio/synth.py`; MP3 for
  iOS Safari testers.
- **Polish the parametric cast, not commission art.** An illustrator pass can still replace it after Gate A.
- **No gauge ticks.** A scale would let players read weights off the needle (rule 3).
- **Looping animation sits behind reduce-motion.** It also keeps `pumpAndSettle` tests deterministic.

## 2026-10-21 · continues always work

- **Restarting or leaving a started level costs a life.** It was a free escape from a bad start, which bypassed the
  lives sink and the extra-life ad. Free before the first move; leaving asks first; restart needs a life left over.
- **Normal cabin sign reads "MIND THE LOAD", not "MAX 4 PERSONS".** There is no rider cap; the old sign taught
  players to under-fill.

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
- **Scenarios: maintenance, rush hour; one per level at most.** Never on Super Hard or another debut. (Power cut was
  removed in v1.6, 2026-10-22.)
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

## 2026-10-22 (PRD v1.6, owner signed off)

- **Powers: Swap, +2 seats, +1 trip, Express; start at 0; 150 coins or 1 ad per use, configurable.** More agency and a
  reason to spend or watch ads. The Scale stays (it is the only thing that teaches weights) and moves to the gauge plate.
- **Unknown residents from L11, not a hidden queue from L1.** Early levels stay fully visible; unknown people are one
  identical ghost, revealed at the front. The number waiting is never shown.
- **Lane count varies 3 to 5 from L16; lane spread, liar weight and slack tune difficulty.**
- **Power cut scenario removed.** "Only the front is lit" stopped being a variant once the queue can hide people.
- **Gate A runs with powers on.** The owner's call over my recommendation; `powersEnabled` is the lever.
- **Left-handed mirror of the bottom bar now.** Restart moves into the pause menu.
- **Restyle, new layout and the art pack come before Gate A.** Art is approved in docs/art/approved/; nothing under lib/ or
  assets/ changed yet.

## 2026-10-22 (engine review, owner decisions)

- **Power refills stop at 10 of the 12 daily rewarded views.** The last two are kept for fail-sheet continues (repair,
  trips, seat). `Formulas.powerRefillFailReserve`.
- **Unknown people keep their true floor in the routing logic.** The lobby still shows "?" for them; the NEXT strip is
  not masked (masking it would soft-lock the level). The jam sheet no longer says how many seats ("more bench seats")
  on levels with unknown people, so the number cannot point at a floor.
- **+1 trip is used during the level, not from the fail sheet.** A player who owns one must use it while a trip is
  left. A last-trip hint in the dock is a UI task.
- **A crash reveals nobody;** Express is refused when it would jam the lobby.
