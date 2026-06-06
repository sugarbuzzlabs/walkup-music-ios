# WalkoutDJ

**One-liner**: A native iOS app for managing and playing baseball walk-up songs for youth baseball teams.

## Problem

Paid apps like BallparkDJ and Ultimate Dugout DJ charge subscriptions for basic functionality — playing walk-up songs for batters. Coaches and parents need a free, offline, reliable app that works in a dugout without internet or iCloud.

## Success Criteria

How we know it worked:

- [ ] Can add players with name, jersey number, and assigned MP3 from Files app
- [ ] Can create and reorder batting lineups with drag-and-drop
- [ ] Game Day mode plays walk-up songs with auto-stop, next/prev batter controls
- [ ] Works fully offline with no cloud dependency
- [ ] Large tap targets usable in outdoor/dugout conditions

## Constraints

- Native Swift/SwiftUI — iOS only, no cross-platform
- AVFoundation for audio (rock-solid playback)
- Fully offline — no network, no iCloud, no subscriptions
- Local persistence (SwiftData or JSON files)
- Import MP3s via iOS Files app (UIDocumentPickerViewController)
- CLI-only build (no Xcode GUI dependency)

## Out of Scope

- Android support
- Cloud sync / multi-device
- Music streaming integration (Spotify, Apple Music)
- Team sharing / collaboration features
- In-app purchase or monetization
