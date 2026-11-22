# Plan: one tool value from the picker, snapshotted per touch (bead context-grabber-ckv5, story 1091)

Spec: [Whiteboard with Claude](../specs/2026-11-01-whiteboard-design.md), *The board acts on the tool Igor picked*.
Recommendation 1 of `~/tmp/agent/notes/wb-arch-recommendations.md`.

## Why

`PaperMarkupViewController.drawingTool` logged a black pen on 7,313 iPad touches, including 11 that erased and strokes
drawn blue (#1078). Ten places decided behaviour from it. The picker's `selectedToolItem` is what Igor sees selected.

## What changes

- `PickedTool` (`native/App/Whiteboard/PaperPickedTool.swift`): ink (with its `PKInkingTool`), eraser, lasso, other;
  built from a `PKToolPickerItem`, or from a `PKTool` for reverting.
- `PaperHost.decidingTool` is the one source (`PickedTool(picker.selectedToolItem)`). `PaperHost.touchTool` is its
  snapshot, taken at every touch down (a Pencil beside a resting palm included), and kept after the run ends, since PaperKit's stroke callback
  (margin hold, word pickup, ink headers) lands after the lift.
- Readers of the snapshot: fold erase (`foldEraserDown`), the answered-card erase in `touchMoved`, shape snap and its
  preview's colour and width, the room band's Pencil hold, `marginHeld`, `pickedUp`, `inkHeaderSoon`.
- `place.erasing` and `model.penInHand` come from `decidingTool` in `toolChanged`, and from the snapshot at every
  touch-down (`toolInHand`), so a pick the observer missed still lands.
- Keep's restore (context-grabber-a3w): when setting the markup changed `drawingTool`, it goes back to the picker's
  tool, not the board's earlier (possibly stale) one. `paper_keep` logs `tool_restored_to` and `picker_tool`.
- Logging is unchanged: `paper_touch`'s `tool`/`ink`, `hold_began`'s `drawing_tool` and `tool_changed`'s
  `tool`/`tool_ink` still read `drawingTool`, beside the picker's word (#1100).

## Not changed

`drawingTool` is never set from the picker (beyond Keep's restore), so PaperKit's own drawing and erasing are as before;
that staleness waits for the iPad's evidence.

## Reverting

Change `decidingTool` to `PickedTool(paper.drawingTool)`; everything else follows it.

## What the iPad must show

On `paper_touch`, `picker` and `ink` side by side; on `tool_changed`, `picker_tool` beside `tool_ink`. Where the
picker says `eraser` and `ink` a black pen, an eraser stroke across a fold's marker now logs `board_outline`
`erase_fold` (via `eraser`), which it could not before.
