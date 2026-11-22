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

## Left for UI tests (follow-up bead)

A finger tap's dot (#883), a touch cancelled against ended (the fold erase, #1105), a pick made with a finger in the
picker (#1078 on a real tap), the name PencilKit gives a drawn stroke's undo ("Add Strokes", #965), and wiring the
bundle into the ladder's map.
