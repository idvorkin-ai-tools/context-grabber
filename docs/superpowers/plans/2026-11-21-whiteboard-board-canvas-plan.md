# Whiteboard: a BoardCanvas protocol for the model-canvas closures (context-grabber-ya6d)

Architecture item 6 of the 2026-11-21 whiteboard review (`~/tmp/agent/notes/wb-arch-recommendations.md`,
`wb-arch-structure.md` §4). **No behaviour change**, so no spec or story change.

## Why

`WhiteboardModel` had 11 closure properties (`visibleRect`, `zoom`, `draw`, `applyOps`, `landPaste`,
`keepMakingRoom`, `changeOutline`, `showOverlays`, `move`, `menuChose`, `pressUndo`), each nil until
`PaperBoardController.viewDidLoad` filled it in. Together they were a protocol with no name: nothing said which ones
belonged together, a new one was easy to forget to wire, and the model couldn't be given a fake canvas.

## What changes

- `native/App/Whiteboard/BoardCanvas.swift`: `@MainActor protocol BoardCanvas: AnyObject` with the 11 requirements and
  their doc comments (the story and issue numbers moved from the closures).
- `WhiteboardModel` holds `weak var canvas: (any BoardCanvas)?`. Weak, as the closures captured `[weak self]`: the
  controller holds the model strongly. Nil until the canvas loads, as each closure was.
- `PaperBoardController.viewDidLoad` sets `model.canvas = self`; `questions.visibleRect` and `pasteReach` stay as
  they are (a separate model and a value).
- The conformance is one same-file extension of thin adapters at the tail of `PaperBoard.swift`, calling the
  controller's existing private methods unchanged. Requirement names differ from those methods (`apply`,
  `moveStrokes`, `pressedUndo`, `changeOutline(named:_:)`) so none of them collides with or captures an existing
  call. No method body changes, which keeps clear of the edit-lane work (arch 2) in the same file.

## Writes and commands

| Requirement | Kind | Returns |
|---|---|---|
| `draw(_:named:)` | write | `Bool`, new: false when there is no markup yet (the load picks the drawing up) |
| `apply(_:)` | write | `BoardCanvasOutcome` (#1040), as before |
| `landPaste(_:)` | write | `Bool`, as before |
| `keepMakingRoom(_:push:why:)` | write | `Bool`, as before |
| `changeOutline(named:_:)` | write | `Bool`, as before |
| `moveStrokes(_:)` | write | `Bool`, new: false when there is no markup yet |
| `visibleRect`, `zoom` | read | |
| `showOverlays(_:)`, `menuChose()`, `pressedUndo(redo:)` | command | nothing |

The model discards the two new results (`_ =`): acting on them would be a behaviour change, left for the edit lane.

## Nil semantics kept

`canvas?.zoom ?? 1`, `canvas?.visibleRect ?? .null`, `canvas?.apply(batch) ?? .unavailable`; a paste still bails with
no canvas, and `landPaste` not answering true still adds the paste as placed.

## Next

A fake `BoardCanvas` makes the model testable without UIKit once the model's tests can host it; the model split
(review item 6's second half) waits until features slow.
