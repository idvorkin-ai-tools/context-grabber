# The whiteboard

Drawing on the iPad with the Pencil, Larry seeing the board, and Claude and Larry drawing back. Specs:
[2026-11-01-whiteboard-design.md](../superpowers/specs/2026-11-01-whiteboard-design.md),
[2026-11-01-whiteboard-shapes-design.md](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md).

---

### User Story 340:

- **Summary:** Draw and erase on the iPad with the Pencil
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), the system's Pencil-only setting in [ab9c1e8](https://github.com/idvorkin/context-grabber/commit/ab9c1e8); built for the simulator, where with no Pencil paired a finger draws (the system's own Pencil-only setting); the Pencil, palm and eraser not yet tried on the iPad

#### Use Case:
- **As someone** who thinks better with a pen in hand
- **I want to** open a board and draw on it with the Pencil, and erase with it
- **so that** an idea gets out of my head the way it would on a whiteboard

#### Acceptance Criteria:
- **Scenario:** Pencil, palm and finger
- **Given:** a board of mine is open on the iPad, with my palm resting on the glass
- **When:** I draw with the Pencil, then double-tap it and rub out a stroke, then drag a finger
- **Then:** the Pencil leaves ink, my palm leaves nothing, the eraser removes the stroke, and the finger moves the board without drawing

---

### User Story 341:

- **Summary:** A board that keeps going past the screen
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); verified by host tests (`WhiteboardFrameTests`: where the view opens, kept on the board) and the simulator build; panning not yet tried on the iPad

#### Use Case:
- **As someone** whose diagrams grow sideways
- **I want to** pan and pinch to more board in every direction
- **so that** I never run out of room halfway through a thought

#### Acceptance Criteria:
- **Scenario:** Off the edge
- **Given:** I have drawn to the right edge of the screen
- **When:** I drag the board left with a finger and keep drawing, then pinch out
- **Then:** fresh board slides in under the Pencil, and pinching out shows everything I drew at once

---

### User Story 342:

- **Summary:** The board is still there next time
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); saving on close, on a link and in the background in [ab9c1e8](https://github.com/idvorkin/context-grabber/commit/ab9c1e8); verified by host tests (`WhiteboardFrameTests`: centred on the drawing) and the simulator build; a relaunch not yet tried on the iPad

#### Use Case:
- **As someone** who comes back to a sketch later
- **I want to** find the board as I left it
- **so that** a half-finished idea is never lost

#### Acceptance Criteria:
- **Scenario:** Relaunch
- **Given:** I drew on the board and then quit the app
- **When:** I open the Whiteboard again and tap that board's card
- **Then:** every stroke is there, and the view opens centred on the drawing

---

### User Story 343:

- **Summary:** Show Larry the board
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), one send per stroke in [abe5876](https://github.com/idvorkin/context-grabber/commit/abe5876), the thread titled with the board's name in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023); verified by host tests (`WhiteboardFrameTests`: the picture's margin and size) and the simulator build; a thread in Chat not yet seen from the iPad

#### Use Case:
- **As someone** who sketches to think and then wants to talk it over
- **I want to** send the board to Larry in one tap
- **so that** he sees what I drew and answers in a chat thread

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** I have drawn on the board and the iPad is in dark mode
- **When:** I tap Send to Larry
- **Then:** the bar says the board is on its way, and Chat gets a new thread titled with the board's name ("Board, Nov 1", or what I renamed it to) holding a picture of the whole drawing, dark ink on white

- **Scenario:** One send, one thread
- **Given:** I have just sent the board to Larry
- **When:** I tap Send to Larry again before drawing anything more
- **Then:** nothing is sent, because the button is disabled until my next stroke, and Chat holds one thread for that board

---

### User Story 344:

- **Summary:** Claude suggests the next strokes as I draw
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), the Cockpit's `POST /whiteboard/suggest` in [7974077](https://github.com/idvorkin/context-grabber/commit/7974077); verified by host tests (`WhiteboardTurnTests`: the request, the answer, each kind of stroke, a label on its baseline, a 429 skipped, shapes onto the board, a tap's hit, kept ink through PencilKit's own spline) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a pause brings a ghost; the keep verified on the simulator by `WhiteboardTurnUITests`); a real Claude answer and undo not yet tried on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing alone
- **I want to** see faint suggested strokes when I pause
- **so that** it feels like drawing with someone

#### Acceptance Criteria:
- **Scenario:** A ghost, kept
- **Given:** I drew two circles and lifted the Pencil with Ghosts on, and a faint orange shape appeared within about five seconds
- **When:** I tap it
- **Then:** it becomes a real stroke in Claude's orange that my eraser and undo treat like mine

- **Scenario:** Every kind of stroke
- **Given:** Ghosts are on and I paused
- **When:** the Cockpit answers with a line, an arrow, a polyline, a circle, an arc, a label and a kind the app doesn't know
- **Then:** the six I know appear as faint orange ghosts, the label's letters standing on the spot the Cockpit gave as its baseline, and the unknown one isn't shown

- **Scenario:** The model takes too long
- **Given:** Ghosts are on and I paused
- **When:** the Cockpit has not answered after 10 s
- **Then:** no ghost appears and the bar says *Ghosts: the Cockpit isn't answering* until a turn gets through

- **Scenario:** Asked too soon
- **Given:** ghosts are showing
- **When:** a new turn comes within the Cockpit's 2 s and it answers 429
- **Then:** the turn is skipped with no error, the bar doesn't change and the ghosts stay

---

### User Story 345:

- **Summary:** Talk while I draw
- **Status:** not implemented

#### Use Case:
- **As someone** whose hands are busy with the Pencil
- **I want to** say what the drawing means and what I want
- **so that** Claude's suggestions follow my words, not just my scrawl

#### Acceptance Criteria:
- **Scenario:** Spoken direction
- **Given:** the mic is open on the board, and I drew a curve
- **When:** I say "this is my energy over the week, mark the dip"
- **Then:** a ghost label "dip" with an arrow appears at the curve's low point

---

### User Story 346:

- **Summary:** Larry on a call sees and draws on the board
- **Status:** not implemented (needs strokes in Larry's replies, Cockpit side)

#### Use Case:
- **As someone** talking an idea through with Larry
- **I want to** call him from the board and keep drawing while we talk
- **so that** he sees the board change and can sketch his answer on it

#### Acceptance Criteria:
- **Scenario:** Call from the board
- **Given:** the board has a drawing
- **When:** I start a Larry call from the board and draw an arrow while talking
- **Then:** Larry speaks to what is on the board, and his own strokes appear in his colour

---

### User Story 347:

- **Summary:** See the iPad's boards on the phone
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and the review fixes in [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5); verified by host tests (`BoardIndexTests`: read-only off the drawing device, the merge, a failed fetch retried) and the simulator (the boards open, iCloud skipped with no account); an iPad board on the phone not yet seen

#### Use Case:
- **As someone** away from the iPad
- **I want to** look at the boards on the phone
- **so that** the sketch is with me wherever I am

#### Acceptance Criteria:
- **Scenario:** View only, through iCloud
- **Given:** I drew a board on the iPad and closed it, and both devices are signed into my iCloud
- **When:** I open the Whiteboard on the phone and tap that board's card
- **Then:** I see the drawing, which I can pan and pinch but not draw on, with a note that it is drawn on the iPad

---

### User Story 348:

- **Summary:** Many boards, as a list
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5), a delete during the first upload in [8625cd8](https://github.com/idvorkin/context-grabber/commit/8625cd8); verified by host tests (`BoardIndexTests`: names, newest first, deletes) and the simulator (`just native-test-sim`: the boards open from the hook); the cards on the iPad not yet seen

#### Use Case:
- **As someone** who sketches a different idea each time
- **I want to** keep each board, see them as a list and start a new one
- **so that** a new idea never draws over an old one

#### Acceptance Criteria:
- **Scenario:** The boards
- **Given:** I drew one board this morning, and one before the list existed
- **When:** I open the Whiteboard and tap + New board, draw, and go back
- **Then:** the list shows three cards, newest first, each with its picture, name and when it changed; an empty new board left without a stroke leaves no card

- **Scenario:** Rename and delete
- **Given:** a card for a board this device drew
- **When:** I long-press it and rename it, then long-press it again, tap Delete and confirm
- **Then:** the card takes the new name, then goes, and the board leaves every device and doesn't come back; a card drawn on another device offers neither

### User Story 349:

- **Summary:** Larry takes a turn on the board
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7) against the fake Cockpit (the real endpoint is cockpit#85); verified by host tests (`WhiteboardTurnTests`) and the simulator (`WhiteboardTurnUITests`: Larry's turn brings his marks); Larry's real answer and his Chat thread wait for cockpit#85
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** working an idea out on the board
- **I want to** hand Larry the Pencil for a turn
- **so that** he answers in marks on my drawing, not only in words somewhere else

#### Acceptance Criteria:
- **Scenario:** Larry answers on the board
- **Given:** the board has a drawing
- **When:** I tap *Larry's turn* and wait
- **Then:** faint blue shapes and a line from Larry appear, nothing on the board changes until I keep one, Chat has a thread named after the board with his words, and the board's next turn goes to it

---

### User Story 350:

- **Summary:** Drawing on dismisses the ghosts
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), with a late answer dropped when it lands; not verified by a test, because the simulator has no Pencil; to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing while Claude suggests
- **I want to** have the ghosts go as soon as I draw on
- **so that** a suggestion never sits on a drawing that has moved past it

#### Acceptance Criteria:
- **Scenario:** The Pencil touches down
- **Given:** ghosts are showing, or a ghost turn is still on its way
- **When:** I touch the Pencil down
- **Then:** the ghosts go, and the late answer adds nothing

---

### User Story 351:

- **Summary:** Turn the ghosts off
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); seen on the simulator in the recording of `WhiteboardTurnUITests.testGhostsOffAsksNothing` (no note with Ghosts off, the note back on); that test failed on its note query, and the query as rewritten has not yet passed on the simulator
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who wants to draw undisturbed
- **I want to** switch Claude's ghosts off in the board's bar
- **so that** nothing is asked or offered until I switch them back

#### Acceptance Criteria:
- **Scenario:** Ghosts off
- **Given:** I turned Ghosts off in the board's bar
- **When:** I draw a stroke and lift the Pencil
- **Then:** nothing is asked and no ghost appears

---

### User Story 352:

- **Summary:** The board still draws when ghosts can't be reached
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); not verified by a test
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing away from the tailnet
- **I want to** keep drawing and be told once why no ghosts come
- **so that** a missing Cockpit neither interrupts me nor looks like nothing to suggest

#### Acceptance Criteria:
- **Scenario:** The Cockpit is away
- **Given:** Ghosts are on and the Cockpit can't be reached
- **When:** I draw a stroke and lift the Pencil
- **Then:** the stroke stays, and the bar says ghosts aren't answering, unless Larry's line is showing there

---

### User Story 353:

- **Summary:** Larry can't be reached
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); not verified by a test
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** see why he didn't answer
- **so that** I can tell it apart from him having nothing to add

#### Acceptance Criteria:
- **Scenario:** Larry away
- **Given:** the Cockpit can't be reached
- **When:** I tap *Larry's turn*
- **Then:** the bar shows a copyable problem saying so, and the board is unchanged

---

### User Story 354:

- **Summary:** Ghosts on a device where a finger draws
- **Status:** app side implemented on this branch; `WhiteboardTurnUITests.testAFingerTapOffAGhostDismissesItAndOnOneKeepsIt` verified on the simulator by `WhiteboardTurnUITests`; an iPhone and an iPad with no Pencil not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a finger, on an iPhone or an iPad with no Pencil
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** tapping a suggestion doesn't draw a dot and lose it

#### Acceptance Criteria:
- **Scenario:** A finger tap while ghosts show
- **Given:** a finger draws on this device and ghosts are showing
- **When:** I tap a ghost
- **Then:** it becomes ink and no dot is drawn; once no ghost is left, or after a tap off them that dismisses them all, my finger draws again

---

### User Story 355:

- **Summary:** Keep Larry's mark
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); the keep itself is checked on the simulator through Claude's ghost (`WhiteboardTurnUITests`), the same path; blue ink on the iPad not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** keep the marks of his I agree with
- **so that** his answer joins my drawing only where I want it

#### Acceptance Criteria:
- **Scenario:** A blue ghost, kept
- **Given:** Larry's faint blue shapes are showing
- **When:** I tap one
- **Then:** it becomes blue ink that my eraser and undo treat like mine

---

### User Story 356:

- **Summary:** Larry's marks stay when the ghosts go off
- **Status:** app side implemented in [e2f693e](https://github.com/idvorkin/context-grabber/commit/e2f693e); verified on the simulator by the session log (`whiteboard` ghosts: Ghosts off drops Claude's one ghost, then Larry's turn shows his two); a UI test could not read it, as the Ghosts button's accessibility label does not refresh for XCUITest while Ghosts is off; on the iPad not yet
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn and wants Claude to stop suggesting
- **I want to** switch the ghosts off without losing what Larry drew
- **so that** the switch only quiets Claude, and Larry's answer waits for me to keep it

#### Acceptance Criteria:
- **Scenario:** Ghosts off with Larry's marks showing
- **Given:** Larry's faint blue shapes are showing
- **When:** I turn Ghosts off in the board's bar
- **Then:** his shapes stay and I can still keep them

---
