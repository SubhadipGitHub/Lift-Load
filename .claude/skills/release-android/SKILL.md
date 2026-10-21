---
name: release-android
description: Build and prepare a Lift Load Android release (app bundle, versioning, signing, Play Console track). Use when the owner asks for a test or production build. Uploading is irreversible and needs an explicit "proceed".
---

# Release Android

Reversibility gate: building is safe; **uploading to Play Console, promoting a track, or changing the store listing
is not reversible**. Show the plan, name what is irreversible, and wait for the owner's explicit "proceed" before
those steps. Never handle the upload keystore password in chat; the owner enters it locally.

## Preflight

1. `git status` clean, on `main`, CI green on the commit.
2. `flutter analyze --no-fatal-infos` and `flutter test` pass locally.
3. `dart run tool/simulate.dart 1 60` unchanged from the last release unless a tuning change is intended.
4. The `monetization-auditor` agent has reviewed any ad or IAP change since the last release.
5. Ad unit IDs are production IDs only in the release flavor; debug builds use Google's test IDs.

## Version

Bump `version:` in `pubspec.yaml`: `MAJOR.MINOR.PATCH+BUILD`. BUILD must increase on every upload.

## Build

```bash
flutter clean
flutter pub get
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

Check `build/app/outputs/bundle/release/app-release.aab` exists and its size is under 25 MB (PRD constraint).
Keep `build/symbols` for crash de-obfuscation; do not commit it.

## Signing

`android/key.properties` and the upload keystore live only on the owner's machine (both are git-ignored). If they
are missing, stop and ask the owner; never generate a new upload key without their go-ahead, because Play App
Signing ties the app to it.

## Upload (after "proceed")

Internal testing track first. Release notes: what changed for players in two or three plain sentences.
Record the release (version, date, track, notable changes) in `.claude/memory/progress.md`.
