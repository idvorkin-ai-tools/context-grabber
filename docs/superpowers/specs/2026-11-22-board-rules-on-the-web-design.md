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

## The interface, version 2: rows and folds

Story 1508. Igor, 2026-11-22: "build all of the web features for the Swift core and drag them back and forth". Version 2 adds the
next two answers the web board takes from the app: which row of writing a tap is on, and what folding a header tucks
away. Everything in version 1 is unchanged; `bw_info` says `"abi": 2`.

These answers need the board's writing itself, not only its boxes, so the Cockpit sends a second copy, the *outline*,
held apart from the board `bw_load` keeps:

- Each stroke with its real points and pen width (a width left out is 3), and whether it is hidden.
- Each kept text and each card as the box the Cockpit measured, since the module cannot measure text. Each moves whole
  and is nobody's handwriting.
- Which strokes belong to one group (a text or a card is its own group).
- The headers as the iPad keeps them: each header's strokes, its `#` mark and deeper marks, and, when it is folded,
  what its fold holds, what it hid itself, how far the rest slid, how many lines it hides and where its section ended.

| Export | Arguments | Returns |
|---|---|---|
| `bw_outline_load` | pointer, length of an outline | the number of strokes and boxes read, or `-1` with nothing loaded |
| `bw_outline_add` | pointer, length of `{"strokes": [...]}` | the number of strokes and boxes now, or `-1` with the outline as it was |
| `bw_row_at` | `y` (`f64`) | a reply: `{"row": null}` on blank paper, `{"row": {"header", "top", "bottom"}}` on a header's row, else `{"row": {"names", "top", "bottom"}}` with the row's strokes in board order |
| `bw_fold` | pointer, length of `{"id"}` | a reply: `{"fold": null}` when there is nothing to fold, else `{"fold": {"ids", "own", "shift", "lines", "bottom"}}` |

- The row at a height is the row of writing within half a line of it, as a margin tap or the hold menu on the iPad
  finds it. A row holding a header is that header.
- Folding asks what the fold would do and leaves the loaded outline as it was: the Cockpit applies the answer to its
  own board, then sends the outline again.
- New writing at the end goes in with `bw_outline_add`; anything else that changes the board loads the outline again.
- With no outline loaded, both questions answer `{"error"}` saying so, and every failure can be read back as words.

The web board's "Swift N/M" level moves each answer over one step at a time: below the step the web board answers
itself, at or above it the module does, so the two can be compared on the same board.

## The interface, version 3: where a paste lands, and the room a drop opens

Story 1513. The next two steps of the web board's Swift level: a paste (text pasted as a kept text) lands where the
iPad's would, and a selection dropped on writing pushes it down by the iPad's rule. Both are asked of the board
`bw_load` keeps, with plain numbers; `bw_info` says `"abi": 3`, and versions 1 and 2 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_place` | `w`, `h`, then the view's `left`, `top`, `right`, `bottom` (all `f64`, board points) | a reply: `{"x", "y", "push": null}` where a clear patch holds it, else `{"x", "y", "push": {"cut", "dy"}}`; `{"error"}` with nothing loaded |
| `bw_drop` | the dropped block's `left`, `top`, `right`, `bottom`, then the box it was lifted from (all `f64`) | a reply: `{"push": null}` when it opens no room, else `{"push": {"cut", "dy"}}`; `{"error"}` with nothing loaded |

- The Cockpit measures the pasted text and sends its size: the module has no font.
- A paste lands on the clear patch of the view nearest its middle that holds it with half a line of air all round, right
  of the margin and inside the page. When none does, it goes under the writing above the clear line nearest the view's
  middle, and room opens there: as much as it needs beyond the blank paper already there, in whole lines.
- A drop opens room only when the block sits on writing other than the line it was lifted from (touching an edge is
  not sitting on it). Then everything below the clear line nearest its top goes down by whole lines until the first of
  it is half a line under the block.
- For a drop the loaded board is everything but what was dropped: the Cockpit loads that board before asking.
- The Cockpit moves the writing; the module only answers where and how far.

## The interface, version 4: headers written in ink, Fold all and Collapse

Story 1512. The next step: an underline or a # the principal writes makes a header by the iPad's rule for headers
written in ink, and Fold all and Collapse to a level fold the headers the iPad's Fold all and Collapse fold. Both are
asked of the outline `bw_outline_load` keeps, each on a copy: the loaded outline stays as it was, and the Cockpit
makes the board change. `bw_info` says `"abi": 4`; versions 1 to 3 are unchanged.

| Export | Arguments | Returns |
|---|---|---|
| `bw_ink_header` | `{"name", "id"}`: the stroke just drawn (already in the outline) and the name a new header takes | a reply: `{"ink": null}` when the stroke does nothing for headers, else `{"ink": {"kind", "header", ...}, "after": the header as it now is}`; `{"error"}` with no outline or no name and id |
| `bw_fold_plan` | `{}` for Fold all, `{"to": n}` for Collapse to level n | a reply: `{"open", "levels", "folds": [{"id", "ids", "own", "shift", "lines", "bottom"}]}`; `{"error"}` with no outline, a request that is not a JSON object, or a `to` that is not a whole number |

- `kind` is `underline` or `hash` (the line became header `id`; with `y`, the line's middle, and `mark`, the strokes
  that made it), `grew` (the stroke was written on a header's line and joined it; with `names`) or `deeper` (a #
  finished beside a # header's #s took it a level deeper; with `level`, `y` and `mark`). `after` is the header as
  the iPad keeps it.
- `folds` are in the order the iPad makes them, the lowest header first, each as `bw_fold` describes one, and only
  the headers that fold now (one already folded, or one that does not fold, is not listed). `open` says every fold
  was opened first (Collapse does that; Fold all does not). `levels` is each header's level with everything open.
- The Cockpit makes the folds one after another by its own fold, given each fold's strokes and shift.

## Precision: a known difference from the iPad

In WebAssembly the rules' arithmetic is 32-bit (the SDK has no 64-bit target), where the iPad's is 64-bit. Boxes
agree to about 1e-4 points. A decision differs only when a height sits
within about 1e-4 points of the exact middle of a row, where the rule breaks a tie between the row's top and bottom:
in the spike, 9 of about 4,600 queries on the recorded boards, 8 of them heights placed there on purpose and one from a
plain 1.5-point sweep (the title-build board at 100). The module answers as the 32-bit rules do; the replay test pins
that one case so a change shows. If it matters, the rules get their own 64-bit geometry, a change on the app's side.

### Boxes that only touch

On Apple's platforms two boxes that only share an edge or a corner do not meet; in the Foundation that Linux and
WebAssembly use, they do. The board's rules therefore decide whether boxes meet themselves, the way Apple does: an edge
or a corner shared is no overlap, any area is. Without that, a paste whose half line of air exactly touched a line of
writing landed elsewhere on the web than on the iPad (found by the Cockpit's comparison on its seeded random boards,
2026-11-22, and checked against Apple on the Mac).

## Acceptance criteria

- The board's rules build for WebAssembly, and the app, its tests and its Linux build are as before (the board's HTTP
  requests moved out of the board's module, the same calls from the same places).
- One command builds the module stripped and prints its size and checksum.
- Every recorded session replays through the module as the app's replay test expects: contract 1, no mismatch but
  ops-move's known one, each turn's hint the end of the recorded hint, the same turns.
- A board loaded whole, and the same board loaded in two halves (the second added as new ink), give the same clear
  line at every height tried; asked before any board is loaded, the answer is NaN with a reason.
