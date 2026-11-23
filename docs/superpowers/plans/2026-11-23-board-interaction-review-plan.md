# Plan: reviewing each writing session on a board

Spec: [2026-11-23-board-interaction-review-design.md](../specs/2026-11-23-board-interaction-review-design.md). Approved
2026-11-23; stories 1237–1262, epic bead `context-grabber-8ao5` (part 1 `.1`, part 2 `.2`). Evidence the checks are built from: the manual review of 2026-11-23
(`~/tmp/agent/notes/ipad-writing-review-2026-11-23.md`) and the event catalogue in `docs/debugging/whiteboard.md`.

Four pieces, in this order. Each lands as its own PR; the record's form (slice 1) goes first because the other three
code against it.

## Slice 1: the review engine in BoardCore, and `bw_review`

New files under `native/ContextCore/Sources/ContextCore/Whiteboard/` (BoardCore's sources, so WASI-clean: no disk, no
network, no clock read inside a check; the whiteboard file rule, one file per piece, not a bigger existing file):

| File | What |
|---|---|
| `BoardSessionRecord.swift` | The record: a header (board id, surface `ipad`/`web`, build, contract version, the starting board in the `bw_outline_load` form), then steps as JSONL. A step: `t` (unix ms), `kind`, `by` (`pencil`, `finger`, `menu`, `larry`, `claude`, `rule`, `system`), `aim` (ids or a box), `changes` (per id: owner, before/after box and transform, hidden), `folds` (before/after per header: held ids), `undo_name`, and `seen` (surface observations: `selection_held`, `pen_before`/`pen_after` (with `pen_approx` when the surface knows the pen only from its last input, the web board), `kept_drawn` {`span`, `whole_span`, `dark_px`, `heals`}), each absent when not observed. Codable, versioned |
| `BoardReview.swift` | `BoardReview.run(record) -> BoardReviewReport`: replays the steps on a `BoardOutline` built from the starting board, asks the existing rules for each step's prediction, and runs the checks. A report: findings (`check`, `verdict` bug/asDesigned/unclear, `step` index and `t`, `story`, `evidence` as ordered key/values) and per check `checked`/`approximate`/`notChecked` (an approximate check's finding is at most `unclear`) |
| `BoardReview+Placement.swift` | Checks 1 (inside a fold) and 2 (under ink), using `BoardRoom`, paste `place`, `drop` and the late-reply rule for the predicted room |
| `BoardReview+Moves.swift` | Checks 3 (Igor's ink moved) and 4 (both owners), using the owners-apart rule and the room and fold shift predictions; intent = `aim` ∪ predicted push/slide |
| `BoardReview+Folds.swift` | Check 5, against `BoardOutline`'s fold with the header's recorded `ends` (story 1231) |
| `BoardReview+Undo.swift` | Check 6: keeps a board snapshot per step and compares an Undo's result with the snapshot before the step it named |
| `BoardReview+Seen.swift` | Checks 7–9, read only from `seen`; absent means `notChecked`, `pen_approx` makes check 8 `approximate` |
| `BoardReviewText.swift` | The copyable text of a finding and the one-line summary for Larry, so both surfaces print the same words |

- **Tolerance** in one place: 0.5 pt for a move, edge-touching is no overlap (the rules already decide meeting the
  Apple way, *Boxes that only touch*). Well above the 1e-4 pt the 32-bit wasm arithmetic differs by.
- **Dedup**: one finding per (check, step, ids).
- **`bw_review`** in `Sources/BoardWasm/BoardWasm.swift`: pointer, length of a record (JSONL) → a reply with the
  report as JSON, or `{"error"}`. Stateless: nothing loaded is touched, so it can run beside a live board. It takes
  the next `abi` (8 on main today; `bw_rows`, `bw_candidates` and `bw_opening` may take 9 first, so the number is
  set when it lands) and a row in the board-rules-on-the-web spec's interface tables.
- Adds the new files to `boardSources` (already the `Whiteboard` folder) and the tests to `boardTests`.

## Slice 2: the iPad

App files, each its own `+Review` extension:

| File | What |
|---|---|
| `native/App/Whiteboard/WhiteboardModel+Review.swift` | The session's lifetime (open, idle timer, close, a cut-short session reviewed on next open), appending model-side steps (Larry's ops, keeps, folds, room, paste, undo names), running `BoardReview` off the main actor, storing the record and report |
| `native/App/Whiteboard/PaperBoard+Review.swift` | Surface-side steps from what the board already observes and logs: `paper_ink` (changes, `undoing`), `paper_drop`/`paper_drop_after`, `paper_apart`, `group_tap_lost`/`_after`, `paper_keep` (pen before/after), `paper_kept_ink` (`span`, `dark_px`, heals), the touch's start (`on_knob`, `handle_inside`, the reflow view) from `PaperBoard+MoveAudit.swift` |
| `native/App/Whiteboard/BoardReviewNote.swift` | The corner note and the findings list; each finding a `BugProblemView`-style copyable block; *Show me* opens `BoardPlayback` at the step with before/after and the named ids marked; *I meant that* / *Not what I meant* |

- **Storage**: the record and report beside the board, device-only (not in the board's iCloud files), pruned at
  launch after 14 days (Igor's decision 2).
- **Log**: `whiteboard` action `board_review` with board, session, steps, per-check counts by verdict, `not_checked`,
  `ms`; `board_review_answer` when Igor answers an unclear finding. Added to `docs/debugging/whiteboard.md`.
- **To Larry**: the summary from `BoardReviewText` rides the next picture's post for that board (Igor's decision 4).
- **Menu**: *Review this session* in the board's menu.

## Slice 3: the web board (Larry's)

- The Cockpit's web board writes the same record (slice 1's form, `surface: "web"`), calls `bw_review` at idle and on
  demand, and shows its own note and list from the report.
- Its pen, lasso and Undo are the page's own, so it fills `seen` as Larry answered (2026-11-23): the selection and the
  kept mark exactly, the pen with `pen_approx`, which the engine reports as *approximate*.
- No app change is needed for it beyond slice 1; the app side only keeps `bw_review` and the record form stable.

## Slice 4: tests on recorded sessions

- **Fixtures** under `native/ContextCore/Tests/ContextCoreTests/Fixtures/board-reviews/`, scrubbed as
  `board-sessions/SOURCE.json` describes (letters to x, stroke points onto a line across their box), each with a
  golden report:
  - `ipad-2026-11-23-s1`, `ipad-2026-11-23-s2`: built from the logs in `~/tmp/agent/grabber-logs/ipad/logs/`
    (grabber-20261122-225645 and grabber-20261123-045031) by a one-off converter (`scripts/native/board-review-from-log.py`):
    the log has each step's ids, boxes and moves; strokes come from the Cockpit's copy of those boards. Golden: no bug,
    05:15 reflow `asDesigned` (1145), 05:28 knob stretch `unclear`, keeps clean, popover selection losses `asDesigned`.
  - One per closed bead: eysh (from the Cockpit's .ink repro already behind `BoardFoldWrittenUnderTests`), 9bll,
    pbvt, dell, 4nnh, eg7v, vhae, each from its recorded numbers on the bead and story.
  - Synthetic pairs per check: fires / clean, and the deliberate version of each move not flagged.
- **`BoardReviewTests`** (host, rung 1): every fixture reviews to its golden; a record re-reviewed gives the same
  report; a review leaves its input untouched; tolerance edges (0.4 pt move not flagged, touching edges not overlap).
- **`just wasm-test`**: `scripts/native/test-board-wasm.mjs` runs every fixture through `bw_review` and compares with
  the same goldens, so the iPad and the web agree verdict for verdict.
- **Rung 2**: a UI test that writes, waits out a shortened idle (a launch hook), and finds the note and a copyable
  finding (a forced fold-swallow through a test hook).
- **Rung 3**: the iPad, a real session reviewed after idle; read `board_review` in the pulled log.

## Order and risk

1. Slice 1 with the synthetic and bead fixtures (host and wasm). No app change; safe to land first.
2. The two 2026-11-23 fixtures, which check the converter and the verdicts against the manual review.
3. Slice 2, then the device check. Slice 3 in parallel on the Cockpit once `bw_review` is in a build.

Risk: the record grows with every step on a long session (the 6bae session had about 300 steps). Changes carry boxes
and transforms, not points, except for added ink, so a session is expected in the tens of KB; measure on slice 2's
first device session.
