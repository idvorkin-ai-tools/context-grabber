# Roles ↔ Journal linking — design spec

> **Status:** Drafted 2026-05-30. Extends the [Roles tab](2026-05-28-roles-tab-design.md) and the [Affirmations & Gratitude Journal](2026-05-10-affirmations-journal-design.md). The *forward* direction — tagging an affirmation/gratitude card with roles — already shipped (commit `4afbfd5`). This spec covers the **reverse** direction: going *from* a role *to* the entries tied to it.

---

## Summary

Today the link between journal entries and roles is one-way: on an Affirmation or Grateful card you can tag the entry with one or more roles, and a moment is recorded against each. But from a role you can't read what you actually wrote, you can't start a journal entry as that role, and you can't browse a role's entries over time. This spec makes the relationship bidirectional, so a role becomes a real lens onto the affirmations and gratitudes that prove you lived it.

## Problem

The eulogy framing treats roles as **evidence of investment — artifacts, not output**. A role's "Recent moments" list is where that evidence should live. Right now it's thin:

- A tagged **gratitude** shows the words you wrote — good.
- A tagged **affirmation** shows only the affirmation's title ("Do It Anyways"), not the opportunity or did-it you actually noticed. The reflection is thrown away at the role layer, so the moment reads as a hollow label.
- Nothing lets you **open or play** the underlying entry from a role.
- Nothing lets you **start a journal entry from a role** — the only create path is a free-form one-line caption.
- Nothing lets you **see a role's entries across time** — only the last ~20 moments, mixed with auto-detected ones.

The pointer back to the source entry already exists on every tagged moment; we're simply not following it.

## Goals

- From a role, **read and play the real affirmation/gratitude content** tied to it — not a bare label.
- From a role, **start a new affirmation or gratitude already tagged to that role**, using the existing cards.
- In the Journal, **filter to a single role** and see every entry tied to it, across all dates.
- A role's recent-moments list never shows a hollow "which affirmation" label where the user wrote actual words.

## Non-goals

- **No new entry types or editing.** Delete-and-re-log stays the only edit path (matches the journal spec).
- **No change to how forward tagging works** — the card role-picker chips are already shipped and stay as-is.
- **No new auto-detection sources.** This is about surfacing existing tagged entries, not detecting new ones.
- **No transcription of voice entries** — voice still plays back; it isn't turned into text.

---

## User-visible behavior

### 1. See the content (role → entries)

In a role's detail sheet, the **Recent moments** list shows the *actual content* of any linked journal entry, not a one-line label:

- A **gratitude** moment shows the gratitude text (unchanged).
- An **affirmation** moment shows the affirmation it was logged against **and** the opportunity / did-it note the user wrote.
- A **voice** entry shows a play button + duration and plays back inline, matching how voice leaf-entries behave in the Journal.
- Moments **not** backed by a journal entry — auto-detected workouts, mindful sessions, and free-form "+ Tag a moment" captions — keep their current compact one-line display. There's nothing to expand.
- Tapping a moment that *is* backed by a journal entry reveals its full content (full text, voice playback, the timestamp it was created, its context, and its affirmation).

Edge cases:

- If the underlying journal entry has been deleted, the moment falls back to its stored label and never errors.
- A role's recent-moments list must never show a bare affirmation title where the user actually wrote something — i.e. the role view shows *what you said*, not just *which affirmation you said it under*.

### 2. Create from a role

A role's detail sheet gains two clearly-labeled create actions:

- **"Log an affirmation as [role]"** → opens the existing Affirmation card with this role pre-selected in its role picker.
- **"Write a gratitude as [role]"** → opens the existing Grateful card with this role pre-selected.

Behavior:

- The pre-selected role is visibly selected in the card's picker; the user can still add/remove roles before saving.
- Saving behaves exactly as saving from the main surface: the entry persists, a moment is recorded per selected role, and the role detail's recent-moments list refreshes to show the new entry.
- These sit **alongside** the existing free-form "+ Tag a moment" action. That stays for a quick one-line caption with no journal entry; the new actions create real, replayable journal entries.

### 3. Browse by role in the Journal

The Journal view gains a way to **narrow to a single role**:

- A role selector at the top of the Journal. Picking a role narrows the list to entries tied to that role; clearing it returns to the full Journal (current behavior).
- Within a role's filtered view, the existing **date → context → affirmation** grouping is preserved.
- An entry tagged to **multiple roles** appears under each of those roles' filters.
- Entries with **no role tag** appear only in the unfiltered (all) view.
- The unfiltered Journal is unchanged — each entry appears once under its date group regardless of how many roles it's tagged to.

---

## Decisions to confirm

- **D1 — Deleting an entry vs. its role moments.** When a journal entry is deleted, should its linked role moments also disappear (so the role view shows no ghost), or should the moment survive as standalone evidence? **Proposed default: cascade — deleting the entry removes its linked role moments.** A moment is evidence *of* an entry; an orphaned moment that can't be read is the hollow-label problem all over again.
- **D2 — Create actions: two buttons or one.** Two explicit buttons ("Log an affirmation as…" / "Write a gratitude as…") vs. one "Journal as [role]" that then asks which. **Proposed default: two buttons** — fewer taps, and it mirrors the two cards the user already knows.
- **D3 — Where the role filter lives in the Journal.** A persistent chip strip at the top vs. a tucked-away filter control. **Proposed default: a chip strip**, consistent with the role-picker idiom already used on the cards.

## Acceptance criteria

A non-technical reader should be able to walk these on the device:

- **See content (affirmation):** On the Affirmation card, pick Opportunity, type "Notice when I'm rushing Amelia", tag the *Father · Amelia* role, save. Open the Amelia role detail. The recent moment shows the note text ("Notice when I'm rushing Amelia"), not just "Do It Anyways".
- **See content (voice gratitude):** On the Grateful card, record a ~5s voice gratitude, tag *Husband · Tori*, save. Open the Tori role detail. The moment has a play button with a duration that plays the clip back.
- **Open from role:** Tap a journal-backed moment in a role detail — its full text / voice + timestamp + context + affirmation is revealed.
- **Non-journal moment unaffected:** A workout auto-moment under *Fit* still shows its one-line label and does not try to expand.
- **Create from role:** Open the *Father · Amelia* detail → "Log an affirmation as Father · Amelia" → the Affirmation card opens with Amelia already selected → save a Did-It → it appears in Amelia's recent moments and in the Journal under today.
- **Create keeps multi-select:** Opening a card from a role lets you add a second role before saving; both roles get the entry.
- **Browse by role:** Tag a gratitude to both *Tori* and *Family*; open the Journal; filter to Tori → entry shows; filter to Family → same entry shows; clear the filter → entry appears once under its date group.
- **Deleted entry (per D1 default):** Delete a journal entry that was tagged to a role; the role detail no longer lists it.

## How this serves the JTBD

- **Artifacts, not output.** A role detail that shows the actual things you noticed (not labels or numbers) is the eulogy-true form of "evidence of investment."
- **Coach-readability.** Once a role can resolve its entries, the Larry export's roles section can cite real reflections, not counts — a separate, downstream win.
- **Capture stays implicit / no nagging.** Nothing here adds a notification or a required daily action; it only makes the evidence you already capture legible from the role side.

## Cross-references

- Role detail surface + recent-moments: [Roles tab spec](2026-05-28-roles-tab-design.md).
- Affirmation/Grateful cards, Journal grouping, voice playback, delete flow: [Affirmations & Gratitude Journal spec](2026-05-10-affirmations-journal-design.md).
- The forward direction (card → role tagging) is already shipped and documented in the Roles tab spec under "Multi-role tagging."
