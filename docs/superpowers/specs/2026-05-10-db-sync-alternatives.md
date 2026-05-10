# DB Sync — 3 Architectural Alternatives

> Sketch. Not a spec. Goal: pick a path before any code lands.
> Context: merging Humane Tracker (web PWA, Dexie + IndexedDB + Dexie Cloud) into Context Grabber (iOS / Expo / SQLite). The journal — affirmations, did-its, gratitudes — is the v1 surface. Sync needs to handle text entries today, voice blobs eventually.

## TL;DR table

|  | **A — Dexie Cloud REST** | **B — CloudKit** | **C — iCloud Drive JSON** |
|---|---|---|---|
| Web app stays alive? | ✅ yes, both stay in sync | ❌ no, sunset | 🟡 partial, brittle |
| iPad ↔ iPhone sync? | ✅ via Dexie Cloud | ✅ via iCloud account | ✅ via iCloud Drive |
| Real-time? | ~5s pull poll, push immediate | ~2s push notification | minutes; manual on web |
| Auth UI on iOS? | Google sign-in | none (silent iCloud) | none |
| Conflict resolution | Dexie's CRDT-ish merge | CloudKit server merge | last-write-wins |
| Voice blobs ride along? | manual — needs blob host | ✅ CKAsset built-in | 🟡 file embed, large |
| Native deploy needed? | once (URL scheme + auth) | once (entitlement + container) | none — pure JS |
| Effort to ship | ~2–3 weeks | ~1 week | ~2–3 days |
| Failure mode | "Dexie Cloud is down" | "your iCloud is full" | "I overwrote my morning entries" |

---

## Alternative A — Dexie Cloud REST from iOS

```
┌─────────────────┐       HTTPS         ┌──────────────────┐
│ Humane Tracker  │ ──────────────────► │                  │
│ (Web PWA)       │ ◄────────────────── │   Dexie Cloud    │
│ Dexie+IndexedDB │   sync protocol     │   (managed SaaS) │
└─────────────────┘                     │                  │
                                        │  affirmationLogs │
┌─────────────────┐    REST + auth      │  audioRecordings │
│ Context Grabber │ ──────────────────► │  habits          │
│ (iOS / RN)      │ ◄────────────────── │  entries         │
│ SQLite mirror   │   custom adapter    │                  │
└─────────────────┘                     └──────────────────┘
       ▲                                          ▲
       │                                          │
       └────── local writes queue ─────────┐      │
                                           │      │
                                Outbound push (PUT /tables/...)
                                Inbound pull  (GET /tables/...?since=cursor)
```

**Why pick A:** Igor keeps the web app alive. Logging from a desktop browser at work still flows to the phone. One source of truth. Existing Humane Tracker users (you) get zero migration friction.

**Why avoid A:**
- Nobody ships Dexie Cloud from React Native today; the official SDK is browser-only. We'd be writing a custom REST/sync adapter against a protocol that's primarily designed for the JS SDK.
- Dexie Cloud doesn't host audio blobs efficiently — voice notes need separate cloud storage (S3, Cloudflare R2) or stay device-local.
- Auth UI surface (Google sign-in via `expo-auth-session`) is a real chunk of work and adds a sign-in gate the rest of Context Grabber doesn't have.
- Vendor lock-in to Dexie Cloud, which is a small managed SaaS. If it shuts down, we're rebuilding sync.

**What we'd build:**
1. **Spike** (2 hrs): Node script hits Dexie Cloud REST API with existing creds, pulls `affirmationLogs`. Confirms feasibility before committing.
2. **Auth**: `expo-auth-session` for Google sign-in. URL scheme + `Info.plist` change. **One-time native deploy.**
3. **Schema**: local SQLite tables mirroring Dexie Cloud's: `affirmationLogs`, `audioRecordings` (metadata only), `habits`, `entries`. Each row carries `realmId`, `userId`, `id`, `createdAt`, `updatedAt`.
4. **Sync engine**:
   - Pull since cursor on app foreground + after every local write.
   - Push outbound mutation queue with retry/backoff.
   - Honor Dexie's server-side conflict resolution.
5. **Audio**: ship without voice in v1; or pick a blob host (S3/Cloudflare R2 + presigned URLs) and add a `media_url` column.

**Risks to call out before committing:**
- Dexie Cloud's REST surface may not expose every table or operation the JS SDK uses; we may hit a feature wall.
- Mobile-network sync timing is a known hard problem. Plan for "user logs an entry on the subway" working correctly.

---

## Alternative B — CloudKit (iOS-native, drop the web)

```
┌────────────────────────┐                ┌────────────────────────┐
│ Context Grabber        │                │ Context Grabber        │
│ on iPhone              │                │ on iPad                │
│                        │                │                        │
│  Local SQLite          │                │  Local SQLite          │
│  + CloudKit sync layer │                │  + CloudKit sync layer │
└──────────┬─────────────┘                └──────────┬─────────────┘
           │                                         │
           │              CloudKit (free)            │
           └─────────────────┬───────────────────────┘
                             │
              ┌──────────────▼─────────────────┐
              │   iCloud (private DB, your     │
              │   Apple ID — no sign-in UI)    │
              │                                │
              │   AffirmationLog: CKRecord     │
              │   AudioRecording: CKAsset      │
              │   Habit: CKRecord              │
              │   HabitEntry: CKRecord         │
              └────────────────────────────────┘

       Web app: read-only legacy or fully sunsetted.
       Once-imported existing journal data via JSON.
```

**Why pick B:**
- Cheapest path to working sync. CloudKit is a mature Apple framework; conflict resolution, offline queue, and audio blobs (CKAsset) are first-class.
- Zero auth UI — uses your iCloud account silently. Works the moment you sign into iCloud on the device.
- Voice notes ride along natively as CKAssets, no separate blob host.
- No third-party SaaS dependency. Apple-managed.

**Why avoid B:**
- The web app is dead to you. If you log a gratitude from your desktop browser, it doesn't reach the phone.
- Apple-only, ever. Android, web, anywhere-else are off the table for any future merge.
- Schema is locked to your private CloudKit container; collaborating with someone else's account or migrating off Apple later is painful.
- CloudKit subscription/notification setup needs careful native work (background fetch entitlement).

**What we'd build:**
1. **Native config** (one-time deploy): CloudKit entitlement, container ID, push notification setup for change subscriptions.
2. **CKRecord schema**: each SQLite table → CKRecordType. Generate a `recordID` per row, preserve `createdAt`/`updatedAt`.
3. **Sync layer**: a thin module wrapping CloudKit's `CKDatabaseOperation`s. On startup, fetch changes since last token; on local write, save record. Conflict policy: server wins on field-level merge (CloudKit default).
4. **Migration**: one-time JSON import from Humane Tracker backup creates initial CKRecords.
5. **Voice**: CKAsset attached to AffirmationLog records. Recording UX records to a temp file, attaches it on save.

**Risks to call out:**
- Background sync on iOS is reliability-flaky; CloudKit's silent push doesn't always wake the app, so we still need foreground-fetch on launch as the safety net.
- The first deploy of a CloudKit-enabled app to a fresh iCloud account creates the container's schema. Schema migrations later are painful — get the v1 schema right.

---

## Alternative C — iCloud Drive shared JSON file

```
┌────────────────────────┐
│ Context Grabber        │
│ on iPhone              │
│                        │
│  In-memory state       │
│  + writes to JSON      │
└──────────┬─────────────┘
           │ Files API
           ▼
┌────────────────────────────────────────────┐
│  iCloud Drive folder                       │
│  /Apps/Context Grabber/journal.json        │
│  - syncs to all your Apple devices         │
│  - downloadable on web (icloud.com)        │
└────────────┬───────────────────────────────┘
             │
             │ manual download/upload only
             ▼
┌────────────────────────┐
│ Humane Tracker (web)   │
│                        │
│ Manual import/export   │
│ (no live sync)         │
└────────────────────────┘
```

**Why pick C:**
- Trivial to ship. No auth, no native config, no SDK. Pure JS + `expo-file-system` writing to `documentDirectory` (which iOS auto-mirrors to iCloud Drive when configured).
- Zero ongoing infra. The file is just sitting in iCloud Drive.

**Why avoid C:**
- **Last-write-wins is dangerous.** Open the app on iPad in the morning, log 6 things; iPhone foregrounds in the afternoon with stale state, you log one more thing, save → all 6 morning entries are gone.
- No real-time. Phone and iPad don't see each other's writes until the file is fully re-read.
- Web app integration is fully manual — same as the existing JSON import/export, just stored on iCloud instead of email.
- Voice blobs blow up the JSON file size; you'd need a sidecar folder of audio files, which complicates the "single file" simplicity.

**What we'd build:**
1. Read+write `journal.json` in `expo-file-system`'s documents directory.
2. iCloud Drive container entitlement (still a deploy, technically) so the folder is visible in Files app + syncs.
3. On app foreground, re-read file before any UI render.
4. Audio: separate `voice/<id>.m4a` files in a sibling folder.

**Verdict:** I'd skip C. It's the cheapest to build but the cheapest reason — "I overwrote my entries" — is also the most painful to debug a month after launch when it's been silently corrupting data.

---

## Decision criteria

The fork is fundamentally **"is the web app a daily-use surface?"**

- **Yes, you log from desktop multiple times a week** → Option A. Pay the Dexie Cloud REST tax to keep both alive.
- **No, the phone is where the logging happens; web was just where the app started** → Option B. CloudKit is faster, simpler, more reliable, and CKAsset-handles voice for free.
- **You want to ship something this weekend and iterate** → Option C as scaffolding only, knowing you'll throw it away. Don't anchor on it.

## My recommendation

**Option B (CloudKit)** unless you push back. Reasoning:

1. The 2025-11-29 backup has zero affirmation logs in it. Either you're not actively using the journal feature on web, or you log on web but never back up — both suggest the web app's role is small.
2. CloudKit handles the hardest parts (offline queue, voice blobs via CKAsset, conflict resolution) for free.
3. Sunsetting the web app is fine — the merged spec already promises a JSON export so you can move data later if you change your mind.
4. ~1 week vs. ~3 weeks of build, with substantially lower risk on the unknowns.

**Action item to unblock:** confirm or push back on B. If confirmed, next step is a 30-min spike — generate a CloudKit container, define the four CKRecord types, write/read one record from a dev-build of Context Grabber on the phone. That spike requires the first `just deploy` (entitlement + container ID need to be in the binary).

If you'd rather sketch this on paper first, the gist version of this doc has the diagrams and the same trade-offs in one scrollable view.
