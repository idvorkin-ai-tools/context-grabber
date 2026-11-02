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
- **Status:** built on this branch; the words to the turn and a ghost on an empty board verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and the new words by `WhiteboardSpeechTests`; real dictation over the Pencil and a real model answer to try on the iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** whose hands are busy with the Pencil
- **I want to** say what the drawing means and what I want
- **so that** Claude's suggestions follow my words, not just my scrawl

#### Acceptance Criteria:
- **Scenario:** Spoken direction
- **Given:** the mic is open on the board, and I drew a curve
- **When:** I say "this is my energy over the week, mark the dip"
- **Then:** within about 5 s of my stopping, faint orange ghosts answer what I said, such as a label "dip" with an arrow at the curve's low point, without my lifting or drawing anything more

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

- **Summary:** Ghosts stay while I draw
- **Status:** first implemented as drawing dismissing the ghosts in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to staying in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) (Igor, 2026-11-02); not verifiable on the simulator, which has no Pencil and no canvas in the accessibility tree; to try on the iPad, including a finger tap on a ghost while the Pencil is down
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing while Claude suggests
- **I want to** keep drawing while the ghosts stay
- **so that** it feels like drawing together, not taking turns

#### Acceptance Criteria:
- **Scenario:** The Pencil touches down
- **Given:** ghosts are showing, or a ghost turn is still on its way
- **When:** I touch the Pencil down and draw on
- **Then:** the ghosts stay, and the answer on its way still shows, drawn in one shape after another

---

### User Story 351:

- **Summary:** Turn the ghosts off
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); seen on the simulator in the recording of `WhiteboardTurnUITests.testGhostsOffAsksNothing` (no note with Ghosts off, the note back on); that test first failed on its note query; rewritten, it passed on the simulator with the other `WhiteboardTurnUITests` in the build turn of [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3)
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

### User Story 357:

- **Summary:** Each new set of ghosts replaces only its author's last one
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3) (Larry's turn no longer drops Claude's); Larry's marks leaving Claude's in place verified on the simulator by `WhiteboardTurnUITests`; Claude's new answer replacing his own, and the draw-in, to try on the iPad (a finger can't draw while ghosts show on the simulator)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing while Claude and Larry suggest
- **I want to** see each one's newest marks replace only their own
- **so that** one voice never wipes out the other's

#### Acceptance Criteria:
- **Scenario:** A new set
- **Given:** Claude's orange ghosts and Larry's blue ones are showing
- **When:** I pause and Claude answers again
- **Then:** Claude's old ghosts fade out as his new ones draw in one after another, and Larry's stay

---

### User Story 358:

- **Summary:** Claude's ghosts fade when they're left alone
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11); verified on the simulator by `WhiteboardTurnUITests` (`testClaudesGhostsFadeAndLarrysStay`, with the time shortened)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on past a suggestion
- **I want to** have Claude's ghosts go by themselves after a while
- **so that** a suggestion doesn't sit on a drawing that has moved past it

#### Acceptance Criteria:
- **Scenario:** Left alone
- **Given:** Claude's orange ghosts and Larry's blue ones are showing
- **When:** 30 s pass with nothing new from Claude
- **Then:** Claude's fade away, and Larry's stay until I keep or dismiss them

---

### User Story 359:

- **Summary:** Strokes made during a ghost turn get their own turn
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3); its rules verified by host tests (`WhiteboardPacerTests`); not on the simulator, whose fake Cockpit answers with no delay, and the Pencil lift still to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on while Claude thinks
- **I want to** have my newest strokes asked about once the turn on its way lands
- **so that** ghosts keep up with the drawing without turns piling up or arriving mid-stroke

#### Acceptance Criteria:
- **Scenario:** Drawing during a turn
- **Given:** a ghost turn is on its way
- **When:** I draw another stroke and lift the Pencil
- **Then:** a second turn is asked a second after the first lands or after the lift, whichever is later

---

### User Story 370:

- **Summary:** Claude's marks arrive one at a time
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: partial lines, unknown lines skipped, the last line) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: six marks climb the count). The real Cockpit streams (cockpit f208f6c; a live request, 2026-11-02: 200 `application/x-ndjson`, a label, an arrow and the last line); the app reading it and the first-mark time are still to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** see his marks appear one at a time as he makes them
- **so that** it feels like someone sketching, not a picture arriving

#### Acceptance Criteria:
- **Scenario:** Marks as he makes them
- **Given:** Ghosts are on, I paused, and the Cockpit streams its answer
- **When:** the marks come
- **Then:** each one draws itself in as it arrives and the count in the bar climbs

---

### User Story 371:

- **Summary:** Ghosts look like ink
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified on the simulator by a screenshot from `WhiteboardTurnUITests`, solid orange lines on an iPhone simulator; how they sit beside real Pencil ink is to judge on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** deciding whether to keep a mark
- **I want to** see a ghost drawn as the ink it would become, only fainter
- **so that** I can judge how it looks on the board before I tap it

#### Acceptance Criteria:
- **Scenario:** Solid, not dashed
- **Given:** a ghost is showing, Claude's in orange or Larry's in blue
- **When:** I look at it
- **Then:** it is a solid faint line with round ends, as wide as a kept stroke, and a label shows the outlines of its letters

---

### User Story 372:

- **Summary:** Claude's old marks go when his new ones start
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); not covered by a test; to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** keep his earlier marks until the first new one lands
- **so that** the board is never blank between his answers

#### Acceptance Criteria:
- **Scenario:** The old set goes when the new one starts
- **Given:** Claude's earlier ghosts are showing and a new turn is on its way
- **When:** the first new mark lands
- **Then:** the earlier ones go then, not when the turn was asked, and Larry's stay

---

### User Story 373:

- **Summary:** A Cockpit that answers all at once still brings its marks
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by a host test (`WhiteboardStreamTests`: a plain answer) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a Cockpit that doesn't stream still brings its ghost)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** get his marks from a Cockpit that doesn't stream
- **so that** the board doesn't depend on which Cockpit answers

#### Acceptance Criteria:
- **Scenario:** A Cockpit that answers all at once
- **Given:** the Cockpit does not stream
- **When:** its answer comes
- **Then:** the marks appear together and everything else works as before

---

### User Story 374:

- **Summary:** An answer cut off after a mark is no failure
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: a broken stream after a mark, the Cockpit's error line after a mark); a real broken stream and the 10 s are still to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** keep the marks that made it when an answer stops early
- **so that** a cut-off answer still gives me what he had started

#### Acceptance Criteria:
- **Scenario:** Cut off part way
- **Given:** at least one mark has arrived
- **When:** the answer breaks off or the turn's 10 s run out
- **Then:** the marks already there stay and the bar says nothing about the Cockpit

---

### User Story 375:

- **Summary:** An answer cut off before any mark says so
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: a broken stream before a mark, the Cockpit's error line with no marks); a real broken stream and the 10 s are still to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** be told when no mark came
- **so that** I know the Cockpit isn't answering rather than wondering about Claude

#### Acceptance Criteria:
- **Scenario:** Cut off before anything
- **Given:** no mark has arrived
- **When:** the answer breaks off or the turn's 10 s run out
- **Then:** no ghost appears and the bar says *Ghosts: the Cockpit isn't answering*

---

### User Story 376:

- **Summary:** A turn sent away shows no more marks
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); not covered by a test; to see on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with Claude beside me
- **I want to** have a dismissal stop the marks still on their way
- **so that** what I sent away doesn't come back

#### Acceptance Criteria:
- **Scenario:** Sent away part way
- **Given:** marks are arriving
- **When:** I tap off them or turn Ghosts off
- **Then:** they go and no more of that turn's marks appear

---

### User Story 377:

- **Summary:** A ghost is no part of the drawing until it's kept
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); the kept line at full strength is not covered by a test; to judge on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** deciding whether to keep a mark
- **I want to** have a ghost stay out of the drawing until I tap it
- **so that** nothing changes my board unless I choose it

#### Acceptance Criteria:
- **Scenario:** Still only a ghost
- **Given:** a ghost is showing
- **When:** I don't tap it
- **Then:** it is no part of the drawing until I do, and keeping it gives the same line at full strength
