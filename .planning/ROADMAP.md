# Roadmap: WalkoutDJ

## Overview

Build a native iOS walk-up song manager from scratch: data models and persistence first, then the audio engine, then each screen (roster, lineup, game day), finishing with settings and polish.

## Phases

- [x] **Phase 1: Foundation** — Swift package, data models, persistence, navigation shell
- [x] **Phase 2: Audio Engine** — AVFoundation playback, document picker, file import
- [x] **Phase 3: Roster** — Player CRUD with MP3 import
- [x] **Phase 4: Lineup** — Drag-to-reorder batting order, multiple lineups
- [x] **Phase 5: Game Day** — Walkout mode with large display and audio controls
- [x] **Phase 6: Polish** — Settings screen, dark theme, edge cases

## Phase Details

### Phase 1: Foundation
**Goal**: Xcode project via CLI, SwiftUI app shell with tab navigation, data models, persistence layer
**Depends on**: Nothing
**Plans**: 2 plans

Plans:
- [x] 01-01: Xcode project setup, SwiftUI app entry point, tab navigation shell
- [x] 01-02: Data models (Player, Lineup, Settings) and persistence layer (JSON)

### Phase 2: Audio Engine
**Goal**: Reliable audio playback with play/pause/stop/seek, document picker for MP3 import, file management
**Depends on**: Phase 1
**Plans**: 2 plans

Plans:
- [x] 02-01: AudioManager with AVFoundation (play, pause, stop, seek, auto-stop timer, volume)
- [x] 02-02: Document picker for MP3 import, copy to app sandbox, file management utilities

### Phase 3: Roster
**Goal**: Full player management — add, edit, delete players with name, jersey number, and walk-up song
**Depends on**: Phase 2
**Plans**: 2 plans

Plans:
- [x] 03-01: RosterView with player list, add/edit sheet, delete with swipe
- [x] 03-02: Song assignment flow — pick MP3, preview playback, set start time

### Phase 4: Lineup
**Goal**: Create and manage batting lineups with drag-to-reorder
**Depends on**: Phase 3
**Plans**: 2 plans

Plans:
- [x] 04-01: LineupView with lineup list, create/rename/delete lineups
- [x] 04-02: Lineup editor — add players from roster, drag-to-reorder, reset to roster order

### Phase 5: Game Day
**Goal**: Full walkout mode — large current batter display, play song, auto-stop, next/prev, on-deck display
**Depends on**: Phase 4
**Plans**: 2 plans

Plans:
- [x] 05-01: GameDayView — lineup selector, large batter display, on-deck preview
- [x] 05-02: Walkout controls — play/stop, auto-stop timer, next/prev batter, manual stop

### Phase 6: Polish
**Goal**: Settings screen, dark baseball theme, edge case handling, final refinements
**Depends on**: Phase 5
**Plans**: 2 plans

Plans:
- [x] 06-01: SettingsView — default auto-stop duration, volume, reset data
- [x] 06-02: Dark theme refinement, edge cases (no song, missing file, audio interruption), haptic feedback

### Phase 7: Multi-Team — Data Model & Migration
**Goal**: Add Team model, add teamId to Player/Lineup, update StorageManager, migrate existing data into a default team
**Depends on**: Phase 6
**Plans**: 2 plans

Plans:
- [ ] 07-01: Team model, add teamId to Player/Lineup, update StorageManager with team CRUD and filtering
- [ ] 07-02: Auto-migrate existing data into default team, add activeTeamId tracking

### Phase 8: Multi-Team — Team Management UI
**Goal**: Team picker/switcher, team list management, scope Roster & Lineup screens by active team
**Depends on**: Phase 7
**Plans**: 2 plans

Plans:
- [ ] 08-01: Team list screen, team switcher in navigation, create/rename/delete teams
- [ ] 08-02: Update Roster & Lineup screens to filter by active team

### Phase 9: Multi-Team — Game Day & Polish
**Goal**: Scope Game Day by active team, handle edge cases, update Settings stats
**Depends on**: Phase 8
**Plans**: 2 plans

Plans:
- [ ] 09-01: Update Game Day to scope by active team
- [ ] 09-02: Update Settings stats per-team, edge cases (no teams, team deletion cascade)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete | 2026-03-19 |
| 2. Audio Engine | 2/2 | Complete | 2026-03-19 |
| 3. Roster | 2/2 | Complete | 2026-03-19 |
| 4. Lineup | 2/2 | Complete | 2026-03-19 |
| 5. Game Day | 2/2 | Complete | 2026-03-19 |
| 6. Polish | 2/2 | Complete | 2026-03-19 |
| 7. Multi-Team Data | 0/2 | In Progress | - |
| 8. Multi-Team UI | 0/2 | Pending | - |
| 9. Multi-Team Polish | 0/2 | Pending | - |
