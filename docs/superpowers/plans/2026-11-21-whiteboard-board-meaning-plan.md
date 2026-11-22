# Plan: a board's meaning saves and syncs with its ink

Bead context-grabber-cc75 (whiteboard architecture item 5). Review: `~/tmp/agent/notes/wb-arch-data-sync.md`, option B.
Specs: [board ops](../specs/2026-11-16-whiteboard-board-ops-design.md) (*Edge cases*), and for step 2
[whiteboard](../specs/2026-11-01-whiteboard-design.md) (*Every device signed into Igor's iCloud sees every board*).
Stories: 1106 (step 1), 1109 (step 2, proposed).

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

## Step 2 (proposed; spec and story 1109 only, waiting on Igor): the file goes to iCloud as a third asset

Spec: [whiteboard](../specs/2026-11-01-whiteboard-design.md), *A board's meaning goes through iCloud with its ink*.
Not built until Igor says yes to syncing the meaning at all, and to the production-schema step below.

- **Upload.** `WhiteboardStore`'s record gets `record["meaning"] = CKAsset(fileURL: boards/<id>.meaning.json)` beside
  `drawing` and `picture`, only on the drawing device (the single-writer rule is unchanged). No file, or a meaning
  the device couldn't read (set aside as `.unreadable` in step 1), leaves the key unset: with `savePolicy .allKeys`
  an unset key isn't sent, so iCloud's asset stays. Never upload an empty `BoardMeaning` written to stand in for an
  unreadable one; a per-board "meaning held" flag (like the drawing's #1042 hold) says the local file isn't
  authoritative until a download replaces it or a real change is saved over it.
- **Meaning-only changes upload.** Step 1 saves the meaning alone without touching the index; step 2 makes that save
  call `index.drew(...)` (or a `meaningChanged`) so `updated` moves and `pendingUploads` picks the board up. It
  must stay clear of `dropsOnClose` (a board with meaning but no strokes is still dropped only by the strokes rule).
- **Download.** `download` asks for `["drawing", "picture", "meaning"]`. `takeReplica` takes the pair: decode the
  drawing and the meaning (`BoardMeaning` decode, every field optional) before replacing either; if the drawing
  fails, take neither; if only the meaning fails, keep the drawing, keep the old meaning and leave the board's
  `fetched` behind so the next sync asks again. A record with no `meaning` (an older build drew it) keeps the
  local meaning, or none.
- **Replica wins over local.** On a look-only device the downloaded meaning replaces the local file whole (its own
  cards and refusals go). An open look-only board reloads its ledger from the new file as it reloads the drawing.
- **Own board after a lost meaning.** On the drawing device, a held meaning is replaced by iCloud's on the next
  download of its own board (the merge already lists own boards; `takeReplica` today refuses this device's boards,
  so the meaning needs its own path there, or the hold just clears once a change is saved).
- **Delete.** The record goes, so the asset goes; nothing new.
- **Logs.** `whiteboard_sync` per board: `meaning` = `taken` | `missing` (no asset on the record) | `unreadable`
  | `held` (upload left it out). DEBUGGING's whiteboard rows get the field.
- **Tests (host).** Upload leaves `meaning` out when held or absent; `takeReplica` takes the pair or neither; a
  record without `meaning` keeps the local file; a meaning-only save moves `updated` and isn't dropped on close.
  CloudKit itself is phone- and iPad-only (the simulator has no iCloud account).

### The CloudKit production schema (TestFlight)

- Cable builds use the container's development environment, where CloudKit creates `WhiteboardBoard.meaning` (an
  Asset field) the first time a record carries it. TestFlight builds are distribution-signed and use production,
  which has only deployed fields: saving a record with an unknown field fails the whole record, so ink would stop
  syncing too.
- Igor's step, once, before the first TestFlight build that carries this: run a cable build that uploads one board
  with a meaning, then CloudKit Console → the container → Schema → *Deploy Schema Changes…* to production. This also
  deploys `WhiteboardBoard` itself if it was never deployed (check: Console → production → Record Types; if the
  record type isn't there, TestFlight builds can't sync boards today, with or without this).
- The TestFlight lane spec's one-time setup gets a line for it when this is built.
- Possible safeguard (Igor to decide): on a save refused for an unknown field, retry once without `meaning` and log
  it, so a TestFlight build shipped before the deploy still syncs ink.

### For Igor to confirm

1. Sync the meaning at all (folds, cards, Larry's groups on the iPhone, Mac and a reinstalled iPad).
2. The drawing device wins: a card Larry leaves on a board on the iPhone is replaced on the next sync.
3. A meaning-only change moves the board's `updated` (it goes up, and moves to the top of the list like new ink).
4. The production-schema deploy before TestFlight, and whether to build the retry-without-meaning safeguard.
