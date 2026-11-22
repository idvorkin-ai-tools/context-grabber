# PaperKit contract tests: implementation plan (bead context-grabber-0u3k, arch 3)

No behaviour change: tests and a recipe only. Recommendation 3 of the whiteboard architecture review: pin, on real
PaperKit, what the board relies on, so the next iOS surprise fails a test rather than Igor's iPad.

## Shape

- A new hosted unit-test bundle, `GrabberNativeContractTests` (`native/ContractTests`, XcodeGen `bundle.unit-test`,
  `TEST_HOST` the app), in the scheme's test targets beside the UI tests. Hosted, because PKToolPicker needs a window
  scene and the responder chain; a unit bundle, because these contracts need PaperKit's API, which a UI test can't
  reach.
- `PaperStage`: a `PaperMarkupViewController` with the board's feature set and inks, on a window of its own, the picker
  shown with the paper and a counting delegate as observers. It doesn't use `PaperHost`: the contract is PaperKit's,
  not the board's, and a test of the board's code would fail for the board's bugs too.
- `just native-test-contracts`: in a build lane, on the lane's iPad simulator, through `xcodebuild-log.sh`, with no
  retry.

## Tests (12)

| Contract | Board code that rests on it |
|---|---|
| a pick in code moves `selectedToolItem`, not `drawingTool` | every `drawingTool` read (#1078; arch 1) |
| setting `drawingTool` leaves the picker | the Keep restore of the pen |
| the picker offers the eight inks, eraser, lasso | `pickerText`, the fold and card erases |
| a set is held at once, told once, no undo step | the 12 sets and their `quiet` flag |
| a set from an older base is refused whole | #999, #1015; arch 2's read-back |
| a set from the held markup, an earlier one or a new one is held | the fix for #999, Undo's `step(to:)` |
| a set inside the change callback, from the held markup, is held | the "next turn" hops |
| a set that takes the selected stroke leaves its id selected | the 21 `selection` reads |
| a registered step keeps its name | #965's bar, #966's steps |
| every ink reads its kind by key, through a markup | `WhiteboardInk` (#1083) |
| an unknown kind rides a markup and the paper | `WhiteboardInk` (#1083) |
| a drawing with an unknown kind writes but doesn't read back | the board files (`WhiteboardStore`) |

## The touches (bead context-grabber-8o93, story 1020)

A hosted unit bundle can't make a touch, so these are a UI test class, `PaperKitTouchContractUITests`, against a bare
stage in the app behind a launch hook (`GRABBER_PAPER_STAGE=<draw|select>[,cancel]`, parsed by `PaperStageHook` in
ContextCore, shown by `PaperTouchStage`): a `PaperMarkupViewController` with the board's feature set, a markup to draw
on, the picker shown, and the board's own `PaperTouchWatcher` on the view around it, in a sheet that clips it (PaperKit
draws, and takes touches, past its view's bounds otherwise). Its state is one accessibility label, `key=value;…`, and an
Undo button calls PaperKit's undo manager. `cancel` takes the stage's view out of its window and back 0.3 s into a held
touch, which UIKit answers with `touchesCancelled`.

| Contract | Board code that rests on it |
|---|---|
| a finger stroke is one step named *Add Strokes*; its lift reaches the watcher ended | `BoardUndoButtons.unnamed` (#965); the fold erase's lift |
| a touch called off mid-touch reaches the watcher cancelled, phase cancelled, never ended | the fold erase's `touch.phase == .cancelled` (#1105) |
| with the finger set to select, a tap still leaves a dot PaperKit's undo takes back | `takesBackTapDot` (#883) |

`just native-test-contracts` runs both bundles' tests, no retry. The ladder (`scripts/native/test-ladder.sh`) runs them as a
step of their own on the iPad when a changed file drives PaperKit (imports it, or is the board's tool, ink kinds or files,
or the contracts' own), checked by `scripts/native/test-ladder-map.sh` (story 1021).

Not here: a pick made with a finger in the tool picker (#1078 on a real tap), another agent's under the same bead.
