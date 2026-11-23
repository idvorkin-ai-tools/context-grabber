# Plan: the board's rules as WebAssembly

Spec: [2026-11-22-board-rules-on-the-web-design.md](../specs/2026-11-22-board-rules-on-the-web-design.md). Story 1503.
The spike that proved it (Swift 6.4.2, the `swift-6.4.2-RELEASE_wasm` SDK, node) found BoardCore two edits away from
building for `wasm32-unknown-wasip1`; this does those edits for real and adds the module, its recipe and its test.

## Slice 1: BoardCore builds for WASI

WASI's Foundation has no FoundationNetworking, so no `URLRequest`, and no temporary files, so no atomic write.

- **The HTTP requests move up into ContextCore, as extensions.** Every request builder in ChatWireKit and BoardCore
  (`ChatWire`'s list, thread, seen, archive and `get`; `ChatDecisions`' list, request and run; `ChatMove`'s
  request, run and `Transport`; the board's events, to-text, asks and answers, strokes, responder and suggest
  requests) is now in `Cockpit/ChatRequests.swift` and `Cockpit/BoardRequests.swift`, extensions on the same types.
  ContextCore re-exports both modules, so every caller (the app, the widgets, the harnesses, ContextCore's own code)
  compiles unchanged. No file moved or was renamed (the rule of
  [2026-11-22-contextcore-targets-plan.md](2026-11-22-contextcore-targets-plan.md)); only bodies left their files.
  `ChatDecisions.postToChat` became `package` so the moved request can read it.
- **Their tests move with them.** BoardCoreTests sees only BoardCore, so the ten request cases from six board test
  files went to a new `WhiteboardRequestsTests` in ContextCoreTests (listed in `boardTestsInContextCore`), unchanged
  but for the two that also checked a non-request rule: those were split, the rule staying where it was.
- **`FileBoardDisk.write` keeps its atomic write everywhere but WASI**, under `#if os(WASI)`. Moving
  `FileBoardDisk` out was the other choice, but `BoardKeeping` takes it as its default disk and two board test
  files build it, so the guard is the smaller change; nothing in the module writes a board to disk.

Source-compatible for iOS and the Mac: the same declarations, public as before, from the same `import ContextCore`.
Only the Linux build was compiled here (no Mac); the Darwin cross-build in `just test-linux` and the Mac's
`just native-test` are owed.

## Slice 2: the BoardWasm reactor

- A `BoardWasm` executable target depending on BoardCore alone, linked with `-mexec-model=reactor` on WASI only.
  Its exports are `@_expose(wasm)` + `@_cdecl` functions under `#if os(WASI)`; elsewhere the target is a one-line
  stub, so `swift build` on the Mac and Linux still builds.
- The state (the loaded board, its boxes, the last error) is plain globals outside `main.swift`, so they are
  initialised on first use: a reactor never runs `main`'s top-level code.
- Boxes are `BoardOps.shownBoxes` over the snapshot's plan input, what the iPad's own make-room and room-by-hand cut
  around, cached until new ink arrives.

## Slice 3: the recipe and the test

- `just wasm` (`scripts/native/build-wasm.sh`): `swift build --swift-sdk <wasm SDK> --product BoardWasm -c release`
  with `--strip-all`, copied to `native/Build/wasm/BoardWasm.wasm`, then its size and sha256. `WASM_SDK` names
  the SDK (default: the first `wasm` one `swift sdk list` shows), `WASM_LIB_DIR` a directory of libraries the
  toolchain's `wasm-ld` needs (an Ubuntu 25.10 box lacks `libxml2.so.2`; SwiftPM drops `LD_LIBRARY_PATH` when it
  runs the linker, so the script hands it a wrapper through a toolset file).
- `just wasm-test` (`scripts/native/test-board-wasm.mjs` under node): instantiates the module with node's own WASI,
  replays the four recorded sessions in `Tests/ContextCoreTests/Fixtures/board-sessions` (vendored by
  `scripts/native/board-sessions.py`, #1240) and checks what `BoardSessionReplayTests` checks; then the load-whole
  versus load-in-halves check, NaN before a load, `bw_info`'s version, and the pinned 32-bit midpoint case. Without
  a wasm SDK it says it skipped.

## The 32-bit midpoint

`CGFloat` is `Float` on wasm32 and the SDK has no wasm64, so the rules compare in 32 bits. The spike measured 9
decision flips in about 4,600 clear-line queries against a 64-bit build, all within 1e-4 points of a row's exact
middle. Handled by stating it (the spec's *Precision*), not by working around it: rewriting `cut` in `Double`
inside BoardWasm would stop it running the app's rules. The test pins the one natural case (title-build's last board,
y = 100) so a change in the rules or the toolchain shows.
