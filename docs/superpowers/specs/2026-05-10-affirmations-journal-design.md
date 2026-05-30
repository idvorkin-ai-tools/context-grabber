# Affirmations & Gratitude Journal — Design Spec

> First slice of the Habit Tracker merge ([roadmap](2026-05-10-habit-tracker-merge-design.md)). The full habit grid, weekly targets, and tag groupings come later. This spec is *only* about the affirmation/gratitude/did-it journal — the part Igor uses many times a day.
>
> **Role linking:** entries can be tagged to eulogy roles, and the Journal gains a per-role filter — see [2026-05-30-roles-journal-linking-design.md](2026-05-30-roles-journal-linking-design.md).

## Summary

Bring the Humane Tracker journal into Context Grabber: a one-tap way to log an **opportunity** to live a chosen affirmation, a **did-it** when you actually lived it, or a **gratitude** — by voice or text — and have those entries flow into the same JSON snapshot the AI life coach already reads.

## Problem

The most-used surface in Humane Tracker isn't the habit grid — it's the Affirmation Card and the Grateful Card. They're how Igor closes the loop on the affirmations he's chosen to live by ("Do It Anyways", "An Essentialist", "A Class Act", "Calm Like Water"): noticing chances to apply them, recording when he followed through, and stacking gratitudes throughout the day.

Today that flow lives in a browser tab on a desktop. On the phone — where most of the noticing actually happens — there's no fast path. Voice would be the natural input on a phone, and the rest of Context Grabber already runs there with always-on storage and a share-sheet pipeline that the coach is plumbed into.

Shipping just the journal first (before the habit grid) means Igor gets the high-frequency surface immediately, the coach gets the missing intentional-life signal in its export, and we learn what the journal-on-iOS feels like before committing to the larger merge.

## Goals

- One-tap **affirmation entry** (opportunity / did-it) and **gratitude entry** from the main app.
- **Voice or text** for every entry; voice is the default on iPhone.
- The four canonical affirmations are present out of the box, picker-style, with their subtitles visible.
- A **Journal view** that lists every entry, grouped by date → context → affirmation, with playback for voice and text inline.
- Entries flow into the existing **Grab Context** JSON export so the coach sees today's opportunities, did-its, and gratitudes alongside the health/location data.
- **Round-trippable** with Humane Tracker: import an existing journal export, and produce a backup the user can take elsewhere.
- "Add another" flow — log multiple entries without dismissing the card.

## Non-Goals

- **No habit grid, weekly targets, or category tracking in this slice.** That's the next spec.
- **No on-device transcription of voice notes in v1.** Voice is stored as audio; the coach receives the audio reference (not the transcript). Transcription is a follow-on once we know whether the coach actually wants it.
- **No editing** an existing entry. Delete-and-re-log is the only path. (Matches Humane Tracker today.)
- **No reminders / notifications.** Glance-and-tap, not push.
- **No sync across devices.** The phone is the source of truth; export/import covers backup and migration.
- **No custom affirmations in v1.** The four canonical ones ship as a fixed list. (Adding custom affirmations is a small follow-on if Igor wants it.)

## User Stories

### Logging an affirmation entry

- As Igor, I can open the **Affirmation Card** in one tap from anywhere on the main screen.
- The card shows an affirmation (title + subtitle) at the top, e.g. "Do It Anyways — Deliberate. Disciplined. Daily." **A different one is picked at random each time the card opens** — rotating exposure across all four is the point, so I don't fixate on whichever I picked last.
- If the rotated one isn't the one I want to log against right now, I can swap to a different affirmation from a small picker on the card. The swap applies to this session of the card only; next time I open the card, it rotates again.
- I pick a context — **Opportunity** ("How will you apply this today?") or **Did-It** ("How did you apply this?") — with two clear buttons.
- Below the prompt I can either:
  - **Speak**: tap the mic, record up to a few minutes, tap to stop. The card shows live recording state and elapsed time.
  - **Type**: tap the text field, type my note, hit save.
- If I tap **Save** (or **Save & add another**) while a recording is still in progress, the recording is finalized and attached automatically — I don't have to stop it first — and the mic stops.
- I can switch between voice and text without losing the card's state.
- The card defaults to **voice on iPhone**, **text** on iPad/desktop-class devices.
- I see a small tally at the top of the card showing **today's count** by context (e.g. "Opp: 3 · Did: 1") so I feel the streak.
- After save, the card either **closes** (default) or **clears for another entry** if I chose "save and add another."

### Logging a gratitude

- I can open the **Grateful Card** as a separate, faster surface from a dedicated button.
- The card shows the prompt **"I'm grateful for…"** — no affirmation picker, no context buttons. Just record or type.
- All other behavior matches the Affirmation Card (voice/text toggle, save vs. save-and-add-another, today's tally at the top).
- A gratitude doesn't need to be tied to an affirmation; it's logged under a "Grateful" bucket so it groups cleanly in the journal.

### The Journal view

- I can open the Journal from a single button on the main screen.
- The Journal lists **every entry I've ever logged**, grouped:
  - by **date** (most recent first), then
  - by **context** within that date — Opportunities → Did-Its → Gratitudes, then
  - by **affirmation** within that context — entries under "Do It Anyways" before "An Essentialist", etc. Gratitudes group under the single "Grateful" affirmation.
- A leaf entry shows:
  - For **voice**: a play button, duration ("0:42"), and a delete affordance. Tapping plays back inline.
  - For **text**: a small note glyph, the full text, the timestamp it was created, and a delete affordance.
- Every grouping level is **collapsible** (date, context, affirmation), so I can fold up old days and zoom in on today.
- I can **delete** any entry; deletion asks for confirmation and is permanent (no undo).
- Empty state ("No entries yet") points me at the Affirmation and Grateful cards.

### Sharing with the coach

- When I press **Grab Context**, the JSON export gains a `journal` block containing today's entries:
  - Each entry has its **context** (opportunity / did-it / grateful), its **affirmation title** ("Do It Anyways", "Grateful", etc.), the **timestamp**, and either the **text content** or a reference like `"voice note, 0:42"` for audio entries.
  - A short **rollup** at the top: "today: 4 opportunities, 2 did-its, 6 gratitudes."
- I can also **export the entire journal database** (all dates, all entries) as a standalone JSON file from the share sheet — same shape as Humane Tracker's export, so it round-trips.
- Voice clips themselves are not embedded in the share — they stay on-device. The coach sees the metadata reference; if voice transcripts become valuable, that's a follow-on.

### Migrating from Humane Tracker

- I can import a Humane Tracker JSON backup. The journal entries (text + voice) populate, grouped under the same affirmations and contexts they were logged under originally.
- Import asks me whether to **merge** with existing entries or **replace** them.
- After import, today's entries (if any were logged on the phone before importing) are still there in merge mode.

### Day-to-day quality of life

- The cards remember which input mode I used last (voice vs. text) and default to that next time.
- **Third-party / dictation keyboards work in the text field.** With a dictation keyboard like Wispr Flow, the card must not blank out or collapse when the keyboard (or a tall dictation overlay) expands, and dictated text must not be dropped or scrambled as it lands.
- Recording survives the card being briefly backgrounded (e.g. control center pulldown) — coming back to the card I can keep recording or save what I have.
- Entries persist instantly. If I force-quit the app right after saving, the entry is still there next launch.
- The four canonical affirmations and the Grateful bucket are present from first launch — no setup screen.

## Acceptance Criteria

A non-technical reader should be able to walk these through on the device:

- Open the app, tap the Affirmation Card button. The card shows one of the four affirmations (title + subtitle) at the top with Opportunity / Did-It buttons below. Today's tally reads "Opp: 0 · Did: 0". Open and close the card a few times — the affirmation shown rotates (not always the same one).
- Tap the affirmation row, see all four affirmations in a picker, pick "An Essentialist". The card now shows "An Essentialist — Know Essential. Give Context. Prioritize Ruthlessly." Close the card and reopen it — a *different* random affirmation is shown (the rotation, not the last pick).
- Pick Opportunity, hold the mic, speak for ~5 seconds, stop, save. The card closes. Reopen — today's tally now reads "Opp: 1 · Did: 0". Open the Journal — today → Opportunities → "An Essentialist" contains a single voice entry with duration "0:05" and a play button that works.
- Pick Did-It, switch to text, type "Cleared inbox before lunch", tap save-and-add-another. The card stays open and clears the text field. Type another entry, hit save. Two text entries appear in the Journal under today → Did-Its → "An Essentialist".
- Open the Grateful Card, type "Sunny morning walk", save. The Journal now contains a today → Gratitudes → "Grateful" group with that text entry.
- In the Journal, tap the delete button on an entry, confirm. The entry is gone after the next refresh and isn't restored after restart.
- Press Grab Context, share to Notes. The shared JSON has a `journal.today` block listing every entry from today: each text entry includes its content, each voice entry includes its duration as a reference.
- Receive a Humane Tracker `humane-tracker-backup-*.json` via AirDrop and open it with the app. Choose Merge. Past dates from the backup show up in the Journal under their original affirmations and contexts; today's entries logged on the phone are still present.
- Force-quit the app immediately after saving an entry. Reopen — the entry is still in the Journal.
- With the Wispr Flow keyboard active, open the Grateful Card and start a dictation. The card stays visible (no black/collapsed screen) while the "Listening" overlay is up, and the dictated text lands in the field intact. Repeat in the Affirmation Card.
- On the Grateful Card, start a voice recording and — while it's still recording — tap Save. The recording stops, the entry is saved with the voice clip attached, and the mic is no longer active. Same on the Affirmation Card, and for "Save & add another".

## Open Questions for Igor

These are the calls I want you to make before we plan the build:

1. **Where do these surfaces live in the app's nav?** I'm picturing two prominent buttons on the main screen ("Affirmation" and "Grateful") and a third button or row link to "Journal". Sound right, or do you want them tucked into a different surface (a tab? a long-press on the dashboard?)?
2. **Voice transcription in v1?** I scoped it out because of the implementation lift (on-device Speech framework, accuracy, storage), but the coach probably gets *much* more value from text than from "voice note, 0:42". Want me to include best-effort iOS Speech transcription as a v1 goal (transcripts shown next to voice entries in the Journal and embedded in the export)?
3. **Custom affirmations?** Four canonical ones is the Humane Tracker default and probably enough, but if you want to add/edit your own list before v1 ships, say so — it's a small but real surface (CRUD, validation, what to do on delete).
4. **"Save & add another" — should it be a separate button, a long-press on Save, or a toggle?** On web it's a `Cmd+Enter` shortcut, which doesn't translate. The shape of this affordance matters for repeat-logging UX.
5. **Quick log from the Home Screen widget / Lock Screen?** Adding a "+1 Gratitude" widget button could mirror the existing tap-counter widget pattern. Out of scope for the first cut, or worth folding in?

## Rationale

**Why the journal first instead of the habit grid?** Frequency. The journal is logged many times a day; the habit grid is glanced at and tapped a handful of times. The most user-pain-per-tap is on the journal side, so shipping it first makes the merge feel valuable on day one. The habit grid layers cleanly on top later.

**Why ship without transcription?** Transcription is two features in a trench coat — the recording quality story (mic permissions, background recording, file size) and the transcription story (on-device vs. cloud, accuracy, latency, errors). Doing the recording right is enough work for v1; transcription is a high-leverage follow-on once we see how voice entries actually flow into the coach's prompts.

**Why no editing?** Humane Tracker doesn't have it either, and the rationale holds: a journal is a record of a moment. Editing turns it into a doc. Delete-and-re-log is fine; it's also rarely needed because voice notes are usually fine even when imperfect.

**Why preserve the affirmation → context → entry hierarchy instead of one flat "log"?** The hierarchy is the *point*. Affirmations are the lens; opportunity/did-it/gratitude are the verbs. Flattening loses the structure the coach uses to reason ("Igor noticed five 'An Essentialist' opportunities this week but only followed through twice — let's talk about that gap"). Keep the shape.

**Why round-trippable JSON?** Lock-in is a smell. If Igor decides next quarter to use a different journal app — or to feed entries through some other pipeline — exporting in the same shape Humane Tracker uses costs nothing now and buys real optionality.
