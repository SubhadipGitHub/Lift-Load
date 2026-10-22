# Lift Load: project memory for Claude Code

Hybrid-casual Android puzzle. Residents wait in a lobby; the player guesses who fits in the lift by how they look,
fills it as close to the limit as they dare, and sends it. Overload it and the cable snaps.

Owner: Subhadip. Read this file, then `.claude/memory/progress.md`, at the start of every session.

## Ground rules (from the owner, non-negotiable)

- **PRD before non-trivial builds.** Check what exists first, write problem / success criteria / scope / constraints /
  plan / open questions, and get an explicit sign-off before implementing. `docs/PRD.md` is the signed-off PRD.
- **Reversibility gate.** Before deleting files, overwriting work, force-pushing, publishing to Play Console, or any
  mass change: show the plan, name what is irreversible, wait for an explicit "proceed".
- **Push back.** Disagree with reasoning when something is technically wrong or scope-creeps. No sycophancy.
- **Checkpoint.** Before switching domains or when a session runs long, update `.claude/memory/progress.md` with what
  is decided, what is open, what is next (use the `session-checkpoint` skill).
- Prose over bullet points in explanations; no emoji.

## Locked game rules (changing one reopens docs/PRD.md)

1. Four lanes of residents. Only lane fronts and bench residents can be selected.
2. A selected resident goes to an empty bench seat or into the waiting lift. A lift refuses anyone not going to one of
   its floors.
3. **Weight is never shown.** Each `ResidentType` and each `Cargo` has one fixed hidden `kg`; a resident weighs type +
   cargo. No number, bar, or icon may reveal either.
4. The gauge shows only current load, in zones of this lift's capacity: grey < 75%, green ≥ 75%, red > 100%. No
   numbers.
5. Boarding past this lift's capacity snaps the cable: the lift drops and the level fails (`FailKind.crash`).
6. Send needs ≥ 1 rider, uses one trip, scores grey 0 / green +8 / ≥ 95% perfect +15 coins.
7. The next lift serves the next floor in rotation that still has reachable residents; an express also serves the
   floor after it.
8. Win when everyone is delivered. Fail on crash, out of trips, or jam (bench full, nothing boardable, lift empty).
9. No Undo (it would reveal weights). The Scale booster previews one resident as a dashed ghost needle.
10. World 2 (L61+) variety is always visible in advance: lift kinds (old, service, express) in the NEXT strip, the one
    lobby scenario (maintenance, power cut, rush hour) on the lobby floor. Levels 1–60 use neither.

## Stack

Flutter (Dart 3.5+), Android first, Flutter web for tester builds. No game engine. Ads, billing and analytics sit
behind interfaces in `lib/services/`; M1 ships stubs (`StubAdsService`, `DebugAnalytics`).

| Path | What lives there |
| --- | --- |
| `lib/game/` | Pure-Dart rules: `cast.dart` (types, cargo, hidden kg), `venue.dart` (five buildings, crowd mix), `scenario.dart` (lift kinds, lobby scenarios), `debuts.dart` (what is new on each level), `formulas.dart` (every tuning number), `engine.dart` (state machine + events), `solver.dart` (greedy bot that plays through the engine), `generator.dart` (seeded levels) |
| `lib/services/` | `ad_policy.dart` (interstitial gating, rewarded caps), `ads_service.dart`, `analytics_service.dart`, `profile.dart` (incl. sound/music/haptics switches), `feedback_service.dart` (event → haptic + `Sfx` cue), `audio_service.dart` (audioplayers: cue pool, venue music loop), `tester_log.dart` + `tester_config.dart` (Gate A tester build: on-device event log, results file) |
| `lib/ui/` | `game_controller.dart` (only bridge from widgets to engine), `theme.dart` (palette, `VenueStyle`, `LiftKindStyle`), `layout.dart` (`Metrics`: every size from the 390×844 design, four form factors), `motion.dart` (one idle clock, sway/blink, shake; all still under reduce-motion), `painters/` (parametric resident bodies, vehicles, cargo, gauge, cabin, shaft walls, sky, lobby floors), `widgets/` (incl. `effects.dart` particle bursts, `pressable.dart`, `settings_sheet.dart`), `screens/` |
| `tool/simulate.dart` | Prints the level table: par, trips, bench, floors per level |
| `tool/audio/synth.py`, `tool/icons/make_icons.py` | Regenerate `assets/sfx`, `assets/music` (numpy + ffmpeg) and the `web/` icons (PIL); both deterministic |
| `tool/art/` | `art_pack.json` (style bible + prompt per asset) and `gemini_art.py` (Gemini generate, key out, size, line-up, review); `docs/art/approved/` holds the approved cast sprites (not shipped); see `docs/art/gemini-art-pack.md` |
| `tool/gate_a_report.dart` | Gate A metrics from the result files testers send back (`docs/gate-a.md`) |
| `assets/`, `web/` | Bundled fonts (OFL), synthesized audio, the web shell (icons, manifest, boot splash) |
| `docs/` | `PRD.md`, `analytics.md`, `concept/` notes |
| `.claude/` | `agents/`, `skills/`, `memory/` |

## Architecture rules (enforced by tests where possible)

- `lib/game` never imports Flutter or `dart:ui` (`test/architecture_test.dart`).
- `lib/ui` and `lib/services` never read `.kg` or print "kg" (`test/architecture_test.dart`).
- Widgets never call the engine directly; they call `GameController`, which drains engine events into messages,
  feedback and analytics.
- Every tuning number lives in `Formulas`. No magic numbers in the engine or UI.
- Rewarded rewards are granted only when the ads SDK reports the reward earned, never on ad close.
- Interstitials only through `InterstitialPolicy.shouldShowAfterWin`. Never after a fail. Never for payers.
- No real metro, society or brand names or logos anywhere (app, assets, store listing).
- Engine changes need engine tests; formula changes need `test/generator_test.dart` green and an updated level table.
- Every debut (type, cargo, lift kind, scenario) lands on its own level, never a multiple of 10 or 25, and is a
  breather (`Debut.at`, enforced by `test/generator_test.dart`).

## Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test                      # engine, generator, ad policy, widget, architecture tests
dart run tool/simulate.dart 1 100 # level table
python3 tool/audio/synth.py       # regenerate sound effects and music
python3 tool/icons/make_icons.py  # regenerate web icons
dart run tool/gate_a_report.dart results/*   # Gate A metrics from tester result files
flutter run -d chrome             # play in the browser (ads stubbed)
flutter run -d <android-device>
```

First-time setup on a machine with the Flutter SDK (`web/` is committed; `android/` is generated until M3):

```bash
flutter create --platforms=android --project-name lift_load --org com.liftload .
rm test/widget_test.dart   # flutter create adds a counter-app test we do not want
```

## Milestones (docs/PRD.md, "Build plan")

M1 core loop (this code) → M2 generator + 60 levels + tester web build → **Gate A** prototype test →
M3 Android shell: AdMob, Play Billing, Firebase → M4 screens, economy, polish, fonts, audio → **Gate B** soft launch.

## Agents and skills

Agents in `.claude/agents/`: `flutter-engineer`, `level-designer`, `monetization-auditor`, `code-reviewer`.
Skills in `.claude/skills/`: `add-resident-type`, `tune-levels`, `add-ad-placement`, `release-android`,
`session-checkpoint`.
