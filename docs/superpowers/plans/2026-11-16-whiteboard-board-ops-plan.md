# Plan: whiteboard board ops, step 1

Spec: [2026-11-16-whiteboard-board-ops-design.md](../specs/2026-11-16-whiteboard-board-ops-design.md). Stories 814–819
(`docs/stories/10-whiteboard.md`). Wire contract agreed with Larry on thread igor2-88g.1499.

## Shape

One applier, many sources. A source turns what it hears into batches; the applier checks, holds and applies every
batch the same way, whoever sent it.

```
 Larry's rows (GET /chat/<thread>) ──► WebBoardOpSource ─┐
 (later) board.mjs in JavaScriptCore ► LocalBoardOpSource ┤──► BoardOpApplier ──► plan ──► PaperBoardController
                       board events (pen, tap) ───────────┘    (rev, dedup,        (BoardOps.plan)   (PaperKit, undo)
                                                               hold, result)
```

### ContextCore (pure, host tests)

`Whiteboard/BoardOps.swift`

- `BoardOps.Op`: `.translateBelow(y:dy:)`, `.translateIDs(_:dx:dy:)`, `.addText(BoardOps.Text)`.
- `BoardOps.Text`: `id, x, y, text, font (plain|hand), size, color` in raw board points, `x, y` the text's top-left.
  `shape` gives the `WhiteboardTurn.Shape` its ghost draws (frame at the origin, scale 1).
- `BoardOps.Batch`: `key` (the message id, or `label@base_rev` without one), `source`, `board`, `label`, `baseRev`,
  `ops`, `refusal` (set when the wire couldn't be taken: `unknown_op`, `too_many_ops`, `dy_out_of_range`, `bad_op`,
  `bad_batch`).
- `BoardOps.batch(_ json:key:source:)`: the wire's `ops` object as a batch; nil when there is none.
- `BoardOps.Item`: one thing that moves as a whole: a stroke, or a kept text's glyph strokes. `ids` it answers to,
  `members` (stroke indices on the canvas), `bounds`.
- `BoardOps.items(strokes:texts:)`: strokes grouped into items; a kept text's strokes (same creation time as the text)
  are one item answering to its id.
- `BoardOps.plan(_ ops:items:pages:board:)` → `Plan`: per-stroke offsets, ghosts to show, pages before and after,
  items moved, ids not found. Ops apply in order; each sees the board as the ops before it left it.
- `BoardOps.Readiness` and `BoardOps.readiness(penDown:liftedAt:now:)`: now, after a wait, or on the lift. The hold
  after a lift is `WhiteboardPacer.pause`.
- `BoardOps.Result`: `label, ok, rev, reason?, missing_ids?` → `wire`.

`Whiteboard/BoardOpApplier.swift`

- `BoardOpApplier`: `rev`, `handled` keys (last 64), the held batch, the last result. `receive(_:board:editable:ready:)`
  → `.ignored(why)` (another board, already handled), `.refused(Result)`, `.held`, `.apply(Batch)`. The rev check is at
  arrival: a batch held for the Pencil applies on the lift to the board as it is then. A newer batch held replaces the
  older one, which is refused `superseded`. `release(ready:)` hands back the held batch once ready. `applied(_:changed:)`
  records the result. `changed()` bumps `rev`; every ink change calls it (it replaces the model's in-memory
  `boardVersion`, so Larry's turn compares the same number the wire carries).
- `BoardOpLedger`: per board in UserDefaults, as `WhiteboardThreads`: `rev`, `handled`, kept texts.

`Whiteboard/BoardOpSource.swift`

- `BoardOpInput`: `.rows([WhiteboardMarks.Row])`, `.event(BoardEvent)`.
- `protocol BoardOpSource { var name: String; mutating func batches(from: BoardOpInput) -> [BoardOps.Batch] }`.
- `WebBoardOpSource`: Larry's rows. First look: only the newest row with ops (the ledger refuses one already handled);
  after that, each new row's, oldest first. Events are not its business.

`Whiteboard/BoardEvents.swift`

- `BoardEvent`: `.pen(down:idleMs:t:)`, `.tap(x:y:target:t:)`; Codable for the Inbox; `wire`.
  `idle_ms` on a down is how long the Pencil was up before it; on an up, how long it was down.
- `BoardEvents`: accumulates, at most 100 (the oldest dropped, counted), `take()` drains.
- `BoardTurnReport`: `rev, op_result, events` → `wire`, merged into the turn's chat message by
  `ChatSend.messageRequest` (never into `POST /whiteboard/strokes`). Rides on `WhiteboardPicture.report`, optional, so
  outbox items written before it still decode.
- `BoardText`: a kept text (`id, t, text, font, size, color`). `WhiteboardStrokes.wire(_:texts:)` folds a kept text's
  glyph strokes into one `strokes` entry, exactly the fields the Cockpit takes: `{kind:"text", id, text, font, x, y, w,
  h, color, t}`, the box's top-left and size, `font` as the endpoint names it (`print` or `hand`). Its glyphs' creation time matches a millisecond either way.

`Whiteboard/BoardStrokeIDs.swift`

- A stroke's id is the hash of its ink, so a move would rename it; Larry's connectors and his "new since my last
  reply" key on ids. `BoardStrokeIDs` maps each moved stroke's new hash to the name it had (`moved(from:to:)`,
  `stable`, `named`), kept per board by the ledger. Only a change of the ink itself names a stroke anew; undo and redo
  land on known hashes.

### App

- `WhiteboardModel` owns `ops: BoardOpApplier`, `sources: [any BoardOpSource]` (`[WebBoardOpSource()]`), `events`,
  `texts`. `lookWorked` feeds rows to the sources after the reply's follow-up is decided (so the board's own change never
  counts as Igor moving on). `beganDrawing`/`endedDrawing` record pen events and track the lift; a held batch is retried
  by a task after the hold. `tapped(at:)` records a tap with its target: a ghost's id (a text ghost's text id), a kept
  text's id, or null. The turn's picture carries `BoardTurnReport`.
- Text ghosts are Larry's ghosts with id `op-text:<id>`, landed beside his row marks. Keeping one makes its glyph
  strokes with one creation date and records a `BoardText` with that time.
- `PaperBoardController.applyOps(plan:label:)`: one `registerStepBack` named `label`, then each stroke's offset with
  `applyTransform` on its markup element (ids kept), the bounds grown to the plan's pages, set quietly; the model hears
  it as `opsApplied`, which saves and bumps `rev` but is no stroke for Claude.
- Session log: `board_ops` with `action` applied / held / refused / ignored, `label`, `source`, `ops`, `moved`, `pages`,
  `reason`.

## Not now

- `LocalBoardOpSource` (board.mjs in JavaScriptCore): the protocol is the seam; no stub.
- Text ghosts don't come back when the board reopens (their batch is handled).
- A stroke Igor moves with the lasso after keeping a text breaks the text's grouping only if its creation time changes,
  which PaperKit's transform doesn't do.

## Step 2 (stories 840–844)

Wire, additive to `ops.list`:

- `{op:"add_strokes", strokes:[{id, points:[[x,y],...], width?, color?, meta?}]}`
- `{op:"delete", ids:[...]}`
- `{op:"set_meta", ids:[...], meta:{...}}`: kept verbatim per stroke; only `meta.group` is read.
- `{op:"replace", ids:[...], strokes:[...]}`: a delete and an add in one op.

Caps: 500 strokes in one op, 4000 points a stroke (the Cockpit's), coordinates within the board's reach; past them the
batch is refused (`too_many_strokes`, `too_many_points`, `bad_op`).

- `BoardOps.Op` gains `.addStrokes`, `.delete`, `.setMeta`, `.replace`; `BoardOps.NewStroke {id, points, width, color,
  meta}`; `BoardMeta` holds the JSON as written (`Data`) and its `group`.
- `BoardOps.plan` works on a list of items that holds the canvas's strokes and the strokes the batch adds, so a later op
  can move or erase what an earlier one drew. The plan says: offsets for the canvas's strokes, the canvas strokes to
  erase, the strokes to add (their points after the batch's later moves), the metas to set (by stroke name), and ids
  not found. Items group by kept text and by `meta.group`; a group answers to its group id.
- `BoardStrokeIDs.name(_:as:)`: a stroke Larry draws is known by his name. `BoardStrokeMeta` keeps each name's meta,
  per board in the ledger. The strokes wire adds `meta` to a stroke that has one (the Cockpit ignores fields it doesn't
  know; storing them is Larry's side).
- Events: `strokes_changed {added, erased, moved, rev}` from PaperKit's own element changes (the controller keeps
  each element's hashes, so a lasso move keeps names through `BoardStrokeIDs.moved` too), and `selection {ids}` when
  the lasso's selection changes.

## Step 3 (stories 845–851)

Wire, additive:

- `{op:"overlay", id, kind:"band"|"chip"|"button"|"hint", rect:{x,y,w,h}, label, style?, tap_event?}`; `{op:
  "remove_overlay", id}`. An overlay replaces one with its id. Not ink, not undone, not saved.
- `{op:"set_hidden", ids, hidden}`: the strokes' ink goes to alpha 0 and back (the hash ignores alpha, so names hold);
  the strokes wire marks a hidden stroke `hidden: true`. Part of the batch's undo.
- `{op:"select", ids}`: the lasso's selection set to those strokes.
- `BoardOverlays`: the overlays on a board, applying ops and hit-testing a tap.
- Events: `margin {gesture:"tap"|"hold"|"drag_end", y, dy}` (a finger starting in the column's left 64 points:
  `BoardMargin.gesture`), `viewport {y, h, scale}` half a second after the view stops, `undo {label}` when Igor undoes
  one of Larry's batches, and an overlay tap: `{type:"overlay_tap", target_id, overlay_id, t, event?}` with his `tap_event` as written under `event` (the Cockpit wakes Larry only for `overlay_tap`/`ghost_tap` with `target_id`). `BoardTurnReport.wire` keeps the Cockpit's caps: 200 events, 8 KB each, 256 KB a body; what it leaves out is added to `events_dropped`.
- A tap on an overlay posts `POST /whiteboard/events {board, rev, op_result?, events}` at once; taken, those events
  leave the queue; a 404 or no answer leaves them for the next turn, logged as `board_events`.
