# Mind Recent-Journal List + Tally→Move Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the last 24h of journal entries (fully interactive) on the Mind tab, move the Tally tap-counter to the top of the Move tab, and extract the entry display into a shared, portable component.

**Architecture:** Extract the interactive entry row from `JournalScreen` into `components/JournalEntryRow.tsx` (shared atom). Build a self-contained `components/JournalRecentList.tsx` that loads its own entries/audio/roles for a time window and hosts the role editor + delete. Mind tab drops in the list; Move tab gains the relocated Tally; `App.tsx` rewires the counter props Mind→Move and adds a reload key so the list refreshes after logging.

**Tech Stack:** React Native + TypeScript, expo-sqlite, Jest/ts-jest. Spec: `docs/superpowers/specs/2026-05-31-mind-recent-journal-and-tally-move-design.md`.

**Decisions locked:** full-interactive rows (reuse the Journal row); Tally at top of Move; rolling 24h window.

---

## File Structure

- `lib/journal.ts` (modify) — add pure `recentEntries(entries, hours, now)`.
- `components/JournalEntryRow.tsx` (create) — the shared interactive row (text, voice, delete, role avatars+edit affordance), lifted verbatim from `JournalScreen`. Exports `JournalEntryRow` and `ROLE_ORDER`.
- `components/JournalScreen.tsx` (modify) — import the extracted row + `ROLE_ORDER`; delete the local copies.
- `components/JournalRecentList.tsx` (create) — self-contained list block: loads entries within a window + audio + roles, renders rows, hosts `JournalEntryRoleEditor` + delete.
- `screens/MindScreen.tsx` (modify) — remove the Tally section + counter props; add `<JournalRecentList>`.
- `screens/MoveScreen.tsx` (modify) — add the Tally section at the top + counter props.
- `App.tsx` (modify) — move counter props Mind→Move; add `journalReloadKey` bumped on card closes; pass to Mind.
- `__tests__/journal.test.ts` (modify) — tests for `recentEntries`.
- `__tests__/JournalRecentList.test.tsx` (create) — empty-state render test.

---

## Task 1: Pure `recentEntries()` window filter

**Files:**
- Modify: `lib/journal.ts` (add after `groupEntriesByRole`)
- Test: `__tests__/journal.test.ts`

- [ ] **Step 1: Write the failing tests**

Add to `__tests__/journal.test.ts` (it already imports from `../lib/journal` and has `createEntry`). Extend the import to include `recentEntries`, then add:

```typescript
describe("recentEntries", () => {
  const NOW = Date.UTC(2026, 4, 31, 12, 0, 0);
  function at(id: string, msAgo: number) {
    return createEntry({
      id,
      date: NOW - msAgo,
      context: "opportunity",
      affirmationTitle: "Do It Anyways",
      text: id,
    });
  }
  const HOUR = 3600_000;

  it("keeps entries within the window and drops older ones", () => {
    const inWindow = at("in", 23 * HOUR);
    const tooOld = at("old", 25 * HOUR);
    const result = recentEntries([tooOld, inWindow], 24, NOW);
    expect(result.map((e) => e.id)).toEqual(["in"]);
  });

  it("sorts newest first", () => {
    const older = at("older", 10 * HOUR);
    const newer = at("newer", 1 * HOUR);
    const result = recentEntries([older, newer], 24, NOW);
    expect(result.map((e) => e.id)).toEqual(["newer", "older"]);
  });

  it("includes an entry exactly at the window edge", () => {
    const edge = at("edge", 24 * HOUR);
    expect(recentEntries([edge], 24, NOW).map((e) => e.id)).toEqual(["edge"]);
  });

  it("returns empty for an empty input", () => {
    expect(recentEntries([], 24, NOW)).toEqual([]);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `npx jest journal -t recentEntries`
Expected: FAIL — `recentEntries is not a function`.

- [ ] **Step 3: Implement `recentEntries`**

In `lib/journal.ts`, add after `groupEntriesByRole`:

```typescript
/**
 * Entries logged within the last `hours` (rolling window ending at `now`),
 * newest first. Pure — powers the Mind tab's "Recent (24h)" list. The edge
 * is inclusive: an entry exactly `hours` old is kept.
 */
export function recentEntries(
  entries: JournalEntry[],
  hours: number,
  now: number,
): JournalEntry[] {
  const cutoff = now - hours * 3600_000;
  return entries
    .filter((e) => e.date >= cutoff)
    .sort((a, b) => b.date - a.date);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest journal -t recentEntries`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/journal.ts __tests__/journal.test.ts
git commit -m "feat(journal): recentEntries window filter for the Mind recent list"
```

---

## Task 2: Extract `JournalEntryRow` (shared row, no behavior change)

**Files:**
- Create: `components/JournalEntryRow.tsx`
- Modify: `components/JournalScreen.tsx`

No new unit test — behavior is unchanged; existing `App.test.tsx`/`StylizedMap` suites + `tsc` guard it.

- [ ] **Step 1: Create `components/JournalEntryRow.tsx`**

Lift the `EntryRow` function and its row-only styles out of `JournalScreen.tsx` verbatim, plus the `ROLE_ORDER` constant:

```tsx
import React from "react";
import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import type * as SQLite from "expo-sqlite";
import type { AudioRecording, JournalEntry } from "../lib/journal";
import { ROLES, getRole, type RoleId } from "../lib/roles";
import { RoleAvatar } from "./RoleAvatar";
import { AudioPlayer } from "./AudioPlayer";

/** Canonical role order, shared by the row avatars and the journal grouping. */
export const ROLE_ORDER: RoleId[] = ROLES.map((r) => r.id);

/**
 * One interactive journal entry: text, inline voice playback, a delete
 * affordance, and the entry's role tags as small avatars that open an
 * editor on tap. Shared by the full Journal modal and the Mind tab's
 * recent list so the two never diverge.
 */
export function JournalEntryRow({
  entry,
  audio,
  db,
  roles,
  onEditRoles,
  onDelete,
}: {
  entry: JournalEntry;
  audio: AudioRecording | undefined;
  db: SQLite.SQLiteDatabase | null;
  roles: ReadonlySet<RoleId> | null;
  onEditRoles: () => void;
  onDelete: () => void;
}) {
  const time = new Date(entry.date).toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
  const roleIds = roles ? ROLE_ORDER.filter((id) => roles.has(id)) : [];
  return (
    <View style={styles.entryRow}>
      <View style={{ flex: 1 }}>
        {entry.text ? <Text style={styles.entryText}>{entry.text}</Text> : null}
        {entry.audioRecordingId && audio && (
          <View style={{ marginTop: entry.text ? 8 : 0 }}>
            <AudioPlayer
              recordingId={entry.audioRecordingId}
              durationMs={audio.durationMs}
              db={db}
            />
          </View>
        )}
        {entry.audioRecordingId && !audio && (
          <Text style={styles.entryMissing}>voice note (metadata pending sync)</Text>
        )}
        <View style={styles.entryFooter}>
          <Text style={styles.entryTime}>{time}</Text>
          <TouchableOpacity
            onPress={onEditRoles}
            style={styles.roleTagBtn}
            testID={`entry-roles-${entry.id}`}
            accessibilityLabel="Edit role tags"
          >
            {roleIds.map((id) => (
              <RoleAvatar key={id} roleId={id} size={16} ringColor={getRole(id).color} />
            ))}
            <Text style={styles.roleTagPlus}>
              {roleIds.length === 0 ? "+ tag" : "＋"}
            </Text>
          </TouchableOpacity>
        </View>
      </View>
      <TouchableOpacity onPress={onDelete} style={styles.deleteBtn}>
        <Text style={styles.deleteBtnText}>×</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  entryRow: {
    flexDirection: "row",
    alignItems: "flex-start",
    paddingVertical: 8,
    paddingHorizontal: 10,
    backgroundColor: "#111",
    borderRadius: 8,
    marginBottom: 6,
  },
  entryText: { color: "#fff", fontSize: 14, lineHeight: 20 },
  entryMissing: { color: "#666", fontSize: 12, fontStyle: "italic" },
  entryTime: { color: "#666", fontSize: 11 },
  entryFooter: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 4,
  },
  roleTagBtn: {
    flexDirection: "row",
    alignItems: "center",
    gap: 3,
    paddingVertical: 2,
    paddingHorizontal: 4,
  },
  roleTagPlus: { color: "#6f7891", fontSize: 12, marginLeft: 2 },
  deleteBtn: { paddingHorizontal: 8, paddingVertical: 4, marginLeft: 6 },
  deleteBtnText: { color: "#ff5555", fontSize: 22, fontWeight: "300" },
});
```

- [ ] **Step 2: Update `JournalScreen.tsx` to use the extracted row**

In `components/JournalScreen.tsx`:

1. Delete the local `function EntryRow(...) { ... }` definition entirely.
2. Delete the local `const ROLE_ORDER: RoleId[] = ROLES.map((r) => r.id);` line.
3. Delete the now-unused row styles from its `styles` object: `entryRow`, `entryText`, `entryMissing`, `entryTime`, `entryFooter`, `roleTagBtn`, `roleTagPlus`, `deleteBtn`, `deleteBtnText`.
4. Replace its internal `<EntryRow .../>` usages with `<JournalEntryRow .../>` (same props — `renderEntry` already passes `entry`, `audio`, `db`, `roles`, `onEditRoles`, `onDelete`).
5. Add the import and re-export `ROLE_ORDER` from the new module:

```tsx
import { JournalEntryRow, ROLE_ORDER } from "./JournalEntryRow";
```

Keep `RoleAvatar`/`getRole` imports in `JournalScreen` only if still used elsewhere (the by-role group header uses `RoleAvatar` + `getRole` — keep those). `ROLE_ORDER` is still referenced by the role-group rendering, now imported.

- [ ] **Step 3: Type-check + run the suite (no regression)**

Run: `npx tsc --noEmit 2>&1 | grep -v "react-native-maps" ; npx jest`
Expected: no new TS errors; all tests pass.

- [ ] **Step 4: Commit**

```bash
git add components/JournalEntryRow.tsx components/JournalScreen.tsx
git commit -m "refactor(journal): extract shared JournalEntryRow from JournalScreen"
```

---

## Task 3: `JournalRecentList` self-contained list block

**Files:**
- Create: `components/JournalRecentList.tsx`
- Test: `__tests__/JournalRecentList.test.tsx`

- [ ] **Step 1: Write the failing empty-state test**

`__tests__/JournalRecentList.test.tsx` (the jest `expo-sqlite` mock returns `getAllAsync → []`, so the list loads empty):

```tsx
import React from "react";
import { render, waitFor } from "@testing-library/react-native";
import { JournalRecentList } from "../components/JournalRecentList";

describe("JournalRecentList", () => {
  it("renders the empty state when no entries are in the window", async () => {
    const result = render(<JournalRecentList db={null} windowHours={24} />);
    await waitFor(() =>
      expect(result.getByTestId("journal-recent-empty")).toBeTruthy(),
    );
  });

  it("shows the heading", () => {
    const result = render(
      <JournalRecentList db={null} windowHours={24} heading="Recent (24h)" />,
    );
    expect(result.getByText("Recent (24h)")).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx jest JournalRecentList`
Expected: FAIL — cannot find module `../components/JournalRecentList`.

- [ ] **Step 3: Implement `components/JournalRecentList.tsx`**

```tsx
import React, { useCallback, useEffect, useState } from "react";
import { Alert, StyleSheet, Text, View } from "react-native";
import type * as SQLite from "expo-sqlite";
import {
  recentEntries,
  type AudioRecording,
  type JournalEntry,
} from "../lib/journal";
import { getAllAudio, getAllEntries } from "../lib/journalDb";
import { getRolesByEntry } from "../lib/roleMoments";
import { deleteJournalEntry } from "../lib/cloudkit";
import type { RoleId } from "../lib/roles";
import { JournalEntryRow } from "./JournalEntryRow";
import { JournalEntryRoleEditor } from "./JournalEntryRoleEditor";
import { CopyableError } from "./CopyableError";

type Props = {
  db: SQLite.SQLiteDatabase | null;
  /** Rolling window in hours (e.g. 24). */
  windowHours: number;
  /** Section heading; default "Recent". */
  heading?: string;
  /** Bump to force a reload (e.g. after logging a new entry elsewhere). */
  reloadKey?: number;
};

/**
 * Self-contained, droppable block that shows the last `windowHours` of
 * journal entries as fully interactive rows (voice playback, delete, role
 * avatars + inline edit). Loads its own entries/audio/roles and hosts the
 * role editor + delete confirmation, so any surface can render recent
 * entries with one line.
 */
export function JournalRecentList({
  db,
  windowHours,
  heading = "Recent",
  reloadKey = 0,
}: Props) {
  const [entries, setEntries] = useState<JournalEntry[]>([]);
  const [audioById, setAudioById] = useState<Record<string, AudioRecording>>({});
  const [rolesByEntry, setRolesByEntry] = useState<Map<string, Set<RoleId>>>(
    new Map(),
  );
  const [editing, setEditing] = useState<JournalEntry | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!db) {
      setEntries([]);
      return;
    }
    setError(null);
    try {
      const all = await getAllEntries(db);
      setEntries(recentEntries(all, windowHours, Date.now()));
      const audio = await getAllAudio(db);
      const map: Record<string, AudioRecording> = {};
      for (const a of audio) map[a.id] = a;
      setAudioById(map);
      try {
        setRolesByEntry(await getRolesByEntry(db));
      } catch {
        setRolesByEntry(new Map());
      }
    } catch (e: any) {
      setError(e?.message ?? String(e));
    }
  }, [db, windowHours]);

  useEffect(() => {
    void load();
  }, [load, reloadKey]);

  function handleDelete(entry: JournalEntry) {
    if (!db) return;
    Alert.alert(
      "Delete entry?",
      entry.text
        ? `"${entry.text.slice(0, 80)}${entry.text.length > 80 ? "…" : ""}"`
        : "This voice entry will be deleted.",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Delete",
          style: "destructive",
          onPress: async () => {
            try {
              await deleteJournalEntry(db, entry.id);
              await load();
            } catch (e: any) {
              setError(e?.message ?? String(e));
            }
          },
        },
      ],
    );
  }

  return (
    <View>
      <Text style={styles.heading}>{heading}</Text>
      {error && (
        <CopyableError message={error} context="JournalRecentList" style={{ marginBottom: 8 }} />
      )}
      {entries.length === 0 ? (
        <View style={styles.empty} testID="journal-recent-empty">
          <Text style={styles.emptyText}>
            Nothing in the last {windowHours}h. Use Affirm, Grateful, or Journal above.
          </Text>
        </View>
      ) : (
        entries.map((entry) => (
          <JournalEntryRow
            key={entry.id}
            entry={entry}
            audio={
              entry.audioRecordingId ? audioById[entry.audioRecordingId] : undefined
            }
            db={db}
            roles={rolesByEntry.get(entry.id) ?? null}
            onEditRoles={() => setEditing(entry)}
            onDelete={() => handleDelete(entry)}
          />
        ))
      )}
      <JournalEntryRoleEditor
        visible={editing != null}
        entry={editing}
        currentRoles={editing ? rolesByEntry.get(editing.id) ?? new Set() : new Set()}
        db={db}
        onClose={() => setEditing(null)}
        onChanged={() => void load()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  heading: {
    color: "#4cc9f0",
    fontSize: 14,
    fontWeight: "600",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    marginTop: 8,
    marginBottom: 8,
  },
  empty: {
    backgroundColor: "#16213e",
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
  },
  emptyText: { color: "#888", fontSize: 13, textAlign: "center" },
});
```

> Note: `AudioRecording` and `JournalEntry` are exported from `lib/journal.ts`; `getAllAudio`/`getAllEntries` from `lib/journalDb.ts`; `getRolesByEntry` from `lib/roleMoments.ts`; `deleteJournalEntry` from `lib/cloudkit.ts` — all already used by `JournalScreen`.

- [ ] **Step 4: Run to verify it passes**

Run: `npx jest JournalRecentList`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add components/JournalRecentList.tsx __tests__/JournalRecentList.test.tsx
git commit -m "feat(journal): JournalRecentList portable recent-entries block"
```

---

## Task 4: Mind tab — drop in the recent list, remove the Tally

**Files:**
- Modify: `screens/MindScreen.tsx`

- [ ] **Step 1: Swap Tally for the recent list, drop counter props**

Edit `screens/MindScreen.tsx`:

1. Replace the `TallyCounter` import with the list import:

```tsx
import { JournalRecentList } from "../components/JournalRecentList";
```

(remove `import TallyCounter from "../components/TallyCounter";`)

2. Change the `Props` type — remove `counterValue`, `onCounterIncrement`, `onCounterReset`; add `journalReloadKey`:

```tsx
type Props = {
  db: SQLite.SQLiteDatabase | null;
  todayMeditationMinutes: number | null;
  weeklyMeditation: DailyValue[] | null;
  onOpenAffirmation: () => void;
  onOpenGrateful: () => void;
  onOpenJournal: () => void;
  onMoodSaved?: () => void;
  /** Bumped when a journal entry is logged so the recent list refreshes. */
  journalReloadKey?: number;
};
```

3. Update the destructured params accordingly (remove the three counter params, add `journalReloadKey`).

4. Replace the entire `<Text style={styles.sectionHeading}>Tally</Text>` block and its `<View style={styles.counterCard}>…</View>` with:

```tsx
        <JournalRecentList
          db={db}
          windowHours={24}
          heading="Recent (24h)"
          reloadKey={journalReloadKey}
        />
```

5. Delete the now-unused styles from `MindScreen`'s `StyleSheet`: `counterCard`, `counterPlusOne`, `counterPlusOneText`, `counterReset`, `counterResetText`. (Keep `sectionHeading` — "Reflect" still uses it.)

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit 2>&1 | grep -v "react-native-maps"`
Expected: errors only in `App.tsx` (it still passes the removed counter props — fixed in Task 6). No errors inside `MindScreen.tsx` itself.

- [ ] **Step 3: Commit**

```bash
git add screens/MindScreen.tsx
git commit -m "feat(mind): show Recent (24h) journal list; remove Tally section"
```

---

## Task 5: Move tab — Tally at the top

**Files:**
- Modify: `screens/MoveScreen.tsx`

- [ ] **Step 1: Add the Tally section + counter props**

Edit `screens/MoveScreen.tsx`:

1. Add the import:

```tsx
import TallyCounter from "../components/TallyCounter";
```

2. Extend `Props` with the counter wiring:

```tsx
  /** Tap-counter value (relocated from the Mind tab). */
  counterValue: number;
  onCounterIncrement: () => void;
  onCounterReset: () => void;
```

3. Add them to the destructured params: `counterValue, onCounterIncrement, onCounterReset`.

4. Insert the Tally block as the FIRST child of the `<ScrollView>` (above `<View style={styles.ringRow}>`):

```tsx
        <Text style={styles.sectionHeading}>Tally</Text>
        <View style={styles.counterCard}>
          <TallyCounter
            value={counterValue}
            onPress={onCounterIncrement}
            testID="move-counter-tally"
          />
          <TouchableOpacity
            onPress={onCounterIncrement}
            style={styles.counterPlusOne}
            testID="move-counter-plus-one"
            accessibilityLabel="Add one to counter"
          >
            <Text style={styles.counterPlusOneText}>+1</Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={onCounterReset}
            style={styles.counterReset}
            testID="move-counter-reset"
            accessibilityLabel="Reset counter"
          >
            <Text style={styles.counterResetText}>↺</Text>
          </TouchableOpacity>
        </View>
```

5. Add the counter styles to `MoveScreen`'s `StyleSheet` (copied from the old MindScreen, with the section-heading's top margin made 0 for the first child via the existing `sectionHeading` — that style already exists in MoveScreen):

```tsx
  counterCard: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    backgroundColor: "#16213e",
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 14,
    marginBottom: 16,
  },
  counterPlusOne: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
    backgroundColor: "rgba(76, 201, 240, 0.18)",
    marginLeft: "auto",
    marginRight: 8,
  },
  counterPlusOneText: { color: "#4cc9f0", fontSize: 15, fontWeight: "700" },
  counterReset: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#2a2a40",
  },
  counterResetText: { color: "#888", fontSize: 18, fontWeight: "600" },
```

- [ ] **Step 2: Type-check**

Run: `npx tsc --noEmit 2>&1 | grep -v "react-native-maps"`
Expected: errors only in `App.tsx` (MoveScreen now requires counter props not yet passed — fixed in Task 6). No errors inside `MoveScreen.tsx` itself.

- [ ] **Step 3: Commit**

```bash
git add screens/MoveScreen.tsx
git commit -m "feat(move): Tally tap-counter at the top of the Move tab"
```

---

## Task 6: App.tsx — rewire counter props + reload key

**Files:**
- Modify: `App.tsx` (MoveScreen ~1826, MindScreen ~1838, card close handlers ~1879+)

- [ ] **Step 1: Add the reload-key state**

Near the other `useState`s (next to `counterValue` at ~line 524), add:

```tsx
  const [journalReloadKey, setJournalReloadKey] = useState(0);
```

- [ ] **Step 2: Bump the key whenever a reflection card closes**

The Affirmation, Grateful, and Journal modals already call refresh on close. In each of their `onClose` handlers (search for `setAffirmationVisible(false)`, `setGratefulVisible(false)`, and the Journal modal's close), add a bump alongside the existing logic:

```tsx
          setJournalReloadKey((k) => k + 1);
```

For example the Affirmation card becomes:

```tsx
      <AffirmationCard
        visible={affirmationVisible}
        onClose={() => {
          setAffirmationVisible(false);
          void refreshReflectTally();
          setJournalReloadKey((k) => k + 1);
        }}
        db={db}
      />
```

Apply the same one-line addition to the Grateful card's `onClose` and the Journal modal's `onClose`.

- [ ] **Step 3: Pass counter props to MoveScreen, reload key to MindScreen**

`MoveScreen` (~1826) — add the three counter props:

```tsx
        <MoveScreen
          exerciseMinutesWeekly={(weeklyCache.exerciseMinutes as DailyValue[] | undefined) ?? null}
          workoutsToday={snapshot?.health.workouts ?? []}
          workoutsByDay={workoutsByDay}
          counterValue={counterValue}
          onCounterIncrement={handleCounterIncrement}
          onCounterReset={handleCounterReset}
          onLaunchPreset={(preset) => {
            setTimerIntent({ mode: "rounds", preset, autostart: false });
            setGymTimerVisible(true);
          }}
          onSelectWorkout={setSelectedWorkout}
        />
```

`MindScreen` (~1838) — remove the three counter props, add `journalReloadKey`:

```tsx
        <MindScreen
          db={db}
          todayMeditationMinutes={snapshot?.health.meditationMinutes ?? null}
          weeklyMeditation={(weeklyCache.meditation as DailyValue[] | undefined) ?? null}
          onOpenAffirmation={() => setAffirmationVisible(true)}
          onOpenGrateful={() => setGratefulVisible(true)}
          onOpenJournal={() => setJournalVisible(true)}
          journalReloadKey={journalReloadKey}
        />
```

- [ ] **Step 4: Type-check + full suite**

Run: `npx tsc --noEmit 2>&1 | grep -v "react-native-maps" ; npx jest`
Expected: no TS errors; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add App.tsx
git commit -m "feat(app): relocate Tally props Mind->Move; reload Mind recent list on log"
```

---

## Task 7: Verify

- [ ] **Step 1: Full gate**

Run: `npx tsc --noEmit 2>&1 | grep -v "react-native-maps" ; npx jest`
Expected: tsc clean (only the pre-existing react-native-maps line filtered); all tests green.

- [ ] **Step 2: Manual walk (device/simulator)** — the spec's acceptance criteria:
  1. Log a gratitude → Mind tab "Recent (24h)" shows it, newest first.
  2. Voice affirmation → row has a working play control + duration.
  3. Delete from the Mind list (confirm) → gone, stays gone.
  4. Edit roles on a Mind-list row → avatars update; same entry in the full Journal shows the new role.
  5. 25h-old entry absent; 23h-old present.
  6. Empty 24h → prompt shows.
  7. Mind has no Tally; Move shows it at top; +1 / reset work; value matches.
  8. Full Journal modal unchanged (grouping/filter/toggle), rows render identically.

---

## Self-Review Notes

- **Spec coverage:** Recent-24h list → Tasks 1+3+4. Full interactivity (voice/delete/roles) → shared `JournalEntryRow` (Task 2) used by the list (Task 3). Refresh-on-log → `reloadKey` (Tasks 3+6). Empty state → Task 3. Tally→Move top → Tasks 4+5+6. Reuse goal → Tasks 2+3 (one row impl, droppable list). Journal modal unchanged → Task 2 keeps `JournalScreen` behavior (extraction only).
- **Type consistency:** `JournalEntryRow` props (entry, audio, db, roles, onEditRoles, onDelete) identical between Task 2's definition and Task 3's usage. `ROLE_ORDER` defined+exported in Task 2, imported by `JournalScreen` in Task 2. `recentEntries(entries, hours, now)` defined Task 1, used Task 3. `journalReloadKey` prop added in Task 4, supplied in Task 6. Counter props removed from Mind (Task 4) and added to Move (Task 5), supplied in Task 6.
- **Intermediate tsc failures are expected** between Tasks 4–6 (App.tsx passes/omits props mid-flight); Task 6 resolves them. Each commit still leaves tests green except the App.tsx prop wiring, which Task 6 closes before the final gate.
- **Placeholder scan:** none — all code shown in full.
