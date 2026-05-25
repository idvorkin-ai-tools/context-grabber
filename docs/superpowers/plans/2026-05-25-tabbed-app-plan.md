# Tabbed App + Roles — Implementation Plan

**Spec:** [`docs/superpowers/specs/2026-05-25-tabbed-app-design.md`](../specs/2026-05-25-tabbed-app-design.md)
**Date:** 2026-05-25

This plan covers the engineering work to ship the spec. **The spec is the source of truth for behavior.** This plan picks file structure, types, and the PR rollout.

## Where this data lives

**Today's storage reality:**

| Data | SQLite (device-local) | CloudKit (cross-device) |
|---|---|---|
| Locations, settings, known places | ✓ | ✗ |
| Health cache (computed + raw) | ✓ | ✗ |
| Journal entries + audio | ✓ (mirror) | ✓ (source of truth, `iCloud.com.idvorkin.contextgrabber` private DB, JournalZone) |

**New tables in this plan sync via CloudKit from v1.** `role_intentions`, `role_moments`, and `mood_log` all live in SQLite as the local mirror + outbound write queue, with CloudKit as source of truth across devices — mirroring the journal sync pattern in `lib/cloudkit.ts`.

Per-table sync policy:
- **`role_intentions` — full sync.** One record per (role, week). New record type `RoleIntention`. Conflict: last-write-wins.
- **`role_moments` — sync only `source = 'manual'` rows.** Auto-detected moments derive from HealthKit/location data already present on each device, so they re-derive locally and don't need to cross the wire. Only manual tags require cross-device. New record type `RoleMoment`. Conflict: last-write-wins on `(role_id, timestamp, what)`.
- **`mood_log` — full sync.** One record per date. New record type `MoodEntry`. Conflict: last-write-wins on `date`.

All three reuse the existing `JournalZone` private zone — zones are private to the user and there's no benefit to splitting. The existing foreground-sync flow that already runs `syncJournal` gets three new calls: `syncIntentions`, `syncRoleMoments`, `syncMood`.

## TypeScript only — no native changes

**Everything in this plan is JS/TS.** No `expo prebuild`, no Pods, no new native modules, no Xcode work, no Apple Maps keys. Charts and visualizations follow the existing project pattern: pure `View` + `StyleSheet` + `transform` (see `LineChart.tsx`, `BarChart.tsx`, `RecoverySparkline.tsx`, `ActivityTimeline.tsx`). The constellation, year heatmap, week strips, and sparklines are all absolute-positioned `View`s with `borderRadius` / `transform: rotate` for non-rect shapes. No `react-native-svg`.

Ship path is `just ota` for every PR after the first. PR-1 should also be OTA-eligible — verify before flipping the channel.

## Pre-work decisions

| Question | Decision | Rationale |
|---|---|---|
| Navigation library | Hand-rolled tab state in App.tsx | App.tsx is already one file with all data effects; react-navigation pulls in a lot for what amounts to a tab index. Revisit if we add deep nav (push screens, modals with backstack). |
| Icon system | **No icon library.** Render small labels as text ("7", "A", "Z"); fall back to small bundled PNGs in `assets/role-icons/` if a glyph really needs to be pictographic. | Matches current app convention (no icon imports anywhere). Avoids fonts or SVG transformer pipelines. |
| Role illustrations | **Bundle** raccoon images into `assets/raccoons/raccoon-*.webp` and reference via `require()` | Offline-first; doesn't break when idvork.in moves; ~30–60 KB each so total adds maybe 400 KB. RN `<Image>` handles WebP natively on iOS. |
| Map | View-based stylized rendering: a colored `View` block with absolute-positioned circles for pins. Looks like a map, isn't one. | No Apple Maps key, no react-native-maps. Real map is a v2 conversation. |
| Charts (sparklines, heatmap, constellation) | Pure `View` + `transform` per the existing `LineChart`/`BarChart`/`RecoverySparkline` pattern | Zero new deps. |
| SQLite migrations | Bump `schema_version` setting + idempotent CREATE TABLE IF NOT EXISTS for new tables | Matches existing `initDB` pattern. |

---

## Module structure (after this work)

```
context-grabber/
├── App.tsx                              # Thin shell: data effects + tab state + <TabBar>
├── screens/                             # NEW
│   ├── TodayScreen.tsx
│   ├── BodyScreen.tsx
│   ├── MoveScreen.tsx
│   ├── MindScreen.tsx
│   ├── PlacesScreen.tsx
│   ├── RolesScreen.tsx
│   └── RoleDetailSheet.tsx
├── components/
│   ├── TabBar.tsx                       # NEW
│   ├── RoleAvatar.tsx                   # NEW
│   ├── RoleConstellation.tsx            # NEW
│   ├── RoleYearHeatmap.tsx              # NEW
│   ├── RoleRow.tsx                      # NEW
│   ├── RoleAttentionCard.tsx            # NEW
│   ├── IntentionComposer.tsx            # NEW
│   ├── WeekStrip.tsx                    # NEW (used in Today + Body)
│   ├── MoodReportCard.tsx               # NEW
│   ├── MeditationFlatlineCard.tsx       # NEW
│   ├── StylizedMap.tsx                  # NEW (Places)
│   └── … existing components untouched …
├── lib/
│   ├── roles.ts                         # NEW: role defs + signal aggregation
│   ├── roleAttention.ts                 # NEW: attention rules
│   ├── roleMoments.ts                   # NEW: SQLite read/write for tags
│   ├── intentions.ts                    # NEW: SQLite read/write for intentions
│   ├── moodLog.ts                       # NEW: SQLite read/write for mood
│   ├── db.ts                            # CHANGED: add 3 new tables, bump schema_version
│   ├── share.ts                         # CHANGED: prepend roles section to export
│   └── … existing lib untouched …
└── assets/raccoons/                     # NEW: bundled illustrations
```

---

## Types

### `lib/roles.ts`

```ts
export type RoleId =
  | "smiles" | "carfree" | "habits" | "fit" | "emo"
  | "tech" | "pro" | "family" | "tori" | "amelia" | "zach";

export type RoleDef = {
  id: RoleId;
  name: string;                          // "Husband to Tori"
  short: string;                         // "Husband · Tori"
  color: string;                         // #hex
  raccoon: any | null;                   // require() of bundled webp, or null
  iconFallback: string;                  // tabler icon name when raccoon is null
  eulogyPassage: string;                 // verbatim from idvork.in/eulogy
  eulogyMarkers: string[];               // 3-5 identity-marker phrases
  attentionThresholdDays: number;        // 5 for fit, 7 for husband, 3 for emo, …
};

export const ROLES: ReadonlyArray<RoleDef>;

// This-week activity summary, computed from existing data + role_moments table.
export type RoleWeekActivity = {
  roleId: RoleId;
  score: 0 to 100;                       // weighted blend of signals
  bars: number[];                        // 7 daily intensity values for the bar strip
  signals: Array<{ label: string; value: string; trend?: string; last: string }>;
  activityLine: string;                  // "3 gym · 6 days weighed · 7.1h avg"
  lastShownIso: string | null;           // ISO date of last contributing event
  daysSinceLastShown: number | null;
  attention: { flagged: boolean; reason: string | null };
};

export type RoleYearActivity = {
  roleId: RoleId;
  weeks: number[];                       // 52 values, 0-100
};

export function computeWeekActivity(
  roleId: RoleId,
  ctx: {
    health: WeeklyDataMap;
    moments: RoleMoment[];
    places: PlacesSummary | null;
    now: Date;
  },
): RoleWeekActivity;

export function computeYearActivity(
  roleId: RoleId,
  ctx: { /* same shape, but 52-week history */ },
): RoleYearActivity;
```

### `lib/roleMoments.ts`

```ts
export type RoleMoment = {
  id: string;                            // uuid
  roleId: RoleId;
  timestamp: number;                     // unix ms
  what: string;                          // one-line caption
  tag: string;                           // optional sub-tag ("gym", "photo", "date")
  source: "manual" | "auto-workout" | "auto-mindful" | "auto-grateful" | "auto-place";
  sourceRef: string | null;              // optional reference into existing entity
};

export function insertMoment(db, m: Omit<RoleMoment, "id">): Promise<string>;
export function getMomentsInRange(db, from: number, to: number): Promise<RoleMoment[]>;
export function getMomentsForRole(db, roleId: RoleId, limit: number): Promise<RoleMoment[]>;
export function deleteMoment(db, id: string): Promise<void>;
```

### `lib/intentions.ts`

```ts
export type Intention = {
  id: string;
  roleId: RoleId;
  weekStartDate: string;                 // YYYY-MM-DD (Monday)
  text: string;
  createdAt: number;
};

export function setIntention(db, roleId: RoleId, text: string): Promise<void>;
export function getIntentionsForWeek(db, weekStart: string): Promise<Intention[]>;
export function getCurrentWeekIntentions(db): Promise<Intention[]>;
```

### `lib/moodLog.ts`

```ts
export type MoodEntry = {
  date: string;                          // YYYY-MM-DD (local)
  energy: 1 | 2 | 3 | 4 | 5;
  mood: 1 | 2 | 3 | 4 | 5;
  note: string | null;
};

export function logMood(db, entry: MoodEntry): Promise<void>;
export function getMoodForDate(db, date: string): Promise<MoodEntry | null>;
export function getMoodRange(db, days: number): Promise<MoodEntry[]>;
```

---

## SQLite schema additions

Add to `lib/db.ts` `initDB`, after the existing CREATE TABLE block:

```sql
CREATE TABLE IF NOT EXISTS role_moments (
  id TEXT PRIMARY KEY,
  role_id TEXT NOT NULL,
  timestamp INTEGER NOT NULL,
  what TEXT NOT NULL,
  tag TEXT,
  source TEXT NOT NULL,
  source_ref TEXT,
  -- CloudKit sync (only source='manual' rows actually push)
  ck_record_name TEXT,
  ck_change_tag TEXT,
  sync_state TEXT NOT NULL DEFAULT 'pending'
);
CREATE INDEX IF NOT EXISTS idx_role_moments_role_time
  ON role_moments(role_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_role_moments_time
  ON role_moments(timestamp);
CREATE INDEX IF NOT EXISTS idx_role_moments_sync
  ON role_moments(sync_state);

CREATE TABLE IF NOT EXISTS role_intentions (
  id TEXT PRIMARY KEY,
  role_id TEXT NOT NULL,
  week_start_date TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  ck_record_name TEXT,
  ck_change_tag TEXT,
  sync_state TEXT NOT NULL DEFAULT 'pending',
  UNIQUE(role_id, week_start_date)
);
CREATE INDEX IF NOT EXISTS idx_intentions_sync
  ON role_intentions(sync_state);

CREATE TABLE IF NOT EXISTS mood_log (
  date TEXT PRIMARY KEY,
  energy INTEGER NOT NULL,
  mood INTEGER NOT NULL,
  note TEXT,
  ck_record_name TEXT,
  ck_change_tag TEXT,
  sync_state TEXT NOT NULL DEFAULT 'pending'
);
CREATE INDEX IF NOT EXISTS idx_mood_sync
  ON mood_log(sync_state);
```

Bump `schema_version` to `'2'` in the `INSERT OR IGNORE` block.

---

## PR rollout

Six PRs. Each shippable on its own, in order. **Spec stays valid through all of them** — they're just incremental implementations of the same spec.

### PR-1 · Tab shell (S — ~3h)

**Scope:** Add a tab bar. Move the existing home into `TodayScreen.tsx`. Stub the other 5 screens with placeholders.

**Files touched:**
- `App.tsx` — extract the existing render into `<TodayScreen>`; replace with `<TabShell>{currentScreen}</TabShell>`. Keep ALL existing data effects in App.tsx for now.
- `components/TabBar.tsx` — new. Bottom bar, 6 tabs, hand-rolled active state.
- `screens/TodayScreen.tsx` — receives data via props from App.tsx.
- `screens/{Body,Move,Mind,Places,Roles}Screen.tsx` — placeholder "Coming soon" text.

**Risk:** Big diff against App.tsx. Block other agents from App.tsx during this PR. Run `__tests__/App.test.tsx` and fix any selector regressions.

**Acceptance:** All existing functionality works from the Today tab. Tab bar visible. Other tabs render a stub.

**bd issues:** `cg-tabbar-shell`, `cg-today-extract`, `cg-stub-placeholder-tabs`

---

### PR-2 · Body tab (M — ~4h)

**Scope:** Move metric grid + week strip + MetricDetailSheet under Body. Fix the sleep card to show asleep + in-bed + efficiency. Surface HRV and resting heart rate as first-class cards.

**Files touched:**
- `screens/BodyScreen.tsx` — metric grid, WeekStrip, tap → MetricDetailSheet (existing component reused).
- `components/WeekStrip.tsx` — new. Pure presentational: 7 days, today highlight, optional per-day dot.
- `lib/sleep.ts` — verify `aggregateSleepDetailed` returns asleep+in-bed; surface in `weekly.ts` if not already there.
- `App.tsx` — strip metric-grid render code (now lives in BodyScreen).

**Risk:** Sleep math. The 25.2-hour bug needs to be confirmed fixed against `__tests__/fixtures/`. Add regression test in `sleep.test.ts` if missing.

**Acceptance:** All Body-tab criteria in the spec pass. `npm test` green.

**bd issues:** `cg-body-screen`, `cg-week-strip-component`, `cg-sleep-asleep-vs-inbed`

---

### PR-3 · Move tab (S — ~3h)

**Scope:** Move GymTimerScreen + WorkoutAnalysisScreen under Move. Add weekly exercise-minutes ring at top.

**Files touched:**
- `screens/MoveScreen.tsx` — preset grid, weekly ring, recent-workouts list (new view; data already in `lib/workoutAnalysis.ts`).
- `components/RingProgress.tsx` — new. Pure `View` ring built with two semicircles + `transform: rotate` (no SVG)—see `TallyCounter.tsx` for the same trick.
- `App.tsx` — strip the Gym Timer entry point from Today (now in Move).

**Risk:** None substantial. Reuses existing screens.

**Acceptance:** Move-tab criteria pass; current workouts navigable.

**bd issues:** `cg-move-screen`, `cg-ring-progress`, `cg-recent-workouts-list`

---

### PR-4 · Mind tab (M — ~4h)

**Scope:** Move Journal + Affirmation + Gratitude + Tally under Mind. Add meditation flatline card. Add mood/energy 1–5 self-report.

**Files touched:**
- `screens/MindScreen.tsx`
- `components/MeditationFlatlineCard.tsx` — uses `aggregateMeditation` from `lib/weekly.ts`.
- `components/MoodReportCard.tsx` — 1–5 buttons × 2 (mood, energy) + optional note. Persists via `lib/moodLog.ts`.
- `lib/moodLog.ts` — new module. Includes CloudKit sync columns from the start.
- `lib/cloudkit.ts` — extend with `syncMood(db)` mirroring `pushJournal`/`pullJournal` shape. Wire into the existing foreground sync flow.
- `lib/db.ts` — add `mood_log` table with `ck_record_name`/`ck_change_tag`/`sync_state` columns.
- `lib/__tests__/moodLog.test.ts` — read/write + range queries.
- `lib/__tests__/cloudkit-mood.test.ts` — push/pull/conflict for MoodEntry records.

**Risk:** New table + new CloudKit record type. Schema migration bump and a new MoodEntry record type in CloudKit. Verify on a real device that the CloudKit container schema gets the new type pushed (first sync may need a one-time write to register the record type).

**Acceptance:** Mind-tab criteria pass; mood persists across restart; mood entered on one device appears on another after foreground sync.

**bd issues:** `cg-mind-screen`, `cg-meditation-flatline`, `cg-mood-log`, `cg-mood-cloudkit-sync`, `cg-db-schema-v2`

---

### PR-5 · Places tab (S — ~3h)

**Scope:** Move location card + LocationDetailSheet content + retention settings under Places.

**Files touched:**
- `screens/PlacesScreen.tsx`
- `components/StylizedMap.tsx` — new. View-based: a colored backdrop + absolute-positioned circles for pins. No `react-native-maps`, no SVG.
- `App.tsx` — strip location-card render.

**Risk:** Background tracking permission UX — make sure the toggle still routes through the existing `Location.requestBackgroundPermissionsAsync()` flow.

**Acceptance:** Places-tab criteria pass; known places CRUD and retention controls work.

**bd issues:** `cg-places-screen`, `cg-stylized-map`, `cg-places-settings-row`

---

### PR-6 · Roles tab (L — 1–2 days)

**Scope:** The new tab. Lots of new code. Should ship behind a feature flag if you want to land it incrementally — `roles_tab_enabled` setting, default off for first install, opt-in via Settings.

**Files touched:**
- `screens/RolesScreen.tsx` — horizon switcher, constellation hero, attention list, all-roles list, weekly review card.
- `screens/RoleDetailSheet.tsx` — full-bleed sheet with eulogy passage, signals, year strip, suggested moments, intention composer, recent moments.
- `components/RoleAvatar.tsx` — bundles raccoon images + Tabler fallbacks. Sizes 22/32/40/56.
- `components/RoleConstellation.tsx` — absolute-positioned `View` dots; JS trig.
- `components/RoleYearHeatmap.tsx` — 11 × 52 grid of `View` cells.
- `components/RoleRow.tsx`, `components/RoleAttentionCard.tsx` — list-row components.
- `components/IntentionComposer.tsx` — textarea + save.
- `lib/roles.ts` — role defs (verbatim eulogy passages) + `computeWeekActivity` + `computeYearActivity`.
- `lib/roleAttention.ts` — attention rules per role.
- `lib/roleMoments.ts` — SQLite CRUD with `sync_state` columns from the start.
- `lib/intentions.ts` — SQLite CRUD with `sync_state` columns from the start.
- `lib/cloudkit.ts` — extend with `syncIntentions(db)` and `syncRoleMoments(db)` mirroring `pushJournal`/`pullJournal`. `syncRoleMoments` filters to `source = 'manual'` on the push side. Wire both into the existing foreground sync flow.
- `lib/db.ts` — add `role_moments`, `role_intentions` tables with `ck_record_name`/`ck_change_tag`/`sync_state` columns.
- `assets/raccoons/*.webp` — 7 bundled images. Resize source to ≤ 256px wide if originals are huge.
- `__tests__/roles.test.ts` — `computeWeekActivity` against fixture data.
- `__tests__/roleMoments.test.ts` — CRUD + range queries.
- `__tests__/roleAttention.test.ts` — attention rules.
- `__tests__/cloudkit-roles.test.ts` — push/pull/conflict for RoleIntention + RoleMoment records.

**Auto-detection wiring:**
- When a workout completes in `GymTimerScreen` → write a `role_moments` row with `roleId: "fit"`, `source: "auto-workout"`, `sourceRef: workout_id`.
- When a gratitude entry saves in `GratefulCard` → write a moment with `roleId: "emo"`, `source: "auto-grateful"`.
- When a journal entry saves → moment with `roleId: "emo"`, `source: "auto-journal"`.
- When a HealthKit mindful session is observed in the daily aggregate → ensure no duplicate, then write a moment with `roleId: "emo"`, `source: "auto-mindful"`. (Idempotency key: `mindful:${session.startTime}`.)
- When a location cluster matches a known place named "Office" / "Gym" / "Home" → daily aggregate at end-of-day writes one moment per match. Idempotency key: `place:${date}:${place.name}`.

**Manual tagging:**
- Add long-press handler on existing journal entry rows, workout rows, and Today event tiles. Opens a role picker (action sheet style or modal). On select, writes a moment with `source: "manual"`.

**Risk:** Heaviest PR. Year-data fixture work — computing 52 weeks of activity needs `healthCache` to have 52 weeks of data, which it won't on a fresh install. Spec: show a "Year view fills in over time" placeholder when fewer than 4 weeks of cached data exist.

**Acceptance:** All Roles-tab criteria in the spec pass. `bd cg-roles-tab` closed.

**bd issues:** `cg-roles-screen`, `cg-role-detail-sheet`, `cg-role-constellation`, `cg-role-year-heatmap`, `cg-role-avatar`, `cg-role-defs`, `cg-role-week-aggregator`, `cg-role-year-aggregator`, `cg-role-attention-rules`, `cg-role-moments-crud`, `cg-intentions-crud`, `cg-manual-tagging`, `cg-auto-tag-workouts`, `cg-auto-tag-gratitude`, `cg-auto-tag-mindful`, `cg-auto-tag-places`, `cg-cloudkit-intentions`, `cg-cloudkit-role-moments`, `cg-raccoon-assets`, `cg-roles-tests`

---

### PR-7 · Larry export with roles (S — ~2h)

**Scope:** Update `lib/share.ts` `buildSummaryExport` to prepend a roles section.

**Files touched:**
- `lib/share.ts` — new `buildRolesExportSection(weekActivities, intentions)` function.
- `lib/share.ts` — call it from `buildSummaryExport`; prepend result to the existing payload.
- `__tests__/share.test.ts` — snapshot of new shape.

**Risk:** Snapshot churn. Update the snapshot intentionally; verify the existing Larry-side parser tolerates the new lead section.

**Acceptance:** Export contains roles block at top; existing HealthKit + location blocks untouched.

**bd issues:** `cg-share-roles-section`, `cg-share-snapshot-update`

---

---

## Testing

Per project convention: pure functions only, tests in `__tests__/`.

New tests to add:
- `__tests__/roles.test.ts` — `computeWeekActivity` produces expected scores for fixture data; `computeYearActivity` returns 52 entries; attention thresholds fire as documented.
- `__tests__/roleMoments.test.ts` — CRUD + range queries.
- `__tests__/roleAttention.test.ts` — flatline detection, threshold edges.
- `__tests__/intentions.test.ts` — UNIQUE(role_id, week_start) constraint upserts.
- `__tests__/moodLog.test.ts` — read/write + range.
- `__tests__/share.test.ts` — extend with roles section snapshot.

Run `just test` after each PR. Maestro tests don't need to change — but worth adding a `.maestro/check-roles-tab.yaml` after PR-6 that verifies tab navigation and one role detail tap.

---

## Rollout

- PR-1 through PR-5 ship as a unit (the tabbed shell + reorg of existing surfaces). Single OTA.
- PR-6 (Roles) ships behind `roles_tab_enabled` setting, default off. After 1 week of dogfood, default on. Includes CloudKit sync for `role_intentions` and `role_moments` from the first deploy.
- PR-7 (Larry export) ships with PR-6 since it depends on `computeWeekActivity`.

Use `just ota` for every PR — all changes are JS-only. PR-1 should be OTA-eligible too; verify the first deploy completes without `just resync-native` running. If for any reason a future change adds a native dep, that's the trigger to revisit this assumption.

---

## Risks & open questions

1. **App.tsx breakup** — Phase 1's extraction will conflict with any in-flight work. Coordinate via `bd` claim.
2. **HealthKit permissions** — v1 ships with no new types. If Roles auto-detection ever needs new HealthKit categories (e.g. cardio), the upgrade story is a permission re-prompt — confirm Igor is OK before adding.
3. **Year heatmap on fresh install** — fewer than 52 weeks of cache means most cells are empty. Spec covers this with a "fills in over time" placeholder; double-check the visual treatment.
4. **Raccoon images licensing** — these are Igor's own illustrations on idvork.in. Bundle them. If they change, bump app version and rebake.
5. **Spec drift** — if behavior changes during implementation, update the spec FIRST per CLAUDE.md spec-first workflow. Don't ship divergent code.
