# Plan: replay Igor's touches from device logs as host fixtures

Bead context-grabber-y544 (whiteboard architecture review 2026-11-21, item 4; notes
`~/tmp/agent/notes/wb-arch-testability.md` §4 and option C). Spec: `2026-11-01-whiteboard-design.md`, *A pen touch's
path is in the log, and a pulled log replays on the Mac*; stories 1104, 1105. Nothing Igor sees changes: the log gains
lines and fields.

## Why

`paper_touch` logs tallies (travel, ink added, the tools), and `scratch` logs a verdict and its reversals. Neither
carries the stroke, so a gesture bug on the iPad (scratch-out tuning, a snap that didn't, a margin hold that drew) was
argued from counts and re-checked only by Igor drawing again. The scratch-out fixture of 2026-11-21 had to be rebuilt
from the Cockpit's stroke vectors by hand.

## What lands

| Piece | Where | What |
|---|---|---|
| Path codec | `ContextCore/Whiteboard/BoardTouchPath.swift` | `x,y,ms;dx,dy,dms;...` in tenths of a board point and whole ms, deltas between rounded values (no drift), thinned evenly to 600 points keeping the ends |
| Replay | `ContextCore/Whiteboard/BoardTouchReplay.swift` | log text to cases; each case's verdict from the board's own rules (`WhiteboardScratchOut.shape` + speed, `BoardShapeSnap.clean` and `Hold`, `BoardMarginHold.pencil`); `agrees` compares with what the iPad logged; a Codable fixture |
| Recipe | `Sources/TouchReplay`, `just touch-fixture` | prints a line per case (DIFFERS where the iPad and the Mac part), `--out` writes the fixture |
| Fixture test | `BoardTouchReplayTests` | codec round trip, Igor's 2026-11-21 scratch-outs judged identically after the codec, a log's lines to cases, and every `Fixtures/touches/*.json` case still gets its `expect` |
| App: every touch | `PaperBoard+TouchPath.swift`, one stored property and one call beside each `snapTouch` in PaperBoard.swift | `board_touch` action path, per drawing touch (Pencil, or finger while fingers draw), at the lift: board points from `lines.columnPoint`, `touch.timestamp` deltas, phase, `picker_tool` at touch-down. No new `drawingTool` read (arch 1 owns the tool) |
| App: each gesture | `scratch` (PaperBoard.swift + PaperScratch.swift's per-point times), `hold_stroke`, `shape_snap` / `shape_snap_none` | a `path` field: the exact stroke the decision read |

## Size and privacy

The iPad's touches arrive at the screen's rate (60 Hz on the iPad Air), so a 1.5 s stroke is about 90 points, about
1 KB. `board_touch` is not a `whiteboard…` type, so `WhiteboardLogArchive` doesn't send it to the Cockpit (2000-line
ring, 500 per batch); the gesture lines are a few a day and the Cockpit already holds the strokes. BugKit's listener
names the log in a GitHub issue and never uploads it. The recipe takes gestures only unless `--all`, so writing reaches
a committed fixture only when asked.

## Verification

Rung 1 (`just native-test`), rung 1.5 (`just native-build-mac`). A simulator run of the scratch-out UI test gives a
real `scratch` line and `board_touch` lines through the recipe into `Fixtures/touches/`. The iPad's own paths come
with the next deploy.

## Follow-ups

- context-grabber-x1zk (vertical scratch "marches along"): settled with a fixture from the iPad's first log with paths.
- Arch 1's tool snapshot can replace `picker_tool` at touch-down with the snapshot itself.
