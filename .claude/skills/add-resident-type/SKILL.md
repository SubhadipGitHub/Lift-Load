---
name: add-resident-type
description: Add a new resident type to Lift Load end to end (hidden weight, unlock level, parametric look, tests, level table). Use when the owner asks for a new character or body type.
---

# Add a resident type

A type is a promise to the player: it always weighs the same and its look must make that weight guessable. Read
`CLAUDE.md` first.

## 1. Agree the design (before code)

Write down and confirm with the owner:
- Name and one-line visual cue (what tells the player it is light or heavy).
- Hidden weight in kg. Check it against the cast in `lib/game/cast.dart`: it should sit in a distinct band from its
  look-alikes, or be a deliberate "liar" (only one liar per 50 levels).
- Unlock level. It must land on a breather (`Formulas.difficulty` makes debut levels breathers) and not collide with
  another type's debut.

## 2. Engine

1. Add the enum value to `ResidentType` in `lib/game/cast.dart`: `name('Display name', kg, unlockLevel)`.
2. Run `flutter test test/generator_test.dart`. The debut test checks it appears ≥ 3 times on its debut level.

## 3. Look

1. Add a case to `ResidentLook.of` in `lib/ui/painters/resident_painter.dart`: height (kids < 75), shoulders, hips,
   belly, clothing colours, hair, accessory. Heavier types get wider hips/belly or visible cargo.
2. If it needs a new accessory or hair, add the enum value and its drawing to `_Figure`. Draw inside the 60 × 120
   box, feet on y = 116.
3. Keep colours distinct from the floor colours in `FloorStyle` so clothing is never mistaken for a floor tag.

## 4. Verify

```bash
flutter analyze --no-fatal-infos
flutter test
dart run tool/simulate.dart 1 60
```

Paste the level-table rows around the debut level into the PR. Add a line to `.claude/memory/decisions.md`
(name, kg, unlock level, why). Update the cast list in `docs/PRD.md` ("Cast unlocks").
