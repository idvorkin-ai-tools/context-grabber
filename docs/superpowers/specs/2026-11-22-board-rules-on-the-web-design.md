# The board's rules on the web: BoardCore as WebAssembly

Story 1503. Plan: [2026-11-22-board-rules-wasm-plan.md](../plans/2026-11-22-board-rules-wasm-plan.md). Igor,
2026-11-22: the Cockpit's web ink board runs the app's own Swift board rules, compiled to WebAssembly, so a board
answers the same on the web as on the iPad.

## Summary

The board's rules (where a clear line is, what a recorded session replays to) build as one WebAssembly module. The
Cockpit's web board loads it once, hands it the board, tells it about new ink as it is drawn, and asks it where a cut
lands. The answers are the iPad's, computed by the same code, not a JavaScript copy of it.

## Goals

- The rules the board uses on the iPad build for WebAssembly (WASI), with nothing else of the app: no networking, no
  disk, no drawing.
- A small interface the Cockpit codes against, with a version number, that stays the same while the rules behind it
  change.
- The board stays loaded: the Cockpit sends it once, then only new ink, and asks with plain numbers.
- One command builds the module, stripped; one replays the Cockpit's recorded board sessions through it and checks them
  against the same goldens the app's own replay test uses.

## Non-goals

- Not the Cockpit's side: the page that loads the module, the browser's WASI stand-in and the board's adapter are the
  Cockpit's work.
- Not text measuring: placing a text needs a font, and the module has none, so nothing that lays out letters is offered.
- Not a smaller module yet. It is about 56 MB stripped (about 20 MB gzipped, 13 MB with brotli), nearly all Foundation
  and its Unicode data. Moving the rules to a lighter Foundation is later work.
- Not the iPad's own precision (below).

## What the Cockpit sees

- It loads the module and starts it once.
- It hands over the board exactly as the iPad posts it to the Cockpit: the board's id and its strokes, each with its
  points and width, kept texts included. The module answers with how many boxes its rules see, or says why it could
  not read the board.
- New ink goes in as strokes in the same form. Anything else that changes the board (an erase, a move, an undo) means
  loading it again.
- Asked where a cut at a height lands, it answers with the clear line the iPad would choose: the height itself when it
  is clear, else the nearer edge of the row of ink it falls in, the top only when it is within two lines.
- With nothing loaded, it says so rather than answering.
- Every failure can be read back as words.

## The interface, version 1

The module is a WASI reactor (`wasm32-unknown-wasip1`): the host calls `_initialize` once, then the exports below.
It imports 34 `wasi_snapshot_preview1` functions and nothing else: `args_get`, `args_sizes_get`,
`clock_res_get`, `clock_time_get`, `environ_get`, `environ_sizes_get`, `fd_close`, `fd_fdstat_get`,
`fd_fdstat_set_flags`, `fd_filestat_get`, `fd_filestat_set_size`, `fd_filestat_set_times`, `fd_pread`,
`fd_prestat_dir_name`, `fd_prestat_get`, `fd_read`, `fd_readdir`, `fd_seek`, `fd_sync`, `fd_tell`,
`fd_write`, `path_create_directory`, `path_filestat_get`, `path_filestat_set_times`, `path_link`,
`path_open`, `path_readlink`, `path_remove_directory`, `path_rename`, `path_symlink`, `path_unlink_file`,
`poll_oneoff`, `proc_exit` and `random_get`. Measured under node over the whole test (the four replays,
loads, new ink, cuts and refusals), only six are called: `random_get`, `args_sizes_get`, `args_get` and
`environ_sizes_get` while `_initialize` runs, then `clock_time_get`, and `fd_prestat_get` once, answered "bad
descriptor" (8): there is no directory to open. A browser's stand-in answers those six and can answer every other
import with an error. All numbers are wasm
`i32` unless marked `f64`.

**Memory.** The host writes input into the module's `memory` through a buffer it asks for with `bw_alloc`, and
frees it with `bw_free` once the call returns: the module never keeps an input buffer. Every pointer an export
returns is a new *reply*: four bytes of length (unsigned, little-endian) and then that many bytes of UTF-8. The host
reads it and frees the pointer with `bw_free`. Text is UTF-8 JSON unless said otherwise. Any call may grow the
memory, which replaces `memory.buffer`: the host takes a fresh view of it after every call, never one kept from
before.

| Export | Arguments | Returns |
|---|---|---|
| `bw_alloc` | `n`: bytes | a pointer to `n` bytes for the host to fill |
| `bw_free` | a pointer from `bw_alloc` or a reply | nothing |
| `bw_info` | none | a reply: `{"abi": 1, "cgfloat_bits": 32, "contract": 1, "line": 40, "near": 80}` |
| `bw_load` | pointer, length of a board | the number of boxes, or `-1` |
| `bw_add_strokes` | pointer, length of `{"strokes": [...]}` | the number of boxes now, or `-1` |
| `bw_cut_y` | `y` (`f64`, board points) | the clear line (`f64`), or NaN |
| `bw_error` | none | a reply holding why the last `bw_load`, `bw_add_strokes` or `bw_cut_y` failed (plain text), or `0` when it did not |
| `bw_replay` | pointer, length of a recorded session (JSONL) | a reply: the replay (below). For tests |

- `bw_info`: `abi` is this interface's version; it goes up when an export's arguments, results or JSON shapes
  change, and a host that sees a version it doesn't know stops. `cgfloat_bits` is the width of the rules'
  arithmetic, `contract` the board contract the replay reads, `line` and `near` the ruled line and how far a cut
  looks for a clear one, in board points.
- A board is the body of the iPad's `POST /whiteboard/strokes`: `{"board": id, "strokes": [...]}`. A stroke is
  `{"id", "points": [[x, y], ...], "width"}` with optional `"hidden"`, `"t"`, `"color"`, `"tool"` and
  `"meta"` (a `group` in it makes strokes one box); a kept text is `{"id", "kind": "text", "x", "y", "w", "h", "t"}`. A kept text is told from another by its
`t` (milliseconds), as on the iPad, which posts it: texts with no `t`, or within a millisecond of each other, count
as one box.
  A width left out is 3, as on the iPad; the web board's own format (`pts`, `w`, a default of 4) is the Cockpit's to
  convert. Other fields are ignored.
- The boxes are what the iPad's rules cut around: each shown stroke's, each kept text's, a group's as one; hidden ones
  left out.
- `bw_load` replaces the loaded board. When it fails nothing is loaded. `bw_add_strokes` adds to the loaded board;
  when it fails (nothing loaded, or a stroke it can't read) the loaded board is as it was.
- `bw_cut_y` answers NaN when nothing is loaded.
- `bw_replay` runs a recorded session (the Cockpit's `fixtures/board/sessions`) through the board's own replay and
  answers `{"name", "contract", "mismatches": [..], "turns": [{"id", "onBoard", "hint"}], "batches": [{"reply",
  "arrivedAt", "matches", "replayedOk", "recordedOk"}]}`, or `{"error": why}`.

## Precision: a known difference from the iPad

In WebAssembly the rules' arithmetic is 32-bit (`CGFloat` is a `Float` on `wasm32`; the SDK has no 64-bit
target), where the iPad's is 64-bit. Boxes agree to about 1e-4 points. A decision differs only when a height sits
within about 1e-4 points of the exact middle of a row, where the rule breaks a tie between the row's top and bottom:
in the spike, 9 of about 4,600 queries on the recorded boards, 8 of them heights placed there on purpose and one from a
plain 1.5-point sweep (the title-build board at 100). The module answers as the 32-bit rules do; the replay test pins
that one case so a change shows. If it matters, the rules get their own 64-bit geometry, a change on the app's side.

## Acceptance criteria

- The board's rules build for WebAssembly, and the app, its tests and its Linux build are as before (the board's HTTP
  requests moved out of the board's module, the same calls from the same places).
- One command builds the module stripped and prints its size and checksum.
- Every recorded session replays through the module as the app's replay test expects: contract 1, no mismatch but
  ops-move's known one, each turn's hint the end of the recorded hint, the same turns.
- A board loaded whole, and the same board loaded in two halves (the second added as new ink), give the same clear
  line at every height tried; asked before any board is loaded, the answer is NaN with a reason.
