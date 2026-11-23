# Plan: ChatWireKit and BoardCore, two targets inside ContextCore (in place)

Bead: context-grabber-wq2j (the whiteboard refactor, D3 slices 1 and 2; Igor approved the plan 2026-11-22). No
behaviour change, so no spec or story change.

## Why

`ContextCore` is one SwiftPM target of about 217 files. A board test run builds all of it, and every board PR shares
one module with everything else. The board's logic (`Sources/ContextCore/Whiteboard`, about 80 files) and its tests
(about 77 of 185 test files) get a target of their own, under a small target that holds the Cockpit chat wire the chat
screen and the board share.

## The rule: nothing moves

About twenty agents are editing these files in other PRs. No file is moved or renamed. Each new target points at the
existing directories with SwiftPM's `path:`/`sources:`, and `ContextCore` `exclude:`s the same files, each list
written once in `Package.swift` and used for both. `ContextCore` re-exports both targets (`@_exported import`), so
the app, the widgets, the share extension, the harnesses and `import ContextCore` callers compile unchanged.

## Slice 1: ChatWireKit

| What | Where it stays | Why it is in the target |
|---|---|---|
| `ChatWire`, `ChatSummary`, `ChatMessage` (and its receipt) | `Chat/ChatWire.swift` | the chat's list and thread decoding, read by the board |
| `ChatAsk`, `ChatDecisions` | `Chat/ChatDecisions.swift` | the asks the board lands as questions |
| `ChatMove`, `ChatLinks`, `ChatBubbleLinks`, `ChatCockpitLink` | `Chat/` | what `ChatDecisions` and the board's note need |
| `CockpitPage`'s address and `origin(of:)` | new `Cockpit/CockpitAddress.swift` | the one piece of the Cockpit screen the wire needs; the rest of `CockpitPage` extends it from `CockpitPage.swift` |

Edits to break the cycle, kept small:

- `ChatWire.pendingThreads` reads `InboxItem`, so it moves to `Chat/ChatWire+Inbox.swift` in ContextCore, as an
  extension: callers are unchanged.
- `InboxSend.origin(of:)` (a ContextCore wrapper) becomes `CockpitPage.origin(of:)` in the two moved files that used it.
- `ChatWire.get` becomes public (ContextCore's PR states and asks use it); `ChatAsk.Mark` and `ChatMove.Line` get
  public inits, because their tests built them through `@testable import ContextCore`, which does not reach a
  re-exported module's internals.
- ChatWireKit has its own internal `trimmingSuffix`, beside ContextCore's.

## Slice 2: BoardCore and BoardCoreTests

- `BoardCore`: `Whiteboard/` (every file in it, new ones included, since the directory is the source) and
  `Platform/LinuxGeometry.swift` (the CGVector and CGAffineTransform the board uses on Linux). Depends on ChatWireKit only.
- Cycle breakers, the only source edits: `WhiteboardThreads.firstSendWaiting(board:in:)` reads `InboxItem`, so it moves to
  an extension in `Inbox/`; the archive record fit the call log and the board's log share moves from `CallLogArchive`
  to `ArchiveRecord` in ChatWireKit (`CallLogArchive.fitted` stays, delegating); four board files' `InboxSend.origin` and
  `BoardToText`'s `CockpitPage.origin` read `CockpitPage.origin`.
- Access: members ContextCore or its remaining tests use become `public` (found by the compiler, one at a time), and
  structs those tests build get a public memberwise init.
- `BoardCoreTests`: the board test files, listed in `Package.swift`, built with `-module-alias ContextCore=BoardCore`
  so their `@testable import ContextCore` line reaches the board's internals unchanged. Test files that also need
  ContextCore (the Inbox, the call log, the session log) stay in `ContextCoreTests`.
- A host-rung check names any `Board*`, `Whiteboard*` or `Paper*` test file that is in neither list, so a new one is placed
  on purpose.
- `just board-test [filter]` builds only ChatWireKit, BoardCore and BoardCoreTests and runs that bundle (Mac only: it
  runs `xctest`). `just native-test` still builds and runs everything, both bundles.

## For agents working on the board

- A board source file can't name a ContextCore type (`InboxItem`, `ChatSend`, `SessionLogLine`, ...). Put the
  piece that needs it in an extension file in ContextCore, or move the shared type down.
- A board test that needs ContextCore goes in `ContextCoreTests` and sees only the board's public API.

## Measured (2026-11-22, a Mac with about twenty other agents' builds running, so the numbers are noisy)

| Edit, then the board's tests | Before (`swift test --filter 'Board|Whiteboard|Paper'`) | After (`just board-test`) |
|---|---|---|
| a board test file, one class run, old layout vs new | 6.3 s | 3.8 s |
| a board source body, one class run, old layout vs new | 6.0 s | 2.8 s |
| a board test file, every board test | 13.1 s | 9.5 s |
| a board source body, every board test, same tree (median of 3) | 7.1 s | 6.4 s |
| a non-board source, every board test, same tree (median of 3) | 6.4 s | 5.4 s |
| a board interface change, every board test, old layout vs new | 17.8 s | 22.2 s |
| cold build, scratch path empty | 17 to 29 s | 18 to 22 s |

The win is a few seconds an edit, not a cold-build win: the board is about 80 heavy files and sits on ContextCore's
critical path either way, and a change to the board's public interface now recompiles its dependents in ContextCore.
The lasting gain is the boundary: board code can't reach into the rest of ContextCore, and its tests build and run
without it. The whole board bundle runs 871 tests; six board-named test files (`boardTestsInContextCore`) stay in
ContextCoreTests.

## Verification

`just native-test` (both bundles, the same test count as before), `just native-build-mac`, the iPad simulator build.
Linux (`just test-linux`) needs a Linux box: owed if none is reachable.
