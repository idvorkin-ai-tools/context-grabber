# CloudKit Sync — Implementation Plan

Engineering plan for the sync transport described in [`2026-05-10-db-sync-alternatives.md`](../specs/2026-05-10-db-sync-alternatives.md) (Option B, CloudKit). Carries the journal data described in [`2026-05-10-affirmations-journal-design.md`](../specs/2026-05-10-affirmations-journal-design.md).

This doc holds file paths, types, and rollout. The spec holds behavior.

## Decision: use `expo-cloudkit` instead of rolling our own native module

We already have a custom-Swift bridge pattern in `ios/ContextGrabber/WidgetBridge.swift` + `WidgetBridge.m`. Building a `CloudKitBridge` the same way is feasible — but `expo-cloudkit` v0.20.8 (published ~1 month ago, MIT, no deps, actively maintained) gives us:

- TypeScript-first `async/await` API for record CRUD, zones, assets, sync.
- CKSyncEngine on iOS 17+, `CKFetchRecordZoneChangesOperation` polling fallback on iOS 16.
- Asset upload/download for voice blobs (the killer feature).
- Background sync via `BGTaskScheduler`.
- Config plugin that adds the right entitlements and `Info.plist` keys automatically.

We accept the dependency. If maintenance lapses, the source is small (~1.4 MB unpacked) and we can fork.

## Landmines we're navigating

### Landmine 1: `expo prebuild` is forbidden in this repo

`CLAUDE.md` explicitly says **"Never run `expo prebuild` in `just deploy`"** — it wipes `DEVELOPMENT_TEAM` from `project.pbxproj` and creates duplicate file refs in the LiveActivity appex.

`expo-cloudkit`'s config plugin documentation says to run `expo prebuild --clean` after adding it. **We're not doing that.** Instead:

1. Install the npm package (autolinks the Pod).
2. **Manually patch** `ios/ContextGrabber/ContextGrabber.entitlements` to add CloudKit entries (matching what the config plugin would emit).
3. **Manually patch** `ios/ContextGrabber/Info.plist` for `UIBackgroundModes`.
4. Run `pod install` from `ios/` to pick up the new Pod.
5. Commit both the JS-side install and the manual native edits — diff is reviewable, no surprise deletions.

We still register the config plugin in `app.json` so future intentional `just resync-native` runs produce the same outcome.

### Landmine 2: CloudKit container needs Apple Developer registration

The `iCloud.com.idvorkin.contextgrabber` container ID isn't created by code. Two paths:

- **Auto-create via Xcode**: open the `.xcworkspace`, target → Signing & Capabilities → `+ Capability` → iCloud → check CloudKit → "Use Default Container". Xcode talks to Apple Developer and creates it. **Igor needs to do this once** because it requires his signed-in Xcode session.
- **Manual via Apple Developer portal**: developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → `+` → CloudKit Container → enter ID → save. Then add the container to the App ID's CloudKit capability.

The first path is faster. Plan: Igor runs Xcode once, confirms the container exists, then we proceed.

### Landmine 3: Free Apple Developer account may not support CloudKit

Free personal Apple Developer accounts have restricted entitlements. CloudKit *should* work on free accounts, but the 7-day expiry mentioned in `CLAUDE.md` suggests we may be on free. **Action: confirm with Igor before deploy** — if his account is free, the build fails at code-sign time with a "missing entitlement" error.

### Landmine 4: First deploy will require `just deploy`, not OTA

Adding the entitlement and Pod are native changes. The very first time we ship CloudKit support, it must be a full native build (`just deploy`). Subsequent JS-only changes ship via OTA.

## Phase split

| Phase | Scope | Delivery |
|---|---|---|
| **P0** | Spike: confirm `expo-cloudkit` can write+read a record on Igor's CloudKit container. No journal logic. | Native deploy (one-time scaffolding). |
| **P1** | Journal data model in SQLite + CloudKit. Bidirectional sync of text journal entries (no audio). Round-trippable JSON export gains journal block. | OTA after P0. |
| **P2** | Voice recording + CKAsset upload/download. Audio playback in journal. | OTA after P1. |
| **P3** | UX: dashboard "Reflect" zone, Affirmation Card, Grateful Card, Journal screen. | OTA after P2 (mostly UI). |
| **P4** | Humane Tracker JSON import → CloudKit. Backfill historical entries. | OTA after P3. |

P0 is the deploy-blocking phase. Everything else iterates over OTA.

## Phase 0 — Spike + native scaffolding

### Goal

Prove that on Igor's phone, with his Apple ID + Apple Developer account, calling `saveRecords()` and `fetchRecord()` against `iCloud.com.idvorkin.contextgrabber` succeeds, and the data round-trips between iPhone and iPad.

### Files touched

- `package.json` — add `expo-cloudkit` dep.
- `app.json` — register `expo-cloudkit` config plugin with container ID + dev environment for debug builds.
- `ios/ContextGrabber/ContextGrabber.entitlements` — add CloudKit entries:
  - `com.apple.developer.icloud-services` = `["CloudKit"]`
  - `com.apple.developer.icloud-container-identifiers` = `["iCloud.com.idvorkin.contextgrabber"]`
  - `com.apple.developer.icloud-container-environment` = `Development` (debug) / `Production` (release)
- `ios/ContextGrabber/Info.plist` — add `remote-notification` to `UIBackgroundModes` (required for push subscriptions).
- `ios/Podfile.lock` — auto-updated by `pod install`.
- `lib/cloudkit.ts` — **new** — thin wrapper around `expo-cloudkit`'s `configure()` + account status. Single entry point so future code doesn't import the SDK directly.
- `App.tsx` — call `configureCloudKit()` once at app boot, log account status to console.
- `components/CloudKitDebug.tsx` — **new, debug-only** — small dev-build-only screen with three buttons: "Save record", "Fetch record", "List zones". Used to validate the spike, removed (or hidden behind `__DEV__`) before P3.

### Sanity check

- **Container ID**: `iCloud.com.idvorkin.contextgrabber` (matches the existing app group prefix `group.com.idvorkin.contextgrabber`).
- **Bundle ID**: `com.idvorkin.contextgrabber` (already in `app.json`).
- **Team ID**: `7D4UQZDYU6` (already in `project.pbxproj`).

### Manual steps Igor needs to take

1. Open `ios/ContextGrabber.xcworkspace` in Xcode.
2. Select `ContextGrabber` target → Signing & Capabilities tab.
3. Click `+ Capability`, choose iCloud.
4. Under iCloud, check **CloudKit**.
5. Container list should show "Use Default Container" — pick that, OR click `+` and type `iCloud.com.idvorkin.contextgrabber`.
6. Verify the entitlements file Xcode wrote matches what we manually committed.
7. Confirm the team `7D4UQZDYU6` has CloudKit enabled (developer.apple.com → Identifiers → check our app).

### Acceptance for P0

- App builds and signs without entitlement errors.
- On launch, console logs `cloudkit account status: available`.
- Tapping "Save record" in the debug screen creates a `SpikeRecord` with field `now: <timestamp>`.
- Tapping "Fetch record" on iPad (after iPhone saved) returns the same timestamp within ~10 seconds.
- App functions normally for users not signed into iCloud (status `noAccount` → sync silently disabled, no crashes).

## Phase 1 — Journal data model + text sync

### Schema

#### CloudKit record types

```
JournalEntry
  recordType:     "JournalEntry"
  zoneName:       "JournalZone"
  fields:
    entryId:           string (uuid, also our SQLite primary key)
    date:              date (when the entry was logged, local time of logging)
    context:           string ("opportunity" | "didit" | "grateful")
    affirmationTitle:  string ("Do It Anyways" | "An Essentialist" | "A Class Act" | "Calm Like Water" | "Grateful")
    text:              string (the freeform note; "" if voice-only)
    audioRecordId:     string? (recordName of paired AudioRecording, null if text-only)
    createdAt:         date (server-set on first save)

AudioRecording
  recordType:     "AudioRecording"
  zoneName:       "JournalZone"
  fields:
    recordingId:       string (uuid)
    asset:             CKAsset (the .m4a file)
    durationMs:        number
    createdAt:         date
```

A custom zone (`JournalZone`) is required for delta-fetch via `CKFetchRecordZoneChangesOperation` / `CKSyncEngine`. The `_defaultZone` doesn't support change tracking.

#### SQLite mirror

```sql
CREATE TABLE journal_entries (
  id            TEXT PRIMARY KEY,            -- entryId
  date          INTEGER NOT NULL,            -- unix ms
  context       TEXT NOT NULL,
  affirmation   TEXT NOT NULL,
  text          TEXT NOT NULL DEFAULT '',
  audio_id      TEXT,                        -- FK to audio_recordings, null if text-only
  created_at    INTEGER NOT NULL,
  ck_record_name  TEXT,                      -- CKRecord.recordName, null until first sync
  ck_change_tag   TEXT,                      -- last server changeTag, for conflict detection
  sync_state    TEXT NOT NULL DEFAULT 'pending'  -- 'pending' | 'synced' | 'failed'
);
CREATE INDEX idx_journal_date ON journal_entries(date);
CREATE INDEX idx_journal_sync ON journal_entries(sync_state);

CREATE TABLE audio_recordings (
  id            TEXT PRIMARY KEY,
  file_path     TEXT NOT NULL,               -- local file path under documents/
  duration_ms   INTEGER NOT NULL,
  created_at    INTEGER NOT NULL,
  ck_record_name  TEXT,
  ck_change_tag   TEXT,
  sync_state    TEXT NOT NULL DEFAULT 'pending'
);
```

### Files touched

- `lib/journalDb.ts` — **new** — SQLite CRUD for `journal_entries`. Mirrors patterns in existing `lib/healthCache.ts`.
- `lib/audioDb.ts` — **new** (P2 will fill in audio details; for P1 just the table create).
- `lib/cloudkit.ts` — extend with `pushPending()`, `pullChanges()`, `startSync()`, helpers for record↔SQLite mapping.
- `lib/journal.ts` — **new** — pure functions for journal grouping (date → context → affirmation), entry creation.
- `__tests__/journal.test.ts` — **new** — pure-function coverage for grouping + entry creation.
- `App.tsx` — call `startSync()` after `configureCloudKit()`.

### Sync engine shape

P1 uses **manual polling**, not CKSyncEngine, to keep the iOS 16 path identical to iOS 17:

- On app foreground: `pullChanges()` — `CKFetchRecordZoneChangesOperation` since stored token, upsert into SQLite.
- On local write (insert/update/delete): write to SQLite first, mark `sync_state = 'pending'`, then `pushPending()` — `CKModifyRecordsOperation` with all pending rows.
- On `pushPending()` success: update SQLite with returned `recordName` + `changeTag`, set `sync_state = 'synced'`.
- On `pushPending()` failure: keep `sync_state = 'pending'`, retry on next foreground.

Conflict resolution: server wins on field-level. If our `pushPending()` includes a stale `changeTag`, server returns the current record; we merge our local fields into it with last-write-wins on `text`.

P2 may upgrade to CKSyncEngine if iOS 17 adoption justifies it.

### Acceptance for P1

- A new entry created on iPhone appears on iPad within ~30s of foregrounding the iPad app.
- Deleting an entry on iPad removes it from iPhone within ~30s of foregrounding.
- Force-quit immediately after creating an entry: on relaunch, the entry is in SQLite and gets pushed to CloudKit on next foreground.
- `Grab Context` JSON includes the journal block: text entries with `text` field populated, `audio` field omitted (P2 work).

## Phase 2 — Voice recording + CKAsset

### Files touched

- `components/VoiceRecorder.tsx` — **new** — uses `react-native-audio-api` to record `.m4a` to `documents/voice/<uuid>.m4a`.
- `components/AudioPlayer.tsx` — **new** — playback for stored recordings.
- `lib/audioDb.ts` — full CRUD.
- `lib/cloudkit.ts` — `uploadAsset()`, `downloadAsset()` for paired `AudioRecording` records.

### CKAsset handling

`expo-cloudkit` exposes assets as file URIs. Upload: pass local file URI in record field. Download: `downloadAsset()` returns a local cached path.

We download lazily — voice clips don't pull onto iPad until the user taps play. Saves bandwidth and storage.

### Acceptance for P2

- Record a 5s voice note on iPhone, save. Within ~30s, iPad's journal shows the entry with the voice player; tapping play streams the audio.
- Force-quit during upload: clip stays in SQLite as `pending`, retries on next foreground.

## Phase 3 — UX (dashboard zone + cards + journal screen)

Mostly mechanical from the spec. Files:

- `App.tsx` — add Reflect zone with three buttons.
- `components/AffirmationCard.tsx` — bottom sheet: rotating affirmation, Opportunity/Did-It buttons, mic + text field.
- `components/GratefulCard.tsx` — bottom sheet: prompt + mic + text field.
- `components/JournalScreen.tsx` — full-screen sheet with date → context → affirmation grouping, collapsible.
- `lib/affirmations.ts` — **new** — the four canonical affirmations + random rotation logic (matches Humane Tracker `getRandomIndex`).

### Affirmation rotation

```ts
// lib/affirmations.ts
export const AFFIRMATIONS = [
  { title: "Do It Anyways",  subtitle: "Deliberate. Disciplined. Daily." },
  { title: "An Essentialist",subtitle: "Know Essential. Give Context. Prioritize Ruthlessly." },
  { title: "A Class Act",    subtitle: "First Understand. Appreciate. Isn't that Curious." },
  { title: "Calm Like Water",subtitle: "Be Present. This too shall pass. Work the problem." },
];

export function getRandomIndex(currentIndex?: number): number {
  if (AFFIRMATIONS.length <= 1) return 0;
  let n: number;
  do { n = Math.floor(Math.random() * AFFIRMATIONS.length); } while (n === currentIndex);
  return n;
}
```

Lifted directly from `humane-tracker/src/components/AffirmationCard.tsx:13–20`. Tests should match Humane Tracker's tests.

## Phase 4 — Humane Tracker import

`lib/humaneImport.ts` — **new** — parses Humane Tracker JSON backup, inserts into `journal_entries`, marks `sync_state = 'pending'`. Next foreground push uploads everything to CloudKit.

Voice blob handling: if the backup contains audio Blobs as base64, decode to `documents/voice/<uuid>.m4a`, create `audio_recordings` row, mark for upload. If the backup omits blob data (most do — they're large), import metadata only and show "audio file not in backup" placeholder.

## Rollout sequence

1. Igor opens Xcode, adds CloudKit capability, confirms container created. Reports back.
2. **Commit + deploy P0**: `npm install`, manual entitlement edits, `pod install`, `just deploy`.
3. Validate on iPhone: account status reads `available`, debug-screen save+fetch round-trips.
4. Validate on iPad: same record fetched.
5. **Commit + OTA P1**: schema, mirror, sync engine. Test by creating a few entries via debug screen.
6. **Commit + OTA P2**: voice recording, CKAsset.
7. **Commit + OTA P3**: real UX. Affirmation Card + Grateful Card + Journal screen.
8. **Commit + OTA P4**: Humane Tracker import.

Total: 1 deploy (P0), then 4 OTA cycles.

## Open questions deferred to execution

- **Account status `noAccount` UX**: silently disable sync, or show a one-time toast suggesting iCloud sign-in? Default: silent. (Add toast later if it matters.)
- **Sync error UX**: if `pushPending()` fails repeatedly, surface in the About screen? Default: silent retry, log to console; add UI when an actual failure mode appears in practice.
- **Schema migration**: SQLite schema changes will need cache version bumps similar to existing `health_cache_meta.cache_version`. Reuse that pattern.
- **Background sync**: `backgroundSyncTaskIdentifier` is in `expo-cloudkit`'s plugin options; defer to P5 if foreground-fetch isn't enough.
