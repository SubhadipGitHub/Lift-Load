---
name: tune-levels
description: Retune Lift Load difficulty with the solver and level table. Use when win rates miss targets, when levels feel unfair, or before adding levels beyond 60.
---

# Tune levels

## Inputs

- The complaint or metric, stated with numbers (for example "Hard win rate 31% on L20–40, target 45–55%").
- The current table: `dart run tool/simulate.dart 1 60` (or the affected range).
- If available, live analytics: `level_win`, `level_fail` (kind), `overload` (type) per level.

## Levers, in order of preference

1. **Slack** (`Formulas.slack`): trips on top of par. Cheapest, most predictable.
2. **Bench** (`Formulas.bench`): seats. Fixes jams; too many seats removes the planning.
3. **Floors** (`Formulas.floors`): more floors means deeper digging and more par.
4. **Residents** (`Formulas.residents`): longer levels. Changes session length; check with the owner.
5. **Cast mix** (`ResidentType` unlocks): changes what players must learn. Last resort.

Never make weights visible. Never change the locked rules in `CLAUDE.md`.

## Steps

1. Run the simulator; quote the rows that show the problem.
2. Propose one lever change with the expected effect; wait for the owner's go-ahead.
3. Edit `lib/game/formulas.dart` only.
4. Run `flutter test test/generator_test.dart` and the simulator again; compare before/after rows.
5. Log the change in `.claude/memory/decisions.md` and update "Level, economy and difficulty formulas" in
   `docs/PRD.md`.

Note: generation is seeded per level. Any formula change can reshuffle layouts for already-shipped levels. After
launch, freeze shipped levels (store their seed and parameters) before retuning, or players will see their current
level change under them.
