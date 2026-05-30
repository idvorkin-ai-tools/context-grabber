# Roles ↔ Journal linking — implementation plan

Spec: [2026-05-30-roles-journal-linking-design.md](../specs/2026-05-30-roles-journal-linking-design.md). Bead epic `context-grabber-sus` (T1 `wm5`, T2 `5f6`, T3 `2dl`). Branch `feature/roles-journal-linking`.

## Data model recap

A tagged moment points back to its journal entry via `role_moments.source_ref`, but in **two formats**:
- card-tagged (`source="manual"`): `source_ref = <entry.id>` (raw uuid)
- auto-emo (`source="auto-journal"|"auto-grateful"`): `source_ref = "journal:<entry.id>"`

Non-journal moments: `auto-workout` → `workout:<ts>`, `auto-mindful` → `mindful:<iso>`, free-form manual tag → `source_ref = null`.

A normalizer collapses these to "journal entry id or null".

## Build sequence

### 1 · Data helpers
- `lib/roleMoments.ts`
  - `journalEntryIdFromMoment(m): string | null` — strip `journal:` prefix; return null for `workout:`/`mindful:`/`place:` prefixes and null refs.
  - `getEntryIdsForRole(db, roleId): Promise<Set<string>>` — journal entry ids tied to a role (for the Journal filter).
- `lib/journalDb.ts`
  - `getEntriesByIds(db, ids): Promise<JournalEntry[]>` — IN-clause batch fetch.
- `lib/cloudkit.ts`
  - `deleteMomentsForEntry(db, entryId)` — find moments whose `source_ref` is `entryId` or `journal:entryId`, delete each via existing `deleteMomentRecord` (sync-aware). **Call it from `deleteJournalEntry`** so D1 cascade holds at the single delete chokepoint.

### 2 · See the content (T1) — `components/RoleDetailSheet.tsx`
- `reload()` also resolves journal-backed moments: `getEntriesByIds` + `getAudio` for any audio.
- Moment row: if a journal entry resolves, render affirmation/context kicker + full entry text + inline `<AudioPlayer>` (reused from the Journal). Non-journal moments keep the compact one-line `m.what`. Fallback to `m.what` if the entry is gone.

### 3 · Create from a role (T2)
- `components/AffirmationCard.tsx` + `components/GratefulCard.tsx`: add optional `initialRoleIds?: RoleId[]`; seed `selectedRoles` from it on open.
- `components/RoleDetailSheet.tsx`: two CTAs in the role color ("Log an affirmation as …" / "Write a gratitude as …") that mount the cards (same nested-modal pattern as the existing `TagMomentSheet`), pre-tagged; `onClose` → reload.

### 4 · Browse by role + cascade delete (T3) — `components/JournalScreen.tsx`
- Role filter chip strip under the header: "All" + the 11 roles (single-select).
- Keep `allEntries` in state; when a role is selected, fetch `getEntryIdsForRole` and filter before `groupEntries` (grouping preserved). Filtered count note.
- Delete already routes through `deleteJournalEntry` → cascade lands for free via step 1.

### 5 · Tests
- `__tests__/roleMoments.test.ts` (new or extend): `journalEntryIdFromMoment` across all source_ref forms.
- Extend role/journal tests as needed for the entry-id filter mapping.

## Decisions locked
- D1 cascade-delete (entry → its moments). D2 two buttons. D3 chip strip.
