# Plan: split WhiteboardView.swift by feature (move only)

Bead: context-grabber-jp6z. No behaviour change, so no spec or story change.

## Why

`native/App/Whiteboard/WhiteboardView.swift` was about 3,000 lines: the whole `WhiteboardModel` (about 2,400 lines),
the ghost types and the SwiftUI view. It took 167 commits in 30 days, and AGENTS.md has two PRs that edit one file
land one after the other, so nearly every whiteboard PR waited on the one before it
(`~/tmp/agent/notes/wb-arch-structure.md`, sections 1 and 2).

## What moves where

| File | What it holds |
|---|---|
| `WhiteboardModel.swift` | the class: its stored and published properties, `init`, `load`, and the init's helpers (meaning file, save debounce, notices) |
| `WhiteboardModel+LarryTurn.swift` | Larry's turn: the note's mark and tap, hand-off, log shipping, strokes, thread polling, marks, waits, timeouts, Retry, Dismiss, Interrupt |
| `WhiteboardModel+InkMirror.swift` | changed, settled, stepped, the save debounce they start, the picture's frame and label boxes |
| `WhiteboardModel+Pacing.swift` | the pause after the pen lifts (VAD) and hover |
| `WhiteboardModel+Settings.swift` | ghosts, grid, ruled lines, lettering, paper |
| `WhiteboardModel+Mic.swift` | the mic and dictation |
| `WhiteboardModel+ClaudeTurn.swift` | Claude's ghost turn: ask, stream, land, fade, fail |
| `WhiteboardModel+Keep.swift` | keep, Keep all, Tidy overlaps, choosing, the room a keep makes |
| `WhiteboardModel+Paste.swift` | stroke building, the undo names, paste of text and strokes |
| `WhiteboardModel+Responder.swift` | the responder knob, read from and written to the Cockpit |
| `WhiteboardModel+Save.swift` | flush, opened, close, save, Send |
| `WhiteboardModel+LarryOps.swift` | Larry's changes to the board (the extension that was already there, moved whole) |
| `WhiteboardGhostLayers.swift` | `Ghost`, `UploadClock`, `GhostLayers` and the colour extensions |
| `WhiteboardView.swift` | the SwiftUI view only |

## Rules of the move

- Every line is moved, not rewritten: a check compared the old file's code lines with the new files' (access
  modifiers set aside) and found only the added imports and extension braces.
- `private` and `fileprivate` were dropped only where the compiler said an extension in another file needed the
  member, and `private(set)` only where another file sets it. Everything else keeps its access.
- Overload resolution can't change: inside the old file every private member was already visible, and callers
  outside it (PaperBoard, the view, the other model extensions) were checked for a newly visible overload with
  the same name.

## Verification

`just native-test`, `just native-build-mac`, and the whiteboard UI tests on the iPad simulator in a build lane.
