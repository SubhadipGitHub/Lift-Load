# Lift Load

A hybrid-casual Android puzzle. Residents wait in an apartment lobby. You guess who fits in the lift from how they
look (their weight is never shown), fill it as close to the limit as you dare, and send it. One rider too many and
the cable snaps.

Status: **M1, core loop.** Playable in the browser with stubbed ads. See `docs/PRD.md` for the full plan.

## Run it

Needs the Flutter SDK (stable, 3.27 or newer).

```bash
# First time only: generate the platform folders, then remove the template test
flutter create --platforms=android,web --project-name lift_load --org com.liftload .
rm test/widget_test.dart

flutter pub get
flutter run -d chrome          # play in the browser
flutter test                   # engine, generator, ad policy, widget and architecture tests
dart run tool/simulate.dart    # level table: par, trips, bench per level
```

Commit the generated `android/` and `web/` folders after the first run.

## How it plays

1. Tap a resident at the front of a lane (or on the bench).
2. Tap the lift to board them, or an empty bench seat to park them.
3. Watch the needle. Green is good. Past red, the lift falls.
4. Tap Send. Near-full lifts earn more coins; half-empty ones waste a trip.

## Layout

| Path | Contents |
| --- | --- |
| `lib/game/` | Pure-Dart rules, solver and level generator |
| `lib/services/` | Ad policy, ads/analytics interfaces, saved profile, haptics |
| `lib/ui/` | Controller, painters (parametric residents, gauge), widgets, screens |
| `test/` | Engine, generator, ad policy, widget and architecture tests |
| `tool/simulate.dart` | Level table for tuning |
| `docs/` | PRD, analytics events |
| `.claude/` | Claude Code agents, skills and project memory |

## Working with Claude Code

`CLAUDE.md` is the project memory: locked rules, architecture rules, commands. Session notes live in
`.claude/memory/`. Agents: `flutter-engineer`, `level-designer`, `monetization-auditor`, `code-reviewer`. Skills:
`add-resident-type`, `tune-levels`, `add-ad-placement`, `release-android`, `session-checkpoint`.
