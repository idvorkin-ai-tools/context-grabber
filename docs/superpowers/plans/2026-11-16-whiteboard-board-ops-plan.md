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
- `BoardText`: a kept text (`id, t, text, font, size, color`). `BoardText.wire(_ strokes:texts:)` folds a kept text's
  glyph strokes into one `strokes` entry `{id, kind:"text", text, font, size, color, x, y, w, h, points: [top-left,
  bottom-right], t, width, tool:"text"}`.

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
