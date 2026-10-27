# Gate A: prototype test (levels 1–60)

Gate A decides whether the core thesis holds before any Android work starts: guessing weight from a silhouette, then
risking one more rider, is fun and learnable. The targets are in `docs/PRD.md` ("Success criteria"), and the kit
that measures them is PRD v1.4.

## What the tester build does

The Pages build at https://subhadipgithub.github.io/Lift-Load/ is the tester build. CI builds it with
`--dart-define=TESTER=true`. Compared with a normal build, it makes these changes:

- **Tester code.** Home shows "Tester build" with a random three-word code. That code is the tester's only
  identity: no name, email or account.
- **Level cap.** Play stops after level 60 with a thank-you and a Send results button.
- **Crash question.** After a crash, the fail sheet asks one optional question: was that crash fair?
- **Heavy-types question.** On the first win from level 15 on, the win sheet asks once: "Which residents do you think
  are the heaviest?" It shows no choices, so the answer is unprompted.
- **Powers are on.** Swap, +2 seats, +1 trip and Express unlock at levels 14, 19, 27 and 29, start at 0 uses, and
  cost 150 coins or one ad. Testers start with 300 coins. The ad is a stub: a short fake ad, then the reward, with the
  daily cap of 12 views still applied.
- **Unknown-people question.** On the first win from level 13 on that had unknown people (they debut at level 11), and
  never on the same win as the heavy-types question: "Did the unknown people in the queue feel fair?" with Fair,
  Unfair and Skip.
- **Results log.** Level starts, wins, fails, abandons, overloads, trips, power use (used, bought, refilled by the stub ad,
  tapped while empty) and the three answers are kept on the device, with a timestamp. Nothing is sent anywhere until the tester sends it themselves.
- **Send results.** Home and the final win sheet have Send results. It downloads `lift-load-<code>.json`, or copies
  a code starting `LLGA1.` that can be pasted into a message.

Weights never appear anywhere: not in the game, the file or the code.

## Running it

1. **Pick testers.** Pick 10–15 people who do not work on the game, with a mix of puzzle players and non-players.
   The PRD's open question "who the testers are" needs an answer before you send invites.
2. **Play it yourself.** Run through levels 1–5 on the live link on a phone. Tap Send results and check that the file
   arrives.
3. **Send the invite** below. Ask testers to play in one sitting where they can. "Cleared 1–10 in one sitting" is a
   gate metric.
4. **Watch two or three in person** if you can, using the observation script.
5. **Collect results.** Ask for results after their first sitting, and again whenever they stop. A later file from
   the same code replaces the earlier one.
6. **Run the report.** Save the files, or paste codes into `.txt` files, in a `results/` folder that is not
   committed. Then run:

   ```bash
   dart run tool/gate_a_report.dart results/*
   ```

7. **Grade the heavy-types answers by hand.** The report lists each answer next to the real order. Count an
   answer as a pass when it names the two heaviest types the tester had met, in any words: by level 15 that is
   the aunty and the man in the office shirt.

### Invite message

> I'm testing a small puzzle game and would love 20–30 minutes of your time.
> Open https://subhadipgithub.github.io/Lift-Load/ on your phone (Chrome or Safari). Add it to your home screen if
> you like. Play in one go if you can, as far as you enjoy it, and answer the two little questions it asks.
> When you stop, tap "Send results so far" on the home screen and send me the file or the copied code.
> There are no right answers. If something annoys or confuses you, that is exactly what I need to hear.

### Observation script (in person)

- Say only: "Think aloud if you can. I can't help, but I'll answer questions at the end." Do not explain the rules
  or the weights.
- Note:
  - The level where they first say something about weight or size.
  - When they first notice the dock, whether they try a power while it shows 0 (the Get more sheet), and whether
    they understand Swap's two taps without help.
  - Their words when a ghost reaches the front and is revealed.
  - Every crash, and their words right after it.
  - Any time they hesitate over Send, which is the push-your-luck moment.
  - Where they stop, and why.
- At the end, ask:
  - "What made someone heavy?"
  - "Was any crash unfair?"
  - "Would you play tomorrow?"

## Reading the numbers

| Metric | Target | If it misses |
| --- | --- | --- |
| Cleared 1–10 in one sitting | ≥ 70% | Onboarding or early pacing. Check where the per-level table shows abandons and fails in 1–10 |
| First-attempt wins on Hard levels | 45–55% | Under: slack over the weight-aware solver's par is too thin (Hard levels have one trip). Over: Hard is not hard |
| Named the heavy types unprompted | ≥ 60% of testers who reached L15 | The cast is not learnable. Look at overloads by type: whoever leads is misread |
| Crashes called unfair | ≤ 1 in 5 rated | A crash felt random. Check which types and cargo caused the "unfair" crashes |

**Powers change what the numbers mean.** This run measures the restyle, the layout, unknown people, lane variety and
the powers together (PRD v1.6, "Gate A"), so a miss cannot be pinned on one cause. The report helps separate them:
- Metric 2 stays the gate number over every first attempt. Under it the report shows the Hard first attempts that used
  no power, which is the closest read on the weight-guessing thesis alone. A big gap between the two means the powers
  carry Hard levels, so read the gate number as "with help".
- The Powers block shows use by type, coin buys, stub-ad refills and taps while empty. Taps while empty are wanted
  and missing: a high count for one power says it is valued, or that stock runs out too early. Few uses overall mean
  testers did not find the dock or did not want it.
- Unknown-people fairness has no target of its own. Read it beside the crash number: more than about 1 in 5 saying
  Unfair is a miss in spirit, and the levers are `Formulas.unknownMax` and the debut level.
- Levers for a follow-up run: `powersEnabled`, `unknownShare` and `laneCount`.

**Expected sample sizes.** From L32 on, levels hold 72 residents and 24–33 trips, so most testers will stop around
L15–25.
- The Hard-level metric will rest mostly on L10, L20 and L25. Read it per level as well as pooled.
- With 10–15 testers, one tester moves a rate by 7–10 points, so treat anything within 10 points of a target as a
  tie, not a pass or a miss.

**Decision.**
- **All four pass:** go to M3 (Android shell).
- **One misses:** fix it with a short retune or onboarding change and a 5-tester re-run of just that metric.
- **The heavy-types or unfair-crash metric misses badly** (the thesis itself): stop and rethink the cast cues
  before building further.

Record the result and the decision in `.claude/memory/decisions.md`.
