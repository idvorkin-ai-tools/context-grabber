# Mind recent-journal list + Tally → Move — design spec

> **Status:** Drafted 2026-05-31. Rearranges content across the tabbed shell ([Tabbed app](2026-05-25-tabbed-app-design.md)) and surfaces journal entries ([Affirmations & Gratitude Journal](2026-05-10-affirmations-journal-design.md)) on the Mind tab. Builds on the inline role-tagging work (entry rows already support voice playback, delete, and role avatars/edit).

---

## Summary

Two changes to the tab layout, plus a reuse goal that motivates how they're built:

1. **Mind tab** gains a **last-24-hours journal list** — the actual affirmations, did-its, and gratitudes you logged recently, shown as fully interactive entries.
2. The **Tally (tap counter)** moves off the Mind tab and onto the **Move** tab.
3. **Reuse goal:** the journal entry display becomes a **shared, portable building block** that can be placed on any surface (the Mind tab now, the Journal modal already, others later) without re-implementing playback / delete / role editing.

## Problem

- The **Mind tab** is all buttons and counters — it lets you *log* reflections (Affirm / Grateful / Journal) but never *shows* what you logged. To see today's entries you have to open the full Journal modal. The most recent reflections deserve to be glanceable right where you log them.
- The **Tally (tap counter)** lives on Mind, but it's a rep/count tool — it belongs with the movement tools (Gym Timer, workouts) on the **Move** tab, not next to mood and meditation.
- The Journal modal's entry display (text, voice playback, delete, role avatars + edit) is **locked inside that one screen**. Wanting the same entries on another tab shouldn't mean rebuilding all of that.

## Goals

- On the Mind tab, **see the last 24 hours of journal entries** without leaving the tab.
- Those entries are **fully interactive** — same as in the Journal modal: play voice, delete, see and edit role tags.
- **Move the Tally** to the Move tab with identical behavior.
- The journal-entry display is a **reusable component** that drops onto any surface; moving it elsewhere later is a placement change, not a rewrite.

## Non-goals

- **No new journal data or entry types.** This surfaces existing entries; it doesn't add fields, transcription, or sources.
- **No change to how entries are created** (the Affirm / Grateful / Journal cards are unchanged).
- **No change to the Tally's behavior** — it's the same counter, just on a different tab.
- **No change to the full Journal modal's grouping/filter/toggle** — it keeps its date → context → affirmation (or by-role) views; it simply renders entries through the same shared block.
- **No redesign of the other tabs.**

---

## User-visible behavior

### Mind tab — "Recent (24h)"

- A section on the Mind tab lists every journal entry whose timestamp is within the **rolling last 24 hours** (now minus 24h), **newest first**, as a flat list (no date grouping — it's a single window).
- Each row is **fully interactive**, matching the Journal modal:
  - text entries show their text; voice entries show an inline **play** control with duration;
  - a **delete** affordance (with confirmation) removes the entry;
  - the entry's **role tags** show as small avatars, tappable to **add/remove roles** inline.
- Deleting an entry or editing its roles **updates the list in place**.
- When a new entry is logged from the Reflect buttons on the same tab, the list **reflects it** (refreshes).
- **Empty state:** when nothing was logged in the last 24 hours, a short prompt points at the Reflect buttons.
- The section sits below the existing **Reflect** buttons (where the Tally section used to be).

### Move tab — Tally

- The **Tally** section — the counter value, **+1**, and **reset** — appears at the **top of the Move tab**, above the weekly-exercise ring.
- Behavior is unchanged: +1 increments, reset zeroes it, the value persists exactly as before.
- The Tally **no longer appears on the Mind tab**.

### Reuse (cross-cutting)

- The same entry display used in the full Journal modal is what renders on the Mind tab — one implementation. A future request to show recent entries on, say, the Today tab is a matter of placing the same block there.

---

## Acceptance criteria

A non-technical reader should be able to walk these on the device:

- **Recent list shows entries:** Log a gratitude ("Sunny walk"). Open the Mind tab — a "Recent (24h)" section shows that gratitude with its time, newest at the top.
- **Voice playback works:** Log a ~5s voice affirmation. On the Mind tab's recent list, the row has a play control with "0:05" that plays back.
- **Delete works inline:** Delete an entry from the Mind recent list (with confirmation). It disappears from the list and stays gone after a refresh.
- **Role edit works inline:** Tap an entry's role avatars on the Mind list, add a role, dismiss — the avatars update, and the same entry in the full Journal modal shows the new role.
- **24h window:** An entry logged 25 hours ago does **not** appear in the Mind recent list; one logged 23 hours ago does.
- **Empty state:** With nothing logged in 24h, the Mind recent section shows its prompt rather than an empty box.
- **Tally moved:** The Mind tab no longer shows the Tally. The Move tab shows it at the top; +1 increments and reset zeroes it, and the value matches what the Mind tab showed before the move.
- **Journal modal unchanged:** Open the full Journal — its grouping, filter, and by-affirmation/by-role toggle all work exactly as before; entries render the same as on the Mind tab.

## Rationale

- **Show what you log, where you log it.** A reflection surface that only captures and never reflects back is half a loop. The last-24h window is the "what did I just notice" view; the full Journal modal remains the archive.
- **Tools belong with their context.** The tap counter is a movement tool; grouping it with the Gym Timer and workouts makes the tabs read by intent (Mind = reflect, Move = train).
- **Portable components reduce drift.** One entry-display implementation means voice playback, delete, and role editing behave identically everywhere and can't silently diverge — and placing entries on a new surface later costs a line, not a rewrite. This is the stated goal: shared blocks we can move around as needed.

## Cross-references

- Mind/Move tabs and the tab shell: [Tabbed app design](2026-05-25-tabbed-app-design.md).
- Journal entries, voice playback, delete, grouping: [Affirmations & Gratitude Journal](2026-05-10-affirmations-journal-design.md).
- Inline role tagging on entries: [Journal inline tagging + group-by-role](2026-05-30-journal-tagging-polish-design.md).
- The tap counter: [Tap counter design](2026-04-25-tap-counter-design.md).
