# The whiteboard

Drawing on the iPad with the Pencil, Larry seeing the board, and Claude and Larry drawing back. Specs:
[2026-11-01-whiteboard-design.md](../superpowers/specs/2026-11-01-whiteboard-design.md),
[2026-11-01-whiteboard-shapes-design.md](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[2026-11-02-whiteboard-paste-design.md](../superpowers/specs/2026-11-02-whiteboard-paste-design.md).

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
- **Status:** the free-panning board implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); the criteria below are the pages change (#636), specified and not built yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)

#### Use Case:
- **As someone** who writes down a page and keeps going
- **I want to** scroll down a column of pages, with a blank one always waiting
- **so that** I never run out of room halfway through a thought, and never get lost on a huge square

#### Acceptance Criteria:
- **Scenario:** Past the bottom
- **Given:** I have drawn to the bottom of the last page
- **When:** I drag the board up with a finger and keep drawing
- **Then:** a blank page slides in under the Pencil, and a faint line marks where the last page ended

- **Scenario:** Pinching out
- **Given:** I am on a page
- **When:** I pinch out as far as it goes
- **Then:** it stops with the page fitting the screen's width, and the board never moves off sideways into nothing

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
- **When:** I open the Whiteboard again and tap that board's row
- **Then:** every stroke is there, and the view opens at the place I left it

---

### User Story 343:

- **Summary:** Show Larry the board
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), one send per stroke in [abe5876](https://github.com/idvorkin/context-grabber/commit/abe5876), the thread titled with the board's name in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023), the board's one thread instead of a new one each time in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardFrameTests`: the picture's margin and size) and the simulator build; a thread in Chat not yet seen from the iPad

#### Use Case:
- **As someone** who sketches to think and then wants to talk it over
- **I want to** send the board to Larry in one tap
- **so that** he sees what I drew and answers in the board's chat thread

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** I have drawn on the board and the iPad is in dark mode
- **When:** I tap Send to Larry
- **Then:** the bar says the board is on its way, and Chat gets the board's thread, titled with the board's name ("Board, Nov 1", or what I renamed it to), holding a picture of the page or pages on screen, dark ink on white

- **Scenario:** One send, one message
- **Given:** I have just sent the board to Larry
- **When:** I tap Send to Larry again before drawing anything more
- **Then:** nothing is sent, because the button is disabled until my next stroke

---

### User Story 344:

- **Summary:** Claude suggests the next strokes as I draw
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), the Cockpit's `POST /whiteboard/suggest` in [7974077](https://github.com/idvorkin/context-grabber/commit/7974077); verified by host tests (`WhiteboardTurnTests`: the request, the answer, each kind of stroke, a label on its baseline, a 429 skipped, shapes onto the board, a tap's hit, kept ink through PencilKit's own spline) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a pause brings a ghost; the keep verified on the simulator by `WhiteboardTurnUITests`); a real Claude answer and undo not yet tried on the iPad
- **Issues:** [#624](https://github.com/idvorkin/context-grabber/issues/624)
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
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); the words to the turn verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and the new words by `WhiteboardSpeechTests`; real dictation over the Pencil and a real model answer to try on the iPad
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
- **Status:** not implemented (needs a call from the board; his marks on the board already come over chat, story 382)

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
- **When:** I open the Whiteboard on the phone and tap that board's row
- **Then:** I see the drawing, which I can pan and pinch but not draw on, with a note that it is drawn on the iPad

---

### User Story 348:

- **Summary:** Many boards, as a list
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5), a delete during the first upload in [8625cd8](https://github.com/idvorkin/context-grabber/commit/8625cd8); verified by host tests (`BoardIndexTests`: names, newest first, deletes) and the simulator (`just native-test-sim`: the boards open from the hook); the rows, and Delete offered on another device's board, in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73), verified on the iPhone simulator by `WhiteboardRowDeleteUITests`; the rows on the iPad not yet seen

#### Use Case:
- **As someone** who sketches a different idea each time
- **I want to** keep each board, see them as a list and start a new one
- **so that** a new idea never draws over an old one

#### Acceptance Criteria:
- **Scenario:** The boards
- **Given:** I drew one board this morning, and one before the list existed
- **When:** I open the Whiteboard and tap + New board, draw, and go back
- **Then:** the list shows three rows, newest first, each with its picture, name and when it changed; an empty new board left without a stroke leaves no row

- **Scenario:** Rename and delete
- **Given:** a row for a board this device drew
- **When:** I long-press it and rename it, then long-press it again, tap Delete and confirm
- **Then:** the row takes the new name, then goes, and the board leaves every device and doesn't come back; a row drawn on another device offers Delete (story 396) but not Rename

### User Story 349:

- **Summary:** Larry takes a turn on the board
- **Status:** first implemented as a call that waited for him in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to the chat path, no waiting, in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b) (Igor, 2026-11-02); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: Larry's turn brings his marks with no further tap) against the fake Cockpit; the real Larry's answer on the iPad not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** working an idea out on the board
- **I want to** hand Larry the Pencil for a turn
- **so that** he answers in marks on my drawing, not only in words somewhere else

#### Acceptance Criteria:
- **Scenario:** Larry answers on the board
- **Given:** the board has a drawing
- **When:** I tap *Larry's turn* and carry on
- **Then:** the bar says *Larry has the board*, with no spinner, and the Pencil keeps drawing. When he answers, faint blue shapes and a line from him appear with no tap, nothing on the board changes until I keep one, Chat has a thread named after the board with the picture and his words, and the board's next turn goes to it

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
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), on the chat path in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); not verified by a test
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who asked Larry for a turn
- **I want to** see why he didn't get it
- **so that** I don't wait for an answer to a picture he never had

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

### User Story 360:

- **Summary:** Ask for something on an empty board
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone; real dictation to try on the iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** starting from nothing
- **I want to** tell Claude what to draw before I have drawn anything
- **so that** the board answers a blank page too

#### Acceptance Criteria:
- **Scenario:** Spoken on an empty board
- **Given:** the mic is open and the board is empty
- **When:** I say "draw a circle"
- **Then:** faint orange ghosts appear in the part of the board on screen, and nothing becomes ink

---

### User Story 361:

- **Summary:** Words during a turn wait for the next one
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking faster than Claude answers
- **I want to** have what I say while Claude is answering go next
- **so that** no word falls between two turns

#### Acceptance Criteria:
- **Scenario:** Speaking during a turn
- **Given:** a ghost turn is on its way
- **When:** I say something and stop
- **Then:** those words go with a new turn a second after the first lands

---

### User Story 362:

- **Summary:** Words whose turn did not get through go with the next
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with a Cockpit that is sometimes away
- **I want to** have my words survive a turn that fails
- **so that** I don't have to say them again

#### Acceptance Criteria:
- **Scenario:** A turn that did not get through
- **Given:** I said "draw a box" and its turn was skipped, refused or never answered
- **When:** the next turn is asked
- **Then:** it carries "draw a box" ahead of anything I said since

---

### User Story 363:

- **Summary:** A call has the microphone
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation and a call
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** on a call with Larry
- **I want to** be told why the board's mic won't open
- **so that** a dead button doesn't leave me guessing

#### Acceptance Criteria:
- **Scenario:** Tapping the mic during a call
- **Given:** a call with Larry is live
- **When:** I tap the board's mic
- **Then:** the mic stays closed and the bar shows a copyable problem saying the call is using the microphone

---

### User Story 364:

- **Summary:** A call takes the mic
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation and a call
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who gets on a call while drawing
- **I want to** have the board's mic let go
- **so that** Larry can hear me

#### Acceptance Criteria:
- **Scenario:** A call starting
- **Given:** the board's mic is open
- **When:** a call with Larry starts
- **Then:** the board's mic stops, and words not yet sent still go

---

### User Story 365:

- **Summary:** Leaving stops the mic
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** done with the board
- **I want to** have the mic close when I go
- **so that** the app never listens to a board I left

#### Acceptance Criteria:
- **Scenario:** Leaving the board
- **Given:** the board's mic is open
- **When:** I close the board or the app goes to the background
- **Then:** the mic stops, and words not yet sent still go

---

### User Story 366:

- **Summary:** See what the mic heard
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking with my eyes on the drawing
- **I want to** glance at the words heard
- **so that** I know the mic got me right

#### Acceptance Criteria:
- **Scenario:** Words in the bar
- **Given:** the board's mic is open
- **When:** I speak
- **Then:** the bar shows *Listening…* until the first words, then the last words heard; a new session starts at *Listening…* again

---

### User Story 367:

- **Summary:** Ghosts off holds for speech too
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone; real dictation to try on the iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who switched the ghosts off
- **I want to** have talking ask nothing either
- **so that** the switch means what it says (story 351)

#### Acceptance Criteria:
- **Scenario:** Speaking with Ghosts off
- **Given:** Ghosts are off and the board's mic is open
- **When:** I say "draw a square"
- **Then:** nothing is asked, no ghost appears, and the words are not sent when Ghosts come back

---

### User Story 368:

- **Summary:** A mic that cannot start says why
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation, with the permission off
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** whose microphone permission is off
- **I want to** see why the mic did not open
- **so that** I can fix it, or send the reason on

#### Acceptance Criteria:
- **Scenario:** The mic refused
- **Given:** the app has no permission to use the microphone or speech recognition
- **When:** I tap the board's mic
- **Then:** the bar shows a copyable problem naming the permission and the state behind it

---

### User Story 369:

- **Summary:** A report takes the mic
- **Status:** implemented on this branch in the review round after [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); not yet seen: the iPad, with real dictation and a shake (the simulator has no dictation to hear)
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who shakes to report a problem while talking to the board
- **I want to** have the board's mic stop when the report opens
- **so that** words meant for the report never go to the Cockpit as a request for ghosts

#### Acceptance Criteria:
- **Scenario:** A shake report opens
- **Given:** the board's mic is open
- **When:** I shake and the report opens
- **Then:** the board's mic stops, what I dictate into the report doesn't reach the Cockpit, and the mic stays closed until I tap it again

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

---

### User Story 378:

- **Summary:** Choose the board's colour
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the menu, the colour on the canvas and the colour still there on reopening verified on the simulator by `WhiteboardTurnUITests` (from the screen's pixels and the button tree); the other boards keeping their colours not covered by a test; the Pencil's tool picker after the menu to judge on the iPad
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who looks at a board for a long time
- **I want to** choose its background from a few colours, and have it remember
- **so that** the board is pleasant to draw on, and I can tell one idea from another

#### Acceptance Criteria:
- **Scenario:** A colour for this board
- **Given:** a board of mine is open
- **When:** I open the Board menu in the bar, choose Cream, draw, go back and open the board again
- **Then:** the board is cream both times, and the other boards haven't changed

---

### User Story 379:

- **Summary:** The colour goes with the board
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the merge carrying the colour verified by host tests (`BoardIndexTests`); the colour on the list's row, which replaced the card in [a8b2730](https://github.com/idvorkin/context-grabber/commit/a8b2730), not covered by a test and not yet seen; iCloud and the look-only view on the phone not yet seen, as the simulator has no iCloud account and no board from another device
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who looks at the iPad's boards on the phone
- **I want to** see them in the colour I chose
- **so that** a board looks like the same board everywhere

#### Acceptance Criteria:
- **Scenario:** On the phone
- **Given:** I chose Sage for a board on the iPad and closed it
- **When:** I open the Whiteboard on the phone and tap that board's row
- **Then:** the row in the list and the look-only board are sage, in the phone's own mode, and the phone offers no way to change it

---

### User Story 380:

- **Summary:** Larry's turn doesn't hold up the drawing
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); the turn's message and the bar verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`) against the fake Cockpit; drawing with the Pencil while he has the board to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a Larry who takes minutes to answer
- **I want to** hand him the board and keep going
- **so that** his turn is a conversation in the background, not a wait

#### Acceptance Criteria:
- **Scenario:** Hand him the board
- **Given:** I have drawn on the board
- **When:** I tap *Larry's turn*
- **Then:** the bar says *Larry has the board* as soon as the picture is taken, with no spinner, and I can keep drawing and, once that picture has gone, tap it again for a newer one

---

### User Story 381:

- **Summary:** A picture for Larry says where it sits on the board
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); the three fields verified by host tests (`WhiteboardMarksTests`), including through the outbox; *Larry's turn* carrying them on the simulator (the fake Cockpit reads the frame to place his marks); *Send to Larry* carrying them to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** whose board is far bigger than any one picture of it
- **I want to** have every picture carry its board, its id and its place
- **so that** Larry's marks go on what he saw, whichever way he got it

#### Acceptance Criteria:
- **Scenario:** Either button
- **Given:** I have drawn away from the middle of the board
- **When:** I tap *Larry's turn* or *Send to Larry*
- **Then:** the picture reaches the board's thread with the board's id, a new picture id, and where the picture sits on the board; his marks answering either kind come back to the board

---

### User Story 382:

- **Summary:** Larry's marks arrive on their own, where the picture was
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); where it lands verified by host tests (`WhiteboardMarksTests`); arriving with no tap and either format by the simulator (`WhiteboardTurnUITests`) against the fake Cockpit, read from the board's note, as the canvas isn't in the accessibility tree; marks landing on what he saw, seen by eye, on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with the board open while Larry thinks
- **I want to** see his marks and his words appear when he has them, even if I didn't ask
- **so that** we are drawing together, in his own time

#### Acceptance Criteria:
- **Scenario:** He answers while I've moved on
- **Given:** I handed Larry the board, then drew elsewhere and panned away
- **When:** he posts a row of marks on the thread
- **Then:** within a few seconds, with no tap, they show as blue ghosts on what the picture showed, not where I am now, and his text shows in the bar as his line

---

### User Story 383:

- **Summary:** A board opens with only his newest marks, and a dismissed set stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: reopened with his newest set)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** coming back to a board Larry has drawn on for days
- **I want to** see only where he has got to, and never what I already turned down
- **so that** the board isn't buried in old marks

#### Acceptance Criteria:
- **Scenario:** Opening a board
- **Given:** the board's thread has several rows of his marks
- **When:** I open the board
- **Then:** only his newest row shows, with its line; older ones stay in Chat

---

### User Story 384:

- **Summary:** The looking stops when I leave
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); stopping on close and in the background not verified by a test; to try on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who leaves a board with a thread
- **I want to** have the looking stop when I'm not there
- **so that** it costs nothing

#### Acceptance Criteria:
- **Scenario:** Closed or backgrounded
- **Given:** a board with a thread is open
- **When:** I close it or the app goes to the background
- **Then:** the looking stops, and starts again when the app comes back to an open board

---

### User Story 385:

- **Summary:** One board, one thread
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b), and a Send recording the thread as it lands, closed board or not, in the review fixes on this branch; verified by host tests (`WhiteboardMarksTests`: pictures queued with no thread share the one the first starts, a lost thread frees the board); the buttons holding each other back, and a Send's thread on the iPad, not yet tried
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who sends a board to Larry more than once
- **I want to** have every picture of it go to one thread
- **so that** the conversation about a board is in one place and his marks in answer come back to it

#### Acceptance Criteria:
- **Scenario:** A later send
- **Given:** I sent this board to Larry, went back and read the thread in Chat
- **When:** I open the board, draw more and tap Send to Larry
- **Then:** the new picture goes to that thread, not a new one

---

### User Story 386:

- **Summary:** Larry draws unprompted
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by the simulator (`WhiteboardTurnUITests`) against the fake Cockpit, read from the board's note
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** with Larry's marks on the board
- **I want to** see his next marks take their place
- **so that** the board shows where he has got to, not every draft

#### Acceptance Criteria:
- **Scenario:** He draws unprompted
- **Given:** his marks are showing and I asked for nothing
- **When:** he posts another row of marks
- **Then:** the new ones replace his unkept ones; Claude's stay

---

### User Story 387:

- **Summary:** Marks with nowhere to go
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b), the board opening on such a row in the review fixes on this branch; verified by host tests (`WhiteboardMarksTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at Larry's marks
- **I want to** have marks that don't say where they go left off the board
- **so that** nothing lands in the wrong place, and the log says why it's missing

#### Acceptance Criteria:
- **Scenario:** Marks with no place
- **Given:** a row of his, his newest with marks, has marks but no frame
- **When:** the app sees it, on a look at the thread or as the board opens
- **Then:** nothing is drawn and nothing is replaced, no older row stands in for it, and the log names the row

---

### User Story 388:

- **Summary:** A set I've dealt with stays gone
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: dismissed, not back on the next look or the next open); keeping one from a row then reopening is host-tested only
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has answered Larry's marks
- **I want to** never see what I already kept or turned down
- **so that** the board isn't nagging me about a settled question

#### Acceptance Criteria:
- **Scenario:** Already settled
- **Given:** I kept or dismissed marks from his newest row
- **When:** a look at the thread comes round, or I open the board again
- **Then:** those marks don't come back, until he posts a new row

---

### User Story 389:

- **Summary:** Looking for his marks fails quietly
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b), a thread the Cockpit no longer has and the shorter wait in the review fixes on this branch; not verified by a test; to try on the iPad, away from the tailnet
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on a board that may be off the tailnet
- **I want to** have the looking stay quiet when it fails
- **so that** it never nags

#### Acceptance Criteria:
- **Scenario:** The Cockpit is away
- **Given:** a board with a thread is open
- **When:** the Cockpit stops answering
- **Then:** the bar says quietly that his marks aren't coming, no error box appears, the log has one error, and the bar clears by itself when the Cockpit answers

---

### User Story 390:

- **Summary:** Paste text onto the board as ink
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); the layout verified by host tests (`WhiteboardPasteTests`); on the simulator (`WhiteboardPasteUITests`), ⌘V from a real clipboard with no prompt, and through a launch hook each line and Claude's pause; the ink's look checked by eye at its pen width in dark mode. Still to try on the iPad: the Paste button itself (XCUITest's taps never fire the system control) and that it shows no prompt, zoomed-out and zoomed-in pastes, sync to the other device
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** thinking on the board with words already on my clipboard
- **I want to** paste them with the bar's Paste button or ⌘V
- **so that** they sit on the board as ink and travel with its picture to Larry and Claude

#### Acceptance Criteria:
- **Scenario:** A paste becomes ink
- **Given:** a board I can draw on is open and the clipboard holds two lines of text
- **When:** I tap Paste or press ⌘V
- **Then:** both lines appear as thin outlined ink in the middle of what's on screen with no *Allow Paste?* prompt, the board saves it, and about a second later Claude's ghosts come

---

### User Story 391:

- **Summary:** One undo takes a whole paste back
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); verified on the simulator (`WhiteboardPasteUITests`: one ⌘Z after a ⌘V)
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** who pasted the wrong thing
- **I want to** undo it in one go
- **so that** I never pick a paste off the board letter by letter

#### Acceptance Criteria:
- **Scenario:** Taking it back
- **Given:** I have just pasted
- **When:** I undo
- **Then:** the whole paste goes at once

---

### User Story 392:

- **Summary:** A paste that is too long is cut, and the bar says so
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); both caps verified by host tests (`WhiteboardPasteTests`); the 500-character cut and its note on the simulator (`WhiteboardPasteUITests`, through a launch hook)
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** pasting more than the board should carry
- **I want to** have the first part land and be told how much
- **so that** I know what was left off

#### Acceptance Criteria:
- **Scenario:** Too long
- **Given:** the clipboard holds more than 500 characters or wraps past 40 lines
- **When:** I paste
- **Then:** the first part lands and the bar says how much of how much

---

### User Story 393:

- **Summary:** Text that cannot be drawn leaves the board alone
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); no outline means no ink verified by host tests (`WhiteboardPasteTests`); the note and the untouched board on the simulator (`WhiteboardPasteUITests`, through a launch hook)
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** pasting only emoji
- **I want to** be told nothing could be drawn
- **so that** an unchanged board doesn't look like a broken paste

#### Acceptance Criteria:
- **Scenario:** Nothing to draw
- **Given:** the clipboard holds only emoji
- **When:** I paste
- **Then:** the board doesn't change and the bar says nothing in it can be drawn

---

### User Story 394:

- **Summary:** Nothing to paste, or a board that is not mine
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); not verified by a test; to try on the iPad: the dimmed Paste, no Paste on a look-only board, ⌘V doing nothing on either
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** looking at a board with nothing to paste, or one another device draws
- **I want to** have Paste and ⌘V stay out of the way
- **so that** nothing lands where it can't or shouldn't

#### Acceptance Criteria:
- **Scenario:** No paste to make
- **Given:** the clipboard holds neither text nor copied strokes, or the board is look-only
- **When:** I look at the bar or press ⌘V
- **Then:** Paste is dimmed (or absent on a look-only board) and ⌘V does nothing

---

### User Story 395:

- **Summary:** Strokes I copied still paste
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented on this branch; not verified by a test (on the simulator, PencilKit's canvas was seen to have its own paste); to try on the iPad with a hardware keyboard
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** moving ink around with the lasso
- **I want to** paste the strokes I copied with ⌘V
- **so that** pasting text doesn't cost me the system's paste of ink

#### Acceptance Criteria:
- **Scenario:** Copied strokes
- **Given:** a board I can draw on is open and the clipboard holds strokes copied with the lasso and no text
- **When:** I press ⌘V
- **Then:** the strokes land the way the system always pastes them, and the bar's Paste stays dimmed

---

### User Story 396:

- **Summary:** Delete a board from any device, with a swipe
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); the list, the swipe, the confirmation and that the row stays gone verified on the iPhone simulator by `WhiteboardRowDeleteUITests`; the merge by host tests (`BoardIndexTests`); on real iCloud, and the rows on the iPad, not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** delete a board with a swipe
- **so that** the list holds only what I still want, and I don't have to go find the iPad to clean it

#### Acceptance Criteria:
- **Scenario:** Swipe on the phone, on a board drawn on the iPad
- **Given:** the phone lists a board drawn on the iPad
- **When:** I swipe its row left, tap Delete and confirm
- **Then:** the row goes and doesn't come back when the list syncs

---

### User Story 397:

- **Summary:** The device that drew a deleted board follows
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); the merge verified by host tests (`BoardIndexTests`); the delete crossing iCloud between the iPhone and the iPad not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** have a delete on the phone reach the iPad, even one that was off
- **so that** a deleted board doesn't linger on the device that drew it

#### Acceptance Criteria:
- **Scenario:** The iPad follows
- **Given:** I deleted an iPad board on the phone, with the iPad off
- **When:** the iPad's list next syncs
- **Then:** the board is gone from the iPad too

---

### User Story 398:

- **Summary:** New ink wins over a delete
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73), the open board's guard held until its last save on this branch; the merge verified by host tests (`BoardIndexTests`); on real iCloud between the iPhone and the iPad not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** keep what I drew when a delete crosses it
- **so that** a delete from another device never costs me ink it hadn't seen

#### Acceptance Criteria:
- **Scenario:** New ink wins
- **Given:** the iPad has the board open, or has drawn on it and not reached iCloud yet, when I delete it on the phone
- **When:** the iPad syncs
- **Then:** nothing it drew is lost: the board goes up again and returns to both devices

---

### User Story 399:

- **Summary:** A picture of a deleted board says so
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); verified on the iPhone simulator by `WhiteboardRowDeleteUITests`
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** be told when a picture or link names a board that has gone
- **so that** a jump that can't land explains itself and I can copy why

#### Acceptance Criteria:
- **Scenario:** A picture of a deleted board
- **Given:** a chat picture or a link names a deleted board
- **When:** I jump to it
- **Then:** I get a copyable problem saying it was deleted or hasn't arrived

---

### User Story 400:

- **Summary:** No delete means no loss
- **Issues:** #613
- **Status:** implemented in [4ddfb73](https://github.com/idvorkin/context-grabber/commit/4ddfb73); the merge verified by host tests (`BoardIndexTests`); a real account switch not yet tried
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** keep this device's boards whatever iCloud's list says
- **so that** only a delete I asked for ever takes a board away

#### Acceptance Criteria:
- **Scenario:** No delete means no loss
- **Given:** this device signs into a different iCloud account, or iCloud's list comes back without its boards
- **When:** the list syncs
- **Then:** the boards this device drew stay, because only an asked-for delete removes them

---

### User Story 401:

- **Summary:** A late delete keeps ink it never saw
- **Issues:** #613
- **Status:** implemented on this branch; the merge verified by host tests (`BoardIndexTests`); on real iCloud between the iPhone and the iPad not yet tried, as the simulator has no iCloud account
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards that have served their purpose, on whichever device is in hand
- **I want to** have a delete cover only what I could see when I made it
- **so that** a delete made offline can't erase what I drew in the days before it arrived

#### Acceptance Criteria:
- **Scenario:** A delete arrives after newer ink
- **Given:** I deleted an iPad board on the phone with no network, and the iPad then drew on it and that reached iCloud
- **When:** the phone gets back online and both devices sync
- **Then:** the board and its new ink return to both devices

---

### User Story 402:

- **Summary:** The Board menu on an iPhone's width
- **Status:** implemented in [6d9f24f](https://github.com/idvorkin/context-grabber/commit/6d9f24f); the top bar with nothing under *More* verified on the simulator by `WhiteboardTurnUITests` (from the button tree); the menu's place at the bottom has not been looked at by eye
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** drawing on a narrow screen
- **I want to** have the Board menu at the bottom of the screen
- **so that** Larry's turn and Send stay where I can reach them

#### Acceptance Criteria:
- **Scenario:** On an iPhone's width
- **Given:** a board of mine is open on a narrow screen
- **When:** I look for the Board menu
- **Then:** it is at the bottom of the screen, and Larry's turn and Send are still in the top bar, not under *More*

---

### User Story 403:

- **Summary:** The colour follows light and dark mode
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the colour on the canvas in both modes verified on the simulator by `WhiteboardTurnUITests` (from the screen's pixels; a screenshot of white ink on the deep Cream comes from the run before the menu moved); ink contrast on every colour by host tests (`BoardPaperTests`)
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** whose iPad changes mode through the day
- **I want to** have a board's colour change with the mode
- **so that** the ink stays easy to read

#### Acceptance Criteria:
- **Scenario:** Light and dark mode
- **Given:** a board is Cream
- **When:** the iPad changes between light and dark mode
- **Then:** the board goes between a pale shade and a deep one, and the ink stays easy to read on both

---

### User Story 404:

- **Summary:** Ghosts show on every colour
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); ghost contrast on every colour verified by host tests (`BoardPaperTests`); ghosts on each colour by eye to judge on the iPad
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who decides which marks to keep
- **I want to** see a ghost as well on a colour as on Plain
- **so that** choosing a colour doesn't hide what Claude and Larry suggest

#### Acceptance Criteria:
- **Scenario:** Ghosts on a colour
- **Given:** a board is any of the colours
- **When:** Claude's orange ghosts and Larry's blue ones show
- **Then:** I can see them about as well as on Plain

---

### User Story 405:

- **Summary:** A colour alone keeps no empty board
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the empty-board rule verified by host tests (`BoardIndexTests`)
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who tries a colour on a new board and changes their mind
- **I want to** have the board go if I never drew on it
- **so that** the list holds only boards with something on them

#### Acceptance Criteria:
- **Scenario:** An empty board
- **Given:** I opened a new board and chose a colour
- **When:** I close it without a stroke
- **Then:** it leaves no row

---

### User Story 406:

- **Summary:** Claude and Larry see dark ink on white
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the pictures to Claude and Larry are left as they were, so stay dark on white; not covered by a test
- **Issues:** [#607](https://github.com/idvorkin/context-grabber/issues/607)

#### Use Case:
- **As someone** who colours a board for my own eyes
- **I want to** have Claude and Larry get the same picture on any colour
- **so that** a colour never changes how they read the board

#### Acceptance Criteria:
- **Scenario:** What Claude and Larry see
- **Given:** a board is Sage and the iPad is in dark mode
- **When:** Claude takes a turn or I send the board to Larry
- **Then:** the picture they get is dark ink on white

---

### User Story 407:

- **Summary:** Faint grid lines on the board
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: the lines appear in the screenshot's pixels; by eye in dark mode, faint and even) and the smoke (`grid_on` from the hook); how faint they look beside real ink and how drawing feels at 120 Hz on a big board are not verified, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** turn on faint grid lines that move with the board
- **so that** I can keep things lined up and to scale

#### Acceptance Criteria:
- **Scenario:** Grid on
- **Given:** a board I draw on, its grid off
- **When:** I choose Grid lines in the Board menu
- **Then:** faint lines show, too faint to break up the ink they cross

---

### User Story 408:

- **Summary:** Turning the grid off
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: the screenshot's pixels return to what they were)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** turn the grid back off
- **so that** the board is only my ink again

#### Acceptance Criteria:
- **Scenario:** Grid off
- **Given:** a board with its grid on
- **When:** I choose Grid lines in the Board menu again
- **Then:** the lines are gone and the ink is as it was

---

### User Story 409:

- **Summary:** The grid stays with its board
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: a reopened board draws its lines, or none, from the screenshot's pixels)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have a board remember whether its grid is on
- **so that** I don't set it again each time

#### Acceptance Criteria:
- **Scenario:** Reopened
- **Given:** I left a board with its grid on or off
- **When:** I open it again on this device
- **Then:** it opens the way I left it

---

### User Story 410:

- **Summary:** A new board has no grid
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by the simulator (`WhiteboardTurnUITests`: the Board menu's label on a new board, with another board's grid on)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** start each new board without a grid
- **so that** a grid is something I ask for on the board I want it on

#### Acceptance Criteria:
- **Scenario:** New board
- **Given:** another board has its grid on
- **When:** I make a new board
- **Then:** its grid is off

---

### User Story 411:

- **Summary:** The eraser leaves the grid alone
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the lines aren't strokes; not verified by a test, and erasing across a line is for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the eraser ignore the grid
- **so that** I can't erase it by accident

#### Acceptance Criteria:
- **Scenario:** Eraser
- **Given:** a board with its grid on
- **When:** I erase across a line
- **Then:** the line stays

---

### User Story 412:

- **Summary:** Larry's picture leaves the grid out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the picture is drawn from the ink alone; not verified by a test, so a picture sent with the grid on is for the iPad's eye
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** leave the grid out of the board I send to Larry
- **so that** what he says answers my drawing and not the squares

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** a board with its grid on
- **When:** I send it to Larry
- **Then:** the picture shows ink only

---

### User Story 413:

- **Summary:** The grid pans with the board
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by host tests (`WhiteboardFrameTests`: the lines cover the view wherever it is, and hold still until it crosses one); a real pan is not verified by a test, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the lines move with the board when I pan
- **so that** they stay put against my drawing

#### Acceptance Criteria:
- **Scenario:** Panning
- **Given:** a board with its grid on
- **When:** I pan the board
- **Then:** the lines keep their place on the drawing and still cover the screen

---

### User Story 414:

- **Summary:** The grid spreads as I pinch in
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by host tests (`WhiteboardFrameTests`: the spacing at 3×); a real pinch is not verified by a test, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the lines zoom with the board when I pinch in
- **so that** they stay put against the detail I'm drawing

#### Acceptance Criteria:
- **Scenario:** Pinching in
- **Given:** a board with its grid on
- **When:** I pinch in
- **Then:** the lines spread apart with the drawing

---

### User Story 415:

- **Summary:** The grid thins as I pinch out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); verified by host tests (`WhiteboardFrameTests`: worked spacings down to 0.1×, a thinned grid's lines on the coarser step, the line count at every zoom); a real pinch is not verified by a test, for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have fewer lines the further I pinch out
- **so that** they never crowd together over the whole drawing

#### Acceptance Criteria:
- **Scenario:** Pinching out
- **Given:** a board with its grid on
- **When:** I pinch out until the lines would crowd
- **Then:** every second line goes and the lines left are ones that were already there

---

### User Story 416:

- **Summary:** The lasso leaves the grid alone
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the lines aren't strokes; not verified by a test, and lassoing across a line is for the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** have the lasso ignore the grid
- **so that** I can't move it by accident

#### Acceptance Criteria:
- **Scenario:** Lasso
- **Given:** a board with its grid on
- **When:** I lasso across a line
- **Then:** nothing is selected for the line

---

### User Story 417:

- **Summary:** A turn's picture leaves the grid out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the picture is drawn from the ink alone; not verified by a test, so a turn with the grid on is for the iPad's eye
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** leave the grid out of what a turn sees
- **so that** the marks that come back answer my drawing and aren't fitted to the squares

#### Acceptance Criteria:
- **Scenario:** A turn
- **Given:** a board with its grid on
- **When:** a turn asks for marks on the board
- **Then:** the picture it sends shows ink only

---

### User Story 418:

- **Summary:** The board's card leaves the grid out
- **Status:** implemented in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); by design the card is drawn from the ink alone; not verified by a test, so a card with the grid on is for the iPad's eye
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608)

#### Use Case:
- **As someone** with many boards
- **I want to** see only my ink on a board's card
- **so that** I recognise the board by what I drew

#### Acceptance Criteria:
- **Scenario:** The card
- **Given:** a board with its grid on and ink on it
- **When:** I go back to the list of boards
- **Then:** its card shows ink only

---

### User Story 419:

- **Summary:** The board's strokes go to Larry on his turn
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), tests fixed in [f79d283](https://github.com/idvorkin/context-grabber/commit/f79d283), conversion and tests changed in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by host tests (`WhiteboardStrokesTests`: the stable id, the colour and tool words, thinning, the request's body, the answer, the width following a lasso's resize) and the whiteboard UI tests on the simulator (18 passed, before [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48)); the width's scaling came in the review fix after [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48) and is host-tested only; a real send from the iPad against the Cockpit is owed (the Cockpit's side is idvorkin-ai-tools/cockpit#91)
- **Why:** Igor, 2026-11-03, on a tall board that reached Larry as a 248x2048 px sliver: "This sounds like a bug in your implementation. Can we send strokes instead?"
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** writing pages of notes down one tall board
- **I want to** have Larry get every stroke, not a thumbnail
- **so that** he reads every word however tall the board is, and knows which lines are new

#### Acceptance Criteria:
- **Scenario:** Larry's turn
- **Given:** a board with ink on it
- **When:** I tap *Larry's turn*
- **Then:** before the picture, every stroke on the board reaches the Cockpit in board points with its time, colour, width, tool and a stable id, under the picture's id

---

### User Story 420:

- **Summary:** The picture for Larry frames the drawing at a readable size
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests (`WhiteboardFrameTests`: the pixel budget, the Nov 2 column at 712 x 5892 px instead of 248 x 2048, the long side capped at 8,000) and the simulator compile; how a 5,900-pixel-tall picture looks in Chat is owed on the iPad
- **Why:** Igor, 2026-11-03: "And maybe zoom into the pages".
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose boards are tall and narrow
- **I want to** have the picture spend its pixels on my drawing's own shape
- **so that** the handwriting stays legible in the picture too, not only in the strokes

#### Acceptance Criteria:
- **Scenario:** A tall column of notes
- **Given:** a drawing 1,179 by 9,759 board points
- **When:** a picture of it goes to Larry
- **Then:** it is about 712 by 5,892 pixels (30-point handwriting at 18 px), not 248 by 2,048

---

### User Story 421:

- **Summary:** Larry's turn goes whatever the Cockpit says to the strokes
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests of the answer and its log fields (`WhiteboardStrokesTests`) and the simulator compile; no test runs the turn against a refusal, since the fake Cockpit accepts every strokes post, so a turn from the iPad before cockpit#91 merges, when the route doesn't exist, is owed
- **Why:** Igor, 2026-11-03: the picture is the fallback, including until the Cockpit has the route
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry
- **I want to** have the picture reach him even when the strokes don't
- **so that** a Cockpit without the strokes route never costs me a turn

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses the strokes on Larry's turn
- **Given:** the strokes route answering an error
- **When:** I tap *Larry's turn*
- **Then:** the picture still goes, with only the session log saying what became of the strokes

---

### User Story 422:

- **Summary:** A big square sketch's picture stays as it was
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests (`WhiteboardFrameTests`: a square board unchanged at 2048 px) and the simulator compile
- **Why:** the pixel budget of story 420 is for tall boards; a square one already spent it well
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** sketching on a square part of a big board
- **I want to** have its picture stay as sharp as before
- **so that** framing tall boards costs ordinary sketches nothing

#### Acceptance Criteria:
- **Scenario:** A big square sketch
- **Given:** a drawing about 2,000 points on a side
- **When:** its picture is made
- **Then:** it is 2,048 pixels on a side, as before

---

### User Story 423:

- **Summary:** Rubbed-out ink doesn't go to Larry as strokes
- **Status:** implemented in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); PencilKit's visible ranges checked with a Mac probe of masked strokes (whole range without a mask, the visible part with one, nothing when all of it is masked), and the conversion compiled for the simulator; whether a real rub with the pixel eraser reaches the Cockpit as this is owed on the iPad
- **Why:** the picture shows the ink gone, so the strokes have to agree, or Larry reads sharp words Igor erased
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** correcting a word with the pixel eraser
- **I want to** have the part I rubbed out gone from what Larry reads
- **so that** he never reads what I erased, and knows it was erased

#### Acceptance Criteria:
- **Scenario:** Part of a stroke rubbed out
- **Given:** a stroke on the board with part of it rubbed out by the pixel eraser
- **When:** the board's strokes next go to the Cockpit
- **Then:** they carry only the part still visible, under new ids, so the Cockpit counts the old stroke as erased

---

### User Story 424:

- **Summary:** The board's strokes go with Send to Larry
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), tests fixed in [f79d283](https://github.com/idvorkin/context-grabber/commit/f79d283), changed in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by host tests (`WhiteboardStrokesTests`: the strokes saved beside the picture and posted before the message, under the picture's id); a real send from the iPad against the Cockpit is owed (idvorkin-ai-tools/cockpit#91)
- **Why:** split from story 419: a Send goes through the outbox, a different road from Larry's turn
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** sending a tall board from the iPad
- **I want to** have the strokes go with a Send as they do with a turn
- **so that** Larry reads a board I sent as sharply as one I handed him

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** a board with ink on it and a network
- **When:** I tap *Send to Larry*
- **Then:** every stroke on the board reaches the Cockpit under the picture's id, before the message that names the picture

---

### User Story 425:

- **Summary:** Claude's ghost turn gets the same framing
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); the turn uses the same framing as story 420, whose arithmetic the host tests pin, and the simulator compile; how a turn answers a picture that tall is owed on the iPad
- **Why:** split from story 420: Claude reads the board's handwriting from the picture alone
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing along with Claude on a tall board
- **I want to** have Claude's picture spend its pixels on my drawing's own shape
- **so that** Claude can read the handwriting it answers

#### Acceptance Criteria:
- **Scenario:** A tall column of notes on a ghost turn
- **Given:** a drawing 1,179 by 9,759 board points
- **When:** Claude's ghost turn takes its picture
- **Then:** it is about 712 by 5,892 pixels, not 248 by 2,048

---

### User Story 426:

- **Summary:** Send to Larry goes whatever the Cockpit says to the strokes
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), not taken for an unreadable item since [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by host tests (`WhiteboardStrokesTests`: a 500 to the strokes still sends the picture and logs the reason); a send from the iPad before cockpit#91 merges is owed
- **Why:** split from story 421: the outbox has its own send, and the same promise
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** sending a board to Larry
- **I want to** have the picture reach him even when the strokes don't
- **so that** a Cockpit without the strokes route never costs me a send

#### Acceptance Criteria:
- **Scenario:** The Cockpit refuses the strokes on a Send
- **Given:** the strokes route answering an error
- **When:** *Send to Larry* goes
- **Then:** the picture still goes, with only the session log saying what became of the strokes

---

### User Story 427:

- **Summary:** With no network a Send waits with its strokes beside it
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1), the strokes file kept out of the inbox's items in [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48); verified by a host test (`WhiteboardStrokesTests`: no network leaves the item waiting with its strokes, then upload, strokes and message in order), added in the review fix after [59e6f48](https://github.com/idvorkin/context-grabber/commit/59e6f48)
- **Why:** split from story 421: no network is a separate condition from the route's error
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** sending a board with no signal
- **I want to** have the strokes wait with the picture
- **so that** the board that arrives later is as readable as one sent now

#### Acceptance Criteria:
- **Scenario:** No network on a Send
- **Given:** no network
- **When:** I tap *Send to Larry*
- **Then:** the board waits in the outbox with its strokes beside it, and both go when the network is back

---

### User Story 428:

- **Summary:** With no network Larry's turn says so and nothing waits
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); the simulator compile only: no test runs a turn with no network, so this is owed on the iPad
- **Why:** split from story 421, whose old wording promised this case a send or a wait; a turn has no outbox
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** handing a board to Larry with no signal
- **I want to** be told the turn didn't go
- **so that** I don't wait for marks that aren't coming

#### Acceptance Criteria:
- **Scenario:** No network on Larry's turn
- **Given:** no network
- **When:** I tap *Larry's turn*
- **Then:** a copyable error says Larry couldn't be reached, and nothing is queued

---

### User Story 429:

- **Summary:** A small sketch's picture is never finer than the screen
- **Status:** implemented in [53481a1](https://github.com/idvorkin/context-grabber/commit/53481a1); verified by host tests (`WhiteboardFrameTests`: a small sketch drawn at 2x)
- **Why:** split from story 422: the pixel budget would otherwise blow a small sketch up past what the iPad drew
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** sketching on a small part of a board
- **I want to** have its picture stay at the screen's own sharpness
- **so that** a small sketch doesn't cost a huge picture

#### Acceptance Criteria:
- **Scenario:** A small sketch
- **Given:** a drawing 200 by 100 board points
- **When:** its picture is made
- **Then:** it is drawn at the screen's 2x, 560 by 360 pixels with its margin

---

### User Story 430:

- **Summary:** I can see which page I'm on
- **Status:** specified, not built yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** scrolling a long board
- **I want to** see a page number
- **so that** I know where I am

#### Acceptance Criteria:
- **Scenario:** Scrolling
- **Given:** a board with three pages of ink
- **When:** I scroll until page 2 is mostly on screen
- **Then:** the corner reads *Page 2 of 3*, stays put while the board moves, and isn't in any picture

---

### User Story 431:

- **Summary:** An old board moves onto pages with nothing lost
- **Status:** specified, not built yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards drawn before pages
- **I want to** open them on pages as they were
- **so that** the change never costs me a drawing

#### Acceptance Criteria:
- **Scenario:** A board that fits a page
- **Given:** a board from before pages, its ink narrower than a page
- **When:** I open it
- **Then:** it opens on pages with every stroke at its old size and in the same place relative to the others, and Larry's marks still sit beside the ink they were drawn beside

- **Scenario:** A board wider than a page
- **Given:** a board from before pages with ink wider than a page
- **When:** I open it
- **Then:** it keeps its own wider width, no stroke scaled, and I can pan sideways only as far as that width

---

### User Story 432:

- **Summary:** A mark past the page edge widens the board
- **Status:** specified, not built yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** Larry draws back to
- **I want to** see all of a mark drawn past the page's edge
- **so that** nothing he drew is cut off

#### Acceptance Criteria:
- **Scenario:** Past the edge
- **Given:** a page-width board
- **When:** Larry's mark lands past the right edge
- **Then:** the board widens to hold it, nothing is clipped, and my ink doesn't move

---

### User Story 433:

- **Summary:** Larry reads the pages I'm looking at
- **Status:** specified, not built yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** showing Larry part of a long board
- **I want to** send what's on my screen
- **so that** he reads my writing at a readable size, not a sliver of the whole column

#### Acceptance Criteria:
- **Scenario:** The middle page
- **Given:** three pages of ink with page 2 on screen
- **When:** I tap Send to Larry
- **Then:** the picture shows page 2 with my writing legible, and Larry's marks in reply land on page 2

- **Scenario:** Nothing on screen
- **Given:** ink on page 1 and a blank page on screen
- **When:** I look at Send to Larry
- **Then:** it's disabled, because there's nothing on screen to send

---

### User Story 434:

- **Summary:** Ruled lines, like notebook paper
- **Status:** specified, not built yet
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who writes notes on the board
- **I want to** turn on faint ruled lines
- **so that** my writing has lines to sit on

#### Acceptance Criteria:
- **Scenario:** Choosing them
- **Given:** a board with no lines
- **When:** I choose Ruled lines in the Board menu
- **Then:** faint horizontal lines appear that move with the board, are in no picture, can't be erased, and are still there when I reopen the board on this device

- **Scenario:** One kind at a time
- **Given:** a board with its grid on
- **When:** I choose Ruled lines
- **Then:** the grid goes and the ruled lines show

---

### User Story 435:

- **Summary:** Try a board on paper, temporarily, from its long press
- **Status:** built, verified on an iPad simulator on iOS 27 (`WhiteboardPaperTrialUITests`: offered on this device's board, not on another's); temporary: goes when the board moves to PaperKit. The hiding below iOS 27 is by construction: there's no older simulator here, and PaperKit is weak linked (`otool -L`). On the iPad: to be played with
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding how a board on PaperKit should work
- **I want to** open a board I drew in a trial on paper
- **so that** I can feel it with my own ink before anything is built on it

#### Acceptance Criteria:
- **Scenario:** A board drawn here, on iOS 27
- **Given:** a board drawn on this device
- **When:** I long-press its row
- **Then:** *Try on paper* is offered and opens the trial

- **Scenario:** Another device's board
- **Given:** a board drawn on another device
- **When:** I long-press its row
- **Then:** *Try on paper* isn't offered

- **Scenario:** Before iOS 27
- **Given:** a device below iOS 27
- **When:** I long-press a row
- **Then:** *Try on paper* isn't offered, and the app runs as it did

- **Scenario:** A board that can't be read
- **Given:** a board whose drawing can't be read
- **When:** I choose *Try on paper*
- **Then:** a copyable problem says so, and the file stays where it is

---

### User Story 436:

- **Summary:** Nothing in the trial reaches a real board
- **Status:** built, verified on an iPad simulator (`WhiteboardPaperTrialUITests`: drawing in the trial leaves the board's row and stroke count as they were; the boards' files hash the same across trial runs on the simulator, and a copy with ink added leaves no file)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** playing with an unfinished canvas
- **I want to** know nothing I do there can touch my boards
- **so that** I can scribble over the real ink without a second thought

#### Acceptance Criteria:
- **Scenario:** Scribbling and closing
- **Given:** a board with one stroke, open in the trial
- **When:** I draw, erase and undo in the trial and close it
- **Then:** the board still has one stroke, and its picture, its place in the list and its *Changed* time are as they were

- **Scenario:** Nothing to send
- **Given:** the trial is open
- **When:** I look for Send, Larry's turn, ghosts or the mic
- **Then:** there's none of them, and nothing goes to the Cockpit or iCloud

---

### User Story 437:

- **Summary:** The trial is a column of pages
- **Status:** built, verified on an iPad simulator (`WhiteboardPaperTrialUITests` and screenshots: tool picker, page lines, page number, a page added). Pinching with real fingers, on the iPad: the simulator's pinch didn't change the zoom
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** trying the Notability-like board
- **I want to** see my ink on a column of pages with a page number
- **so that** I can judge the shape before it's built for real

#### Acceptance Criteria:
- **Scenario:** Opening
- **Given:** a board with ink
- **When:** the trial opens
- **Then:** the tool picker, faint page lines, *Page 1 of N* at the corner and a blank page below the last ink all show

- **Scenario:** Pinching out
- **Given:** the trial is open
- **When:** I pinch out as far as it goes
- **Then:** it stops when the page fits the screen's width

- **Scenario:** Writing on the last page
- **Given:** a stroke reaching the last page
- **When:** I lift the Pencil
- **Then:** one more blank page is below, and the page number's total goes up

---

### User Story 438:

- **Summary:** The trial says what to try, and has the switches to try it
- **Status:** built, verified on an iPad simulator (`WhiteboardPaperTrialUITests` runs every switch, the `paper_probe` lines read: a page added mid-stroke with a finger kept the stroke and undo). On the iPad: to be played with
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with the iPad in hand and no notes
- **I want to** read one line and find the switches in one menu
- **so that** I don't need instructions to settle the questions

#### Acceptance Criteria:
- **Scenario:** The line
- **Given:** the trial just opened
- **When:** I look under the title
- **Then:** one short line says it's a copy and what to try

- **Scenario:** A page in the middle of a stroke
- **Given:** the Trial menu
- **When:** I choose *Add a page in 3 s* and write a long stroke across that moment
- **Then:** the page is added, and the log says a touch was down and what became of the stroke

- **Scenario:** Going far down
- **Given:** the Trial menu
- **When:** I choose *Go to page 11*
- **Then:** the view goes past 9,600 points down, adding pages if it must, so I can write there

---

### User Story 439:

- **Summary:** The trial's log settles the five questions
- **Status:** built; the host part is `PaperProbeTests`, the lines checked on the simulator (`sim-smoke.sh`, whiteboard). Questions 2 and 4 are answered there; 1, 3 and 5 need the iPad: `just pull-logs` after Igor's played
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who plays on the iPad and reads the answers later
- **I want to** have every touch and its outcome in the log
- **so that** the questions are answered without my having to remember what happened

#### Acceptance Criteria:
- **Scenario:** A finger on the ink
- **Given:** the trial is open
- **When:** I drag a finger across some ink
- **Then:** the log has the touch, whether it panned, selected or moved ink, and each moved stroke's id and how far it went

- **Scenario:** A page added
- **Given:** the trial is open
- **When:** a page is added
- **Then:** the log has where the view was and is, the zoom, whether undo survived, and whether a touch was down

- **Scenario:** Scrolling
- **Given:** the trial is open
- **When:** I scroll or pinch
- **Then:** the log has how often the visible area was reported, and how far the ring slipped from its cross

- **Scenario:** A board far from the corner
- **Given:** a board with ink about 10,000 points from the corner
- **When:** the trial opens with the ink where it is
- **Then:** the log says whether that start was kept and whether the ink is on screen, and the first stroke says whether it landed under the Pencil
