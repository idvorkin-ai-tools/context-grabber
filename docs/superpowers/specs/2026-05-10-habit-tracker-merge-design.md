# Habit Tracker Merge — Design Spec

## Summary

Bring the habit-tracking experience from Humane Tracker (web PWA) into Context Grabber so that habits, daily completions, and the affirmation/gratitude journal live in the same iOS app that already snapshots HealthKit, GPS, and location history. Habit data joins the daily JSON export the AI coach already consumes — the coach can now reason about "what Igor intends to do" alongside "what his body and location actually did."

## Problem

Today, Igor's daily picture for AI coaching is split across two apps:

- **Context Grabber** owns the body + place data (steps, sleep, HR, GPS, clusters) but knows nothing about Igor's *intentions* — what he was trying to do that day.
- **Humane Tracker** owns the intentions (habits, weekly targets, gratitudes, affirmations) but lives in a browser tab on a different device and has no awareness of his health or location data.

The coach gets half the story from each. Two apps means two places to open, two share-sheet flows, and an export that has to be manually stitched together. There's also no easy way for habits to *react to* observed behavior (e.g. "your watch saw a 30-min run — do you want to mark Movement done?").

Merging puts every signal a life coach needs behind a single "Grab Context" tap.

## Goals

- One app, one share, one JSON: when Igor presses Grab Context, the export contains habits, today's completions, recent streaks, and journal entries alongside health and location.
- Daily habit tracking on the iOS phone that's always with him — bumping a habit takes one tap, no sign-in, no browser.
- The full Humane Tracker mental model carries over: life categories, weekly targets, binary/sets tracking, tag groupings, weekly grid view.
- The affirmation and gratitude journal carries over with voice and text entries.
- Backfill: import an existing Humane Tracker JSON backup so Igor doesn't lose history when he switches.
- Habits surface in the existing dashboard the same way health metrics do — they're not a sidecar.

## Non-Goals

- No web or Android version. iOS-only, like the rest of Context Grabber.
- No multi-user / family sharing. Single-user device, like everything else here.
- No cloud sync between devices in v1. The local-first DB on the phone is the source of truth; export/import covers backup and one-time migration. Cross-device sync is a later spec if it's ever wanted.
- No automatic "your watch saw a run, mark Movement done" inference in v1. Surface the data side-by-side; auto-suggestion is its own follow-up.
- No charts/heatmaps beyond what the weekly grid already shows. Streak-style visualizations come later if they earn their slot.
- No notifications / reminders. The dashboard is glanceable; pushy reminders are out of scope.

## User Stories

### Defining habits

- As Igor, I can create a habit by giving it a **name**, a **life category** (one of: Movement & Mobility, Connections, Inner Balance, Joy & Play, Strength Building), a **weekly target** (1–7 days/week), and a **tracking type** (binary, sets, or hybrid).
- I can edit any of those fields later, and rename a habit without losing its history.
- I can delete a habit; deletion removes its tracking history with a two-step confirm so I can't fat-finger it.
- I can mark a habit as a **tag** — a container that groups two or more child habits, where completing *any one child* on a given day counts as one day toward the tag's weekly target.
- I can hide a habit from the main view without deleting it (for paused experiments).
- The very first time I open the app I'm offered a starter set of habits (the same demo set Humane Tracker ships) so the empty state isn't blank.

### Tracking daily completion

- I can mark a habit done for today by tapping its cell in the weekly grid.
- For a **binary** habit, tapping cycles: empty → ✓ → empty.
- For a **sets** habit, tapping cycles: empty → 1 → 2 → 3 → 4 → 5 → ½ → empty. The ½ value records partial-effort days.
- For a **hybrid** habit, the first tap sets ✓; subsequent taps reveal the sets cycle.
- For a **tag** habit, long-pressing the cell opens a picker showing the children — I tap which one I actually did, and that child gets the credit (the tag's count updates accordingly).
- When I'm logging a day **more than 2 days in the past**, I get a confirm prompt — late-logging is supported but not friction-free, because day-of accuracy is the goal.
- I can attach a freeform note to any cell ("3×10 @ 135 lb", "30 min easy", "missed because traveling"). Notes ride along into the export so the coach sees the texture.

### Glancing at where I stand

- The main view shows a 7-day grid of habits, organized by life category, with TODAY on the left and the trailing 6 days to the right.
- Each habit row shows its weekly progress as **X/Y** (days completed / target).
- Each habit shows a **status badge**: Done · Met · Today · Tomorrow · Soon · Overdue · Pending — so I know at a glance whether I'm ahead, on track, or slipping.
- A summary bar at the top shows: how many habits are due today, how many I've already done today, and how many are overdue.
- I can collapse a category section, expand all, or zoom into one category to filter the rest out.
- The view updates instantly when I tap a cell — no save button.

### Affirmations and gratitudes

- I can open an **Affirmation Card** to record an *opportunity* I see, a *did-it* (something I followed through on), or a *gratitude*.
- I can open a dedicated **Grateful Card** for fast gratitude logging.
- Each entry can be a **voice note** or **text** — voice is the default on a phone where typing is slower.
- I can save and immediately add another entry without closing the card.
- The card shows a tally of today's entries by type so I can feel the count growing.
- A separate **Journal** view lists every entry I've ever made, grouped by date → context (opportunity/did-it/gratitude) → affirmation title, with the voice clips playable in place.
- I can edit or delete any entry from the Journal.

### Importing my history

- I can import an existing Humane Tracker JSON backup file from the share sheet or Files. Habits, completions, notes, and journal entries all come over.
- Import asks me whether to **merge** (add to what's here) or **replace** (wipe and reload from the backup).
- After import I see the same totals and streaks I had on the web.

### Sharing my day with the coach

- When I press **Grab Context** (the existing top-level action), the JSON export now includes:
  - The list of habits I track, with their categories and weekly targets.
  - Today's completion state for each habit (and partial completions where they exist).
  - The trailing-7-day completion grid for each habit (so the coach sees this week's pattern, not just today).
  - Today's affirmations, did-its, and gratitudes (voice clips referenced by short transcripts when available, otherwise as "voice note, 12s").
  - A short rollup: "habits met today: 4/7 due, 2 overdue, 1 ahead-of-schedule."
- I can also export the full habit + journal database as a standalone JSON backup file (the same shape Humane Tracker uses today) so I can move my data anywhere.

### Day-to-day quality of life

- I can keep using the app fully without signing in to anything. No accounts, no setup gates.
- I never have to think about saving — every tap persists immediately.
- The habit data survives an app reinstall as long as I exported a backup or did a database export beforehand (same expectation as the existing health/location DB).

## Acceptance Criteria

A user story above is "shipped" when a non-technical reader can pick up an iPhone with the app installed and walk through it without consulting a developer:

- Create a new habit named "Pushups", category Strength Building, target 4/week, tracking type Sets. Tap today's cell three times. The cell shows `3` and the row shows `1/4` for the week.
- Long-press a tag habit's cell, pick one of its children, and watch the tag's weekly count tick up by one.
- Open the Affirmation Card with one tap, record a 5-second voice note as an "opportunity", save-and-add-another, type a gratitude, save. Both appear in the Journal grouped under today.
- Press Grab Context. The shared JSON, opened in Notes or sent to the coach, contains a `habits` block with this week's grid and a `journal` block with today's affirmations.
- Receive a Humane Tracker backup JSON via AirDrop, open with Context Grabber, choose Replace, and see all imported habits and history populate the grid.
- Mark a habit done for two days ago — confirm the late-log prompt appears, then verify the past cell now shows ✓.
- Delete a habit — confirm the two-step prompt appears, then verify the row disappears and re-creating a habit with the same name does not resurrect old data.

## Open Questions for Igor

These are the v1 calls I'd like you to make before we plan the implementation:

1. **Where does habit tracking live in the existing nav?** Is it a new tab/screen alongside the metric grid, or does it replace the dashboard's main surface? My instinct: dedicated screen, with a one-line "habits today: 4/7" summary on the main dashboard that taps through.
2. **Categories: keep all five, or trim?** Humane Tracker has Movement & Mobility, Connections, Inner Balance, Joy & Play, Strength Building. All five carry over, or do you want fewer/different ones for v1?
3. **Voice notes: keep or skip for v1?** They're a meaningful chunk of UX (recording, playback, storage) and the rest of Context Grabber doesn't currently have audio. Acceptable to ship text-only journal in v1 and add voice later?
4. **Auto-suggestion from health data?** "Your watch saw 8,500 steps — mark Movement done?" Is this a v1 must, a v2 nice-to-have, or never?
5. **Sunset of Humane Tracker?** Is the merged Context Grabber a *replacement* for the web app (we stop deploying surge.sh) or do they coexist for some time?

## Rationale

**Why merge instead of "the coach reads two JSON files"?** The coach can technically stitch two exports, but the *user* is also better off: one app, one tap, one mental model. Splitting forces the user to remember two contexts and two share flows; merging makes habits feel like a first-class signal rather than a separate ritual.

**Why iOS-only / drop the web?** The phone is where Igor actually is throughout the day. Habit tracking has the highest "tap latency matters" coefficient — open Safari, find the tab, log a thing, close — that's already 3× the friction of a one-tap home-screen affordance. The PWA's local-first IndexedDB also doesn't survive iOS Safari's eviction policies as reliably as a real app's SQLite.

**Why no cross-device sync in v1?** Sync is a feature with its own large surface (auth, conflict resolution, offline queues). Humane Tracker uses Dexie Cloud for this; replicating it inside Context Grabber is a large bet that earns its slot only if multi-device daily use is actually happening. Backup-via-JSON-export plus one-time import covers the migration case without committing to that surface.

**Why keep the binary/sets/hybrid distinction instead of one tracking type?** The three types map to three real categories of habit (yes/no like meditation, counted like pushups, mixed like "did some climbing — record sets if you remember, ✓ if you don't"). Collapsing to one type either loses information (binary-only) or forces friction onto every habit (sets-only). The cycle UI keeps the cost of "more types" small.

**Why preserve the same JSON shape for backup as Humane Tracker?** Round-trip compatibility means Igor can move data between the two without writing a converter, and the existing Humane Tracker export is already known-good for the coach's prompts.
