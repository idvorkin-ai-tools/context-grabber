# Split PaperBoard.swift by feature (move only)

Bead: context-grabber-fz4x (Igor, 2026-11-21: split the big whiteboard files now, alongside in-flight work).

No behaviour change: every declaration moves as it was, word for word. No spec or story changes, as nothing a person
sees changes.

## Where each part went

| File | What it holds |
|---|---|
| `PaperHost.swift` | `PaperHost`: lifecycle, the paper's colour and fit, the tool picker, touch runs, the log's words |
| `PaperBoard.swift` | `PaperBoardController`'s stored state, lifecycle and the model's wiring, load and layout, the rules, the PaperKit delegate (`didChangeMarkup`, the push on a move, selection, the visible frame), every `override` of a `PaperHost` hook, the gesture delegate, `PaperRules`, the `BoardCanvas` conformance |
| `PaperBoard+GhostsTaps.swift` | ghosts on the sheet, the chosen mark's place, finger taps, the tap's dot taken back, the scratch-out's hookup |
| `PaperBoard+PasteRoom.swift` | paste (⌘V, the clipboard, landing, its Delete), a keep that makes room, an outline change, the margin's header marks |
| `PaperBoard+HoldMenu.swift` | the press-and-hold menu, room by hand, the margin's Pencil hold, pick up, `replaceInk` |
| `PaperBoard+InkCommits.swift` | keep, `applyOps`, `put`, select, the strokes' hashes, `noteInk`, the labels' move, the redraw |
| `PaperBoard+RenderProbe.swift` | `lookForInk`, `shownPixels` |
| `PaperBoard+Undo.swift` | step-back registration, PaperKit's step taken back, the stack watched, the bar's Undo and Redo, the board closing, `step(to:)` |
| `PaperBoard+Touches.swift` | the pacer's word, `fingersDraw`, `toolInHand` |
| `PaperBoard+TestHooks.swift` | the simulator's launch hooks (after ink, page after ink, copy, after a keep or a batch) |
| `PaperBoardCanvas.swift` | the SwiftUI canvas, its host, Keep and Dismiss, `HoldMenu` and its buttons, a paste's Delete |
| `PaperLines.swift` | `PaperLines` |
| `PaperTouchWatcher.swift` | `PaperTouchWatcher` |

The existing extension files (EditLane, FoldErase, RoomBand, ScratchFeedback, HeaderMarks, InkHeaders, TouchPath) stay.

## What had to bend

- **Overrides stay in the class.** Swift can't override a non-`@objc` method from an extension, so
  `touchWentDown`, `touchMoved`, both `touchEnded`s, `touchLifted`, `toolChanged`, `fingerTapped` and
  `fingerLifted` stay in `PaperBoard.swift`; their helpers moved.
- **`private` loosened only where the compiler asked.** A `private` member is seen only in its own file, so each one
  now used across files is internal, and `private(set)` dropped where another file sets it. Found by building until
  the build was clean, not by guessing; everything else keeps its `private`.
- Imports per file are the ones its code uses.

## Verified

`just native-test` (lint, host, scripts), `just native-build-mac`, and the whiteboard UI tests on the iPad simulator
through the lanes (`just test-ladder`).
