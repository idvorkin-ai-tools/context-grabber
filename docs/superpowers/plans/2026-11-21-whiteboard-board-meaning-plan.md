# Plan: a board's meaning saves and syncs with its ink

Bead context-grabber-cc75 (whiteboard architecture item 5). Review: `~/tmp/agent/notes/wb-arch-data-sync.md`, option B.
Specs: [board ops](../specs/2026-11-16-whiteboard-board-ops-design.md) (*Edge cases*), and for step 2
[whiteboard](../specs/2026-11-01-whiteboard-design.md) (*Every device signed into Igor's iCloud sees every board*).
Stories: 1106 (step 1).

## Why

A board was four stores with no shared save: the drawing file, the index, and per-board UserDefaults keys. The ops
ledger was written on every change (`didSet`), the drawing a second later, so a kill in that second left a batch of
Larry's remembered as handled with its ink lost. None of the meaning reached iCloud, and a delete left the keys behind.

## The keys, classified

| Key (`whiteboard_<name>_<board>`) | What | Goes where |
|---|---|---|
| `ops` | rev, handled batches, last result | the meaning file |
| `texts` | Larry's kept texts | the meaning file |
| `stroke_ids` | names moved strokes keep | the meaning file |
| `stroke_meta` | Larry's notes and groups | the meaning file |
| `headers` | headers and folds | the meaning file |
| `questions` | question cards | the meaning file |
| `labels`, `theirs` | creation moments of kept labels and of Larry's ink | stay (follow-up bead: they're ink identity too) |
| `thread`, `picture_times`, `picture_folds`, `marks_settled`, `marks_settled_marks` | this device's chat with Larry about the board | stay: per device |
| `paper_y`, `grid`, `ruled`, `lettering` | this device's view of the board | stay: per device |

A delete (here, or arriving from elsewhere) forgets every key of the board (`BoardDeviceKeys.forget`).

## Step 1 (this PR): one local file, saved with the drawing; no change Igor sees

- ContextCore `BoardMeaning`: the six parts plus `inkBytes` (the drawing's size when last written with it), every
  field optional on decode. `boards/<id>.meaning.json` beside the drawing (not a `.drawing` extension: the
  save-fails and unreadable hooks key on that).
- `BoardMeaningLedger`: one open board's meaning, with `BoardOpLedger`'s method names so the model's call sites stay;
  every change calls `onChange`; `unsaved` compares with what the file holds.
- The model: on a board drawn here a meaning change schedules the same one-second save as ink; the save writes the
  drawing, then the meaning (`BoardKeeping.save(_:meaning:board:)`); with no ink change, the meaning alone (the index
  isn't touched, so `dropsOnClose` and the list's order don't move). Flush and close save when either is unsaved. On a
  look-only board the meaning is written at once, as the keys were (cards land there; batches are refused there).
- Order: drawing first. A kill between the two leaves the meaning a step behind: the batch is offered again and may
  land twice (visible, one Undo). Meaning first would lose it silently with Larry told `ok`. On open, `inkBytes`
  against the drawing read logs `whiteboard` `meaning_behind` if that ever happens.
- The in-memory applier is unchanged: `handled` still updates at once; only its persistence moved.
- Migration (`BoardKeeping.migrateMeaning`, at the store's load, for every board in the index): read the six keys
  (`BoardOpLedger.meaning`), write the file, read it back and compare, then remove the keys. Never over an existing
  file (whose stale keys are removed). A failure keeps the keys for next launch; until then the board opens from them.
  One `whiteboard` `meaning_migrated` line with per-board counts.
- An unreadable meaning file is set aside (`.unreadable`) and the board opens with none; logged as
  `error` `whiteboard_meaning`.

## Step 2 (next PR): the file goes to iCloud as a third asset

- Upload: `meaning` CKAsset beside `drawing` and `picture`; download asks for it; `takeReplica` validates it before it
  replaces the local copy, as #1043 does the drawing. A record with no meaning (an older build drew it) is normal.
- A meaning-only change bumps the board's `updated` so it uploads (and stays clear of `dropsOnClose`).
- Rules to spec first: the owner's file wins on every other device (a look-only device's own cards and refusals are
  replaced on the next download); an owner whose file was unreadable must not upload an empty one over iCloud's.
- `whiteboard_sync` fields: meaning taken, missing, unreadable.
- Open: whether a new record field needs the CloudKit production schema deployed before TestFlight builds can save
  (see the TestFlight lane spec, step 5). Builds from the cable use the development environment.
