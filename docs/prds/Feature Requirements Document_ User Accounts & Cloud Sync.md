# Feature Requirements Document: User Accounts & Cloud Sync

## 1. Overview
**Feature Name:** User Accounts & Cloud Sync
**Target Audience:** Coaches, team parents, and game-day DJs who manage multiple teams across devices or want to back up their data.
**Objective:** Allow users to create an account, sign in, and sync their team data (rosters, lineups, songs, photos, stadium sounds) to the cloud. This enables multi-device access, data backup/restore, and lays the foundation for future collaboration features (e.g., sharing a team with an assistant coach).

## 2. Problem Statement
Currently, all HypeDeck data lives locally on a single device. If a user loses their phone, switches devices, or wants to manage teams from an iPad and iPhone, they lose everything or must start over. There is no way to back up, restore, or transfer data.

## 3. User Stories

As a coach, I want to sign in with my Apple ID so I don't need to create yet another username and password.

As a team parent, I want my teams, rosters, and songs to sync to the cloud so I can access them from my iPad at home and my iPhone at the field.

As a coach, I want my data backed up automatically so I don't lose everything if I drop my phone in the dugout.

As a user, I want the app to still work fully offline — sync should happen in the background when I have connectivity, not block me from using the app.

As a user switching phones, I want to sign in on my new device and have all my teams, lineups, and songs download automatically.

## 4. Scope & Requirements

### 4.1. Authentication

| Requirement | Description |
| :--- | :--- |
| **Sign in with Apple** | Primary authentication method. Uses Apple's built-in `AuthenticationServices` framework. Minimal friction — users tap one button and authenticate with Face ID / Touch ID. No email/password to manage. |
| **Anonymous / Offline Mode** | The app must continue to function fully without sign-in. Users who never sign in keep the current local-only behavior. Sign-in is optional and prompted non-intrusively (e.g., a banner in Settings or after first team creation). |
| **Account Linking** | If a user has been using the app without an account and later signs in, all existing local data must be associated with their new account and uploaded. No data loss during the transition. |
| **Sign Out** | Signing out keeps a local copy of data on the device. Signing in on another device (or back on the same device) restores from the cloud. |
| **Account Deletion** | Per App Store requirements, users must be able to delete their account and all associated cloud data from within the app. Local data remains on-device after deletion. |

### 4.2. Backend & Cloud Storage

The strategy is to **launch iOS-only, then potentially expand to Android**. This means the backend choice must balance immediate simplicity with future portability. Two options are fully documented below.

---

#### Option A: CloudKit (iOS-Only Launch)

**Technology:** Apple's CloudKit framework with a private database per user.

| Aspect | Details |
| :--- | :--- |
| **Auth** | Sign in with Apple (built-in, one-tap). |
| **Structured Data** | CloudKit private database. Records for Team, Player, Lineup, StadiumData, UserSettings. |
| **Binary Assets** | `CKAsset` — songs and photos attached directly to records. 250MB per-asset limit (MP3s are typically 3-10MB). |
| **Offline Support** | Built-in. CloudKit caches records locally and syncs when connectivity returns. |
| **Conflict Resolution** | Server-side timestamps. Last-write-wins out of the box. |
| **Cost** | Free — 1PB aggregate asset storage, 10TB database storage, 200GB/month transfer across all users. |
| **Sync** | `CKDatabaseSubscription` + silent push notifications for real-time delta sync. |
| **Setup Effort** | Minimal. Enable CloudKit in Xcode capabilities. Define record types. No server to deploy or maintain. |

**Pros:**
- Zero backend cost, zero infrastructure to manage
- Native Swift SDK, deeply integrated with iOS
- Binary assets handled natively (no separate storage service)
- Sign in with Apple works seamlessly
- Built-in offline caching and conflict resolution

**Cons:**
- Apple-only — no path to Android without a full backend rewrite
- Limited query capabilities vs. a traditional database
- If Android becomes a priority, all sync code must be replaced

**Migration path to Android:** If Android is needed later, CloudKit data would need to be exported and migrated to a cross-platform backend (Firebase or custom). The local data models and sync logic would be rewritten. The iOS app would also need to be updated to use the new backend. This is a significant effort but feasible since the data model is simple.

---

#### Option B: Firebase (Cross-Platform Ready)

**Technology:** Firebase Auth + Cloud Firestore + Firebase Cloud Storage.

| Aspect | Details |
| :--- | :--- |
| **Auth** | Firebase Auth with Sign in with Apple provider (iOS). Google Sign-In, email/password, or other providers can be added later for Android. |
| **Structured Data** | Cloud Firestore — NoSQL document database. Collections for teams, players, lineups, stadiumData, userSettings. |
| **Binary Assets** | Firebase Cloud Storage (backed by Google Cloud Storage). Songs and photos uploaded as files, referenced by URL in Firestore documents. |
| **Offline Support** | Firestore has built-in offline persistence on both iOS and Android. Queued writes sync when online. |
| **Conflict Resolution** | Firestore transactions or last-write-wins via server timestamps. |
| **Cost** | Free tier (Spark plan): 1GB Firestore storage, 5GB Cloud Storage, 10GB/month transfer. Blaze (pay-as-you-go) beyond that — ~$0.026/GB/month for storage, $0.12/GB for transfer. |
| **Sync** | Firestore real-time listeners for instant sync across devices. |
| **Setup Effort** | Moderate. Create Firebase project, add `GoogleService-Info.plist`, integrate Firebase SDK via SPM, configure storage rules. |

**Pros:**
- Cross-platform from day one — same backend serves iOS and Android
- Firestore real-time listeners are excellent for sync
- Mature ecosystem with good documentation
- Sign in with Apple works as a Firebase Auth provider
- Easy to add Google Sign-In, email/password later for Android users

**Cons:**
- Adds a Google SDK dependency (~10MB to app size)
- Binary storage costs money beyond 5GB free tier (a team with 15 songs ≈ 75-150MB; 100 users ≈ 7.5-15GB → ~$0.20-0.40/month)
- Slightly more configuration (storage security rules, Firestore indexes)
- Requires a Firebase project and Google Cloud account

**Cost projection at scale:**

| Users | Avg Songs/User | Storage | Monthly Cost |
| :--- | :--- | :--- | :--- |
| 100 | 15 (~7MB each) | ~10 GB | ~$0.50 |
| 1,000 | 15 | ~100 GB | ~$3.00 |
| 10,000 | 15 | ~1 TB | ~$26.00 |
| 100,000 | 15 | ~10 TB | ~$260.00 |

---

#### Recommendation: Phased Approach

**Phase 1 (iOS Launch):** Start with **CloudKit**. It's free, requires no backend infrastructure, and provides the best native iOS experience. Ship the feature faster with less complexity.

**Phase 2 (Android Expansion):** If/when Android becomes a priority, migrate to **Firebase**. The migration plan:
1. Build the Firebase backend and Android app simultaneously
2. Add Firebase SDK to the iOS app alongside CloudKit
3. Run a migration period: iOS app reads from CloudKit, writes to both CloudKit and Firebase
4. Once all users have migrated, remove CloudKit dependency from iOS
5. Both platforms now share Firebase as the single backend

This phased approach avoids paying for Firebase infrastructure before there are enough users to justify it, while keeping the Android door open.

**Alternative:** If there is strong conviction that Android will happen within 6 months, skip CloudKit and go straight to Firebase. The extra setup cost is modest and avoids the migration effort later.

### 4.3. Data Schema — What Gets Synced

| Data Type | Current Storage | Cloud Record Type | Binary Assets | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Teams** | `teams.json` | `Team` record | Team photo (JPEG) | Name, color, photo, creation date |
| **Players** | `players.json` | `Player` record | Player photo (JPEG), Walk-up song (MP3) | Linked to Team via `teamId` reference |
| **Lineups** | `lineups.json` | `Lineup` record | None | Ordered array of Player references |
| **Stadium Data** | `stadium_<id>.json` | `StadiumData` record | Soundboard MP3s, Inning break MP3s, Warm-up MP3s | Linked to Team. Multiple binary assets per record. |
| **App Settings** | `settings.json` | `UserSettings` record | None | Global settings, synced per-user |
| **Active Team** | `activeTeam.json` | Not synced | None | Device-local preference only |

### 4.4. Sync Architecture

| Requirement | Description |
| :--- | :--- |
| **Offline-First** | The app always reads/writes to local storage first. Sync happens asynchronously in the background. The user never waits for a network call to use the app. |
| **Conflict Resolution** | Last-write-wins for simple fields (name, jersey number, settings). For binary assets (songs, photos), the most recent upload wins. CloudKit provides server-side timestamps for this. |
| **Delta Sync** | Only changed records sync — not the entire dataset. CloudKit subscriptions notify the app of remote changes. |
| **Initial Sync (New Device)** | On first sign-in on a new device, all records and assets download. Large binary downloads (songs) should happen progressively with a progress indicator. |
| **Background Sync** | Use `CKDatabaseSubscription` and background push notifications to sync when the app is not in the foreground. |
| **Asset Size Limits** | MP3 files are typically 3-10MB. Photos are ~50-200KB (already JPEG compressed). Well within CloudKit's 250MB per-asset limit. A team with 15 players and songs would use roughly 75-150MB of cloud storage. |

### 4.5. UI/UX Additions

| Screen | Changes |
| :--- | :--- |
| **Settings** | Add "Account" section at top: Sign in with Apple button (if signed out), or account info + Sign Out / Delete Account (if signed in). Sync status indicator (last synced, syncing, error). |
| **First Launch / Welcome** | Add optional "Sign in with Apple" below the "Create Team" button. Skip option clearly visible. |
| **Sync Indicator** | Small cloud icon in navigation bar or tab bar showing sync status. Unobtrusive — no blocking modals. |
| **New Device Flow** | After sign-in on a fresh install, show "Restoring your data..." with progress bar for binary asset downloads. User can start using the app immediately with metadata while songs download in background. |

## 5. Technical Implementation Phases

### Phase 1: Authentication (1-2 plans)
- Integrate Sign in with Apple via `AuthenticationServices`
- Store user identifier in Keychain
- Add Account section to Settings screen
- Anonymous-to-authenticated account linking (associate local data with Apple ID)

### Phase 2: CloudKit Schema & Core Sync (2-3 plans)
- Define CloudKit record types matching local models
- Build `SyncManager` service: upload, download, delta tracking
- Implement `CKRecord` ↔ local model conversion
- Handle binary asset (CKAsset) upload/download for songs and photos

### Phase 3: Background Sync & Conflict Resolution (1-2 plans)
- Subscribe to remote changes via `CKDatabaseSubscription`
- Background push notification handling
- Conflict resolution (last-write-wins with timestamps)
- Retry logic for failed uploads

### Phase 4: Multi-Device UX (1 plan)
- New device restore flow with progress UI
- Sync status indicator
- Handle edge cases: sign out, account deletion, storage limits

## 6. Settings & Configuration

| Setting | Description | Default |
| :--- | :--- | :--- |
| **Sync Enabled** | Toggle to enable/disable cloud sync (for users who want local-only even with an account) | Enabled (when signed in) |
| **Sync Over Cellular** | Allow syncing binary assets (songs) over cellular data | Disabled |
| **Last Synced** | Display-only timestamp of the last successful sync | — |

## 7. Privacy & Compliance

| Requirement | Description |
| :--- | :--- |
| **App Privacy Nutrition Label** | Must declare: Name (from Apple ID), Identifiers (Apple user ID). Data is linked to identity. Used for app functionality only, not tracking. |
| **Data Storage Disclosure** | CloudKit private database — Apple stores the data but cannot read it. Each user's data is isolated. |
| **Account Deletion** | Must fully delete all CloudKit records and assets when user requests account deletion. Use `CKDatabase.delete()` for all record types. |
| **COPPA Considerations** | If the app is used by minors (youth baseball), the account holder is the parent/coach, not the child. No child-specific data collection. |

## 8. Cost Considerations

### CloudKit (Phase 1)
**Entirely free.** Apple provides per-app limits shared across all users:
- 1 PB total asset storage
- 10 TB database storage
- 200 GB data transfer per month

For HypeDeck's use case, this free tier is more than sufficient indefinitely.

### Firebase (Phase 2 — if Android expansion)
**Free to start, low cost at scale:**
- Free tier covers first ~100 users comfortably (5GB storage, 10GB/month transfer)
- At 1,000 users: ~$3/month
- At 10,000 users: ~$26/month
- At 100,000 users: ~$260/month

Firebase costs are driven almost entirely by binary storage (songs). Firestore document reads/writes are negligible for this use case.

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
| :--- | :--- | :--- |
| **Large song library exceeding CloudKit transfer limits** | Sync failures, slow restores | Compress songs before upload. Progressive download. Sync-over-WiFi-only default. |
| **Merge conflicts when editing on two devices simultaneously** | Data inconsistency | Last-write-wins is acceptable for this use case. Users are typically one person managing one team at a time. |
| **User never signs in** | No backup, no multi-device | App works fully without an account. This is the current behavior and is acceptable. |
| **Apple deprecates CloudKit** | Backend migration needed | Extremely unlikely given iCloud's centrality to Apple's ecosystem. If needed, migration to Firebase would be straightforward since the data model is simple. |

## 10. Future Enhancements (Out of Scope for V1)

- **Team Sharing:** Invite another user (e.g., assistant coach) to view/edit a team's roster and lineups via CloudKit shared databases.
- **Export/Import:** Export team data as a file bundle for manual transfer.
- **iPad App:** With cloud sync in place, an iPad version with a wider layout becomes more valuable.
- **watchOS Companion:** Simple remote control for play/stop from an Apple Watch, leveraging the synced data.
