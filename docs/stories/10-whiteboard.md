# The whiteboard

Drawing on the iPad with the Pencil, Larry seeing the board, and Claude and Larry drawing back. Specs:
[2026-11-01-whiteboard-design.md](../superpowers/specs/2026-11-01-whiteboard-design.md),
[2026-11-01-whiteboard-shapes-design.md](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md),
[2026-11-02-whiteboard-paste-design.md](../superpowers/specs/2026-11-02-whiteboard-paste-design.md),
[2026-11-16-whiteboard-question-cards-design.md](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md),
[2026-11-16-whiteboard-to-text-and-snap-design.md](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md),
[2026-11-17-whiteboard-reword-and-live-snap-design.md](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md).

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
- **Status:** the free-panning board implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); the criterion below is the pages change, not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
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

---

### User Story 342:

- **Summary:** The board is still there next time
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3); saving on close, on a link and in the background in [ab9c1e8](https://github.com/idvorkin/context-grabber/commit/ab9c1e8); verified by host tests (`WhiteboardFrameTests`: centred on the drawing) and the simulator build; a relaunch not yet tried on the iPad; that the view opens at the place I left it is the pages change, not implemented (it still opens centred on the drawing); asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)

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
- **Status:** implemented in [9c1adc3](https://github.com/idvorkin/context-grabber/commit/9c1adc3), one send per stroke in [abe5876](https://github.com/idvorkin/context-grabber/commit/abe5876), the thread titled with the board's name in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023), the board's one thread instead of a new one each time in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardFrameTests`: the picture's margin and size) and the simulator build; a thread in Chat not yet seen from the iPad; a picture of the page or pages on screen is the pages change, not implemented (it still shows the whole drawing); asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)

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
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7), the Cockpit's `POST /whiteboard/suggest` in [7974077](https://github.com/idvorkin/context-grabber/commit/7974077); verified by host tests (`WhiteboardTurnTests`: the request, the answer, each kind of stroke, a label on its baseline, a 429 skipped, shapes onto the board, a tap's hit, kept ink through PencilKit's own spline; `WhiteboardGhostTurnsTests`: a failing Cockpit noted once, a stale answer shown nowhere) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a pause brings a ghost; the keep verified on the simulator by `WhiteboardTurnUITests`); a real Claude answer and undo not yet tried on the iPad; #624's label converts to one unbroken row of every letter, pinned in [0215bb6](https://github.com/idvorkin/context-grabber/commit/0215bb6) (`BoardLabelOneLineTests`, host; the break seen on the iPad came after the keep, not from the conversion, and waits on the iPad's `ink_moved` evidence)
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
- **Issues:** [#1002](https://github.com/idvorkin/context-grabber/issues/1002) (an upload sometimes fails *Batch Request Failed / Atomic failure*, the first sync of a launch)
- **Status:** implemented in [f65c023](https://github.com/idvorkin/context-grabber/commit/f65c023) and the review fixes in [58048e5](https://github.com/idvorkin/context-grabber/commit/58048e5); verified by host tests (`BoardIndexTests`: read-only off the drawing device, the merge, a failed fetch retried) and the simulator (the boards open, iCloud skipped with no account); an iPad board on the phone not yet seen; a failed sync's log line names its step and each record's own CloudKit error (#1002, instrumentation only) in [6ccd13a](https://github.com/idvorkin/context-grabber/commit/6ccd13a), its fields verified by host tests (`BoardSyncFailureTests`), the real error awaits the iPad's next log

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

### User Story 836:

- **Summary:** Rename a board from its row's swipe
- **Status:** implemented in [d9fd5cf](https://github.com/idvorkin/context-grabber/commit/d9fd5cf), the rename menu on the board's bar taken out again in [d33c7d0](https://github.com/idvorkin/context-grabber/commit/d33c7d0) (it kept the iPad's Board menu up after a pick); verified by host tests (`BoardIndexTests.testARenameIsKeptAndReachesTheOtherDevices`: the name kept through the list's save, not undone by iCloud's older copy, shown on the phone, which offers no Rename; `just test`) and on an iPad simulator (`WhiteboardRowDeleteUITests.testABoardDrawnHereIsRenamedFromItsRowAndShowsItInItsBar`: the swipe's Rename beside Delete, the long press's, the row and the bar taking the name); the real iPad not yet tried
- **Issues:** [#916](https://github.com/idvorkin/context-grabber/issues/916) ("Log bug: Rename boards")
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The boards*

#### Use Case:
- **As someone** with several boards named for the day they were started
- **I want to** rename a board where I'd look for it, a swipe on its row as in Mail or Chat
- **so that** I can tell my boards apart by what's on them

#### Acceptance Criteria:
- **Scenario:** From the list
- **Given:** the list, with a row for a board this device drew, named *Board, Nov 16*
- **When:** I swipe the row left, tap *Rename*, type *Energy week* and confirm
- **Then:** the row says *Energy week*, at the top, and opening the board its bar says *Energy week*

---

### User Story 878:

- **Summary:** A rename with no name changes nothing
- **Status:** implemented in [d9fd5cf](https://github.com/idvorkin/context-grabber/commit/d9fd5cf) (story 836); verified by host tests (`BoardIndexTests.testRenameIsTrimmedAndCountsAsAChange`: a blank name ignored; `just test`); *Cancel* on the simulator not yet tried
- **Issues:** [#916](https://github.com/idvorkin/context-grabber/issues/916)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The boards*

#### Use Case:
- **As someone** renaming a board from its row (story 836)
- **I want to** back out of a rename without losing the name it had
- **so that** a slip of the finger never leaves a board nameless

#### Acceptance Criteria:
- **Scenario:** Nothing changes
- **Given:** the rename box is open for a board named *Board, Nov 16*
- **When:** I clear the name and confirm, or tap *Cancel*
- **Then:** the board keeps the name *Board, Nov 16*

---

### User Story 879:

- **Summary:** Another device's board offers no Rename
- **Status:** implemented in [d9fd5cf](https://github.com/idvorkin/context-grabber/commit/d9fd5cf) (story 836: the swipe's Rename only for a board this device drew, as the long press already was); verified by host tests (`BoardIndexTests.testARenameIsKeptAndReachesTheOtherDevices`: the phone offers no Rename; `just test`)
- **Issues:** [#916](https://github.com/idvorkin/context-grabber/issues/916)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The boards*

#### Use Case:
- **As someone** with boards drawn on the iPad and seen on the phone
- **I want to** rename a board only on the device that drew it
- **so that** two devices never fight over a board's name

#### Acceptance Criteria:
- **Scenario:** Another device's board
- **Given:** a board drawn on another device
- **When:** I swipe or long-press its row
- **Then:** it offers *Delete* and no *Rename*

---

### User Story 349:

- **Summary:** Larry takes a turn on the board
- **Status:** first implemented as a call that waited for him in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); changed to the chat path, no waiting, in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b) (Igor, 2026-11-02); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: Larry's turn brings his marks with no further tap) against the fake Cockpit; the real Larry's answer on the iPad not yet tried; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** working an idea out on the board
- **I want to** hand Larry the Pencil for a turn
- **so that** he answers in marks on my drawing, not only in words somewhere else

#### Acceptance Criteria:
- **Scenario:** Larry answers on the board
- **Given:** the board has a drawing
- **When:** I tap *Larry's turn* and carry on
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) until he answers (story 662), with no spinner, and the Pencil keeps drawing. When he answers, faint purple shapes and a line from him appear with no tap, nothing on the board changes until I keep one, Chat has a thread named after the board with the picture and his words, and the board's next turn goes to it

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
- **Status:** app side implemented in [66343f7](https://github.com/idvorkin/context-grabber/commit/66343f7); seen on the simulator in the recording of `WhiteboardTurnUITests.testGhostsOffAsksNothing` (no note with Ghosts off, the note back on), which passed with the other `WhiteboardTurnUITests` in the build turn of [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11) and [17343c3](https://github.com/idvorkin/context-grabber/commit/17343c3). Since bead `context-grabber-5eq` the rule is a host test (`WhiteboardGhostTurnsTests`: a stroke with Ghosts off starts no pause, Claude's go and Larry's stay, an answer on its way lands stale, on again asks), and that UI test is gone
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
- **Status:** app side implemented on this branch; `WhiteboardTurnUITests.testAFingerTapOffAGhostDismissesItAndOnOneKeepsIt` verified on the simulator by `WhiteboardTurnUITests` (an old-canvas test, dropped 2026-11-07; on paper `WhiteboardPaperGhostsUITests.testAGhostShowsOnThePaperAndKeepMakesItInk` and `testATapOffKeepsTheGhostDismissRemovesItAndAFingerDrawsAgain` hold it since story 825); an iPhone and an iPad with no Pencil not yet tried. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first and Larry's only once his are all that's left (stories 663, 664); on branch `native/batch-decided-1114` (#883, story 825) a tap on a ghost offers Keep and Dismiss and a tap off them does nothing, verified by host tests and the Mac build, simulator and device still to do
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a finger, on an iPad with no Pencil (an iPhone only looks since story 746)
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** tapping a suggestion doesn't draw a dot and lose it

#### Acceptance Criteria:
- **Scenario:** A finger tap while ghosts show
- **Given:** a finger draws on this device and ghosts are showing
- **When:** I tap a ghost
- **Then:** Keep and Dismiss show beside it and no dot is drawn (story 825); once no ghost is left, kept, dismissed or faded, my finger draws again

---

### User Story 663:

- **Summary:** A stray tap leaves Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (`WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad; changed on branch `native/batch-decided-1114` (#883, story 825): a tap off the marks dismisses nothing, and a mark goes only by its own Dismiss; verified by host tests and the Mac build, simulator and device still to do
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good), [#883](https://github.com/idvorkin/context-grabber/issues/883) (Keep and Dismiss beside the mark, story 825)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on a board where Claude and Larry have both drawn back
- **I want to** dismiss only Claude's ghosts when I tap off them
- **so that** one stray tap can't lose Larry's marks, which can't come back

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with both showing
- **Given:** Claude's ghosts and Larry's marks are both showing
- **When:** I tap off them
- **Then:** nothing is dismissed: Claude's and Larry's all stay (story 825)

---

### User Story 664:

- **Summary:** A deliberate choice clears Larry's marks
- **Status:** implemented in [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38); verified on the host (`WhiteboardGhostTurnsTests.testATapOffDismissesClaudesFirstAndLarrysOnlyWhenTheyAreAlone`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad; changed on branch `native/batch-decided-1114` (#883, story 825): a tap off the marks dismisses nothing, and a mark goes only by its own Dismiss; verified by host tests and the Mac build, simulator and device still to do
- **Issues:** [#823](https://github.com/idvorkin/context-grabber/issues/823) (one stray tap dismissed Larry's marks for good), [#883](https://github.com/idvorkin/context-grabber/issues/883) (Keep and Dismiss beside the mark, story 825)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who has looked at Larry's marks and doesn't want them
- **I want to** dismiss Larry's marks with a tap off them once they're all that's left
- **so that** clearing his always takes a tap of its own

#### Acceptance Criteria:
- **Scenario:** A tap off the ghosts with only Larry's left
- **Given:** only Larry's marks are showing
- **When:** I tap Dismiss beside each of them (story 825)
- **Then:** each goes as I dismiss it, and a tap off them dismisses nothing

---

### User Story 665:

- **Summary:** Turning Ghosts off closes the board's mic
- **Status:** implemented in [9a83d67](https://github.com/idvorkin/context-grabber/commit/9a83d67); verified on the host (`WhiteboardGhostTurnsTests`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad
- **Issues:** [#824](https://github.com/idvorkin/context-grabber/issues/824) (the mic heard words with Ghosts off and dropped them silently)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** talking to the board who switches the ghosts off mid-sentence
- **I want to** have the mic close and say why
- **so that** I don't keep talking to a mic that reaches no one (story 367)

#### Acceptance Criteria:
- **Scenario:** Ghosts go off while I talk
- **Given:** the board's mic is open
- **When:** I turn Ghosts off
- **Then:** the mic closes, the bar says Ghosts are off so the mic would reach no one, and the words aren't asked about, now or when Ghosts come back

---

### User Story 666:

- **Summary:** A palm resting before the Pencil doesn't make the stroke a finger's
- **Status:** implemented in [b0e8221](https://github.com/idvorkin/context-grabber/commit/b0e8221); verified on the host (`PaperProbeTests`) and the Mac build; the Pencil-and-palm line not yet seen in an iPad log
- **Issues:** [#825](https://github.com/idvorkin/context-grabber/issues/825) (a run was typed by its first touch, so a palm made the Pencil's strokes a finger's)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding what a palm and a finger should do on paper
- **I want to** have a touch logged as the Pencil's whenever the Pencil was in it, with what else was touching
- **so that** the next iPad log tells a resting palm from a finger (story 600)

#### Acceptance Criteria:
- **Scenario:** A palm resting before the Pencil
- **Given:** a board on paper
- **When:** my palm lands first and then the Pencil draws, before both lift
- **Then:** the line says the Pencil drew, counts how many touches of each kind it held, and gives the largest finger contact's size

---

### User Story 825:

- **Summary:** Keep and Dismiss beside a tapped mark
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests`: the tap and where the buttons sit) and the Mac build. Fixed in [6754880](https://github.com/idvorkin/context-grabber/commit/6754880): the dot PaperKit draws under a finger's tap is taken back (`PaperProbeTests.testATapsDotIsTheSmallInkAtTheTapJustAfterIt`), and Keep and Dismiss carry their own names; verified on an iPad simulator by `WhiteboardPaperGhostsUITests`, three runs, every test passing first time. The iPad itself still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** see Keep and Dismiss beside a mark I tap, wholly on screen
- **so that** a tap never keeps or loses a mark without my saying which

#### Acceptance Criteria:
- **Scenario:** A tap on a mark at the edge
- **Given:** Larry's marks are showing on a board, one of them at the edge of the screen
- **When:** I tap the one at the edge
- **Then:** nothing on the board has changed, and Keep and Dismiss show beside it, wholly on screen

---

### User Story 808:

- **Summary:** Dismiss beside a mark removes only it
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests.testDismissRemovesOnlyThatMark`, `WhiteboardMarksTests.testSettlingRemembersOnlyThatRowsKeptOrDismissedMarks`) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** dismiss one mark with the Dismiss beside it
- **so that** I turn down that mark and keep thinking about the rest

#### Acceptance Criteria:
- **Scenario:** Dismissing one of his marks
- **Given:** Keep and Dismiss show beside one of Larry's three marks
- **When:** I tap Dismiss
- **Then:** only that mark goes, and when the board opens again it stays gone while his other two show

---

### User Story 809:

- **Summary:** Keep beside a mark makes it ink
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests.testKeepTakesTheChosenMarkOffTheGhosts`) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** keep one mark with the Keep beside it
- **so that** it joins my drawing only because I said so

#### Acceptance Criteria:
- **Scenario:** Keeping a mark
- **Given:** Keep and Dismiss show beside a mark
- **When:** I tap Keep
- **Then:** it becomes ink in its colour, and one undo takes it back

---

### User Story 810:

- **Summary:** A stray tap or a stroke puts Keep and Dismiss away
- **Status:** implemented on branch `native/batch-decided-1114`; verified by host tests (`WhiteboardMarkChoiceTests`: the stray tap and the stroke) and the Mac build; the simulator (`WhiteboardPaperGhostsUITests`, compiled, not run) and the iPad still to do
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883) (a tap on Larry's writing kept it with nothing on screen saying so; Igor, 2026-11-14: Keep and Dismiss beside the mark, a stray tap does nothing)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** looking at a mark Larry or Claude drew on my board
- **I want to** have a tap off the marks, or a stroke, only put the buttons away
- **so that** a stray touch never keeps or loses a mark

#### Acceptance Criteria:
- **Scenario:** A stray tap or a stroke
- **Given:** Keep and Dismiss are showing beside a mark
- **When:** I tap off the marks, or start drawing with the Pencil
- **Then:** the buttons go, every mark is still showing, nothing is kept, and the Pencil's stroke is drawn

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
- **Scenario:** A purple ghost, kept
- **Given:** Larry's faint purple shapes are showing
- **When:** I tap one
- **Then:** it becomes purple ink that my eraser and undo treat like mine

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
- **Given:** Larry's faint purple shapes are showing
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
- **Given:** Claude's orange ghosts and Larry's purple ones are showing
- **When:** I pause and Claude answers again
- **Then:** Claude's old ghosts fade out as his new ones draw in one after another, and Larry's stay

---

### User Story 358:

- **Summary:** Claude's ghosts fade when they're left alone
- **Status:** implemented in [26d9d11](https://github.com/idvorkin/context-grabber/commit/26d9d11); verified on the simulator by `WhiteboardTurnUITests` (`testClaudesGhostsFadeAndLarrysStay`, with the time shortened); since bead `context-grabber-5eq` by host tests instead (`WhiteboardGhostTurnsTests`: Claude's go at 30 s and Larry's stay, a newer answer starts the 30 s over, Larry's never fade)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing on past a suggestion
- **I want to** have Claude's ghosts go by themselves after a while
- **so that** a suggestion doesn't sit on a drawing that has moved past it

#### Acceptance Criteria:
- **Scenario:** Left alone
- **Given:** Claude's orange ghosts and Larry's purple ones are showing
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
- **Status:** implemented in [c863d76](https://github.com/idvorkin/context-grabber/commit/c863d76); verified on the simulator by `WhiteboardTurnUITests` with the hook standing in for the microphone, and since bead `context-grabber-y8r` by the host alone (`WhiteboardGhostTurnsTests`); real dictation to try on the iPad. Since [9a83d67](https://github.com/idvorkin/context-grabber/commit/9a83d67) (#824) the mic doesn't open with Ghosts off, so the say hook no longer stands in for it here: verified on the host (`WhiteboardGhostTurnsTests`) and the Mac build. The whiteboard UI tests are blocked by [#850](https://github.com/idvorkin/context-grabber/issues/850) (Board-menu taps swallowed on the iPad simulator) and weren't run; not yet tried on an iPad
- **Issues:** [#604](https://github.com/idvorkin/context-grabber/issues/604), [#605](https://github.com/idvorkin/context-grabber/issues/605), [#824](https://github.com/idvorkin/context-grabber/issues/824) (the mic heard words with Ghosts off and dropped them silently)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** who switched the ghosts off
- **I want to** have talking ask nothing either
- **so that** the switch means what it says (story 351)

#### Acceptance Criteria:
- **Scenario:** Speaking with Ghosts off
- **Given:** Ghosts are off
- **When:** I tap the board's mic
- **Then:** it doesn't open, and the bar says Ghosts are off so the mic would reach no one; nothing is asked, no ghost appears, and nothing is sent when Ghosts come back

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
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by host tests (`WhiteboardStreamTests`: partial lines, unknown lines skipped, the last line) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: six marks climb the count); since bead `context-grabber-5eq` the climb is a host test (`WhiteboardGhostTurnsTests`: six streamed marks land one at a time, the first replacing Claude's last set), and the simulator keeps one streamed mark reaching the screen (`testAPauseBringsAGhostAndLarryTakesATurn`). The real Cockpit streams (cockpit f208f6c; a live request, 2026-11-02: 200 `application/x-ndjson`, a label, an arrow and the last line); the app reading it and the first-mark time are still to see on the iPad
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
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified on the simulator by a screenshot from `WhiteboardTurnUITests`, solid orange lines on an iPhone simulator (since bead `context-grabber-5eq` the screenshot is `testAPauseBringsAGhostAndLarryTakesATurn`'s, Claude's ghost and Larry's two); how they sit beside real Pencil ink is to judge on the iPad
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** deciding whether to keep a mark
- **I want to** see a ghost drawn as the ink it would become, only fainter
- **so that** I can judge how it looks on the board before I tap it

#### Acceptance Criteria:
- **Scenario:** Solid, not dashed
- **Given:** a ghost is showing, Claude's in orange or Larry's in purple
- **When:** I look at it
- **Then:** it is a solid faint line with round ends, as wide as a kept stroke, and a label shows its letters written in single strokes (since story 1049; before, their outlines)

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
- **Status:** implemented in [c8dcd20](https://github.com/idvorkin/context-grabber/commit/c8dcd20); verified by a host test (`WhiteboardStreamTests`: a plain answer) and the simulator against the fake Cockpit (`WhiteboardTurnUITests`: a Cockpit that doesn't stream still brings its ghost); since bead `context-grabber-5eq` that check is a host test (`WhiteboardGhostTurnsTests`: a plain answer lands no mark while it's read and all of it at the end)
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
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); the turn's message and the bar verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`) against the fake Cockpit; drawing with the Pencil while he has the board to try on the iPad; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Spec:** [Whiteboard: Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md)

#### Use Case:
- **As someone** drawing with a Larry who takes minutes to answer
- **I want to** hand him the board and keep going
- **so that** his turn is a conversation in the background, not a wait

#### Acceptance Criteria:
- **Scenario:** Hand him the board
- **Given:** I have drawn on the board
- **When:** I tap *Larry's turn*
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) as soon as the picture is taken (story 662), with no spinner, and I can keep drawing and, once that picture has gone, tap it again for a newer one

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
- **Then:** within a few seconds, with no tap, they show as purple ghosts on what the picture showed, not where I am now, and his text shows in the bar as his line

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
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by the simulator (`WhiteboardTurnUITests`) against the fake Cockpit, read from the board's note. Since story 770 the simulator keeps the unprompted marks and the reopen after a dismissal; the newest set on opening and a seen set never coming back are `WhiteboardMarksTests` on the host
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
- **Status:** implemented in [b1e1b1b](https://github.com/idvorkin/context-grabber/commit/b1e1b1b); verified by host tests (`WhiteboardMarksTests`) and the simulator (`WhiteboardTurnUITests`: dismissed, not back on the next look or the next open); keeping one from a row then reopening is host-tested only; on branch `native/batch-decided-1114` (#883, story 808) only the marks kept or dismissed stay gone, and the rest of the row shows again on opening, verified by host tests (`WhiteboardMarksTests`) and the Mac build
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
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597), [#996](https://github.com/idvorkin/context-grabber/issues/996)
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); the layout verified by host tests (`WhiteboardPasteTests`); on the simulator (`WhiteboardPasteUITests`), ⌘V from a real clipboard with no prompt, and through a launch hook each line and Claude's pause; the ink's look checked by eye at its pen width in dark mode. Still to try on the iPad: the Paste button itself (XCUITest's taps never fire the system control) and that it shows no prompt, zoomed-out and zoomed-in pastes, sync to the other device; written in single strokes in [c0b61e1](https://github.com/idvorkin/context-grabber/commit/c0b61e1) (#996), verified by host tests (`WhiteboardPasteTests`: a letter's own strokes, curly typography, rows by the written width) and the simulator's whiteboard smoke; the paste UI tests (`WhiteboardPasteUITests`, `WhiteboardPaperPasteUITests`) pass on the iPad simulator (rung 2, 2026-11-20), and the paste counts in the Outline and Paper Lines classes (`WhiteboardOutlineUITests`, `WhiteboardPaperLinesUITests`) followed in [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) and [3d3842fe](https://github.com/idvorkin/context-grabber/commit/3d3842fe)
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** thinking on the board with words already on my clipboard
- **I want to** paste them with the bar's Paste button or ⌘V
- **so that** they sit on the board as ink and travel with its picture to Larry and Claude

#### Acceptance Criteria:
- **Scenario:** A paste becomes ink
- **Given:** a board I can draw on is open and the clipboard holds two lines of text
- **When:** I tap Paste or press ⌘V
- **Then:** both lines appear as thin ink, written in single strokes like Larry's labels (#996), in the middle of what's on screen with no *Allow Paste?* prompt, the board saves it, and about a second later Claude's ghosts come

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
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); both caps verified by host tests (`WhiteboardPasteTests`); the 500-character cut and its note on the simulator (`WhiteboardPasteUITests`, through a launch hook); since bead `context-grabber-y8r` the note's words are a host test too (`WhiteboardPasteTests`), and the UI case that drew 500 strokes is gone
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
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); no outline means no ink verified by host tests (`WhiteboardPasteTests`); the note and the untouched board on the simulator (`WhiteboardPasteUITests`, through a launch hook); which note, a host test since bead `context-grabber-y8r`. Since story 770 the note's words are `WhiteboardPasteTests` and its place on the bar `WhiteboardNoteTests`, on the host; the simulator no longer pastes emoji
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
- **Status:** implemented in [135f67c](https://github.com/idvorkin/context-grabber/commit/135f67c); not verified by a test; changed in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac) (#1005: no Paste without text), verified on the iPad simulator by `WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole`; to try on the iPad: no Paste on a look-only board, ⌘V doing nothing on either
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** looking at a board with nothing to paste, or one another device draws
- **I want to** have Paste and ⌘V stay out of the way
- **so that** nothing lands where it can't or shouldn't

#### Acceptance Criteria:
- **Scenario:** No paste to make
- **Given:** the clipboard holds neither text nor copied strokes, or the board is look-only
- **When:** I look at the bar or press ⌘V
- **Then:** there is no Paste in the bar and ⌘V does nothing

---

### User Story 395:

- **Summary:** Strokes I copied still paste
- **Issues:** [#597](https://github.com/idvorkin/context-grabber/issues/597)
- **Status:** implemented on this branch; changed in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac) (#1005: no Paste without text); not verified by a test (on the simulator, PencilKit's canvas was seen to have its own paste); to try on the iPad with a hardware keyboard
- **Spec:** [Whiteboard: paste text onto the board](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** moving ink around with the lasso
- **I want to** paste the strokes I copied with ⌘V
- **so that** pasting text doesn't cost me the system's paste of ink

#### Acceptance Criteria:
- **Scenario:** Copied strokes
- **Given:** a board I can draw on is open and the clipboard holds strokes copied with the lasso and no text
- **When:** I press ⌘V
- **Then:** the strokes land the way the system always pastes them, and there is no Paste in the bar

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

### User Story 1054:

- **Summary:** The board's bar has no hole: Paste shows only with text to paste, beside the Board menu
- **Status:** implemented in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac); verified on the iPad simulator (`just test-ladder`: `WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole` with no text on the clipboard, `WhiteboardPasteUITests` and `WhiteboardPaperGhostsUITests` with text on it, and the whiteboard's other UI classes) and the Mac build; changed in [53231df](https://github.com/idvorkin/context-grabber/commit/53231df) (text copied in an app beside the board shows Paste within about a second), not verified by a test. Not yet seen on the iPad
- **Issues:** [#1005](https://github.com/idvorkin/context-grabber/issues/1005) (design critique of the iPad board, 2026-11-20: unlabelled sparkle and hand, a large gap between the palette and the mic)
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *The top bar's groups and labels*

#### Use Case:
- **As someone** reaching for Larry's buttons at the top of a board
- **I want to** see the bar's buttons evenly spaced, the board's own menu in a group of its own
- **so that** a blank space doesn't look like a missing or broken button

#### Acceptance Criteria:
- **Scenario:** Nothing to paste
- **Given:** a board open on an iPad and no text on the clipboard
- **When:** I look at the top bar
- **Then:** the Board menu sits in a group of its own, Talk, Ghosts, Larry and Send are evenly spaced in theirs, and there is no empty space; once I copy some text, here or in an app beside the board, Paste appears beside the Board menu within about a second and the other four don't move

---

### User Story 1055:

- **Summary:** A long press on a bar button says its name
- **Status:** implemented in [cd677ac](https://github.com/idvorkin/context-grabber/commit/cd677ac); verified on the iPad simulator (`WhiteboardTurnUITests.testTheBarNamesItsButtonsAndHasNoHole`: a long press on Ghosts shows the *Ghosts* menu, its row turns them off, a tap turns them back on) and the Mac build. Not yet seen on the iPad
- **Issues:** [#1005](https://github.com/idvorkin/context-grabber/issues/1005) (design critique of the iPad board, 2026-11-20: unlabelled sparkle and hand, a large gap between the palette and the mic)
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *The top bar's groups and labels*

#### Use Case:
- **As someone** who sees a sparkle and a hand in the board's bar
- **I want to** find out what each one does without trying it
- **so that** I don't send Larry a picture or turn off Claude's suggestions by accident

#### Acceptance Criteria:
- **Scenario:** Long press the sparkle
- **Given:** a board open with Ghosts on
- **When:** I press and hold the sparkle
- **Then:** a small menu headed *Ghosts* shows one row, *Hide Claude's suggestions*, which does it if I tap it; Talk, Larry and Send name themselves the same way, and a plain tap on any of them does what it always did

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
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the colour on the canvas in both modes verified on the simulator by `WhiteboardTurnUITests` (from the screen's pixels; a screenshot of white ink on the deep Cream comes from the run before the menu moved); ink contrast on every colour by host tests (`BoardPaperTests`). On paper, which stays light, its colour staying with the board is `WhiteboardPaperLinesUITests.testRuledLinesStayWithTheBoardUnderTheInk` since bead `context-grabber-y8r`
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
- **When:** Claude's orange ghosts and Larry's purple ones show
- **Then:** I can see them about as well as on Plain

---

### User Story 405:

- **Summary:** A colour alone keeps no empty board
- **Status:** implemented in [0b5c0fe](https://github.com/idvorkin/context-grabber/commit/0b5c0fe); the empty-board rule verified by host tests (`BoardIndexTests`, and `BoardKeepingTests`: a new board closed without a stroke is dropped)
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

- **Summary:** A new board opens with the grid on
- **Status:** first implemented as *A new board has no grid* in [9fbed41](https://github.com/idvorkin/context-grabber/commit/9fbed41), in the Board menu in [1f0f009](https://github.com/idvorkin/context-grabber/commit/1f0f009); reversed to the grid on (Igor, 2026-11-16, #915) in [c0e22ba](https://github.com/idvorkin/context-grabber/commit/c0e22ba); verified by host tests (`BoardLinesTests`: a new board's grid on, a board with no saved choice off, a saved choice kept, ruled lines taking the grid's place; `just test`); verified on an iPad simulator (`WhiteboardPaperLinesUITests.testANewBoardOpensWithTheGrid`, and the class's other tests with new boards started bare by `GRABBER_WHITEBOARD_GRID=off`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#608](https://github.com/idvorkin/context-grabber/issues/608), [#915](https://github.com/idvorkin/context-grabber/issues/915) ("Log bug: default new boards have grid lines")

#### Use Case:
- **As someone** sketching on the iPad
- **I want to** start each new board with faint grid lines
- **so that** I can line things up from the first stroke without going to the Board menu

#### Acceptance Criteria:
- **Scenario:** New board
- **Given:** another board has its grid off
- **When:** I make a new board
- **Then:** its grid is on, and the Board menu shows *Grid lines* chosen

---

### User Story 888:

- **Summary:** A board made before new boards had the grid keeps no grid
- **Status:** implemented in [c0e22ba](https://github.com/idvorkin/context-grabber/commit/c0e22ba) (story 410, #915); verified by host tests (`BoardLinesTests`: a board with no saved choice off, a saved choice kept; `just test`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)
- **Issues:** [#915](https://github.com/idvorkin/context-grabber/issues/915)

#### Use Case:
- **As someone** with boards from before new boards opened with the grid (story 410)
- **I want to** find those boards as I left them
- **so that** a change to the default never redraws a page I already made

#### Acceptance Criteria:
- **Scenario:** A board made before
- **Given:** a board made before new boards had the grid, never given one
- **When:** I open it
- **Then:** it has no grid, as before

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
- **Status:** implemented on paper in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (stories 591, 603); the page mostly on screen is the one at the screen's middle, verified by host tests (`BoardPagesTests`) and on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: *Page 1 of 2*) and on an iPhone 17 simulator (`WhiteboardPaperGhostsUITests.testThePictureIsThePageOnScreen`: *Page 2 of 2*, then *Page 2 of 3*, reaching page 2 through a launch hook). The corner is in no picture by construction: since [a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315) (story 433) Larry's picture is drawn from the strokes, not the screen. Reaching page 2 by scrolling with a finger is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
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
- **Status:** implemented on paper in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e) as a look-only board (story 658; Igor, 2026-11-07: "Old canvas can be erased"): its ink moved onto the first page's corner, never scaled, by the rule in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34) (story 539); verified by host tests (`BoardPagesTests`, `BoardKeepingTests`) and the simulator smoke's `paper_open` (40 strokes at the first page's corner). A look-only board takes no turns, so Larry's marks don't arise on it. Igor's own old boards on the iPad not yet seen
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
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

---

### User Story 432:

- **Summary:** A mark past the page edge widens the board
- **Status:** not implemented; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
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
- **Status:** implemented on paper in [a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315), for Send to Larry and *Larry's turn*; verified on the host (`BoardPicturePagesTests`) and on an iPhone 17 simulator (`testThePictureIsThePageOnScreen`: the frame the fake Cockpit got is page 2's alone, and Larry's marks came back to it). Whether Larry reads the writing well, and how it feels on the iPad, haven't been checked; the old canvas still sends the whole board; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
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

---

### User Story 434:

- **Summary:** Ruled lines, like notebook paper
- **Status:** implemented on paper in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`). 40 points is provisional until Igor has seen it; the old canvas has no ruled lines; asks: [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#678](https://github.com/idvorkin/context-grabber/issues/678)
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

---

### User Story 435:

- **Summary:** Try a board on paper, temporarily, from its long press
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator on iOS 27 (`WhiteboardTrialOnPaperUITests`: opens on this device's board) and by host tests (`BoardKeepingTests`: offered on this device's boards only); played with on the iPad by Igor, 2026-11-03; temporary: goes when the board moves to PaperKit
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

---

### User Story 436:

- **Summary:** Nothing in the trial reaches a real board
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`BoardKeepingTests`: the trial's copy reads the board's ink and writes, moves or removes nothing, and an unreadable board stays where it is), and by construction: the trial is handed a drawing, never the store. Earlier, on an iPad simulator, the boards' files hashed the same across trial runs, and a copy with ink added left no file
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

---

### User Story 437:

- **Summary:** The trial is a column of pages
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests` and screenshots: tool picker, page lines, page number)
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

---

### User Story 438:

- **Summary:** The trial says what to try, and has the switches to try it
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`: the line, and every switch runs); played with on the iPad by Igor, 2026-11-03; since bead `context-grabber-y8r` the every-switch probe runs only when asked (`TEST_RUNNER_GRABBER_PAPER_PROBES=1`), not in each suite run
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

---

### User Story 439:

- **Summary:** The trial's log settles the five questions
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`PaperProbeTests`) and the simulator (`WhiteboardTrialOnPaperUITests` and `sim-smoke.sh`, whiteboard). Question 1, what a finger does with a Pencil paired, needs the iPad's log: `just pull-logs`
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

---

### User Story 520:

- **Summary:** Pinching out stops at the page
- **Status:** implemented on paper in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f): the pinch's floor is the zoom that fits the column's width, and it scrolls only up and down; the fit zoom verified by host tests (`BoardPagesTests`). XCUITest's pinch barely moves on an iPad simulator, so a real pinch is the iPad's. Zooming out past the page to a whole page held sideways was weighed for #636 and not wanted
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who zooms out to look at a page
- **I want to** have the pinch stop when the page fits the screen
- **so that** the board never moves off sideways into nothing

#### Acceptance Criteria:
- **Scenario:** Pinching out
- **Given:** I am on a page
- **When:** I pinch out as far as it goes
- **Then:** it stops with the page fitting the screen's width, and the board never moves off sideways into nothing

---

### User Story 521:

- **Summary:** An old board wider than a page keeps its width
- **Status:** implemented on paper in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e) (story 658): ink wider than a page widens the board by the rule in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34), never scaled, and pages get no taller; verified by host tests (`BoardPagesTests`: `testInkWiderThanAPageWidensTheBoardInsteadOfShrinking`, `testAWideBoardsPagesAreWideAndNoTaller`). Panning sideways only as far as that width hasn't been driven on a simulator, as no fixture board is wider than a page; Igor's own wide boards on the iPad not yet seen
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), closed by Igor 2026-11-20 ("the board feels good now")
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with an old board drawn wider than a page
- **I want to** keep all of it, at its old size
- **so that** moving onto pages never shrinks or crops my drawing

#### Acceptance Criteria:
- **Scenario:** A board wider than a page
- **Given:** a board from before pages with ink wider than a page
- **When:** I open it
- **Then:** it keeps its own wider width, no stroke scaled, and I can pan sideways only as far as that width

---

### User Story 522:

- **Summary:** Nothing on screen, nothing to send
- **Status:** implemented on paper in [a5dbc315](https://github.com/idvorkin/context-grabber/commit/a5dbc315), Send to Larry and *Larry's turn* both disabled; verified on the host (`BoardPicturePagesTests`) and on an iPhone 17 simulator (`testThePictureIsThePageOnScreen`). Not yet checked on the iPad; asks: [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a blank page of a long board
- **I want to** see that Send to Larry has nothing to send
- **so that** I never send him an empty picture

#### Acceptance Criteria:
- **Scenario:** Nothing on screen
- **Given:** ink on page 1 and a blank page on screen
- **When:** I look at Send to Larry
- **Then:** it's disabled, because there's nothing on screen to send

---

### User Story 523:

- **Summary:** One kind of lines at a time
- **Status:** implemented on paper in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`); asks: [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** choosing what the paper looks like
- **I want to** have ruled lines replace the grid
- **so that** the two never pile up on one board

#### Acceptance Criteria:
- **Scenario:** One kind at a time
- **Given:** a board with its grid on
- **When:** I choose Ruled lines
- **Then:** the grid goes and the ruled lines show

---

### User Story 524:

- **Summary:** The trial isn't offered on another device's board
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`BoardKeepingTests`: another device's board isn't offered it; the list's menu asks `BoardKeeping.offersTrial`)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose boards sync between devices
- **I want to** find the trial only on the boards this device draws
- **so that** a board I can't draw on here doesn't offer me a way to draw on it

#### Acceptance Criteria:
- **Scenario:** Another device's board
- **Given:** a board drawn on another device
- **When:** I long-press its row
- **Then:** *Try on paper* isn't offered

---

### User Story 525:

- **Summary:** The trial isn't offered before iOS 27
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: retired by [bacbc3e](https://github.com/idvorkin/context-grabber/commit/bacbc3e): the whole app now needs iOS 27, so there's no older system left to offer it on (built for the simulator, every bundle's minimum read as 27.0). Implemented earlier in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** on an older system
- **I want to** see the app as it was
- **so that** a trial of a new framework costs me nothing

#### Acceptance Criteria:
- **Scenario:** Before iOS 27
- **Given:** a device below iOS 27
- **When:** I long-press a row
- **Then:** *Try on paper* isn't offered, and the app runs as it did

---

### User Story 526:

- **Summary:** A board that can't be read says so, and stays
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); not yet run on any rung: no test hands it an unreadable file
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose board file has gone bad
- **I want to** a problem I can copy, and the file left alone
- **so that** the trial never makes a bad file worse

#### Acceptance Criteria:
- **Scenario:** A board that can't be read
- **Given:** a board whose drawing can't be read
- **When:** I choose *Try on paper*
- **Then:** a copyable problem says so, and the file stays where it is

---

### User Story 527:

- **Summary:** The trial has nothing to send with
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`: none of the four buttons exists). That nothing goes out is by construction: the trial is handed no store, model or inbox
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** playing with an unfinished canvas
- **I want to** find no way to send from it
- **so that** a scribble in the trial never reaches Larry or iCloud

#### Acceptance Criteria:
- **Scenario:** Nothing to send
- **Given:** the trial is open
- **When:** I look for Send, Larry's turn, ghosts or the mic
- **Then:** there's none of them, and nothing goes to the Cockpit or iCloud

---

### User Story 528:

- **Summary:** The trial's pinch stops at the page
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`BoardPagesTests`: the fit zoom); pinching with real fingers is the iPad's: the simulator's pinch didn't change the zoom
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** trying the Notability-like board
- **I want to** have pinching out stop at the page
- **so that** I can judge the page-width shape before it is built for real

#### Acceptance Criteria:
- **Scenario:** Pinching out
- **Given:** the trial is open
- **When:** I pinch out as far as it goes
- **Then:** it stops when the page fits the screen's width

---

### User Story 529:

- **Summary:** Writing on the last page adds a blank one
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`PaperProbeTests`: when ink needs a page) and an iPad simulator (`WhiteboardTrialOnPaperUITests`: a page added)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing to the end of the trial's column
- **I want to** always have a blank page below
- **so that** I can judge how the column grows

#### Acceptance Criteria:
- **Scenario:** Writing on the last page
- **Given:** a stroke reaching the last page
- **When:** I lift the Pencil
- **Then:** one more blank page is below, and the page number's total goes up

---

### User Story 530:

- **Summary:** A page in the middle of a stroke
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`, the `paper_probe` lines read: a page added mid-stroke with a finger kept the stroke and undo); the Pencil's half is the iPad's
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding how a column of pages should grow
- **I want to** land a page in the middle of a stroke on purpose
- **so that** question 2 gets its answer from the log

#### Acceptance Criteria:
- **Scenario:** A page in the middle of a stroke
- **Given:** the Trial menu
- **When:** I choose *Add a page in 3 s* and write a long stroke across that moment
- **Then:** the page is added, and the log says a touch was down and what became of the stroke

---

### User Story 531:

- **Summary:** Going far down the column
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`: the corner reads *Page 11 of*); the ink's feel there is the iPad's
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** judging the ink's feel far down a board
- **I want to** jump past 9,600 points in one choice
- **so that** I can write there without scrolling all that way

#### Acceptance Criteria:
- **Scenario:** Going far down
- **Given:** the Trial menu
- **When:** I choose *Go to page 11*
- **Then:** the view goes past 9,600 points down, adding pages if it must, so I can write there

---

### User Story 532:

- **Summary:** The log says what adding a page did
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on an iPad simulator (`WhiteboardTrialOnPaperUITests`, the `paper_probe` lines read): question 2 is answered there
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who plays on the iPad and reads the answers later
- **I want to** have each page added in the log
- **so that** question 2 is answered without my remembering it

#### Acceptance Criteria:
- **Scenario:** A page added
- **Given:** the trial is open
- **When:** a page is added
- **Then:** the log has where the view was and is, the zoom, whether undo survived, and whether a touch was down

---

### User Story 533:

- **Summary:** The log says how far the ring slipped
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified by host tests (`PaperProbeTests`) and the simulator that the lines are written; question 3 needs the iPad's log: `just pull-logs`
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who plays on the iPad and reads the answers later
- **I want to** have each scroll and pinch in the log
- **so that** question 3 is answered without my having to judge it by eye

#### Acceptance Criteria:
- **Scenario:** Scrolling
- **Given:** the trial is open
- **When:** I scroll or pinch
- **Then:** the log has how often the visible area was reported, and how far the ring slipped from its cross

---

### User Story 534:

- **Summary:** The log says whether a far corner works
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [f2ae827](https://github.com/idvorkin/context-grabber/commit/f2ae827); verified on the simulator (`WhiteboardTrialOnPaperUITests`: `stroke_landing`, and `sim-smoke.sh`: `origin`): question 4 is answered there
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with old boards whose ink sits far from the corner
- **I want to** have the log say whether the column can start there
- **so that** I know if the ink has to move

#### Acceptance Criteria:
- **Scenario:** A board far from the corner
- **Given:** a board with ink about 10,000 points from the corner
- **When:** I choose *Ink where it is* in the Trial menu
- **Then:** the log says whether that start was kept and whether the ink is on screen, and the first stroke says whether it landed under the Pencil

---

### User Story 535:

- **Summary:** Always one blank page below the last ink
- **Status:** the page count implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); on a real board since [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (story 603)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing down a board on paper
- **I want to** always have one blank page below my last ink
- **so that** I never run out of room and never have to add a page

#### Acceptance Criteria:
- **Scenario:** Ink reaching a new page
- **Given:** a new board, which is one blank page
- **When:** my ink goes past the end of page 1
- **Then:** the board has three pages, the last of them blank

- **Scenario:** Ink stopping exactly at a page's end
- **Given:** a new board, which is one blank page
- **When:** my ink reaches the end of page 1 and goes no further
- **Then:** the board has two pages, and page 2 still counts as the blank one

---

### User Story 536:

- **Summary:** A mark is on the page that holds it
- **Status:** the page of a point implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); the corner's page number on a real board since [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (story 603); nothing shows Larry a page yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who thinks of a board page by page
- **I want to** have every place on the board belong to one page
- **so that** the page number and what Larry is shown agree with what I see

#### Acceptance Criteria:
- **Scenario:** A mark on the line between pages
- **Given:** a board on paper with two pages or more
- **When:** a mark sits exactly on the line where page 1 ends
- **Then:** that mark counts as on page 2

---

### User Story 537:

- **Summary:** Pages stack edge to edge, and a line marks where each ends
- **Status:** page edges and end lines implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); the page lines on a real board since [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) (story 592); a board wider than a page isn't on any screen yet
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** used to writing on paper
- **I want to** see where each page ends, on pages all the same height
- **so that** a board reads as sheets of paper

#### Acceptance Criteria:
- **Scenario:** A board wider than a page
- **Given:** a board whose ink makes it 2,000 points wide
- **When:** I look at its pages
- **Then:** every page is that wide and still 1,060 tall, touching the next, with a line at each page's end

---

### User Story 538:

- **Summary:** Every page is ruled the same
- **Status:** the line positions implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); the 40-point spacing is provisional until Igor has seen it. Drawn on paper in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`), which shows one page at a time; two pages ruled alike is from `BoardPagesTests`.
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who writes on notebook paper
- **I want to** have the same lines at the same places on every page, thinning when I pinch out
- **so that** the lines guide my writing without crowding the page

#### Acceptance Criteria:
- **Scenario:** Pinching out over ruled pages
- **Given:** a board on paper with ruled lines on
- **When:** I pinch out
- **Then:** only lines that were already there stay, every page's lines stay the same as each other's, and none lands on a page's end

---

### User Story 539:

- **Summary:** Moving onto pages never scales a stroke
- **Status:** the move implemented in [4a04a34](https://github.com/idvorkin/context-grabber/commit/4a04a34); verified by host tests (`BoardPagesTests`); no real board has moved yet: that's a later slice
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with boards from before pages
- **I want to** have my strokes keep their size and their places relative to each other when a board moves onto pages
- **so that** my old drawings are the drawings I made

#### Acceptance Criteria:
- **Scenario:** Ink wider than a page moving onto pages
- **Given:** an old board with ink 2,000 points wide, far from the board's corner
- **When:** it moves onto pages
- **Then:** the ink sits inside the first page's corner at the same size, and the board is wide enough to hold it

---

### User Story 590:

- **Summary:** A switch for new boards on paper
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f), and on by default since [6a96779](https://github.com/idvorkin/context-grabber/commit/6a96779); verified on an iPhone simulator (`WhiteboardOnPaperUITests`: on until turned off)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), [#671](https://github.com/idvorkin/context-grabber/issues/671)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who wants paper
- **I want to** have new boards on paper unless I turn that off from the boards list
- **so that** I get paper without asking, and can go back to the old canvas while paper lacks something

#### Acceptance Criteria:
- **Scenario:** A device that never touched the switch
- **Given:** the boards list
- **When:** I open its menu beside +
- **Then:** *New boards on paper* is on

---

### User Story 591:

- **Summary:** A new board on paper is a column of pages
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: *Page 1 of 1*) and by host tests (`BoardPagesTests`). How it feels under the Pencil is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing down a new board
- **I want to** get a page-wide column with a blank page below my ink and a page number at the corner
- **so that** I never run out of room and always know where I am

#### Acceptance Criteria:
- **Scenario:** A new board
- **Given:** the switch on
- **When:** I tap +
- **Then:** the board fits one page across the screen and reads *Page 1 of 1*

---

### User Story 592:

- **Summary:** Page lines under the ink, and nothing to test with
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified by reading screenshots from an iPhone and an iPad simulator: page lines under the ink, no cross, no ring. Ruled lines are story 434
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at my own notes
- **I want to** see faint page lines under the ink and no test marks
- **so that** the board reads as paper and not as a trial

#### Acceptance Criteria:
- **Scenario:** A board on paper
- **Given:** a board on paper with ink
- **When:** I look at it
- **Then:** a faint line marks each page's end, under the ink, with no small cross and no orange ring

---

### User Story 593:

- **Summary:** A board on paper is kept like any other
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: killed and reopened with the same ink); #1044: every save logs `save_timing`, the time of each stage (encode, write, picture, index) with its trigger, strokes and revision and nothing of the drawing, verified by host tests (`BoardSaveTimingTests`) and the Mac build; the measurement at 100, 1,000 and 5,000 strokes on the iPad is Igor's
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636); [#1044](https://github.com/idvorkin/context-grabber/issues/1044) (bead context-grabber-a99q: what each stage of a save costs on the iPad)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing on a board on paper
- **I want to** have it saved, listed and synced as any board is
- **so that** paper costs me nothing I rely on

#### Acceptance Criteria:
- **Scenario:** Killed after a stroke
- **Given:** a board on paper with a stroke drawn a moment ago
- **When:** the app is killed and opened again
- **Then:** the row says *On paper* and the board opens with that ink

---

### User Story 594:

- **Summary:** Another device looks at a board on paper
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified by host tests only (`BoardIndexTests`: the mark survives the list and the merge, and opens on paper only on its own device). iCloud isn't signed in on the simulator, so the other device's view is for the iPad and iPhone; shown on paper since [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e) (host tests: `BoardIndexTests`)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a board my iPad draws, on my iPhone
- **I want to** see its ink in the look-only view
- **so that** paper doesn't cut a board off from my other device

#### Acceptance Criteria:
- **Scenario:** On the other device
- **Given:** a board on paper drawn on the iPad
- **When:** I open it on the iPhone
- **Then:** the ink shows look-only on paper, on its pages, with no tool picker (the old canvas went 2026-11-07, story 658)

---

### User Story 595:

- **Summary:** The switch never moves a board
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator earlier (`WhiteboardOnPaperUITests`: an old board with the switch on), and now by host tests (`BoardKeepingTests`: a board keeps what it was made as through a relaunch)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with old boards and new ones side by side
- **I want to** have each board stay on the canvas it started on
- **so that** the switch can't cost me a board

#### Acceptance Criteria:
- **Scenario:** An old board, switch on
- **Given:** a board from before, and the switch on
- **When:** I open it
- **Then:** it opens on the old canvas with its ghosts and mic

---

### User Story 596:

- **Summary:** A board on paper opens where I left it
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the place's rule verified by host tests (`BoardPagesTests`); not driven on the simulator, where one finger draws, so coming back to a scrolled place is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** coming back to a long board
- **I want to** land on the page I was on
- **so that** I don't scroll to find my place

#### Acceptance Criteria:
- **Scenario:** Coming back
- **Given:** a board on paper I scrolled down and left
- **When:** I open it on this device
- **Then:** it opens at that place

---

### User Story 597:

- **Summary:** A board on paper keeps its colour
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: Sage chosen, and read off a screenshot)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who gave a board a colour
- **I want to** choose its colour on paper as on the old canvas
- **so that** the page looks the way I chose

#### Acceptance Criteria:
- **Scenario:** Choosing a colour
- **Given:** a board on paper
- **When:** I choose Sage in the Board menu
- **Then:** the paper under the ink turns sage

---

### User Story 598:

- **Summary:** A board on paper says what it can't do yet
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: the bar and the Board menu). The paste button back in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); that it's there is checked on an iPhone simulator (`WhiteboardPaperGhostsUITests`: `testAGhostShowsOnThePaperAndKeepMakesItInk`, named `testAGhostShowsOnThePaperAndATapKeepsIt` before story 825). The Board menu's grid in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** used to the old canvas
- **I want to** not be offered what paper can't do yet
- **so that** nothing looks like it works and then doesn't

#### Acceptance Criteria:
- **Scenario:** The top bar
- **Given:** a board on paper
- **When:** I look at its bar
- **Then:** the Ghosts switch, the mic, *Larry's turn*, *Send to Larry* and the paste button are there

---

### User Story 599:

- **Summary:** A failed save on paper says so, and doesn't vanish
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`, `GRABBER_WHITEBOARD_SAVE_FAILS`: *Copy error* on the board) and by host tests (`BoardKeepingTests`: a full disk fails the save and keeps the last good drawing). A real full disk wasn't tried
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who can't afford to lose notes silently
- **I want to** see a problem I can copy when a save fails
- **so that** I know right then that something isn't kept

#### Acceptance Criteria:
- **Scenario:** While drawing
- **Given:** a board on paper whose save fails
- **When:** a stroke's save runs
- **Then:** the board shows the problem with a *Copy error* button, and I can keep drawing

---

### User Story 600:

- **Summary:** The log tells the Pencil from a finger
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the line verified on the simulator's log for a finger (`whiteboard` action: paper_touch); the Pencil's is for the iPad. This story says only that the log tells them apart, not what a finger does. Since [b0e8221](https://github.com/idvorkin/context-grabber/commit/b0e8221) (#825) a touch is the Pencil's when any touch in it was: verified on the host (`PaperProbeTests`) and the Mac build; the Pencil's line still for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636), [#825](https://github.com/idvorkin/context-grabber/issues/825) (a run was typed by its first touch, so a palm made the Pencil's strokes a finger's)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** deciding what a finger should do on paper
- **I want to** have each touch on a board on paper logged with which it was and what came of it
- **so that** the next try on the iPad settles it without another build

#### Acceptance Criteria:
- **Scenario:** A touch
- **Given:** a board on paper
- **When:** I touch it with the Pencil or a finger
- **Then:** a line says which it was, how far it went, and whether it drew, panned, selected, moved ink or did nothing

---

### User Story 601:

- **Summary:** *Try on paper* stays
- **Status:** removed 2026-11-07 with the trial on paper and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified earlier on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`; `WhiteboardTrialOnPaperUITests` on the iPhone), and now by host tests (`BoardKeepingTests`: a board on paper is offered it, and its copy reads the ink and writes nothing)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** still testing what PaperKit does
- **I want to** open any board this device draws in the trial
- **so that** the switch doesn't take away the place to test with

#### Acceptance Criteria:
- **Scenario:** A board on paper in the trial
- **Given:** a board on paper
- **When:** I long-press its row and choose *Try on paper*
- **Then:** the trial opens a copy with its test marks, and the real board is untouched

---

### User Story 602:

- **Summary:** Turning new boards on paper on
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: turned on, then a new board is on paper). That the switch is still on after a relaunch isn't asserted there
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who turned the switch off on this device
- **I want to** turn the switch back on once
- **so that** every new board here is on paper until I turn it off

#### Acceptance Criteria:
- **Scenario:** Turning it on
- **Given:** the switch off
- **When:** I turn on *New boards on paper* and tap +
- **Then:** the new board is on paper, and the switch stays on when the app opens again

---

### User Story 603:

- **Summary:** The first ink brings the next page
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: *Page 1 of 2*) and by host tests (`BoardPagesTests`)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing down a new board
- **I want to** have a blank page ready below my ink
- **so that** I never stop to make room

#### Acceptance Criteria:
- **Scenario:** The first ink
- **Given:** a new board on paper
- **When:** I draw on it
- **Then:** it reads *Page 1 of 2*, and a blank page is there to scroll to

---

### User Story 604:

- **Summary:** A board on paper closed empty leaves nothing
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator earlier (`WhiteboardOnPaperUITests`: no row left), and now by host tests (`BoardKeepingTests`: a new board of this device's closed without a stroke is dropped, on paper too; one drawn on, renamed or another device's stays)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** opening a new board and changing my mind
- **I want to** leave nothing behind when I go back
- **so that** the list holds only what I drew

#### Acceptance Criteria:
- **Scenario:** Closed without a stroke
- **Given:** a new board on paper with nothing on it
- **When:** I go back
- **Then:** no row is left behind

---

### User Story 605:

- **Summary:** A board on paper is saved in today's format
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the same format by construction, as what's saved is a `PKDrawing`; not run against an older build
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with devices on different builds
- **I want to** have a board on paper saved as every board is
- **so that** an older build can still read it

#### Acceptance Criteria:
- **Scenario:** In today's format
- **Given:** a board on paper with ink
- **When:** an older build reads its file
- **Then:** it opens the same strokes on the old canvas, as the file is what every board's file is

---

### User Story 606:

- **Summary:** A board on paper comes back on paper
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified by host tests only (`BoardIndexTests`: the mark survives the list and the merge). iCloud isn't signed in on the simulator, so the record's new field is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose device lost its list of boards
- **I want to** have a board on paper come back as it was
- **so that** iCloud's copy doesn't land me on the old canvas

#### Acceptance Criteria:
- **Scenario:** Back on the same device
- **Given:** a board on paper whose list this device lost
- **When:** iCloud brings it back
- **Then:** it opens on paper again

---

### User Story 607:

- **Summary:** Turning the switch off leaves paper boards on paper
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator earlier (`WhiteboardOnPaperUITests`: a paper board with the switch off), and now by host tests (`BoardKeepingTests`: a board keeps what it was made as through a relaunch)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who turned the switch off
- **I want to** have the boards already on paper stay there
- **so that** turning it off can't cost me a board

#### Acceptance Criteria:
- **Scenario:** A paper board, switch off
- **Given:** a board on paper, and the switch off
- **When:** I open it
- **Then:** it opens on paper

---

### User Story 608:

- **Summary:** A remembered place past the end of the board
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); the rule verified by host tests (`BoardPagesTests`); not driven on the simulator
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who erased ink from a long board
- **I want to** open at the last page if my place is gone
- **so that** I don't land past the end of the board

#### Acceptance Criteria:
- **Scenario:** Ink erased since
- **Given:** a place further down than the board now reaches
- **When:** I open it
- **Then:** it opens at the last page's top

---

### User Story 609:

- **Summary:** A board on paper in dark mode
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [9af014a](https://github.com/idvorkin/context-grabber/commit/9af014a); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`: the screenshot's pixels hold dark ink on pale paper, and the list is dark again). Dark mode on the iPad itself is still to be seen
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with my device in dark mode
- **I want to** see my ink on a board on paper
- **so that** what I draw never vanishes black on black

#### Acceptance Criteria:
- **Scenario:** In dark mode
- **Given:** a board on paper, and the device in dark mode
- **When:** I draw
- **Then:** the ink shows dark on the colour's pale shade, as dark mode's deep shades aren't on paper yet

---

### User Story 610:

- **Summary:** Send to Larry from a board on paper
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f) and [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); *Send to Larry* is the old canvas's code, its button enabled on paper, and wasn't tapped on paper
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with a board on paper to show Larry
- **I want to** send it as I would any board
- **so that** paper doesn't cut Larry off, even before his marks come back

#### Acceptance Criteria:
- **Scenario:** Larry
- **Given:** a board on paper with ink
- **When:** I tap *Send to Larry*
- **Then:** the whole drawing goes, his reply shows in Chat, and marks he draws in answer come to the board (story 621)

---

### User Story 611:

- **Summary:** Paste wasn't on paper at first
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); ⌘V wasn't run. Ended by [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6): stories 637, 638
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** used to pasting text as ink on the old canvas
- **I want to** have had ⌘V do nothing on paper until paste was built
- **so that** no text lands where it can't be kept as it should

#### Acceptance Criteria:
- **Scenario:** Keys
- **Given:** a board on paper
- **When:** I press ⌘V
- **Then:** this held until stories 637 and 638, which replace it: the text lands

---

### User Story 612:

- **Summary:** A save that fails on leaving shows on the list
- **Status:** implemented in [a2e922f](https://github.com/idvorkin/context-grabber/commit/a2e922f); verified on an iPhone and an iPad simulator (`WhiteboardOnPaperUITests`, `GRABBER_WHITEBOARD_SAVE_FAILS`: *Copy error* on the list after leaving). The problem staying through another failed save or another board's save, and going once that board saves, is verified by host tests (`BoardKeepingTests`). Boards on the old canvas take the same path
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who can't afford to lose notes silently
- **I want to** be told when the ink I just left couldn't be kept
- **so that** the failure doesn't go with the board's screen

#### Acceptance Criteria:
- **Scenario:** On leaving
- **Given:** a board with ink that can't be saved
- **When:** I go back
- **Then:** the boards list shows the problem until that board next saves

---

### User Story 613:

- **Summary:** Ghosts come to a board on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator by every old-canvas turn test run on paper (`WhiteboardTurnOnPaperUITests`, bar the colour's dark mode and the grid), and on an iPad simulator by two of them; and `WhiteboardPaperGhostsUITests` on an iPhone and an iPad simulator, read from the screen's pixels. A real Claude answer is for the iPad. Since bead `context-grabber-y8r` the bar and the turns, the same on either canvas, run once on the old canvas (`WhiteboardTurnUITests`), and what paper shows is `WhiteboardPaperGhostsUITests`'
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing on a board on paper
- **I want to** see the same faint suggestions as on any board when I pause
- **so that** paper doesn't cost me drawing with someone

#### Acceptance Criteria:
- **Scenario:** A pause
- **Given:** a board on paper with Ghosts on
- **When:** I draw a stroke and pause
- **Then:** a faint orange shape appears, and the bar says *1 suggestion: tap one to keep it*

---

### User Story 614:

- **Summary:** A ghost stays on the ink as the board moves
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardPaperGhostsUITests`: pinched in, the ghost's place against the ink read from the pixels; `ghost_slip` was 0 in the log of a run of that pinch at 0.49 to 0.67 zoom). XCUITest's pinch barely moves on an iPad simulator, so that test skips there. How it looks through a fast scroll at 120 Hz is for the iPad: `paper_touch`'s `ghost_slip` and `ghost_checks`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking around a board with suggestions on it
- **I want to** have a ghost stay where it was drawn when I scroll or pinch
- **so that** it never drifts off what it's about

#### Acceptance Criteria:
- **Scenario:** Scroll and pinch
- **Given:** a ghost beside my ink on a board on paper
- **When:** I scroll or pinch
- **Then:** the ghost moves and zooms exactly as the ink does, and doesn't trail behind

---

### User Story 615:

- **Summary:** A tap keeps a ghost on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: orange ink where the ghost was, from the pixels)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a suggestion I like
- **I want to** tap it with a finger and have it become ink
- **so that** keeping it is as easy as on any board

#### Acceptance Criteria:
- **Scenario:** On a ghost
- **Given:** a ghost on a board on paper
- **When:** I tap it
- **Then:** it becomes ink in its author's colour, in the same place, and the stroke count goes up by its strokes

---

### User Story 616:

- **Summary:** A finger doesn't draw while ghosts show on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); verified on an iPhone simulator and an iPad simulator, where a finger draws (`WhiteboardPaperGhostsUITests`, `WhiteboardTurnOnPaperUITests`: no dot, and the next stroke draws). What a finger drag does while ghosts show, with a Pencil paired or not, isn't settled: `paper_touch`'s `touch_mode` is `selection` then. Since bead `context-grabber-y8r`, `WhiteboardPaperGhostsUITests` alone. Since [a117e38](https://github.com/idvorkin/context-grabber/commit/a117e38) a tap off them dismisses Claude's first (stories 663, 664). Since [6754880](https://github.com/idvorkin/context-grabber/commit/6754880) the dot PaperKit still draws under such a tap is taken back by its own undo (story 825; `PaperProbeTests`), verified on an iPad simulator by `WhiteboardPaperGhostsUITests`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing with a finger, on a phone or an iPad with no Pencil
- **I want to** keep or dismiss a ghost with the finger I draw with
- **so that** a tap doesn't leave a dot or select my ink

#### Acceptance Criteria:
- **Scenario:** A tap off them
- **Given:** a finger draws here, and ghosts show
- **When:** I tap away from them
- **Then:** they're dismissed (Larry's only once Claude's are gone, stories 663, 664), no dot is drawn and nothing is selected, and my finger draws again

---

### User Story 617:

- **Summary:** One undo takes a kept mark back
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`, by a hook, `GRABBER_WHITEBOARD_AFTER_KEEP`). The tool picker's own Undo and ⌘Z weren't pressed: a phone's picker has none, and keys reach only a run's first test. PaperKit registers no undo for a markup that's set, so this step is the app's own
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who kept a suggestion and thought again
- **I want to** undo it with one press
- **so that** my eraser and undo treat it as my own ink

#### Acceptance Criteria:
- **Scenario:** Undo
- **Given:** a kept ghost
- **When:** I undo once
- **Then:** it's gone, and my strokes before it stay

---

### User Story 618:

- **Summary:** A kept mark past the last page brings its pages
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the fake's `/far`, *Page 1 of 6*, kept by a hook). A ghost that far down can't be seen until it's kept: the Cockpit has never been seen to answer that far from the ink. Since story 770 the pages a far mark brings are `BoardPagesTests` on the host (`testPagesAddedAsInkReachesThemAndNeverTakenBack`), and the one undo that takes them back is `WhiteboardPaperPasteUITests.testATallPasteBringsItsPagesInOneUndo`, through the same keep
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose suggestion lands below the last page
- **I want to** have the board make room for it
- **so that** kept ink is never out of reach below

#### Acceptance Criteria:
- **Scenario:** Far down
- **Given:** a mark below the last page
- **When:** it's kept
- **Then:** the pages down to it come with it, and a blank one below

---

### User Story 619:

- **Summary:** A kept mark has one name for Larry
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the same two ids at the fake Cockpit before and after closing and opening the board). `paper_keep`'s `same_ids` was true on every keep in both simulators' logs, with `drift` 0: the mark's id is the same before and after PaperKit. A real Cockpit wasn't used. Since story 770, `WhiteboardPaperGhostsUITests.testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`: the same two ids before and after the app is killed and relaunched; the names' rule is `WhiteboardStrokesTests`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** working with Larry on a board that changes
- **I want to** have each stroke keep its name every time it's sent
- **so that** Larry knows what's new and doesn't see the board as redrawn

#### Acceptance Criteria:
- **Scenario:** Kept and sent again
- **Given:** a kept mark on a board on paper, sent to Larry
- **When:** I close and open the board and send it again
- **Then:** every stroke goes under the same name

---

### User Story 620:

- **Summary:** A ghost is never saved on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: killed with a ghost showing, and one stroke after the relaunch). The strokes sent to Larry hold only ink, as story 619's two ids show. Since story 770, one test with story 619's (`testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`): killed with Larry's marks showing, and two strokes after the relaunch
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** leaving a board with a suggestion on it
- **I want to** have only what I drew or kept stay
- **so that** an unkept suggestion never turns into my ink

#### Acceptance Criteria:
- **Scenario:** Left showing
- **Given:** a ghost on a board on paper
- **When:** the app is killed after the save
- **Then:** the board opens with my strokes and no ghost of Claude's

---

### User Story 621:

- **Summary:** Larry's turn from a board on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`: his two marks beside Claude's one, unprompted ones replacing them) and an iPad simulator (the first of those). Where his marks land on real ink is for the iPad, with a real Larry. Since bead `context-grabber-y8r`, Larry's marks on paper are `WhiteboardPaperGhostsUITests`' (`testThePictureIsThePageOnScreen`) and unprompted ones `WhiteboardTurnUITests`', as the bar is the same on either canvas
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** wanting Larry's hand on a board on paper
- **I want to** tap *Larry's turn* and have his marks come back on the board
- **so that** paper doesn't send his answers off to Chat only

#### Acceptance Criteria:
- **Scenario:** His turn
- **Given:** a board on paper with ink
- **When:** I tap *Larry's turn*
- **Then:** his marks arrive by themselves in purple, kept by a tap like Claude's, and his words show in the bar

---

### User Story 622:

- **Summary:** Talk to a board on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the turn verified on an iPhone simulator with the spoken-words hook (`WhiteboardTurnOnPaperUITests`: words on an empty board bring a ghost, and nothing with Ghosts off). The microphone itself, and a call taking it, are for the iPad. Since bead `context-grabber-y8r`, words on an empty board are `WhiteboardTurnUITests`' (the same model on either canvas) and Ghosts off for words is `WhiteboardGhostTurnsTests`, on the host
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** talking while I draw on paper
- **I want to** ask Claude out loud as on any board
- **so that** my voice works whichever canvas a board is on

#### Acceptance Criteria:
- **Scenario:** Words
- **Given:** a board on paper, empty or not
- **When:** I tap the mic and say *draw a circle*
- **Then:** a ghost comes about as soon as on the old canvas, in the part on screen when the board is empty

---

### User Story 623:

- **Summary:** The Pencil holds Claude's pause on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the rule's own tests are the host's (`WhiteboardPacerTests`); a finger stroke's pause verified on the simulators (every ghost test above). The Pencil is only on the iPad: PaperKit tells when drawing begins and not when it ends, so the lift is read from the touch, and `paper_touch`'s `began_drawing` with `whiteboard_turn`'s timing will show it
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** still drawing with the Pencil
- **I want to** not be interrupted by a turn between strokes
- **so that** Claude answers when I stop, as on any board

#### Acceptance Criteria:
- **Scenario:** Touching down
- **Given:** a pause under way
- **When:** the Pencil touches down
- **Then:** the pause stops, and starts over when it lifts

---

### User Story 624:

- **Summary:** A mark past the page's side, for now
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the telling verified by host tests (`BoardPagesTests`); the case not driven on the simulator. The log's `paper_ghosts` says `past_side`. A later step widens the board for these
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** whose suggestion lands past the page's edge
- **I want to** know nothing is lost
- **so that** the board's later widening has all of it

#### Acceptance Criteria:
- **Scenario:** Past the side
- **Given:** a mark past the column's side or above its top
- **When:** it shows
- **Then:** it shows only as far as the column does

---

### User Story 625:

- **Summary:** A ghost lies under the ink on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); seen on simulator screenshots of an iPhone (a ghost beside ink, and zoomed). A ghost crossing ink wasn't shown in a test, and how it looks is for Igor's eye on the iPad. This differs from the old canvas, and it's his to overrule
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** looking at a suggestion across my own writing
- **I want to** see my ink on top of it
- **so that** it can't lag behind the board

#### Acceptance Criteria:
- **Scenario:** Crossing
- **Given:** a ghost crossing my ink on a board on paper
- **When:** I look at it
- **Then:** the ink is on top, and the ghost shows either side of it

---

### User Story 626:

- **Summary:** The log says what ghosts did on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the lines read from the simulators' logs (`paper_ghosts`, `paper_tap`, `paper_keep`, `paper_step`, and `paper_touch`'s `ghost_slip` and `ghost_checks`). What they say on the iPad is to come
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** working out on the iPad what the simulator can't show
- **I want to** have the log say where a ghost sat and what each tap and keep did
- **so that** the next try settles it without another build

#### Acceptance Criteria:
- **Scenario:** A try on the iPad
- **Given:** a board on paper with ghosts
- **When:** I scroll, tap and keep
- **Then:** the log says how far a ghost slipped, what the tap came to, and what the keep did to undo and to the strokes' names

---

### User Story 627:

- **Summary:** Ghosts off asks nothing on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`: `testGhostsOffAsksNothing`); since bead `context-grabber-5eq` the rule is a host test (`WhiteboardGhostTurnsTests`), the same model on paper as on the old canvas; since bead `context-grabber-y8r` no UI case on either canvas
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing alone on a board on paper
- **I want to** turn the suggestions off
- **so that** nothing interrupts me

#### Acceptance Criteria:
- **Scenario:** Ghosts off
- **Given:** a board on paper with Ghosts off
- **When:** I draw and pause
- **Then:** nothing is asked and nothing appears

---

### User Story 628:

- **Summary:** A tap keeps a ghost during a Pencil stroke
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); not verified: a Pencil is only on the iPad, and `paper_tap` will show it
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing with the Pencil in one hand
- **I want to** keep a suggestion with a finger of the other
- **so that** I don't have to stop drawing to keep it

#### Acceptance Criteria:
- **Scenario:** During a stroke
- **Given:** a ghost, and the Pencil drawing
- **When:** I tap the ghost with a finger
- **Then:** it's kept, and the stroke under way goes on

---

### User Story 629:

- **Summary:** A palm doesn't dismiss ghosts on paper
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2) and [e3167f1](https://github.com/idvorkin/context-grabber/commit/e3167f1); not driven on a simulator: a touch the system calls off is for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** resting my hand on the glass
- **I want to** have that touch not count as a tap
- **so that** my palm doesn't throw away the suggestions

#### Acceptance Criteria:
- **Scenario:** A palm
- **Given:** ghosts show
- **When:** the system calls off a touch, as it does a palm
- **Then:** the ghosts stay

---

### User Story 630:

- **Summary:** Redo brings a kept mark back
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: by the same hook as story 617, orange ink back from the pixels)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who undid a kept suggestion and thought again
- **I want to** redo it with one press
- **so that** it comes back as any ink does

#### Acceptance Criteria:
- **Scenario:** Redo
- **Given:** a kept ghost I undid
- **When:** I redo
- **Then:** it's back where it was

---

### User Story 631:

- **Summary:** The undo after a kept mark takes the stroke before it
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: by the same hook as story 617, none of his ink left, from the pixels)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** stepping back through what's on the board
- **I want to** have undo go on past a kept mark to my own strokes
- **so that** the kept mark doesn't stop the steps behind it

#### Acceptance Criteria:
- **Scenario:** Before it
- **Given:** a kept ghost I undid
- **When:** I undo again
- **Then:** the stroke before it goes

---

### User Story 632:

- **Summary:** One undo takes a kept mark and the pages it brought
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator and an iPad simulator (`WhiteboardPaperGhostsUITests`: the fake's `/far`, *Page 1 of 6* then *Page 1 of 2*, by a hook). Since story 770: `BoardPagesTests` for the pages, `WhiteboardPaperPasteUITests.testATallPasteBringsItsPagesInOneUndo` for the one undo, through the same keep (story 618)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who kept a suggestion far down the board
- **I want to** undo it and its pages together
- **so that** no empty pages are left behind

#### Acceptance Criteria:
- **Scenario:** With its page
- **Given:** a kept mark that brought pages
- **When:** I undo once
- **Then:** the mark and those pages both go

---

### User Story 633:

- **Summary:** Larry's marks come back when a board on paper opens
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); verified on an iPhone simulator (`WhiteboardTurnOnPaperUITests`: the newest set on reopening, a dismissed set staying gone). Since bead `context-grabber-y8r`, `WhiteboardTurnUITests` on the old canvas (the same marks on either) and `WhiteboardMarksTests` on the host; since story 770 the newest set coming back on reopening is `WhiteboardMarksTests` alone, and the UI test keeps a dismissed set staying gone
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** coming back to a board Larry drew on
- **I want to** find his newest marks where they were
- **so that** closing a board doesn't cost me his answer, and what I dismissed stays dismissed

#### Acceptance Criteria:
- **Scenario:** Reopened
- **Given:** his marks showing
- **When:** I close and open the board
- **Then:** his newest set is there, and a set I dismissed stays gone

---

### User Story 634:

- **Summary:** Drawing during a turn on paper brings another after the next pause
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the rule's own tests are the host's (`WhiteboardPacerTests`). With the Pencil on paper it's for the iPad
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** still drawing while Claude answers
- **I want to** be answered about what I added too
- **so that** a turn under way doesn't swallow my new strokes

#### Acceptance Criteria:
- **Scenario:** During a turn
- **Given:** a turn on its way
- **When:** I draw and lift
- **Then:** a new turn comes after the next pause

---

### User Story 635:

- **Summary:** A kept mark past the page's side is saved and sent
- **Status:** implemented in [24280a2](https://github.com/idvorkin/context-grabber/commit/24280a2); the case not driven on the simulator. A later step widens the board for these
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** keeping a suggestion that runs past the page's edge
- **I want to** have all of it kept, not just what shows
- **so that** the board's later widening has all of it

#### Acceptance Criteria:
- **Scenario:** Kept past the side
- **Given:** a mark past the column's side or above its top, that I can reach
- **When:** I keep it
- **Then:** it's saved and sent like any ink, and what's past the column is out of reach on paper

---

### User Story 636:

- **Summary:** An undo doesn't outlive its board
- **Status:** implemented with the review fixes of #636, on paper and on the old canvas; built only, not driven on a simulator. Which undo stack a board has is for the iPad: `paper_keep`'s `undo_on_window` and `paper_undo_closed`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** going from one board to the next
- **I want to** have Undo on the new board never reach back
- **so that** a board I closed can't lose a kept mark without my seeing

#### Acceptance Criteria:
- **Scenario:** The next board
- **Given:** a mark kept on a board, which I then closed
- **When:** I open another board and press Undo
- **Then:** the closed board keeps that mark

---

### User Story 637:

- **Summary:** Paste text onto a board on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator through `GRABBER_WHITEBOARD_PASTE` (`WhiteboardPaperPasteUITests`: the letters read from the screen's pixels, across the middle; `WhiteboardPasteOnPaperUITests`: each line, the cap, the emoji note, Claude's pause). The bar's button itself is for the iPad, as XCUITest's taps never reach it. The iPad simulator wasn't run. Since bead `context-grabber-y8r`, each line, the cap and the note are `WhiteboardPasteTests`, on the host, and the pause and the emoji note `WhiteboardPasteUITests`, on the old canvas
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** writing on a board on paper
- **I want to** paste text as ink, as on any board
- **so that** paper doesn't cost me what I could already do

#### Acceptance Criteria:
- **Scenario:** The bar
- **Given:** a board on paper and text on the clipboard
- **When:** I tap Paste
- **Then:** the letters land as ink in the middle of the paper on screen, and the stroke count goes up

---

### User Story 638:

- **Summary:** ⌘V on a board on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`test1CommandVOnPaperAndCommandZ`: text after a stroke, read from the log as `paper_paste` how: key, went: ink; since bead `context-grabber-y8r`, `WhiteboardPasteUITests.testCommandVPastesAndCommandZTakesItBackOnBothCanvases`, after the old canvas's in the same launch; since 2026-11-07 `testCommandVPastesAndCommandZTakesItBack`, on paper only). A real keyboard on the iPad is to try, with text and a picture copied from another app, to see whether *Allow Paste?* shows: story 390 says it doesn't, this key reads the clipboard itself, and `paper_paste` can't show a prompt
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with a keyboard on a board on paper
- **I want to** press ⌘V and have the text land
- **so that** my hands don't leave the keys

#### Acceptance Criteria:
- **Scenario:** Keys
- **Given:** a board on paper and text on the clipboard
- **When:** I press ⌘V
- **Then:** the text lands as it does from the button

---

### User Story 639:

- **Summary:** One undo takes a paste back on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator: one ⌘Z (`test1CommandVOnPaperAndCommandZ`, since bead `context-grabber-y8r` `testCommandVPastesAndCommandZTakesItBackOnBothCanvases`, since 2026-11-07 `testCommandVPastesAndCommandZTakesItBack`), and an undo by a hook on a tall paste (`testATallPasteBringsItsPagesInOneUndo`). The tool picker's own Undo is for the iPad, as a phone's has none
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who pasted the wrong thing
- **I want to** undo it in one press
- **so that** a paste of many strokes is one thing to take back

#### Acceptance Criteria:
- **Scenario:** Undo
- **Given:** a paste on a board with my strokes on it
- **When:** I undo once
- **Then:** the whole paste goes, and my strokes stay

---

### User Story 640:

- **Summary:** A paste brings the pages it needs
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); the pages and their one undo verified on an iPhone simulator (`testATallPasteBringsItsPagesInOneUndo`: 40 lines, *Page 1 of 4*, and *Page 1 of 1* after the undo)
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** pasting something long
- **I want to** have the board make room
- **so that** a long paste doesn't run off the last page

#### Acceptance Criteria:
- **Scenario:** Tall
- **Given:** a paste taller than the pages left
- **When:** it lands
- **Then:** the pages it needs come with it, with a blank one below

---

### User Story 641:

- **Summary:** Copied strokes paste on a board on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator with hooks (`testCopiedStrokesPaste`: PaperKit's own clipboard format, *landed_here*), and the middle of the view by host tests (`BoardPagesTests`). A real lasso Copy can't be worked on the simulator, and nothing took the system's Copy there, so what a real copy puts on the clipboard, and whether PaperKit pastes it itself, is for the iPad: `paper_paste`'s `types` and `went`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** moving ink around with the lasso
- **I want to** paste the strokes I copied with ⌘V
- **so that** pasting text doesn't cost me pasting ink

#### Acceptance Criteria:
- **Scenario:** Copied strokes
- **Given:** strokes on the clipboard and no text
- **When:** I press ⌘V
- **Then:** they land as ink at their own size, in the middle of the paper on screen unless PaperKit places them itself

---

### User Story 642:

- **Summary:** A paste stays on the page
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified by host tests (`WhiteboardPasteTests`: a view by the right edge, above the first page); on an iPhone simulator only as far as a short paste across the middle
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** pasting while zoomed in by a page's edge
- **I want to** have nothing land past the side
- **so that** I never paste where paper can't show it

#### Acceptance Criteria:
- **Scenario:** By the edge
- **Given:** a view near a page's side
- **When:** I paste
- **Then:** the text is wholly on the page

---

### User Story 643:

- **Summary:** Larry knows a paste by the same names
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`testAPastesStrokesKeepTheirNamesForLarry`: the same two ids at the fake Cockpit before and after a relaunch; `paper_keep`'s `same_ids` true and `drift` 0). That the letters are in the picture is the old canvas's code, on the same drawing, and wasn't looked at. A real Cockpit wasn't used. Since story 770 the names through a relaunch are `WhiteboardPaperGhostsUITests.testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`, through the keep and the save a paste shares, and the names' rule `WhiteboardStrokesTests`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** working with Larry on a board with pasted text
- **I want to** have him see the letters as ink, the same every time
- **so that** he knows what's new

#### Acceptance Criteria:
- **Scenario:** Sent again
- **Given:** a paste on a board on paper, sent to Larry
- **When:** I close and open the board and send it again
- **Then:** every letter's stroke goes under the same name, and the letters are in the picture, dark on white

---

### User Story 644:

- **Summary:** A picture on the clipboard isn't pasted on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator through a hook (`testAPictureIsNotPasted`: `went`: refused_picture, no red on the screen's pixels, the count unchanged). Pasting images remains a non-goal on every board
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with a picture on the clipboard from somewhere else
- **I want to** have ⌘V leave the board alone
- **so that** nothing lands that would vanish when I leave, as only strokes are saved

#### Acceptance Criteria:
- **Scenario:** A picture
- **Given:** a picture on the clipboard and no text or strokes
- **When:** I press ⌘V
- **Then:** the board doesn't change

---

### User Story 645:

- **Summary:** A phone's one page takes a paste
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator (`testAPasteLandsInTheMiddleOfThePaperOnScreen`: the letters read from the screen's pixels, across the middle). The test doesn't measure up and down, so `paper_keep`'s `ink`, `visible` and `sheet` are what say where they landed
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** on a phone
- **I want to** paste on a new board and see the text
- **so that** a page shorter than the screen doesn't lose it in the margin

#### Acceptance Criteria:
- **Scenario:** A phone's one page
- **Given:** a new board on paper on a phone, its page shorter than the screen
- **When:** I paste
- **Then:** the text is on the paper, not in the margin around it

---

### User Story 646:

- **Summary:** Redo brings a paste back on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified on an iPhone simulator by a hook's press on a tall paste (`testATallPasteBringsItsPagesInOneUndo`: the strokes and the pages back). The tool picker's own Redo is for the iPad, as a phone's has none
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who undid a paste too soon
- **I want to** redo it in one press
- **so that** I get the whole paste back, not a part of it

#### Acceptance Criteria:
- **Scenario:** Redo
- **Given:** a paste I undid
- **When:** I redo
- **Then:** the whole paste is back

---

### User Story 647:

- **Summary:** A paste lands far down the board
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified by host tests only (`WhiteboardPasteTests`: page 29), as the simulator's test wasn't taken that far down
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** many pages down a board on paper
- **I want to** paste where I'm looking
- **so that** the old canvas's edge doesn't send it somewhere else

#### Acceptance Criteria:
- **Scenario:** Far down
- **Given:** a view past where the old canvas ended
- **When:** I paste
- **Then:** the text is in the middle of that view

---

### User Story 648:

- **Summary:** Text wins over copied strokes on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); built only, not driven on a simulator: no test puts text and strokes on the clipboard together. Whether a real copy ever holds both is for the iPad: `paper_paste`'s `types` and `went`
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** with text and strokes both on the clipboard
- **I want to** have ⌘V do one thing I can predict
- **so that** a paste never lands twice

#### Acceptance Criteria:
- **Scenario:** Text wins
- **Given:** strokes and text on the clipboard
- **When:** I press ⌘V
- **Then:** the text lands

---

### User Story 649:

- **Summary:** A wide line wraps on paper
- **Status:** implemented in [ce10bd6](https://github.com/idvorkin/context-grabber/commit/ce10bd6); verified by host tests (`WhiteboardPasteTests`: long text stays on the page's width on paper, and a long line wraps inside the view by the same layout). Not on a simulator
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** pasting a long line while zoomed in
- **I want to** have it wrap
- **so that** I can read all of it without scrolling sideways

#### Acceptance Criteria:
- **Scenario:** Wide
- **Given:** a line wider than the part of the page on screen
- **When:** I paste
- **Then:** it wraps

---

### User Story 650:

- **Summary:** Ink the app adds always shows
- **Status:** implemented in [869cb8d](https://github.com/idvorkin/context-grabber/commit/869cb8d); the simulator only, iPhone 17, iOS 27: pasted ink missing from the screen in 15 of 180 runs before the fix, 0 of 60 after it (`testAPasteLandsInTheMiddleOfThePaperOnScreen`, read from `paper_ink_look`). The wait for the view to come to rest came after those counts, in [a86ac93](https://github.com/idvorkin/context-grabber/commit/a86ac93). A centred page skipped the redraw in [97bbdbe](https://github.com/idvorkin/context-grabber/commit/97bbdbe), verified on an iPad Pro 11-inch simulator (`testAGhostLeftShowingIsNotSaved`: crashed before, passes after; since story 770 part of `testKeptInkKeepsItsNamesAndAGhostLeftShowingIsNotSaved`). Since [62c7672](https://github.com/idvorkin/context-grabber/commit/62c7672) a centred page redraws by moving a point down and back, never setting the zoom (`paper_redraw_nudge` says `how: frame`), verified on an iPad Pro 11-inch simulator: `testAPasteLandsInTheMiddleOfThePaperOnScreen` missed 1 of 8 before, drew 24 of 24 after, no crash. Since [c4b3dc1](https://github.com/idvorkin/context-grabber/commit/c4b3dc1) a look that finds the ink missing redraws and looks again (#906), verified on an iPad Pro 11-inch (M5) simulator: `testAPasteLandsInTheMiddleOfThePaperOnScreen` alone 20 of 20, every paste drawn on the first look, so the heal itself is not yet seen working (40 of 40 on main before it: the 1 in 6 of 2026-11-14 no longer shows alone). Whether it happens on a real iPad, and whether the small redraw can be felt there, is still to be seen.
- **Issues:** [#636](https://github.com/idvorkin/context-grabber/issues/636); [#829](https://github.com/idvorkin/context-grabber/issues/829): on an iPad, where the page is narrower than the screen and PaperKit centres it, the redraw's zoom recursed inside PaperKit until the app crashed; a centred page skipped it; [#833](https://github.com/idvorkin/context-grabber/issues/833): with the redraw skipped, a centred iPad page missed kept or pasted ink again (1 of 8 pastes, and 2 kept marks in a ladder run); a centred page now moves a point down and back instead, which never sets the zoom: 24 of 24 pastes drawn on an iPad Pro 11-inch simulator (`testAPasteLandsInTheMiddleOfThePaperOnScreen`, `paper_ink_look`), no crash; [#906](https://github.com/idvorkin/context-grabber/issues/906): the same test still found no letters on screen about 1 run in 6 on that simulator (2026-11-14), and a missed tile the one redraw left empty stayed empty, since the look that measured it only wrote it down. Now a look that finds the ink missing in view redraws and looks again, twice at most, each time moving the view a little further (`paper_ink_heal`, then the next `paper_ink_look` with its attempt).
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** keeping a ghost or pasting text on a board on paper
- **I want to** see the ink as soon as it's there
- **so that** nothing the board counts and saves is invisible to me

#### Acceptance Criteria:
- **Scenario:** Added ink shows
- **Given:** a board on paper
- **When:** I keep a ghost, paste text, or undo or redo one of those
- **Then:** the ink is on the screen within half a second, and the view stays where it is

---

### User Story 651:

- **Summary:** Turning new boards on paper off
- **Status:** removed 2026-11-07 with the *New boards on paper* switch and the old canvas (Igor: "Old canvas can be erased"), in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e). Before: implemented in [6a96779](https://github.com/idvorkin/context-grabber/commit/6a96779); verified on an iPhone simulator (`WhiteboardOnPaperUITests`: turned off and back on from the menu) and by host tests (`BoardKeepingTests`: on until it's turned off, the launch hook, and a board made with it off stays on the old canvas through a relaunch). That the store's `UserDefaults` keeps it across a relaunch is no longer driven on the simulator; every launch hook relies on the same write and read
- **Issues:** [#671](https://github.com/idvorkin/context-grabber/issues/671)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** who needs the old canvas while paper lacks something
- **I want to** turn the switch off once
- **so that** every new board here is on the old canvas until I turn it back on

#### Acceptance Criteria:
- **Scenario:** Turning it off
- **Given:** I turned *New boards on paper* off
- **When:** I open the app again and tap +
- **Then:** the new board is on the old canvas

### User Story 652:

- **Summary:** A grid on a board on paper
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`, `testTheGridShowsWhenAskedAndStaysWithItsBoard`, an old-canvas test dropped 2026-11-07; host `BoardPagesTests`; feel on a big board is the iPad's)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608), [#678](https://github.com/idvorkin/context-grabber/issues/678)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** thinking on paper
- **I want to** turn on faint grid lines under my ink
- **so that** I can line things up without the lines competing with the ink

#### Acceptance Criteria:
- **Scenario:** The grid
- **Given:** a board on paper
- **When:** I choose *Grid lines* in the Board menu
- **Then:** faint squares lie under the ink, run on unbroken from page to page, and thin when pinched out

### User Story 653:

- **Summary:** Lines stay with their board on paper
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesStayWithTheBoardUnderTheInk`, `testTheGridShowsWhenAskedAndStaysWithItsBoard`, the latter an old-canvas test dropped 2026-11-07); a new board starting with the grid, not none, in [c0e22ba](https://github.com/idvorkin/context-grabber/commit/c0e22ba) (story 410, #915), verified by host tests (`BoardLinesTests`)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608), [#915](https://github.com/idvorkin/context-grabber/issues/915)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** going back to a board
- **I want to** find its lines as I left them
- **so that** each board keeps its own look

#### Acceptance Criteria:
- **Scenario:** Reopening
- **Given:** a board on paper with ruled lines on
- **When:** I leave it and open it again
- **Then:** the lines are on. A new board starts with the grid, not ruled lines (story 410)

### User Story 654:

- **Summary:** Lines are never ink
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testRuledLinesAndTheGridAreOneChoiceAndNeverInk`, the stroke count; that they can't be erased or lassoed follows from their not being in the drawing, and hasn't been driven with those tools)
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing over lines
- **I want to** have them left out of everything that is the drawing
- **so that** what I save and send is only what I drew

#### Acceptance Criteria:
- **Scenario:** Lines on
- **Given:** a board on paper with a stroke
- **When:** I turn lines on or off
- **Then:** the stroke count stays the same, nothing is added to undo, and they're not in the saved drawing, the card or any picture

### User Story 655:

- **Summary:** Lines and ghosts show on every colour
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testEveryColourShowsItsLinesAndKeepsTheInk` for the grid on all five, `testAGhostShowsOnTheDarkestColours` for a ghost on Grey; `testABoardsColourShowsInBothModesAndStaysWithIt` for the colour, an old-canvas test dropped 2026-11-07; on paper `testRuledLinesStayWithTheBoardUnderTheInk` keeps a board's colour); since bead `context-grabber-y8r` the grid on Lilac, the darkest, and Plain stand for all five (the lines are one grey on every colour); since story 770 Lilac alone, the grid on Plain being `testRuledLinesAndTheGridAreOneChoiceAndNeverInk`
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** choosing a colour on paper
- **I want to** still see the page lines, the grid and ghosts
- **so that** a colour never hides what I need

#### Acceptance Criteria:
- **Scenario:** Each colour
- **Given:** a board on paper
- **When:** I choose any of the five colours
- **Then:** its pale shade shows, even with the device in dark mode, and the lines and ghosts show on it

### User Story 656:

- **Summary:** Changing colour or lines leaves the ink
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testEveryColourShowsItsLinesAndKeepsTheInk`; `paper_ink_look` after each change); since bead `context-grabber-y8r` on Lilac and Plain; since story 770 on Lilac alone
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** changing how the paper looks
- **I want to** have the ink stay on screen
- **so that** nothing I drew seems to vanish

#### Acceptance Criteria:
- **Scenario:** A change under ink
- **Given:** ink on screen on a board on paper
- **When:** I change the colour or the lines
- **Then:** the ink stays where it was and the view doesn't move

### User Story 657:

- **Summary:** The Board menu never costs a stroke
- **Status:** implemented in [bc0f653](https://github.com/idvorkin/context-grabber/commit/bc0f653); verified on an iPhone 17 simulator (`testTheFirstStrokeAfterTheMenuDraws`, 5 of 5 after the fix, and before it the stroke was lost 5 of 5). Choosing the colour already chosen takes the same path; its test, `testTheFirstStrokeAfterChoosingTheSameColourDraws`, hasn't been run on a simulator yet; since bead `context-grabber-y8r` the first two cases share one launch, and since [e234dc6](https://github.com/idvorkin/context-grabber/commit/e234dc6) the same-colour case has its own again, on a fresh board choosing Plain (chained after the others, the menu tap missed the colour row); verified on the simulator (the whole whiteboard suite, 0 failures). Since [efab29b9](https://github.com/idvorkin/context-grabber/commit/efab29b9) (#880) a Board-menu row whose tap the on-screen keyboard's rise cancelled is tapped again; verified on the iPad Pro 11-inch (M5) simulator, `WhiteboardPaperLinesUITests` four times with no retry, 28 of 28 (the second tap was needed 3 times, each a miss before), against 13 of 14 before it
- **Issues:** [#635](https://github.com/idvorkin/context-grabber/issues/635), [#608](https://github.com/idvorkin/context-grabber/issues/608), [#880](https://github.com/idvorkin/context-grabber/issues/880) (the menu's UI tests flaky on the iPad simulator: opening the Board menu raises the on-screen keyboard there, and a row tapped as it rises is cancelled, so `WhiteboardPaperLinesUITests` taps the row again while the menu is still up)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md)

#### Use Case:
- **As someone** drawing right after the menu
- **I want to** have my first stroke draw
- **so that** I don't lose a mark to a menu

#### Acceptance Criteria:
- **Scenario:** After the menu
- **Given:** a board on paper
- **When:** I close the Board menu, with a choice or without one, and draw
- **Then:** the stroke draws

### User Story 698:

- **Summary:** Claude's and Larry's marks look the way they ask, and labels read as writing
- **Status:** implemented in [bb3f487](https://github.com/idvorkin/context-grabber/commit/bb3f487); verified on the host (`WhiteboardTurnTests`, 22 of 22, five new). Letters written in single strokes, not traced, in [ca0aa8a](https://github.com/idvorkin/context-grabber/commit/ca0aa8a) (#895, story 1049), verified on the host and the Mac build. Not yet seen on a device
- **Issues:** [#698](https://github.com/idvorkin/context-grabber/issues/698)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** drawing with Larry on the board
- **I want to** see his marks at the width, colour and lettering he chose, with labels in a thin pen
- **so that** what he writes reads like writing and his diagram says what he meant, not a bold marker

#### Acceptance Criteria:
- **Scenario:** A mark that asks for its look
- **Given:** a board with a thread, and Larry answers with a box in green at a fine pen and a label in the hand face
- **and Given:** another label of his that names no pen, colour or face
- **When:** his marks arrive and I keep them
- **Then:** the box is a green outline at the fine pen, the first label is in joined handwriting letters, the second is in his purple print at a thin pen, both written in single strokes rather than traced (story 1049), not bold (since story 1003, at the pen in my hand once the board knows it; never thinner than the iPad draws, story 772, so small letters read bolder), and each kept mark is ink exactly as its ghost showed

### User Story 1003:

- **Summary:** Larry's kept text is at the width of the pen in my hand
- **Status:** implemented in [1df5eda4](https://github.com/idvorkin/context-grabber/commit/1df5eda4); verified on the host (`WhiteboardTurnTests.testALabelTakesThePenInIgorsHand`; `just test`), the Mac build and the simulator smoke (`just native-test-sim`); the iPad whiteboard UI tests didn't start (the Mac's screen was locked); not yet seen on the iPad
- **Issues:** [#949](https://github.com/idvorkin/context-grabber/issues/949)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** writing on a board beside Larry's labels
- **I want to** have a label of his that names no pen drawn at the width of the pen I'm holding
- **so that** his text and mine read at one weight, not his thinner or bolder than my writing

#### Acceptance Criteria:
- **Scenario:** A label with no pen of its own
- **Given:** a board where I last held a pen of some width, then picked up the eraser
- **When:** Larry's label that names no pen shows, and I keep it
- **Then:** its ghost and its kept ink are at that pen's width (never thinner than the iPad draws, never wider than the widest pen), whatever its letters' size, and the eraser is still in my hand

---

### User Story 774:

- **Summary:** Larry's marks are his own colour, and keeping one leaves my pen alone
- **Status:** implemented in [4aee299](https://github.com/idvorkin/context-grabber/commit/4aee299), PR [#891](https://github.com/idvorkin/context-grabber/pull/891), the paper colours held to his purple in [e4efeae](https://github.com/idvorkin/context-grabber/commit/e4efeae); verified on the host (`just native-test`: `WhiteboardTurnTests.testLarrysColourIsNoneOfThePickersOrClaudes`, `BoardPaperTests.testLarrysPurpleInkReadsOnEveryColour` and `testGhostsAreNearlyAsVisibleAsOnPlain` with his purple) and the Mac build (`just native-build-mac`). That a keep leaves the pen as it was lives in the paper view, with no host test: it is logged (`paper_keep` tool_before, tool_after, tool_restored) and put back if it ever changed. Not yet seen on the simulator or a device
- **Issues:** bead context-grabber-a3w
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Larry's own colour*

#### Use Case:
- **As someone** writing back to Larry on a board in the picker's blue
- **I want to** see his marks in a colour I can't pick
- **so that** I can tell his writing from mine, and so can he

#### Acceptance Criteria:
- **Scenario:** His colour
- **Given:** a board, and Larry answers with marks that name no colour
- **When:** they arrive and I keep one
- **Then:** the ghost and the kept ink are purple, a colour none of the picker's swatches has

---

### User Story 778:

- **Summary:** Keeping one of Larry's marks leaves my pen alone
- **Status:** implemented in [4aee299](https://github.com/idvorkin/context-grabber/commit/4aee299), PR [#891](https://github.com/idvorkin/context-grabber/pull/891); split from story 774. Verified by the Mac build (`just native-build-mac`) only: it lives in the paper view, with no host test, and is logged (`paper_keep` tool_before, tool_after, tool_restored) and put back if it ever changed. Not yet seen on the simulator or a device
- **Issues:** bead context-grabber-a3w
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Larry's own colour*

#### Use Case:
- **As someone** writing back to Larry on a board in the picker's blue
- **I want to** keep one of his marks without my pen changing
- **so that** my next stroke is still mine, in the colour and width I chose

#### Acceptance Criteria:
- **Scenario:** My pen after a keep
- **Given:** I'm writing with the picker's blue pen at its width
- **When:** I tap one of Larry's ghosts to keep it and write again
- **Then:** my next stroke is the same blue pen at the same width as before the keep

---

### User Story 772:

- **Summary:** A kept label of small letters stays on the board
- **Status:** implemented in [b54599d](https://github.com/idvorkin/context-grabber/commit/b54599d), the floor at 2.5 points in [b18aa04](https://github.com/idvorkin/context-grabber/commit/b18aa04); verified on the host (`just native-test`: `WhiteboardTurnTests.testNoMarkIsThinnerThanTheIPadDraws`, a small label's pen, a thin asked-for pen and an unasked line, and the rest of `WhiteboardTurnTests`) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** keeping a label Larry wrote on my board
- **I want to** see it stay as ink where its ghost was
- **so that** a tap that keeps his words never looks like a tap that threw them away

#### Acceptance Criteria:
- **Scenario:** Small letters
- **Given:** a board on paper, and a label of Larry's with 12-point letters and no pen of its own
- **When:** I tap it to keep it
- **Then:** it stays on the board as purple ink, as thick as its ghost was, and the next picture Larry gets shows it

---

### User Story 779:

- **Summary:** A mark that asks for a pen too thin to draw is drawn at the thinnest the iPad shows
- **Status:** implemented in [b54599d](https://github.com/idvorkin/context-grabber/commit/b54599d), the floor at 2.5 points in [b18aa04](https://github.com/idvorkin/context-grabber/commit/b18aa04); split from story 772. Verified on the host (`just native-test`: `WhiteboardTurnTests.testNoMarkIsThinnerThanTheIPadDraws`, a thin asked-for pen) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*

#### Use Case:
- **As someone** keeping a fine line Larry drew on my board
- **I want to** see it stay as ink, as its ghost showed it
- **so that** a mark that asked for a hairline never vanishes when I keep it

#### Acceptance Criteria:
- **Scenario:** A pen too thin to draw
- **Given:** a mark that asks for a pen thinner than the iPad draws
- **When:** it arrives and I keep it
- **Then:** its ghost and its ink are both drawn at the thinnest pen the iPad shows, never vanishing once kept

---

### User Story 771:

- **Summary:** Larry can read the board's log without my exporting it
- **Status:** implemented in [dfc284d](https://github.com/idvorkin/context-grabber/commit/dfc284d), the header record naming the build in [973d927](https://github.com/idvorkin/context-grabber/commit/973d927); verified on the host (`just native-test`: `WhiteboardLogArchiveTests`, which lines are the board's, batches oldest first, the newest kept when the ring is full, a header and one record a line the archive keeps once, within 8 KB) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad: no turn has yet landed rows in the Cockpit's archive
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Larry can read what the board did*

#### Use Case:
- **As someone** telling Larry that something on the board went wrong
- **I want to** have him already hold what the board did
- **so that** he can find the cause without my pulling logs off the iPad

#### Acceptance Criteria:
- **Scenario:** A turn carries the log
- **Given:** a board on the iPad, and I tapped a ghost to keep it
- **When:** I give Larry his turn
- **Then:** the board's log lines since the last turn, the keep among them, are in the Cockpit's archive, and the board behaves as before

---

### User Story 800:

- **Summary:** Log lines the Cockpit missed go with the next picture
- **Status:** implemented in [dfc284d](https://github.com/idvorkin/context-grabber/commit/dfc284d); split from story 771. Verified on the host (`just native-test`: `WhiteboardLogArchiveTests`, batches oldest first, the newest kept when the ring is full, one record a line the archive keeps once) and by the Mac build (`just native-build-mac`). Not yet seen on the simulator or the iPad
- **Issues:** [#883](https://github.com/idvorkin/context-grabber/issues/883)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Larry can read what the board did*

#### Use Case:
- **As someone** telling Larry that something on the board went wrong, on a patchy connection
- **I want to** have the board's log reach him whole even when one sending fails
- **so that** he never reads a log with a hole in it, or the same lines twice

#### Acceptance Criteria:
- **Scenario:** The Cockpit misses one
- **Given:** a turn whose log didn't reach the Cockpit
- **When:** the next picture goes to Larry
- **Then:** the lines that missed go with it, none lost and none twice

---

### User Story 658:

- **Summary:** A board drawn on the old canvas opens to look at, on paper
- **Status:** implemented in [71bba7e](https://github.com/idvorkin/context-grabber/commit/71bba7e); verified by host tests (`BoardIndexTests`: only a board made on paper, on its own device, is drawn on; the bar's words for each look-only board; `BoardKeepingTests`: through a relaunch; `BoardPagesTests`: the ink moved, never scaled) and on the simulator (`WhiteboardOnPaperUITests.testAnOldCanvasBoardOpensLookOnlyOnPaper`, on an iPad Pro 11-inch simulator too since [#845](https://github.com/idvorkin/context-grabber/issues/845): it searches for the old ink from under the navigation bar and drags right to left, as a swipe right is Back; `paper_ink_look` why `open` counted the ink drawn in 6 of 6 opens; the smoke's `paper_open`). Igor's own old boards on the iPad not yet seen. Since story 770 the simulator's check is the smoke's `paper_open` (look-only, 40 strokes at the first page's corner); the UI test was a duplicate of it and of `BoardIndexTests`
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Paper is the only canvas*

#### Use Case:
- **As someone** whose early boards were drawn before paper
- **I want to** open one and see its ink on paper, where every board now lives
- **so that** the old canvas can go without taking my old sketches with it

#### Acceptance Criteria:
- **Scenario:** An old board, after the old canvas is gone
- **Given:** a board I drew on the old canvas, on this device
- **and Given:** the app has only paper
- **When:** I open it
- **Then:** its ink shows on the first page, every stroke where it was relative to the others and none scaled, the bar says *Drawn on the old canvas: look only*, and there are no tools, no Board menu and no Send, so nothing draws on it or changes its file

---

### User Story 659:

- **Summary:** I pick who answers a board's pause: Haiku, Sonnet or the real Larry
- **Status:** implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (`WhiteboardResponderTests`: the read and the write on the wire, the tick while they are on their way, a failed write taking it back, who answered from a stream or a whole answer, when a Larry board's pause goes to his thread) and the Linux cross-builds of ContextCore. [0a91f6e](https://github.com/idvorkin/context-grabber/commit/0a91f6e) moved the choice into a *Responder: Sonnet*-style submenu of the Board menu (#848); verified on the iPad simulator (`WhiteboardPaperLinesUITests` 6/6: the Board menu closes on a pick of colour or lines). The Cockpit's live knob and a Larry board's hand-off not yet seen on the Mac or the iPad; the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`)
- **Issues:** [#848](https://github.com/idvorkin/context-grabber/issues/848) (the section made the iPad's Board menu too tall to close on a pick; now a submenu)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing with a model beside me
- **I want to** choose per board whether Haiku, Sonnet or the real Larry answers when I pause
- **so that** I can feel the difference between a fast ghost, a sharper one and Larry himself, and keep the one that suits the board

#### Acceptance Criteria:
- **Scenario:** The board's own choice
- **Given:** a board I draw on, which nobody has set
- **When:** I open its Board menu
- **Then:** its Responder row says Larry (story 960) and opens on Haiku, Sonnet and Larry with Larry ticked, and when I pick Haiku the tick moves at once and the board has Haiku when I reopen it, here and on my other devices

- **Scenario:** A Larry board
- **Given:** a board whose responder is Larry, with Ghosts on
- **When:** I draw and pause
- **Then:** no orange ghosts come; the bar's note begins with Larry's clock (*Larry · 0:00*, story 667), the picture is in the board's chat thread, and his purple marks show when he answers

- **Scenario:** The Cockpit can't take the choice
- **Given:** the Cockpit can't be reached
- **When:** I pick another responder
- **Then:** the tick goes back to the one the Cockpit last said and a copyable problem says why

---

### User Story 960:

- **Summary:** Larry answers every board I haven't set otherwise
- **Issues:** Igor on his board, 2026-11-17: "Let's make Larry default responder"
- **Status:** implemented in [436837c](https://github.com/idvorkin/context-grabber/commit/436837c); verified on the host (`WhiteboardResponderTests`: Larry ticked until the Cockpit says) and the Mac build. A new board's Responder on the live Cockpit not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing to talk with Larry
- **I want to** have Larry answer my boards without picking him on each one
- **so that** the board is a conversation with him from the first stroke, and Sonnet answers only where I chose it

#### Acceptance Criteria:
- **Scenario:** A new board
- **Given:** a board I just made
- **When:** it opens
- **Then:** its Responder is Larry, here and on my other devices

---

### User Story 962:

- **Summary:** An old board nobody set is given to Larry when I open it
- **Issues:** Igor on his board, 2026-11-17: "Let's make Larry default responder"
- **Status:** implemented in [436837c](https://github.com/idvorkin/context-grabber/commit/436837c); verified on the host (`WhiteboardResponderTests`: a never-set board given to Larry) and the Mac build. The write on open not yet seen against the live Cockpit or on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing to talk with Larry
- **I want to** have Larry answer my boards without picking him on each one
- **so that** the board is a conversation with him from the first stroke, and Sonnet answers only where I chose it

#### Acceptance Criteria:
- **Scenario:** An old board nobody set
- **Given:** a board from before, whose responder was never set
- **When:** I open it
- **Then:** its Responder becomes Larry, and the session log says it was the default

---

### User Story 963:

- **Summary:** A board I set keeps the responder I chose
- **Issues:** Igor on his board, 2026-11-17: "Let's make Larry default responder"
- **Status:** implemented in [436837c](https://github.com/idvorkin/context-grabber/commit/436837c); verified on the host (`WhiteboardResponderTests`: a set board kept, a Cockpit that doesn't say `set` counts as set) and the Mac build
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing to talk with Larry
- **I want to** have Larry answer my boards without picking him on each one
- **so that** the board is a conversation with him from the first stroke, and Sonnet answers only where I chose it

#### Acceptance Criteria:
- **Scenario:** A board I set
- **Given:** a board I set to Sonnet
- **When:** I open it
- **Then:** it stays Sonnet

---

### User Story 961:

- **Summary:** Larry's change applies though I wrote on since he looked
- **Issues:** Larry, 2026-11-17: his make-room ops came back stale (rev 257 on 11/16, rev 111 today) because Igor wrote a stroke or two before they arrived
- **Status:** implemented in [905337c](https://github.com/idvorkin/context-grabber/commit/905337c); verified on the host (`BoardOpsTests`: new strokes since don't stop a push and it says `rebased_from`, only changes after the look count, a rebased push moves the strokes below now) and the Mac build; on the iPad simulator, merged with main at 2510b8c6 (`WhiteboardPaperGhostsUITests` rung 2: `testAPushFromAnOlderLookStillApplies` passes)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** writing on while Larry thinks
- **I want to** have his make-room still happen when my new strokes don't get in its way
- **so that** I don't have to stop writing for his changes to land

#### Acceptance Criteria:
- **Scenario:** I wrote a stroke after he looked
- **Given:** Larry looked at the board, and I drew two new strokes since
- **When:** his make room arrives
- **Then:** everything below its line now moves down, my new strokes included, one Undo, and his next turn says it applied on a newer board than the one he saw

---

### User Story 964:

- **Summary:** Larry's change from an older look is refused when it names what I moved or erased
- **Issues:** Larry, 2026-11-17: his make-room ops came back stale (rev 257 on 11/16, rev 111 today) because Igor wrote a stroke or two before they arrived
- **Status:** implemented in [905337c](https://github.com/idvorkin/context-grabber/commit/905337c); verified on the host (`BoardOpsTests`: a named stroke Igor moved is stale with `conflict_ids`, a named group or kept text whose stroke Igor moved is stale too, every name an op uses is checked) and the Mac build; on the iPad simulator, merged with main at 2510b8c6 (`WhiteboardPaperGhostsUITests` rung 2: `testAStalePushMovesNothingAndLarryIsTold` passes)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** writing on while Larry thinks
- **I want to** have his make-room still happen when my new strokes don't get in its way
- **so that** I don't have to stop writing for his changes to land

#### Acceptance Criteria:
- **Scenario:** I moved what he names
- **Given:** Larry looked, and I since moved one of the strokes his change names, or a stroke of a group or kept text it names
- **When:** it arrives
- **Then:** nothing moves, and his next turn says it was stale and which of his names I had moved or erased

---

### User Story 965:

- **Summary:** Larry's change from too far back is refused as stale
- **Issues:** Larry, 2026-11-17: his make-room ops came back stale (rev 257 on 11/16, rev 111 today) because Igor wrote a stroke or two before they arrived
- **Status:** implemented in [905337c](https://github.com/idvorkin/context-grabber/commit/905337c); verified on the host (`BoardOpsTests`: too old or after Larry's own change is stale, the memory's limit) and the Mac build
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** writing on while Larry thinks
- **I want to** have his make-room still happen when my new strokes don't get in its way
- **so that** I don't have to stop writing for his changes to land

#### Acceptance Criteria:
- **Scenario:** He is too far behind
- **Given:** Larry's change was made on a board older than the board remembers, or before the app restarted
- **When:** it arrives
- **Then:** it is refused as stale, as before

---

### User Story 660:

- **Summary:** Claude is asked half a second after I lift the Pencil, not a second
- **Status:** superseded by story 892 (the wait follows my rhythm, 1.5 to 5 s); was implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (`WhiteboardResponderTests.testThePauseIsHalfASecond`; the pause's own rules unchanged in `WhiteboardPacerTests`). The feel on the iPad not yet tried
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Ghosts from Claude*

#### Use Case:
- **As someone** drawing with Claude
- **I want to** see ghosts sooner after I stop
- **so that** it feels like drawing together, not waiting for a turn

#### Acceptance Criteria:
- **Scenario:** A shorter pause
- **Given:** Ghosts are on
- **When:** I draw a circle and lift the Pencil
- **Then:** the turn is asked half a second later (the session log's `pause_ms` is about 500), and the Pencil going back down before then still holds it

---

### User Story 661:

- **Summary:** Every ghost turn says how long the iPad's half took
- **Status:** implemented in [10ee878](https://github.com/idvorkin/context-grabber/commit/10ee878); verified on the host (`WhiteboardResponderTests`: the milliseconds, what goes to the Cockpit and what only the log has, the request carrying the board and the timings). The upload time comes from URLSession's own report, seen only on a device
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** deciding which model draws the ghosts
- **I want to** see where the wait goes: the pause, the picture, the upload, the model
- **so that** the choice rests on measurements, not guesses

#### Acceptance Criteria:
- **Scenario:** A measured turn
- **Given:** Ghosts are on
- **When:** I draw, pause, and a ghost turn goes
- **Then:** its session-log line has `pause_ms`, `render_ms`, `encode_ms` and `upload_ms` beside who answered, and the Cockpit's log of that turn has the pause, render and encode times

---

### User Story 662:

- **Summary:** A Larry board sends him one picture at a time, the newest
- **Issues:** the stale-push UI test, 2026-11-17: on a board's first turn, which opens its thread, an answer that landed before the board first looked was taken as already there, so the note kept *Larry has been looking* and never said it. Every row on a thread the turn opened is his answer; fixed in [3d91a5d](https://github.com/idvorkin/context-grabber/commit/3d91a5d), verified by host tests (`WhiteboardMarksTests`) and on the simulator (`testAStalePushMovesNothingAndLarryIsTold`, rung 2)
- **Status:** implemented in [41b83fb](https://github.com/idvorkin/context-grabber/commit/41b83fb); verified on the host (`WhiteboardLarryTurnTests`: a pause while idle sends, a pause while he is looking doesn't, his answer with the board moved on sends once and with nothing new sends nothing, the 3-minute timeout, a tap taking over what was waiting, words carried, a failed picture freeing the turn). Not yet seen on the iPad or against the real Larry; a tap while he is looking with nothing new sending nothing (story 765) in [61761b8](https://github.com/idvorkin/context-grabber/commit/61761b8), verified by host tests (`WhiteboardLarryTurnTests`); the bar's note beginning with Larry's clock where it said *Larry is looking…* in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205) (story 667), verified by host tests (`WhiteboardLarryClockTests`); Larry closing a turn with nothing to say (#913) is stories 811–813
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** keep drawing and talking while he looks, without each pause sending him another picture
- **so that** his thread holds one picture per answer, always the newest board, and nothing I said is lost

#### Acceptance Criteria:
- **Scenario:** Pauses while he is looking
- **Given:** a Larry board, a picture sent and no answer from him yet
- **When:** I draw and pause several times, and say "and label it"
- **Then:** the bar's note begins with Larry's clock (*Larry · 0:00*, story 667) and no new picture goes; when he answers, exactly one picture of the board as it is then goes, with "and label it" as its message

- **Scenario:** Nothing new since
- **Given:** a Larry board, a picture sent, and no pause since
- **When:** he answers
- **Then:** nothing more goes and the bar stops saying he is looking

- **Scenario:** He doesn't answer
- **Given:** a Larry board, a picture sent, and pauses since
- **When:** 3 minutes pass with no answer from him
- **Then:** one fresh picture goes, and the session log says the turn ended by timeout

- **Scenario:** I don't wait
- **Given:** he is looking and the board has moved on
- **When:** I tap *Larry's turn*
- **Then:** a picture of the board goes at once with any words that waited, and his answer to the earlier one sends nothing more; with nothing new since his picture went, the tap sends nothing (story 765)

---

### User Story 811:

- **Summary:** Larry closing the turn with nothing to add ends it
- **Status:** implemented in [462676e](https://github.com/idvorkin/context-grabber/commit/462676e); verified by host tests (`WhiteboardLarryTurnTests`, `WhiteboardLarryWaitTests`, `WhiteboardLarryClockTests`: done with nothing new sends nothing and says *Larry: nothing to add yet*, done with the board moved on sends one picture); not yet seen on the simulator or the iPad
- **Issues:** [#913](https://github.com/idvorkin/context-grabber/issues/913) (Larry marked the picture done with no reply, and the bar sat at *Larry · 0:54*)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see his turn end when he marks my picture done and has nothing to say
- **so that** the board never sits on his clock waiting for an answer that isn't coming

#### Acceptance Criteria:
- **Scenario:** He closes the turn with nothing to add
- **Given:** a Larry board, a picture sent and the bar showing Larry's clock
- **When:** Larry marks the picture done on the thread and writes no reply after it
- **Then:** the clock stops and the bar's note says *Larry: nothing to add yet* until the next turn starts; if I drew or spoke since the picture went, exactly one fresh picture goes, else nothing; the session log says the turn ended as done with no reply

---

### User Story 812:

- **Summary:** A reply after Larry closed the turn sends nothing more
- **Status:** implemented in [462676e](https://github.com/idvorkin/context-grabber/commit/462676e); verified by host tests (`WhiteboardLarryTurnTests`: a late reply sends nothing more); not yet seen on the simulator or the iPad
- **Issues:** [#913](https://github.com/idvorkin/context-grabber/issues/913) (Larry marked the picture done with no reply, and the bar sat at *Larry · 0:54*)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** have a reply he writes after closing the turn not send the board again
- **so that** his thread never gets the same board twice

#### Acceptance Criteria:
- **Scenario:** His reply comes after he closed the turn
- **Given:** Larry marked the picture done with no reply, and the turn ended
- **When:** a reply of his lands on the thread afterwards
- **Then:** no further picture goes for a board that hasn't moved on since

---

### User Story 813:

- **Summary:** Larry having the picture keeps his turn out
- **Status:** implemented in [462676e](https://github.com/idvorkin/context-grabber/commit/462676e); verified by host tests (`WhiteboardLarryWaitTests`: received and seen keep the turn out); not yet seen on the simulator or the iPad
- **Issues:** [#913](https://github.com/idvorkin/context-grabber/issues/913) (Larry marked the picture done with no reply, and the bar sat at *Larry · 0:54*)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Who answers the pause*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** have his turn stay out while he has the picture but hasn't finished
- **so that** a picture he is still working on isn't treated as answered

#### Acceptance Criteria:
- **Scenario:** He has the picture but hasn't finished
- **Given:** a Larry board and a picture sent
- **When:** the thread says the Cockpit received it, or Larry has picked it up, and nothing more
- **Then:** the clock keeps running and no picture goes

---

### User Story 746:

- **Summary:** On an iPhone, boards are for looking, not drawing
- **Status:** implemented in [df438e6](https://github.com/idvorkin/context-grabber/commit/df438e6), [d053c9a](https://github.com/idvorkin/context-grabber/commit/d053c9a); verified by host tests (`BoardIndexTests`), `PhoneBoardsUITests` on the iPhone simulator, and the whiteboard classes on the iPad simulator (`just test-ladder`). Since story 770 the iPhone simulator's check is the smoke's whiteboard section, from the session log: the list's `new_board` false, and its own board on paper opening with `editable` false and `look_only` *Look only on iPhone: draw on the iPad*; *Send to Larry* still being there on a phone is no longer checked by a test
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *On an iPhone every board is look-only*

#### Use Case:
- **As Igor,** on my iPhone, where a finger on a small screen is too hard to draw with ("we can't do hand drawing")
- **I want to** open any board to look at what was drawn, with nothing offering to draw
- **so that** the phone shows the boards without pretending to be a drawing surface, and the drawing happens on the iPad

#### Acceptance Criteria:
- **Scenario:** Opening the boards on an iPhone
- **Given:** an iPhone whose list holds a board it drew earlier and a board drawn on the iPad
- **and Given:** the list has no *+ New board*
- **When:** I open either board
- **Then:** it opens to pan and pinch with no tool picker, no Board menu and no ghosts, *Send to Larry* still there to talk about it, and the bar says *Look only on iPhone: draw on the iPad*

### User Story 667:

- **Summary:** See how long Larry has been looking
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: the clock counts from the picture, shows the true time after the app was away, stops at his answer, and VoiceOver's words) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see that he is working and for how long
- **so that** I can tell a slow answer from a broken one without stopping to wonder

#### Acceptance Criteria:
- **Scenario:** The clock counts while he looks
- **Given:** a Larry board and a picture just sent
- **When:** I keep drawing for forty-two seconds
- **Then:** the bar's note begins *Larry · 0:42*, and it goes when his answer arrives

---

### User Story 668:

- **Summary:** Larry's clock times the picture he is looking at now
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: a newer picture restarts the clock) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** have the clock start again when a newer picture goes
- **so that** it never counts a picture he is no longer answering

#### Acceptance Criteria:
- **Scenario:** A newer picture
- **Given:** Larry has been looking for twenty seconds
- **When:** I tap *Larry's turn* with new ink
- **Then:** the clock goes back to 0:00

---

### User Story 669:

- **Summary:** A wait that ended without an answer says so
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: his silence carries when the picture went, the wait, what was waiting and whether the Cockpit was answering; `WhiteboardLarryTurnTests`: the 3-minute timeout) and the Mac build (`just native-build-mac`); the problem on the bar not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** be told when the board has stopped waiting for him, with the state that explains it
- **so that** I can hand the evidence over instead of guessing whether he was slow or gone

#### Acceptance Criteria:
- **Scenario:** He doesn't answer
- **Given:** a picture sent and no answer
- **When:** three minutes pass
- **Then:** the bar shows *Larry didn't answer* as a problem I can copy, naming when the picture went, how long the board waited, what was waiting and whether the Cockpit was answering

---

### User Story 760:

- **Summary:** Slow and unreachable never look the same
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: the Cockpit not answering is said and the clock keeps counting) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see when the board can't reach the Cockpit while he is looking
- **so that** I know the wait is the connection's and not his

#### Acceptance Criteria:
- **Scenario:** The Cockpit can't be reached
- **Given:** Larry is looking
- **When:** the board's looks at his thread keep failing
- **Then:** the state adds *Cockpit not answering* and keeps counting, the bar's separate *Larry's marks: the Cockpit isn't answering* note stays away while the clock says it, and the state clears itself when the Cockpit answers

---

### User Story 761:

- **Summary:** Dismiss *Larry didn't answer*
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by the Mac build (`just native-build-mac`) and, for the launch hook that shortens the wait and dismisses it (`GRABBER_WHITEBOARD_LARRY_TIMEOUT`), host tests (`LaunchHooksTests`, `WhiteboardLarryTurnTests`: a shorter timeout); the button not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** put his silence away once I have read it
- **so that** the bar goes back to the board

#### Acceptance Criteria:
- **Scenario:** I dismiss it
- **Given:** the bar shows *Larry didn't answer*
- **When:** I tap *Dismiss* beside it
- **Then:** the problem goes, and the session log says it was dismissed

---

### User Story 762:

- **Summary:** *Larry didn't answer* stays until he next answers
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** keep seeing that he went quiet, even once the board has moved on to the next picture
- **so that** a silence I didn't notice at the time is still there when I look up

#### Acceptance Criteria:
- **Scenario:** The waiting ink goes and the problem stays
- **Given:** the bar shows *Larry didn't answer*
- **and Given:** ink was waiting, so a fresh picture went and a new clock started
- **When:** his answer to that picture arrives
- **Then:** the problem was there for the whole of that wait, and goes only now, with his clock

---

### User Story 763:

- **Summary:** The board shows one problem at a time
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** see only the newest thing that went wrong
- **so that** the bar never stacks problems over the drawing

#### Acceptance Criteria:
- **Scenario:** A later failure
- **Given:** the bar shows *Larry didn't answer*
- **When:** a later picture can't be handed to him
- **Then:** that failure's problem takes the place of *Larry didn't answer*, with no *Dismiss* beside it

---

### User Story 764:

- **Summary:** Larry's clock shows on any board his turn is out
- **Status:** implemented in [4f92205](https://github.com/idvorkin/context-grabber/commit/4f92205); verified by host tests (`WhiteboardLarryClockTests`: the clock runs from a tapped turn, whoever answers the board's pauses) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md)

#### Use Case:
- **As someone** drawing on a board Haiku or Sonnet answers
- **I want to** see Larry's clock after I hand him a turn myself
- **so that** his slow answer is timed there too, while the fast responders' pauses start no clock

#### Acceptance Criteria:
- **Scenario:** A manual turn on a Haiku or Sonnet board
- **Given:** a board whose pauses Haiku or Sonnet answers, and a pause that started no clock
- **When:** I tap *Larry's turn*
- **Then:** the bar's note begins *Larry · 0:00* and counts until he answers

---

### User Story 765:

- **Summary:** A repeat tap doesn't send Larry the same picture again
- **Status:** implemented in [61761b8](https://github.com/idvorkin/context-grabber/commit/61761b8); verified by host tests (`WhiteboardLarryTurnTests`: a repeat tap with nothing new sends nothing, a pause that sent counts too, a stroke, waiting words or another part of the board on screen send, with no turn out a tap always sends, a failed picture lets the same board go again; `WhiteboardLarryClockTests.testARepeatTapIsAnsweredForTwoSeconds`; `just native-test`) and the Mac build (`just native-build-mac`). The whiteboard's UI classes passed on the iPad simulator with it in (`just test-ladder`, at 98878ae), though none of them makes a repeat tap. Another part of the board on screen sending was added after that run and is verified on the host only. Not yet seen on the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) (seven identical pictures in twelve seconds)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *A repeat tap sends nothing*

#### Use Case:
- **As someone** waiting on Larry and not sure my tap took
- **I want to** be told he already has the picture
- **so that** his thread isn't filled with copies and I know the tap was heard

#### Acceptance Criteria:
- **Scenario:** Nothing new since the picture
- **Given:** Larry is looking at a picture, I have drawn and said nothing since, and the same part of the board is on screen
- **When:** I tap *Larry's turn* or *Send to Larry*
- **Then:** no picture goes, and the note says *Larry already has this* with the clock for two seconds; had I drawn a stroke, said something or scrolled to another page, a fresh picture would go at once and the clock restart

---

### User Story 766:

- **Summary:** The board's note is one line that opens into the conversation
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea), its line kept while empty in [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6) (the iPad simulator: `WhiteboardPaperGhostsUITests`' push and stale-push tests measured the ink 24 points lower once his state showed, and pass with it); verified by host tests (`WhiteboardNoteTests`: the line's state with *next:*, the middle and which end it keeps, a message giving the middle back after five seconds and one about the Cockpit not answering keeping it, *3 to keep*; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder` at 98878ae: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply` with the whiteboard's other UI classes). The Cockpit-not-answering messages keeping the middle was added after that run and is verified on the host only. Not yet seen on the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation"); [#882](https://github.com/idvorkin/context-grabber/issues/882) (the panel's live rows were drawn over each other)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** drawing and talking with Larry on a board
- **I want to** glance at one line for where things stand and open it to read what was said
- **so that** his reply and my own words aren't cut off, and reading them doesn't take me off the board

#### Acceptance Criteria:
- **Scenario:** One line
- **Given:** Larry's long reply and a long line from the mic
- **When:** I look at the note
- **Then:** it is one line: his state first, the newest words after it, and the paper hasn't moved

- **Scenario:** The note first speaks
- **Given:** a board just opened, its note saying nothing yet, with ink on it
- **When:** I ask Larry and his state shows in the note
- **Then:** the ink stays exactly where it was on screen

---

### User Story 767:

- **Summary:** The note says what goes to Larry next
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea); verified by host tests (`WhiteboardNoteTests`: *next: ink*, *next: words* and *next: ink + words*, and the panel's chip with the waiting words, which took the *Next* row's place in #1003; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** drawing and talking while Larry is still looking
- **I want to** see what is waiting to go to him when he answers
- **so that** I know my new ink and words weren't lost and needn't tap to send them

#### Acceptance Criteria:
- **Scenario:** What is waiting
- **Given:** Larry is looking
- **When:** I draw and speak
- **Then:** the note's state says *next: ink + words*

---

### User Story 768:

- **Summary:** A tap on the note opens the conversation above the board
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea), [128a18c](https://github.com/idvorkin/context-grabber/commit/128a18c); the live rows one under another (#882) in [98878ae](https://github.com/idvorkin/context-grabber/commit/98878ae); verified by host tests (`WhiteboardNoteTests`: the tap on an iPad, the last ten messages with their marks, what is live, a board with no thread; `just native-test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder` at 98878ae: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply` with the whiteboard's other UI classes). Not yet seen on the iPad: the Pencil on and below the panel is the iPad's check. Above the board, pushing the page down: [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129) (#1003, story 1048); #1039 moved the note's strip, the problem row with Retry and Dismiss, the panel and its scrolling text to their own file with no change in behaviour, verified by the host tests, the Mac build and the simulator smoke's whiteboard section (the iPhone's look-only boards; 2026-11-21); the iPad simulator's whiteboard classes wait on the Mac's screen unlocking
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation"); [#882](https://github.com/idvorkin/context-grabber/issues/882) (the panel's live rows were drawn over each other); [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the panel covered ink); [#1039](https://github.com/idvorkin/context-grabber/issues/1039) (bead context-grabber-gsfm: the strip, the panel and its text moved out of the drawing screen's file, so changes to one stop overlapping the other)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** drawing and talking with Larry on a board
- **I want to** open the note and read what was said in full
- **so that** his reply and my own words aren't cut off, and reading them doesn't take me off the board

#### Acceptance Criteria:
- **Scenario:** Open it
- **Given:** a board with a thread, on an iPad
- **When:** I tap the line with a finger
- **Then:** a panel above the board shows the last messages of the thread in full and, under them, the status chip (story 1047); the page moves down to make room so no ink is under it (story 1048, #1003; until then it lay over the board), and the Pencil still draws below it

---

### User Story 1048:

- **Summary:** The open conversation pushes the page down and never covers ink
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by host tests (`WhiteboardNoteTests`; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder`: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply`: the paper's ? button below the open panel and moving back up when it closes, with the whiteboard's other UI classes). Not yet seen on the iPad
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** drawing with Larry on an iPad, with ink at the top of the page
- **I want to** open the conversation and still see every line I wrote
- **so that** reading Larry never hides what I am talking about

#### Acceptance Criteria:
- **Scenario:** Open it over ink
- **Given:** a board with ink on its top line and a thread, on an iPad
- **When:** I tap the note's line
- **Then:** the panel opens above the paper and the page moves down by its height, the top line of ink just under the panel and none of it under it; I tap again and the page moves back up

---

### User Story 1047:

- **Summary:** Igor's turns are one status chip, in one vocabulary
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by host tests (`WhiteboardNoteTests`; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (`just test-ladder`: `WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply`: no row for a wordless picture and the chip *Your board · Sent*). Not yet seen on the iPad
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading Larry's replies in the open conversation
- **I want to** see his sentences one after another and one place that says where my picture is
- **so that** the panel is the conversation, not a log of *Your turn on the board · done* rows in four different words

#### Acceptance Criteria:
- **Scenario:** Three wordless turns
- **Given:** a thread of three pictures I sent without words, each answered by Larry
- **When:** I open the conversation
- **Then:** it shows Larry's three replies one after another with no *You: Your turn on the board* row, and under them one chip, *Your board · Answered*; while a turn is out the chip says what the closed line says, *Your board · Larry · 0:12 · next: ink*; a picture that went with my spoken words shows as a row of those words

---

### User Story 1053:

- **Summary:** Larry's words lead, and every line can be read
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by host tests (`WhiteboardNoteTests`: Larry's line marked for emphasis; `just test`) and a screenshot on the iPad simulator (`WhiteboardTurnUITests`, Larry's words in the main colour). The contrast figures are from the colour values, not measured on the iPad
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** glancing at the note and the open conversation while I draw
- **I want to** have Larry's words stand out and the quieter text still be readable
- **so that** the grey status text at about 2:1 no longer strains my eyes and his reply is what I see first

#### Acceptance Criteria:
- **Scenario:** Read the note
- **Given:** Larry has replied and the conversation is open
- **When:** I look at the note and the panel
- **Then:** Larry's words are in the main text colour, in the closed line and in the panel; my lines, his state and the chip are quieter but at least 4.5:1 against what is behind them

---

### User Story 1045:

- **Summary:** The conversation's lines are about seventy characters
- **Status:** implemented in [60c8129](https://github.com/idvorkin/context-grabber/commit/60c8129); verified by the Mac build and the iPad simulator run (`WhiteboardTurnUITests`); a reply long enough to wrap at seventy characters is for the iPad's eye
- **Issues:** [#1003](https://github.com/idvorkin/context-grabber/issues/1003) (the banner covered Igor's top line of ink and was mostly *You: Your turn on the board · done* rows; iPad screenshots 2026-11-20)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading a long reply of Larry's on an iPad
- **I want to** have it wrap like a paragraph, not run across the whole board
- **so that** I can read it at a glance

#### Acceptance Criteria:
- **Scenario:** A long reply on a wide iPad
- **Given:** Larry's reply of several sentences and the iPad in landscape
- **When:** I open the conversation
- **Then:** his reply wraps at about seventy characters, the panel's background still spanning the width

---

### User Story 837:

- **Summary:** The conversation panel keeps its size and scrolls, newest in view
- **Status:** implemented in [e403844](https://github.com/idvorkin/context-grabber/commit/e403844); verified by host tests (`WhiteboardNoteTests.testThePanelIsAFifthOfTheBoardAtMost`; `just test`), the Mac build (`just native-build-mac`) and an iPad simulator (`WhiteboardTurnUITests.testTheNoteOpensOnLarrysReply`: the panel's height, with the class's other tests); scrolling to the newest line with a long thread is for the iPad's eye
- **Issues:** [#917](https://github.com/idvorkin/context-grabber/issues/917) ("when chat expands it needs to scroll not grow"), seen in [#913](https://github.com/idvorkin/context-grabber/issues/913)'s screenshot, the panel over nearly half the page
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** talking with Larry on a board while I draw
- **I want to** keep the conversation panel small however long the conversation gets, with the newest words showing
- **so that** reading what he said never covers the page I'm drawing on

#### Acceptance Criteria:
- **Scenario:** A long conversation
- **Given:** a board whose thread has more messages than the panel holds, on an iPad
- **When:** I tap the note's line to open the panel
- **Then:** the panel is no taller than a fifth of the board, its newest line is in view at the bottom, and a finger scrolls up to the older ones

---

### User Story 887:

- **Summary:** Another reply scrolls the full panel, not grows it
- **Status:** implemented in [e403844](https://github.com/idvorkin/context-grabber/commit/e403844) (story 837, #917); verified by host tests (`WhiteboardNoteTests.testThePanelIsAFifthOfTheBoardAtMost`; `just test`); a reply landing in a full panel is for the iPad's eye
- **Issues:** [#917](https://github.com/idvorkin/context-grabber/issues/917)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** with the conversation panel open while Larry talks (story 837)
- **I want to** see each new answer without the panel growing
- **so that** the page I'm drawing on stays where it was

#### Acceptance Criteria:
- **Scenario:** Another reply
- **Given:** the panel is open and full
- **When:** Larry answers again
- **Then:** the panel stays the same height and scrolls to show his answer

---

### User Story 1001:

- **Summary:** Larry's words with no marks stay in the note and the panel, off the board
- **Status:** already true on main (only a reply's marks become ghosts, only its board changes are applied); pinned in [c8cc50d](https://github.com/idvorkin/context-grabber/commit/c8cc50d), verified by host tests (`WhiteboardWordsOnlyTests`: `testWordsAfterMarksAreSaidAndTheMarksStay`, `testOpeningOnWordsAfterSettledMarksShowsNothing`, `testTheReplayLeavesTheBoardAsItWas`; `just test`); not yet seen on the iPad
- **Issues:** [#898](https://github.com/idvorkin/context-grabber/issues/898) (asked 2026-11-12 on [#879](https://github.com/idvorkin/context-grabber/issues/879); Larry's bead `context-grabber-0q7`)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Closed: one line*

#### Use Case:
- **As someone** drawing with Larry on a board
- **I want to** have his words-only replies read as words, in the note and the panel
- **so that** the board holds only what was drawn on it, mine or the marks he means to draw

#### Acceptance Criteria:
- **Scenario:** Words after marks
- **Given:** Larry's marks from his last reply showing on the board
- **When:** he replies in words only
- **Then:** his words are the note's line and the newest message in the panel, nothing new is on the board or offered to keep, and his earlier marks are where they were

---

### User Story 1002:

- **Summary:** A board whose thread holds only Larry's words draws nothing of his
- **Status:** already true on main; split from story 1001, pinned in [c8cc50d](https://github.com/idvorkin/context-grabber/commit/c8cc50d), verified by host tests (`WhiteboardWordsOnlyTests.testAThreadOfOnlyWordsDrawsNothing`, which also opens the board on that thread and finds nothing drawn; `just test`); not yet seen on the iPad
- **Issues:** [#898](https://github.com/idvorkin/context-grabber/issues/898)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Closed: one line*

#### Use Case:
- **As someone** drawing with Larry on a board
- **I want to** have his answer in words read as words, even when he has never drawn on the board
- **so that** the board holds only what was drawn on it

#### Acceptance Criteria:
- **Scenario:** Only words
- **Given:** a board whose thread holds only Larry's words
- **When:** he answers my picture in words
- **Then:** nothing of his is on the board, and the panel shows what he said

---

### User Story 1046:

- **Summary:** Larry's marks on a picture with a folded section land where he drew them
- **Status:** implemented in [a043ea5c](https://github.com/idvorkin/context-grabber/commit/a043ea5c) (#1013); verified by host tests (`BoardFoldPictureTests`); `just test` and the Mac build (`just native-build-mac`); the iPad simulator (rung 2, `WhiteboardOutlineUITests.testLarrysPictureShowsAFoldedSectionWholeAndShaded`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** [#1013](https://github.com/idvorkin/context-grabber/issues/1013)

#### Use Case:
- **As someone** whose folded board Larry marks up
- **I want** his marks to land on my folded board by the ink he drew them on in his picture
- **so that** a picture showing my folded lines in full never puts his marks in the wrong place

#### Acceptance Criteria:
- **Scenario:** A mark below a folded section
- **Given:** a header folded over four lines, a line of writing below the section, and Larry's picture showing the section whole
- **When:** Larry circles that line of writing on the picture
- **Then:** his circle shows around the same line on my folded board, not four lines below it; a mark he draws on the folded lines shows just under their header

---

### User Story 1049:

- **Summary:** Larry's labels read as plain written letters, not traced outlines
- **Status:** implemented in [ca0aa8a](https://github.com/idvorkin/context-grabber/commit/ca0aa8a); verified on the host (`just test`: `BoardLetteringTests`, the written glyphs, curly punctuation, an outline kept for a character the letters lack, a label's room and baseline, reword's measure; `WhiteboardTurnTests` and `BoardMarksReplayTests`) and by the Mac build (`just native-build-mac`). UI tests and the iPad not yet: the Mac's screen was locked
- **Issues:** [#895](https://github.com/idvorkin/context-grabber/issues/895)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *How a mark looks*, *Letters are written, not traced*

#### Use Case:
- **As someone** reading what Larry wrote on my board
- **I want to** see his labels as plain letters, one pen stroke wide, like print
- **so that** his words read at a glance instead of as hollow, traced shapes that fill in when small

#### Acceptance Criteria:
- **Scenario:** A small label, kept
- **Given:** a board on paper, and a label of Larry's in print with 13-point letters, "It’s Tori — hi…"
- **When:** it shows as a ghost and I tap Keep
- **Then:** its letters are single strokes, open and legible at the thinnest pen, the quote, dash and dots written as plain ' - ..., and the kept ink is the same strokes in his purple

---

### User Story 1056:

- **Summary:** I can letter a board's text in a real font, still as ink
- **Status:** implemented in [d4f7faaa](https://github.com/idvorkin/context-grabber/commit/d4f7faaa), [9d963efd](https://github.com/idvorkin/context-grabber/commit/9d963efd), [133e7124](https://github.com/idvorkin/context-grabber/commit/133e7124) and [c8bcc70f](https://github.com/idvorkin/context-grabber/commit/c8bcc70f); verified on the host (`just test`: `BoardRealFontTests`, the per-board choice, a mark's and Larry's lettering, a kept text's lettering through a save, the strokes sent to the Cockpit unchanged, H as one closed outline, baseline and height, paste layout and wrap, reword) and the Mac build (`just native-build-mac`); on the iPad simulator, rung 2, 2026-11-20 (`WhiteboardLetteringUITests`: HI four strokes on a new board, Real font on with no redraw, reopened still on, HI again as two outlines, a new board single strokes). The iPad not yet
- **Issues:** [#950](https://github.com/idvorkin/context-grabber/issues/950): Igor, 2026-11-18, "Why not have the app render a real font?"; 2026-11-20 (W3 on #912's decision page), "a real font as a per-board or per-text option, still drawn as ink"
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A real font, still drawn as ink*; [the paste spec](../superpowers/specs/2026-11-02-whiteboard-paste-design.md)

#### Use Case:
- **As someone** who wants a board's typed words to look typeset rather than written
- **I want to** choose a real font for that board's lettering
- **so that** pastes and labels read as type while staying ink I can move, erase and fold

#### Acceptance Criteria:
- **Scenario:** A paste on a real-font board
- **Given:** a board on paper I can draw on, with *Real font* turned on in its Board menu
- **When:** I copy "HI" and tap Paste
- **Then:** "HI" lands as Helvetica's letter outlines traced in thin ink, one closed outline a letter where single strokes write it in four, and *Real font* is still on when I reopen the board

---

### User Story 1057:

- **Summary:** A board starts, and stays, in single-stroke letters until I choose otherwise
- **Status:** implemented in [d4f7faaa](https://github.com/idvorkin/context-grabber/commit/d4f7faaa), [9d963efd](https://github.com/idvorkin/context-grabber/commit/9d963efd) and [133e7124](https://github.com/idvorkin/context-grabber/commit/133e7124); verified on the host (`just test`: `BoardRealFontTests`, the per-board choice, a mark's and Larry's lettering, a kept text's lettering through a save, the strokes sent to the Cockpit unchanged, H as one closed outline, baseline and height, paste layout and wrap, reword) and the Mac build (`just native-build-mac`); on the iPad simulator, rung 2, 2026-11-20 (`WhiteboardLetteringUITests`: HI four strokes on a new board, Real font on with no redraw, reopened still on, HI again as two outlines, a new board single strokes). The iPad not yet
- **Issues:** [#950](https://github.com/idvorkin/context-grabber/issues/950): Igor, 2026-11-18, "Why not have the app render a real font?"; 2026-11-20 (W3 on #912's decision page), "a real font as a per-board or per-text option, still drawn as ink"
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A real font, still drawn as ink*

#### Use Case:
- **As someone** who liked #895's single-stroke letters
- **I want to** have every board letter in single strokes unless I pick the real font for it
- **so that** the option changes nothing on the boards I already have

#### Acceptance Criteria:
- **Scenario:** A new board and an old one
- **Given:** a new board, and a board made before the option, neither with a lettering chosen
- **When:** I open its Board menu and paste "HI"
- **Then:** *Real font* is off and the paste is four strokes; turning it on changes nothing already on the board, adds no undo step and costs no stroke

---

### User Story 1058:

- **Summary:** Larry can letter one text in the real font, and it stays one text
- **Status:** implemented in [d4f7faaa](https://github.com/idvorkin/context-grabber/commit/d4f7faaa), [9d963efd](https://github.com/idvorkin/context-grabber/commit/9d963efd) and [c8bcc70f](https://github.com/idvorkin/context-grabber/commit/c8bcc70f); verified on the host (`just test`: `BoardRealFontTests`, the per-board choice, a mark's and Larry's lettering, a kept text's lettering through a save, the strokes sent to the Cockpit unchanged, H as one closed outline, baseline and height, paste layout and wrap, reword) and the Mac build (`just native-build-mac`). A text of Larry's in the real font not yet seen on the simulator or the iPad, and the Cockpit drops a chat mark's lettering until context-grabber-qlr3
- **Issues:** [#950](https://github.com/idvorkin/context-grabber/issues/950): Igor, 2026-11-18, "Why not have the app render a real font?"; 2026-11-20 (W3 on #912's decision page), "a real font as a per-board or per-text option, still drawn as ink"
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A real font, still drawn as ink*; [board ops](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md)

#### Use Case:
- **As someone** working on a board with Larry
- **I want to** have a text of his that asks for the real font drawn in it, whatever the board's lettering
- **so that** he can set a heading or a quote apart, and it still moves, folds, rewords and erases as his text

#### Acceptance Criteria:
- **Scenario:** Larry's text in the real font, reworded
- **Given:** a single-stroke board and a text of Larry's that asks for the real font
- **When:** it lands, I keep it, and I reword it
- **Then:** it is the real font's outlines as ink under his id, and after the reword it is still one text in the real font while the board's next paste is single strokes

---

### User Story 1004:

- **Summary:** A kept reply of Larry's pushes what I wrote since his picture out of the way
- **Status:** implemented in [6cd94985](https://github.com/idvorkin/context-grabber/commit/6cd94985), [64dae5ba](https://github.com/idvorkin/context-grabber/commit/64dae5ba); the simulator test reworked in [ebd344b5](https://github.com/idvorkin/context-grabber/commit/ebd344b5); verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`), the Mac build (`just native-build-mac`) and on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`: his marks stay where they showed, both of Igor's lines move 40 points down clear of them, one undo puts them back and takes his marks away); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** writing on while Larry answers a picture of my board
- **I want to** have his reply push down what I wrote after he looked, when I keep it
- **so that** his reply never lands on my newer ink, and his marks still sit beside what they name

#### Acceptance Criteria:
- **Scenario:** Keep group over writing newer than his picture
- **Given:** Larry's reply of several marks showing where I have written two lines since his picture went, under my older plan
- **When:** I tap one of his marks and *Keep group*
- **Then:** his marks become ink where they showed, my two lines and everything under them move down in whole lines until they sit half a line under his lowest mark, my plan above doesn't move, and one Undo puts my lines back and takes his marks away

---

### User Story 1005:

- **Summary:** One kept mark of Larry's makes room for what I wrote since his picture
- **Status:** implemented on branch `native/board-make-room-894`; verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** keeping Larry's marks one at a time
- **I want to** have one mark of his, kept, push my newer writing out from under it
- **so that** a single Keep never leaves his mark on top of my ink

#### Acceptance Criteria:
- **Scenario:** Keep one mark over newer writing
- **Given:** one of Larry's marks showing on a line I wrote after his picture went
- **When:** I tap it and *Keep*
- **Then:** the mark becomes ink where it showed, my line and everything under it move down clear of it, and one Undo takes back both

---

### User Story 1006:

- **Summary:** Ink Larry saw never makes room for his reply
- **Status:** implemented on branch `native/board-make-room-894`; verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** who sometimes wants Larry to draw over what I wrote
- **I want to** keep his marks on ink he saw exactly where he put them, with nothing moved
- **so that** a circle round my word or an arrow onto it stays on it

#### Acceptance Criteria:
- **Scenario:** His reply on ink that was in his picture
- **Given:** a mark of Larry's drawn over writing that was in the picture he answered, or over marks of his or Claude's kept since, and nothing newer of mine under it
- **When:** I keep it, alone or as a group
- **Then:** nothing of mine moves

---

### User Story 1037:

- **Summary:** A reply that lands with the board closed still makes room
- **Status:** implemented on branch `native/board-make-room-894`; verified by host tests (`BoardRoomLateTests`, `BoardMarksReplayTests` on the family board with a line written after the picture; `just test`) and the Mac build (`just native-build-mac`); the simulator check (`WhiteboardPaperGhostsUITests.testKeepGroupPushesWhatIgorWroteSinceThePictureUnderTheReply`) and the iPad not yet run
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A reply of Larry's makes room for what Igor wrote after Larry looked*; [the object-layer design](https://github.com/idvorkin/context-grabber/pull/912), *A late reply*
- **Issues:** [#894](https://github.com/idvorkin/context-grabber/issues/894): Igor, 2026-11-14, "push what he wrote since the picture down the page to make room for Larry's reply"; board 302d5345, 2026-11-19, "group pushes purple text out of the way"

#### Use Case:
- **As someone** who closes the board while Larry thinks
- **I want to** have his reply, shown when I open the board again, still know what I wrote after his picture
- **so that** closing the board never brings back the overlap

#### Acceptance Criteria:
- **Scenario:** Reopened after his reply
- **Given:** a picture sent to Larry from this device, more writing of mine after it, the board closed, and his reply arrived meanwhile
- **When:** I open the board and keep his reply over that writing
- **Then:** my writing made after the picture moves down clear of it, as if the board had stayed open; a reply to a picture this device didn't send keeps with nothing moved

---

### User Story 1044:

- **Summary:** Holding the room handle shows a band and a "Making room" chip until I lift
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700); verified by host tests (`BoardRoomBandTests`; `just test`), the Mac build, and on the iPad simulator by `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (a finger in the margin, the band and chip photographed with `GRABBER_WHITEBOARD_FEEDBACK_SECONDS`); the Pencil's hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** making room in the middle of my writing on the iPad
- **I want to** see a see-through band with up and down arrows and a *Making room* chip while I hold and drag in the margin
- **so that** it's clear I'm in that mode, and where the room will open, before I lift

#### Acceptance Criteria:
- **Scenario:** Dragging down in the margin
- **Given:** a board on paper with writing above and below
- **When:** I hold a finger or the Pencil in the margin until the handle fires, and drag down two lines without lifting
- **Then:** a see-through band two lines tall lies across the page at the clear line, with up and down arrows and a *Making room* chip beside it; nothing below has moved yet; and when I lift, the band goes and the ink below moves down those two lines

---

### User Story 1038:

- **Summary:** Dragging the room handle up shows the blank paper that will close
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700); verified by host tests (`BoardRoomBandTests`; `just test`), the Mac build, and on the iPad simulator by `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (a finger in the margin, the band and chip photographed with `GRABBER_WHITEBOARD_FEEDBACK_SECONDS`); the Pencil's hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** closing up a gap I no longer need
- **I want to** see the band cover the blank paper that will close
- **so that** I know what the lift will do before I lift

#### Acceptance Criteria:
- **Scenario:** Dragging up over blank paper
- **Given:** a board with three blank lines between two lines of writing
- **When:** I hold in the margin in the gap and drag up four lines
- **Then:** the band covers the three blank lines, never the writing, and the chip says *Closing room*

---

### User Story 1039:

- **Summary:** Dragging the room handle up with no blank paper says there is none to close
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700); verified by host tests (`BoardRoomBandTests`; `just test`), the Mac build, and on the iPad simulator by `WhiteboardOutlineUITests.testTheRoomHandleShowsABandWhileHeld` (a finger in the margin, the band and chip photographed with `GRABBER_WHITEBOARD_FEEDBACK_SECONDS`); the Pencil's hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** closing up a gap I no longer need
- **I want to** be told when there is no blank paper to close
- **so that** I know the lift will change nothing before I lift

#### Acceptance Criteria:
- **Scenario:** Dragging up with no blank paper
- **Given:** a board with two lines of writing with no blank line between them
- **When:** I hold in the margin between the two lines and drag up
- **Then:** the band is a thin line and the chip says *No blank paper to close*

---

### User Story 1042:

- **Summary:** The room band follows Reduce Motion
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [1827700](https://github.com/idvorkin/context-grabber/commit/1827700): the band's easing is off under Reduce Motion; built and its UI tests pass on the iPad simulator with Reduce Motion off; with it on, not yet seen anywhere
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** with Reduce Motion on
- **I want to** have the room band move without easing
- **so that** the board never moves more than it has to

#### Acceptance Criteria:
- **Scenario:** Dragging the room handle with Reduce Motion on
- **Given:** Reduce Motion is on in Settings
- **When:** I drag the room handle down
- **Then:** the band jumps a line at a time with no easing

---

### User Story 1043:

- **Summary:** The scratch-out's flash follows Reduce Motion
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4): the flash is off under Reduce Motion; built and its UI tests pass on the iPad simulator with Reduce Motion off; with it on, not yet seen anywhere
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** with Reduce Motion on
- **I want to** have the struck ink fade without flashing
- **so that** the board never moves more than it has to

#### Acceptance Criteria:
- **Scenario:** Scratching out with Reduce Motion on
- **Given:** Reduce Motion is on in Settings
- **When:** I scratch out a word
- **Then:** the struck ink shows plainly and fades without a flash

---

### User Story 1050:

- **Summary:** A scratch-out flashes and fades the ink it took
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13), [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4); verified by `just test`, the Mac build, and on the iPad simulator by `WhiteboardScratchOutUITests.testAScratchOutFlashesTheInkItTook` (the hook's zigzag, the flash held for its picture); the Pencil's zigzag is the iPad's
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** scribbling out a word with the Pencil
- **I want to** see the ink I struck flash and fade where it was
- **so that** I know the scratch-out fired and what it took

#### Acceptance Criteria:
- **Scenario:** Scratching out a word
- **Given:** a board on paper with a word written on it
- **When:** I draw a quick zigzag over it
- **Then:** the word and the zigzag show in a bright tint where they were and fade out over about half a second, and the board is without them, one Undo bringing the word back

---

### User Story 1051:

- **Summary:** A zigzag that finds nothing to erase says so and goes
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13), [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4); verified on the host (`WhiteboardScratchOutTests.testOnlyAZigzagOverNothingFindsNothing`), the Mac build, and on the iPad simulator by `WhiteboardScratchOutUITests.testAZigzagOverNothingSaysSoAndGoes` (the word, the zigzag gone, Redo bringing it back); the Pencil's zigzag is the iPad's
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** who scribbled where there was nothing
- **I want to** be told nothing was erased, and not be left with the scribble
- **so that** I don't wonder whether the scratch-out failed, and can try again over the ink

#### Acceptance Criteria:
- **Scenario:** A zigzag over bare paper
- **Given:** a board on paper with bare paper where I draw
- **When:** I draw a quick zigzag there
- **Then:** the zigzag is taken away, *Nothing under the scribble to erase* shows beside where it was for a few seconds, and Redo brings the zigzag back as ink

---

### User Story 1052:

- **Summary:** A zigzag that only clips the end of a word says so and goes, leaving the word
- **Issues:** [#1000](https://github.com/idvorkin/context-grabber/issues/1000)
- **Status:** implemented in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13), [d70e8e4](https://github.com/idvorkin/context-grabber/commit/d70e8e4); verified on the host (`WhiteboardScratchOutTests.testOnlyAZigzagOverNothingFindsNothing`), and the Mac build; the simulator's UI test draws over bare paper only (story 1051), so a zigzag beside a word is the iPad's
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every pen gesture shows what it did (#1000)*

#### Use Case:
- **As someone** who scribbled beside a word rather than over it
- **I want to** be told nothing was erased, and not be left with the scribble
- **so that** I don't wonder whether the scratch-out failed, and can try again over the ink

#### Acceptance Criteria:
- **Scenario:** A zigzag beside a word
- **Given:** a board on paper with a long word written on it
- **When:** I draw a quick zigzag that only clips the end of the word
- **Then:** the word stays, the zigzag is taken away, *Nothing under the scribble to erase* shows beside where it was for a few seconds, and Redo brings the zigzag back as ink

---

### User Story 769:

- **Summary:** On an iPhone a tap on the note opens the board's thread in Chat
- **Status:** implemented in [eafb6ea](https://github.com/idvorkin/context-grabber/commit/eafb6ea); verified by host tests (`WhiteboardNoteTests`: the tap on an iPhone with a thread and with none; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPhone
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("some kind of collapse expand conversation")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *One line that opens*

#### Use Case:
- **As someone** looking at a board on the iPhone
- **I want to** get from the note to the board's conversation
- **so that** I can read what Larry said where there is room for it

#### Acceptance Criteria:
- **Scenario:** On a phone
- **Given:** a board with a thread, on an iPhone
- **When:** I tap the note's line
- **Then:** Chat opens on the board's thread

---

### User Story 773:

- **Summary:** The board says whether Larry has picked the picture up
- **Status:** implemented in [d055f34](https://github.com/idvorkin/context-grabber/commit/d055f34), reconciled with stories 775–777 (one reading of the mark, 20 s) in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryClockTests`: `testUntilHePicksItUpTheStateSaysSent`, `testARepeatTapStillSaysLarryAlreadyHasThis`, `testVoiceOverSaysSentInWords`, `testHisSilenceSaysWhereThePictureWas`; `WhiteboardLarryWaitTests`: `testThePicturesOwnMarkSaysWhereItIs`, `testASendToLarryIsReadByTheNewestMessageSinceThePicture`, `testNoTurnOutIsUnknown`; `WhiteboardNoteTests.testTheLineAndThePanelSayWhetherHeHasThePicture`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879) ("This seems very slow, are we crashing/hung?")
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Where the picture is*

#### Use Case:
- **As someone** waiting on Larry at the board
- **I want to** see whether he has picked my picture up yet
- **so that** I can tell "Larry is thinking" from "Larry never got it" without guessing from the clock

#### Acceptance Criteria:
- **Scenario:** Sent, then with Larry
- **Given:** a picture has just gone to Larry and the Cockpit has marked it *received*
- **When:** he picks it up four seconds later
- **Then:** the note's state reads *Sent · 0:03* and then *Larry · 0:04*, the clock never restarting; had he not picked it up in twenty seconds it would read *Sent · 0:21 · not picked up yet*, VoiceOver saying *Sent 21 seconds ago, not picked up yet*, with *Interrupt* beside it (story 777)

---

### User Story 801:

- **Summary:** On a Cockpit that marks nothing the board never says Sent
- **Status:** implemented in [d055f34](https://github.com/idvorkin/context-grabber/commit/d055f34), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 773. Verified by host tests (`WhiteboardLarryWaitTests.testAnOlderCockpitIsNeverStuck`, `WhiteboardLarryClockTests.testTheClockCountsFromThePicture`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Issues:** [#879](https://github.com/idvorkin/context-grabber/issues/879)
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Where the picture is*

#### Use Case:
- **As someone** waiting on Larry at the board, against a Cockpit from before it marked messages
- **I want to** see the state read as it always did
- **so that** a missing mark is never read as news about my picture

#### Acceptance Criteria:
- **Scenario:** An older Cockpit
- **Given:** a Cockpit that puts no marks on messages
- **When:** a picture goes and he is slow
- **Then:** the state reads *Larry · 0:42* throughout, never *Sent*

---

### User Story 775:

- **Summary:** A picture that hasn't reached the Cockpit in 20 seconds offers Retry
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), reconciled with story 773 in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryWaitTests`: `testNoMarkAtTwentySecondsIsStuckWithRetryAndDismiss`, `testNoMarkIsStuckOnlyOnACockpitThatMarks`, `testTheMarkIsFoundByTheMessagesId`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against a hung Cockpit. Retry itself, a Cockpit that marks nothing and a picture that lands after all are stories 802–804
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing on a board the real Larry answers ("I think Larry got stuck. I need interrupt/retry button after 20s!")
- **I want to** be told when a picture I sent hasn't reached the Cockpit, and send it again with one tap
- **so that** I'm never left guessing whether Larry is slow or never got it

#### Acceptance Criteria:
- **Scenario:** The picture never lands
- **Given:** a picture sent to Larry, with no mark from the Cockpit on its message
- **When:** twenty seconds pass
- **Then:** the bar shows *Larry hasn't got the picture* as a problem I can copy, with *Retry* and *Dismiss* beside it, and the canvas is not covered

---

### User Story 802:

- **Summary:** Retry sends the stuck picture again, once
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 775. Verified by host tests (`WhiteboardLarryWaitTests`: `testRetryStartsTheTwentySecondsAgainOnTheSamePicture`, `testAFailureOfThePictureBeforeRetryNeverFreesTheRetriedTurn`, `testAHandOffReplacedByRetryOrDismissSpeaksNoMore`; `LaunchHooksTests`: the hook that taps it, `GRABBER_WHITEBOARD_LARRY_WAIT=retry`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against a hung Cockpit
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** told that my picture hasn't reached Larry
- **I want to** send it again with one tap
- **so that** he gets it, and gets it once even if the first one did land

#### Acceptance Criteria:
- **Scenario:** I retry
- **Given:** the bar shows *Larry hasn't got the picture*
- **When:** I tap *Retry*
- **Then:** the same picture goes again under the same message, the clock goes back to 0:00, the problem goes, and the session log says I retried; if the first one did land, the thread still holds it once

---

### User Story 803:

- **Summary:** A Cockpit that marks nothing never looks stuck
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 775. Verified by host tests (`WhiteboardLarryWaitTests`: `testNoMarkIsStuckOnlyOnACockpitThatMarks`, `testAnOlderCockpitIsNeverStuck`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing with Larry against a Cockpit from before it marked messages
- **I want to** never be told a picture is stuck when the board can't know
- **so that** I don't resend pictures he already has

#### Acceptance Criteria:
- **Scenario:** A Cockpit that marks nothing
- **Given:** an older Cockpit, whose messages carry no marks
- **When:** twenty seconds pass on any picture
- **Then:** the board never says *Larry hasn't got the picture* and never offers *Retry*; it offers *Interrupt* (story 777)

---

### User Story 804:

- **Summary:** A stuck picture that lands after all stops looking stuck
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098), [4d8a67e](https://github.com/idvorkin/context-grabber/commit/4d8a67e) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 775. Verified by host tests (`WhiteboardLarryWaitTests`: `testAPictureTheCockpitAnsweredForIsNeverStuck`, `testRetryStartsTheTwentySecondsAgainOnTheSamePicture`: a mark that arrives reads as working; `just native-test`) and the Mac build (`just native-build-mac`); that only its own problem goes lives in the board's view, with no host test. Not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** told that my picture hasn't reached Larry when it was only slow
- **I want to** see that go by itself once it lands
- **so that** I'm not left with a warning that is no longer true

#### Acceptance Criteria:
- **Scenario:** He was slow, not stuck
- **Given:** *Larry hasn't got the picture* is showing
- **When:** the Cockpit's mark on the picture arrives, or his answer does
- **Then:** the problem goes on its own, and any other problem showing stays

---

### User Story 776:

- **Summary:** Dismiss a stuck picture and the board stops waiting
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), reconciled in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryWaitTests`: `testDismissFreesTheTurnAndKeepsItsWords`, `testAfterInterruptOrDismissTheNextTapSends`, `testAHandOffANewerPictureReplacedStillSpeaks`; `LaunchHooksTests`: the hook that taps it, `GRABBER_WHITEBOARD_LARRY_WAIT=dismiss`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** stop waiting on a picture that hasn't reached him
- **so that** my next pause or tap is a fresh ask instead of being held for an answer that won't come

#### Acceptance Criteria:
- **Scenario:** I dismiss it
- **Given:** the bar shows *Larry hasn't got the picture*
- **When:** I tap *Dismiss*
- **Then:** the problem and Larry's clock go, words that went with the picture wait for the next one, nothing more is said about that picture, my next tap sends (never *Larry already has this*), and the session log says it was dismissed

---

### User Story 777:

- **Summary:** Interrupt Larry when he has the picture and is taking long
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), reconciled in [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); verified by host tests (`WhiteboardLarryWaitTests`: `testReceivedSeenOrUnknownAtTwentySecondsIsWorkingWithOnlyInterrupt`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry. The tap and his finishing are stories 805 and 806
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** drawing on a board the real Larry answers
- **I want to** free the board from waiting on him once the Cockpit has my picture
- **so that** I can ask afresh without sending the same picture again, which wouldn't wake him

#### Acceptance Criteria:
- **Scenario:** He has it and hasn't finished
- **Given:** a picture the Cockpit marked received or seen, not done, or one on a Cockpit that marks nothing
- **When:** twenty seconds pass
- **Then:** the note's line offers a small *Interrupt* after the clock (*Sent · 0:21 · not picked up yet* or *Larry · 0:21*), and nothing else appears

---

### User Story 805:

- **Summary:** A tap on Interrupt frees the board, even with the picture still going up
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 777. A picture whose sending hasn't been answered is let go of too, so the next tap sends at once and, unless the Cockpit's mark says it has the picture, its words wait for the next one (this PR's review). Verified by host tests (`WhiteboardLarryWaitTests`: `testInterruptFreesTheTurnAndALateAnswerFindsNone`, `testAfterInterruptOrDismissTheNextTapSends`, `testDismissFreesTheTurnAndKeepsItsWords` for the words; `LaunchHooksTests`: the hook that taps it, `GRABBER_WHITEBOARD_LARRY_WAIT=interrupt`; `just native-test`) and the Mac build (`just native-build-mac`); letting go of the sending lives in the board's view, with no host test. Not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** waiting on Larry with *Interrupt* showing
- **I want to** stop waiting with one tap
- **so that** my next pause or tap is a fresh ask, at once, whatever became of the last picture

#### Acceptance Criteria:
- **Scenario:** I interrupt
- **Given:** *Interrupt* is showing, on a picture Larry has or on one still going up
- **When:** I tap *Interrupt*
- **Then:** the clock goes, the next pause or tap sends a fresh picture at once (never *Larry already has this*, never held for the last one's sending), words that went with a picture the Cockpit hasn't taken wait for the next one and nothing more is said about it, what Larry draws or says later still lands, and the session log says I interrupted

---

### User Story 806:

- **Summary:** Interrupt goes when Larry finishes
- **Status:** implemented in [e695098](https://github.com/idvorkin/context-grabber/commit/e695098) (bead `context-grabber-stl`), [32fa1e4](https://github.com/idvorkin/context-grabber/commit/32fa1e4); split from story 777. Verified by host tests (`WhiteboardLarryWaitTests`: `testDoneOffersNothingEvenWithTheTurnStillOut`, `testNoTurnOutOffersNothing`; `just native-test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *After 20 seconds*

#### Use Case:
- **As someone** about to interrupt Larry just as he answers
- **I want to** see the control go with the wait
- **so that** I'm never offered a way to stop a wait that is already over

#### Acceptance Criteria:
- **Scenario:** He finishes
- **Given:** *Interrupt* is showing
- **When:** his answer arrives or the Cockpit marks the picture done
- **Then:** *Interrupt* goes

---

### User Story 807:

- **Summary:** The Cockpit's own line stays out of the board's conversation
- **Status:** implemented in this PR's review, with story 820; verified by host tests (`WhiteboardNoteTests.testTheCockpitsOwnLineIsLeftOut`; `just native-test`); not yet seen on the simulator or the iPad
- **Spec:** [Larry's clock and the conversation strip](../superpowers/specs/2026-11-12-whiteboard-conversation-design.md), *Open: the conversation*

#### Use Case:
- **As someone** reading the board's conversation after sending one of my messages on to a new chat
- **I want to** see only what Larry and I said
- **so that** the Cockpit's *Moved to a new chat* never reads as Larry's words

#### Acceptance Criteria:
- **Scenario:** A message moved out of the board's thread
- **Given:** a board whose thread holds *Moved to a new chat* where a message of mine was
- **When:** I open the note's panel
- **Then:** it shows my messages and Larry's, and the moved line is not among them

---

### User Story 880:

- **Summary:** Larry's question about a board lands on it as a card
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests`: `testLarrysQuestionMarkLandsAtHisPlaceByTheRowsFrame`, `testACardIsOncePerAskAndInsideThePage`, `testAnErasedCardsMarkNeverLandsAgain`; `just test`); and on the simulator (`WhiteboardQuestionUITests` 1/1, `scripts/native/test-whiteboard-ui.sh`); not yet seen on the iPad or against the real Larry
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Where a card comes from*

#### Use Case:
- **As someone** drawing with Larry who has a question about the drawing
- **I want to** see his question on the board, where he put it
- **so that** I answer it looking at what it is about, not in another screen

#### Acceptance Criteria:
- **Scenario:** Larry asks on the board
- **Given:** a board I draw on, with its thread to Larry
- **When:** his reply on the thread holds a question for one of his asks
- **Then:** a card *? \<question> ···* lands where he put it, inside the page, once for that ask, and the session log says a card landed from Larry

---

### User Story 881:

- **Summary:** An open ask about a board shows on it when it opens
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests`: `testAnOpenAskNamesTheBoardByItsThreadOrInItsContext`, `testOpenAsksLandAtTheTopOfTheScreenOneUnderAnother`; `just test`); not yet seen on the simulator or the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Where a card comes from*

#### Use Case:
- **As someone** coming back to a board Larry has a question about
- **I want to** find the question on the board
- **so that** a decision about the drawing isn't only in the Inbox

#### Acceptance Criteria:
- **Scenario:** The board opens with an ask naming it
- **Given:** an open ask whose thread is the board's thread, or whose context names the thread or the board, and no card for it
- **When:** I open the board
- **Then:** its card lands at the top of what is on screen, by the left margin, and several land one under another

---

### User Story 882:

- **Summary:** Answer a question card from the board
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e), with Chat's decision card in the popup and an answer in my own words added to its verbs. Verified by host tests (`WhiteboardQuestionsTests`: `testAnAnswerLeavesTheQuestionOverTheAnswer`, `testOwnWordsAreTheInboxsFreeTextAnswer`; `ChatDecisionsTests` for the option's answer; `just test`); and on the simulator (`WhiteboardQuestionUITests.testLarrysQuestionLandsAnswersAndFolds`, 1/1); not yet seen on the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Answering*, *When it fails*

#### Use Case:
- **As someone** with Larry's question on my board
- **I want to** tap it and answer, with an option or in my own words
- **so that** Larry has my decision exactly as if I had answered in the Inbox

#### Acceptance Criteria:
- **Scenario:** I answer a card
- **Given:** an open card on the board
- **When:** I tap it and tap an option, or write my own answer and tap *Send*
- **Then:** the Cockpit takes *DECISION: \<label>* or *DECISION: \<my words>* as the Inbox's answer, the popup closes, and a refused answer instead leaves the popup with a copyable problem and its buttons live again

---

### User Story 883:

- **Summary:** An answered card keeps the question over the answer
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests`: `testWhatACardSays`, `testTheCardsKeepWithTheBoard`; `just test`); and on the simulator (`WhiteboardQuestionUITests` 1/1)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *An answered card*

#### Use Case:
- **As someone** who answered a question on a board
- **I want to** still see what was asked and what I said
- **so that** the drawing keeps the decision it led to

#### Acceptance Criteria:
- **Scenario:** The Cockpit takes my answer
- **Given:** a card I just answered
- **When:** the popup closes
- **Then:** the card is grey, *✓ \<question>* over the answer (and the note), and it is still there when the board opens again, with no network

---

### User Story 884:

- **Summary:** A card answered elsewhere shows that answer
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests.testClosedAsksFetchTheirAnswerAndAMissingOneIsAskedAgain`, `testTheWireAsksForSnoozedAsksAndEncodesTheIDs`; `just test`); not yet seen on the simulator or the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Answered elsewhere*

#### Use Case:
- **As someone** who answered a board's question in the Inbox or in Chat
- **I want to** see that answer on the board's card
- **so that** the board never shows a question as open that I have already decided

#### Acceptance Criteria:
- **Scenario:** The ask closed while the board was shut
- **Given:** a card whose ask is no longer open in the Cockpit
- **When:** I open the board
- **Then:** the card shows *✓ \<question>* over the answer the Cockpit gives, or *✓ answered* when it has none yet, asked again the next time the board opens

---

### User Story 885:

- **Summary:** An answered card opens read-only and folds to a chip
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests.testOnlyAnAnsweredCardFoldsToAChipAsWideAsItsWords`; `just test`); and on the simulator (`WhiteboardQuestionUITests` 1/1)
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Reading and folding*

#### Use Case:
- **As someone** with answered questions on a board
- **I want to** read one in full, or fold it out of the way
- **so that** old decisions stay on the board without crowding the drawing

#### Acceptance Criteria:
- **Scenario:** I fold an answered card
- **Given:** an answered card on the board
- **When:** I tap it and tap *Collapse*
- **Then:** the popup showed the question and the answer in full, the card is now a one-line chip *✓ \<question>* as wide as its words, and a tap on the chip opens it out again

---

### User Story 886:

- **Summary:** The eraser takes an answered card
- **Status:** implemented in [fa5381e](https://github.com/idvorkin/context-grabber/commit/fa5381e). Verified by host tests (`WhiteboardQuestionsTests.testTheEraserTakesAnAnsweredCardAndLeavesAnOpenOne`; `just test`); the eraser's touches live in the board's view, with no host test, and take a card only from a touch that would erase ink — the Pencil, or a finger while fingers draw, never a finger panning the board (review fix); not yet seen on the iPad
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *The eraser*

#### Use Case:
- **As someone** done with an answered question on a board
- **I want to** erase it as I would ink
- **so that** clearing the board is one gesture whatever is on it

#### Acceptance Criteria:
- **Scenario:** I erase across cards
- **Given:** an answered card and an open card on the board, and the eraser in hand
- **When:** I stroke the eraser across both
- **Then:** the answered card goes, the open card stays, and the session log says a card was erased

- **Scenario:** I pan the board with the eraser in hand
- **Given:** an answered card on the board, the eraser in hand, and fingers set not to draw
- **When:** I drag a finger that starts on the card
- **Then:** the board scrolls and the card stays

---

### User Story 889:

- **Summary:** I speak my own answer to a question card, with the mic beside Send
- **Status:** implemented in [a113e38](https://github.com/idvorkin/context-grabber/commit/a113e38), Chat's mic beside the own answer's *Send*. Verified by host tests and lint (`just test`), the Mac build, and on the iPad simulator (`just test-ladder`: `WhiteboardQuestionUITests` measures the field, then the mic, then *Send*, a gap of at most 8 points and both buttons at least 44 points each way). Recording itself is dictation, so it is the phone's to show: not yet tried on a device
- **Issues:** [#625](https://github.com/idvorkin/context-grabber/issues/625) ("put the record button by the send button", then "that should go on all of my screens")
- **Spec:** [Question cards](../superpowers/specs/2026-11-16-whiteboard-question-cards-design.md), *Answering*

#### Use Case:
- **As someone** answering Larry's question on a board, often with the Pencil in hand
- **I want to** speak my own answer with the mic right beside *Send*, as in Chat
- **so that** every place I write to Larry has its two thumb actions together

#### Acceptance Criteria:
- **Scenario:** The mic sits by Send
- **Given:** an open question card's popup, on iPhone or iPad
- **When:** I look at *Your own answer*
- **Then:** the mic is immediately beside *Send*, after the field, each at least 44 points in both directions; the mic records into the field as Chat's does and *Send* answers as before

---

### User Story 814:

- **Summary:** Larry makes room between my lines
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testAPushMovesOnlyWhatStartsAtOrBelowTheLine`, `testAPushThatNeedsAPageAddsOne`, `testAPushBelowTheLastInkMovesNothingAndAddsPaper`, `testATranslateBelowALine`; `just test`) and the Mac build (`just native-build-mac`). The one undo named for the change, page count included, is PaperKit's, in the board's view, with no host test; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysPushMovesTheInkBelowAndOneUndoPutsItBack`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** who asked Larry on the board to open space between two parts of my notes
- **I want to** see everything below the line slide down by the amount he chose, in one step I can undo
- **so that** I get room to write without redrawing or squeezing anything

#### Acceptance Criteria:
- **Scenario:** A push in the middle of the board
- **Given:** a board with ink above and below a line, and Larry answers my turn with "make room below that line"
- **When:** his answer lands with the Pencil up
- **Then:** every stroke, kept mark and pasted line whose top is at or below the line moves straight down exactly that far, the ink above doesn't move, a page is added at the bottom if the push needs one, and one tap on Undo puts the board back as it was, page count included; Redo pushes it down again

---

### User Story 862:

- **Summary:** A push below the last ink adds paper
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testAPushMovesOnlyWhatStartsAtOrBelowTheLine`, `testAPushThatNeedsAPageAddsOne`, `testAPushBelowTheLastInkMovesNothingAndAddsPaper`, `testATranslateBelowALine`; `just test`) and the Mac build (`just native-build-mac`). The one undo named for the change, page count included, is PaperKit's, in the board's view, with no host test; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysPushMovesTheInkBelowAndOneUndoPutsItBack`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*

#### Use Case:
- **As someone** whose ink all sits above the line Larry names
- **I want to** have his push grow blank paper rather than move anything
- **so that** the room he asked for is there to write in

#### Acceptance Criteria:
- **Scenario:** A push below the last ink
- **Given:** a board whose ink all sits above the line Larry names
- **When:** his push lands
- **Then:** nothing moves, and the board grows blank paper to reach the room he asked for

---

### User Story 815:

- **Summary:** Larry moves the strokes he names
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testNamedStrokesMoveAndOnlyThose`, `testOpsApplyInOrderOnTheBoardTheEarlierOnesLeft`, `testAStrokeWithSeveralStretchesAnswersToEachId`, `testATranslateOfNamedStrokes`, `testAMovedStrokeGoesBackUnderTheIdItHad`, `testAStrokeWhoseInkChangedIsNotRenamed`, `testTheNamesAreKeptPerBoard`; `just test`) and the Mac build (`just native-build-mac`). An id the board doesn't have is skipped and named back to Larry (`missing_ids`); the rest applies; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose board Larry is tidying
- **I want to** see the strokes he names, and only those, move where he says, together with anything else he changes in the same answer
- **so that** a change of his is never half applied

#### Acceptance Criteria:
- **Scenario:** Named strokes and a push in one answer
- **Given:** Larry answers with a push and a move of some strokes he names by the ids the board sent him
- **When:** the answer lands with the Pencil up
- **Then:** both happen, and one Undo takes both back

---

### User Story 863:

- **Summary:** A stroke Larry moved keeps its name
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testNamedStrokesMoveAndOnlyThose`, `testOpsApplyInOrderOnTheBoardTheEarlierOnesLeft`, `testAStrokeWithSeveralStretchesAnswersToEachId`, `testATranslateOfNamedStrokes`, `testAMovedStrokeGoesBackUnderTheIdItHad`, `testAStrokeWhoseInkChangedIsNotRenamed`, `testTheNamesAreKeptPerBoard`; `just test`) and the Mac build (`just native-build-mac`). An id the board doesn't have is skipped and named back to Larry (`missing_ids`); the rest applies; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose strokes Larry moves and talks about later
- **I want to** have a moved stroke keep the id he knew it by
- **so that** his connectors and diffs still find it

#### Acceptance Criteria:
- **Scenario:** A moved stroke keeps its name
- **Given:** a stroke Larry has moved
- **When:** the board next sends him its strokes
- **Then:** the stroke has the id he knew it by; only ink I draw, erase or rub part of gets a new one

---

### User Story 816:

- **Summary:** A push never moves ink under my Pencil or on a board that changed
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, so a change held for the Pencil applies to the board as the lift leaves it; the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testAStalePushMovesNothingAndLarryIsTold`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** still drawing when Larry answers
- **I want to** have his push wait until I lift the Pencil, and be refused if I changed the board after he looked
- **so that** ink never jumps under my pen and never lands in the wrong place

#### Acceptance Criteria:
- **Scenario:** The Pencil is down
- **Given:** I am drawing, or lifted the Pencil less than a moment ago
- **When:** Larry's push arrives
- **Then:** it waits, and applies within a second of the Pencil lifting

---

### User Story 864:

- **Summary:** A push on a board that changed since he looked is refused
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, so a change held for the Pencil applies to the board as the lift leaves it; the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testAStalePushMovesNothingAndLarryIsTold`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** who drew after Larry looked at the board
- **I want to** have his push refused rather than land on ink that moved
- **so that** his change never lands in the wrong place

#### Acceptance Criteria:
- **Scenario:** I drew after he looked
- **Given:** the board changed after the picture Larry answered
- **When:** his push arrives
- **Then:** nothing moves, his next turn tells him it was stale, and a fresh push from him applies

---

### User Story 865:

- **Summary:** A change the board can't take applies none of it
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, so a change held for the Pencil applies to the board as the lift leaves it; the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testAStalePushMovesNothingAndLarryIsTold`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry; context-grabber-4nes, a revision no board can have refused whole instead of stopping the app, in [d2e8a11](https://github.com/idvorkin/context-grabber/commit/d2e8a11): `BoardOpsTests.testARevisionNoBoardCanHaveRefusesTheBatchAndNeverTraps` (host, Larry's reply read end to end; it trapped before the fix)
- **Issues:** context-grabber-4nes (a revision too large for a whole number stopped the app while it read Larry's reply)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose board gets an answer it can't carry out
- **I want to** have none of that answer's changes apply, and Larry told why
- **so that** a board is never half changed

#### Acceptance Criteria:
- **Scenario:** A change the board can't take
- **Given:** an answer with more than 50 changes, a push of more than 4000 points, a kind of change this build doesn't know, or a board revision no board can have (a fraction, or a number too large to be one)
- **When:** it arrives
- **Then:** none of it applies, Larry is told why, the rest of his answer shows as it does today, and the session log has one line saying what was refused and why

---

### User Story 866:

- **Summary:** An answer of Larry's applies once
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testWithThePencilDownTheBatchWaitsThenApplies`, `testThePencilsHold`, `testAStaleBatchAppliesNothingAndSaysSo`, `testMoreThanFiftyOpsAreRefused`, `testAPushPastFourThousandPointsIsRefused`, `testAnUnknownOpRefusesTheWholeBatch`, `testTheSameBatchNeverAppliesTwice`, `testANewerHeldBatchReplacesTheOlder`; `just test`) and the Mac build (`just native-build-mac`). The revision is checked when the change arrives, so a change held for the Pencil applies to the board as the lift leaves it; the hold after a lift is the board's half-second pause; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testAStalePushMovesNothingAndLarryIsTold`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry makes room*, *Edge cases*

#### Use Case:
- **As someone** whose board reads Larry's thread again or opens again
- **I want to** have a push that already applied not apply again
- **so that** nothing moves twice

#### Acceptance Criteria:
- **Scenario:** The same answer seen twice
- **Given:** a push that already applied
- **When:** the board reads the thread again or opens again
- **Then:** it is not applied a second time

---

### User Story 817:

- **Summary:** Larry writes plain, readable text on my board
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testAddTextWithItsLooks`, `testPlainTextIsAPrintGhostAtItsTopLeft`, `testAKeptTextGoesBackAsOneStrokeOfKindText`, `testAKeptTextMovesWholeByItsIdOrAPush`, `testAKeptTextsTimeMatchesItsGlyphsReadBack`; `WhiteboardGhostTurnsTests.testLarrysTextJoinsHisMarksAndReplacesOnlyItsOwnId`; `just test`) and the Mac build (`just native-build-mac`). The text's place is its top-left. A text ghost doesn't come back when the board opens again; a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysTextArrivesAsAGhostAndKeepsAsOneText`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry writes plain text*

#### Use Case:
- **As someone** reading Larry's small labels on the board
- **I want to** see his text in a plain typeface, offered as a ghost I keep or dismiss like his other marks
- **so that** it reads cleanly and stays mine to accept

#### Acceptance Criteria:
- **Scenario:** Keep his text
- **Given:** Larry's answer puts a line of text on the board
- **When:** it lands, and I tap it and Keep
- **Then:** it shows as a ghost in a plain typeface at his size and colour, Keep makes it ink on the board (one Undo takes it back, Dismiss throws it away instead), the next picture and strokes Larry gets have it as one text with his id, and a later push from him moves it with the ink around it

---

### User Story 818:

- **Summary:** Larry hears the Pencil and my taps
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testPenAndTapEventsAccumulateUntilTaken`, `testEventsKeepTheirNewestUnderTheCap`, `testEventsOnTheWire`, `testTheTurnMessageCarriesRevResultAndEventsButTheStrokesDont`; `just test`) and the Mac build (`just native-build-mac`); simulator UI tests against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysTextArrivesAsAGhostAndKeepsAsOneText` (the op_result) and `testAStalePushMovesNothingAndLarryIsTold`, pass on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the pen and taps*

#### Use Case:
- **As someone** drawing while Larry watches the board
- **I want to** have Larry told when the Pencil went down and came up and where I tapped
- **so that** he can wait for me to finish and offer things I tap on

#### Acceptance Criteria:
- **Scenario:** A turn after some drawing and a tap
- **Given:** I drew two strokes and tapped one of his marks since his last turn
- **When:** the next picture goes to Larry
- **Then:** it carries the board's revision, what came of his last change, and the Pencil's downs and ups and my tap (where it was, and which of his marks it hit, if any), each with its time; a later turn carries only what happened after

---

### User Story 819:

- **Summary:** The board takes changes from one place, whoever sends them
- **Status:** implemented in [69f96a0](https://github.com/idvorkin/context-grabber/commit/69f96a0), [dd71ae1](https://github.com/idvorkin/context-grabber/commit/dd71ae1); verified by host tests (`BoardOpsTests`: `testTheWebSourceOffersTheNewestBatchFirstThenEachNewOne`, `testTheSameBatchNeverAppliesTwice`, `testTheLedgerKeepsRevHandledAndTexts`, `testAnotherBoardsBatchIsIgnored`; `just test`) and the Mac build (`just native-build-mac`). Only the web source exists; a source inside the app is the next step; not yet seen on the simulator or the iPad, nor against the real Larry; #1040 (bead context-grabber-img6): what the canvas made of a batch (taken, not there, or refused by PaperKit) is now reported to the one applier, which records it once, only for the batch it let through, so a twice-delivered batch, a closed canvas, a refused edit or an answer after the board closed changes nothing else and Larry still hears `not_applied`. Verified by host tests (`BoardCanvasOutcomeTests`, a recording canvas) and the Mac build; the iPad simulator's one-Undo push (`WhiteboardPaperGhostsUITests`) waits on the Mac's screen unlocking
- **Issues:** [#1040](https://github.com/idvorkin/context-grabber/issues/1040) (bead context-grabber-img6): a review, 2026-11-21, "give remote whiteboard edits a testable canvas application outcome"
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Driven from the web or from the app*

#### Use Case:
- **As someone** whose board Larry will one day drive partly from inside the app
- **I want to** see the same push, the same text and the same single undo whichever side sends them
- **so that** moving a feature from the web into the app changes nothing I see

#### Acceptance Criteria:
- **Scenario:** Today's source
- **Given:** Larry's changes arrive over the network on his board replies
- **When:** they reach the board
- **Then:** they go through the one place that checks, holds and applies changes, which would take a source inside the app the same way, and never applies one change twice

---

### User Story 840:

- **Summary:** Larry draws ink straight onto my board
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testAddStrokesWithTheirLooksAndNotes`, `testAPenTooThinOrTooWideDrawsWithinReach`, `testLarrysInkJoinsTheBoardWhereLaterOpsLeaveIt`, `testLarrysStrokesGoBackUnderHisNamesWithHisNotes`, `testInkTheCockpitWouldRefuseIsRefusedHere`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry draws, erases and replaces ink*

#### Use Case:
- **As someone** whose board Larry is helping lay out
- **I want to** have Larry draw real strokes on the board, at his width and colour
- **so that** his drawing is part of the page, not a ghost I have to keep

#### Acceptance Criteria:
- **Scenario:** He draws
- **Given:** Larry's answer adds two strokes with names of his own
- **When:** it lands with the Pencil up
- **Then:** both strokes are ink on the page at once, the board's next strokes give them back under his names, and one Undo takes them away

---

### User Story 841:

- **Summary:** Larry erases and replaces ink by name
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testDeleteSetMetaAndReplace`, `testDeleteByNameAndReplace`, `testAStrokeDrawnAgainUnderItsNameReplacesIt`, `testLarrysOwnInkCanBeErasedInTheSameBatch`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry draws, erases and replaces ink*

#### Use Case:
- **As someone** whose scrawl Larry is tidying
- **I want to** have Larry erase strokes, or swap some for clean ones, in one step
- **so that** a tidy never leaves the old and the new ink both on the page

#### Acceptance Criteria:
- **Scenario:** A replace and an erase in one answer
- **Given:** Larry's answer erases one stroke and replaces two others with one clean line
- **When:** it lands
- **Then:** the three strokes go, the clean line is there, one Undo brings back exactly what was, and a name the board doesn't have is told back to him and nothing else of the answer is lost

---

### User Story 842:

- **Summary:** Larry's groups move as one
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testAGroupMovesWholeAndAnswersToItsName`, `testNotesAreKeptAsWritten`, `testNotesSetByNameAndForgottenWithTheirStrokes`, `testTheNotesAreKeptPerBoard`, `testLarrysStrokesGoBackUnderHisNamesWithHisNotes`; `just test`) and the Mac build (`just native-build-mac`). The Cockpit's strokes endpoint ignores `meta` today, so the notes reach Larry only once it keeps them; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry groups ink*

#### Use Case:
- **As someone** with a label Larry underlined
- **I want to** have the strokes Larry groups move together
- **so that** a push never splits a label from its underline

#### Acceptance Criteria:
- **Scenario:** A group across the line
- **Given:** a group of Larry's whose top is above the line he pushes below, and another stroke of it below
- **When:** the push lands
- **Then:** the whole group moves together or stays together by its top, and his notes on the strokes come back to him exactly as he wrote them

---

### User Story 843:

- **Summary:** Larry hears my ink change
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests`: `testIgorsInkChangeIsToldByName`, `testInkEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`). A rub with the pixel eraser that leaves a stroke's box as it was isn't seen as a change; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears my ink change and my selection*

#### Use Case:
- **As someone** drawing, erasing and moving ink while Larry follows
- **I want to** have Larry told what I added, erased and moved, by name
- **so that** he can say "new since my last reply" without guessing

#### Acceptance Criteria:
- **Scenario:** A few changes
- **Given:** since his last turn I drew a stroke, erased one and moved one with the lasso
- **When:** his next turn goes
- **Then:** it names the added, erased and moved strokes and the board's revision after each change, and the moved stroke keeps the name it had

---

### User Story 844:

- **Summary:** Larry hears my lasso selection
- **Status:** implemented in [7d3981a](https://github.com/idvorkin/context-grabber/commit/7d3981a); verified by host tests (`BoardOpsInkTests.testInkEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears my ink change and my selection*

#### Use Case:
- **As someone** circling ink to talk about it
- **I want to** have Larry told which strokes I selected
- **so that** "this" means what I circled

#### Acceptance Criteria:
- **Scenario:** I circle some ink
- **Given:** I lasso three strokes
- **When:** his next turn goes
- **Then:** it names those three strokes as my selection

---

### User Story 845:

- **Summary:** Larry lays bands, chips, buttons and hints on the board
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testAnOverlayWithItsLooksAndItsEvent`, `testAnOverlayThatCantShowIsRefused`, `testControlsAreLaidReplacedTakenAwayAndHit`, `testSelectingAndControlsLeaveTheInkAsItIs`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** talking with Larry on the board
- **I want to** see Larry's few controls at their places, scrolling with the board
- **so that** I can answer him with a tap instead of words

#### Acceptance Criteria:
- **Scenario:** A band and a button
- **Given:** Larry lays a band across the page and a button beside it
- **When:** they land
- **Then:** they show at their places with their labels, scroll and zoom with the board, are in no picture and no strokes, are never undone, and go when he takes them away

---

### User Story 846:

- **Summary:** A tap on Larry's control reaches him at once
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6), the wake and the caps in [782b1ad](https://github.com/idvorkin/context-grabber/commit/782b1ad) (`BoardOpsControlsTests.testAReportKeepsToTheCockpitsCaps`; the fake Cockpit mirrors the live endpoint); verified by host tests (`BoardOpsControlsTests`: `testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** tapping one of Larry's buttons
- **I want to** have the tap reach him straight away
- **so that** he answers what I chose without waiting for my next turn

#### Acceptance Criteria:
- **Scenario:** I tap his button
- **Given:** a button of Larry's on the board
- **When:** I tap it with a finger
- **Then:** its event goes to the Cockpit at once with the board's revision; if the Cockpit can't take it, it goes with my next turn, and the session log says which

---

### User Story 867:

- **Summary:** A tap on Larry's button wakes him with what he asked to hear
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6), the wake and the caps in [782b1ad](https://github.com/idvorkin/context-grabber/commit/782b1ad) (`BoardOpsControlsTests.testAReportKeepsToTheCockpitsCaps`; the fake Cockpit mirrors the live endpoint); verified by host tests (`BoardOpsControlsTests`: `testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** tapping one of Larry's buttons
- **I want to** have the Cockpit wake him with what the button was for
- **so that** he answers the choice he offered

#### Acceptance Criteria:
- **Scenario:** The tap wakes him
- **Given:** a button of Larry's that asks to hear "make room"
- **When:** I tap it
- **Then:** the Cockpit gets a tap on his control naming the button, with his "make room" as he wrote it, and wakes him; a plain tap elsewhere on the board is never sent as one

---

### User Story 868:

- **Summary:** Events since the last turn keep to the Cockpit's caps
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6), the wake and the caps in [782b1ad](https://github.com/idvorkin/context-grabber/commit/782b1ad) (`BoardOpsControlsTests.testAReportKeepsToTheCockpitsCaps`; the fake Cockpit mirrors the live endpoint); verified by host tests (`BoardOpsControlsTests`: `testATapOnAControlGoesAtOnceAndWaitsIfTheCockpitCantTakeIt`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); a simulator UI test against the fake Cockpit, `WhiteboardPaperGhostsUITests.testLarrysInkAndButtonLandAndATapOnItReachesHim`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)); not yet seen on the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Bands, chips, buttons and hints*

#### Use Case:
- **As someone** who did a lot on the board since Larry's last turn
- **I want to** have the newest events reach him within the Cockpit's limits
- **so that** he is never refused for too much, and knows what he missed

#### Acceptance Criteria:
- **Scenario:** A lot happened since the last turn
- **Given:** more events than the Cockpit takes at once, or one too big
- **When:** they are sent
- **Then:** at most 200 go, none over 8 KB, the whole under 256 KB, the newest kept, and Larry is told how many he missed

---

### User Story 847:

- **Summary:** Larry folds ink away and back
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testHiddenInkMovesWithAPushAndHidingIsAChange`, `testInkHeDrawsHiddenIsDrawnHidden`, `testAHiddenStrokeIsSaidToBe`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry folds and selects*

#### Use Case:
- **As someone** whose long board Larry is folding into sections
- **I want to** have Larry hide strokes and show them again
- **so that** a section can be out of the way without being gone

#### Acceptance Criteria:
- **Scenario:** He hides a section
- **Given:** Larry's answer hides five strokes
- **When:** it lands, and a push of his later moves them, and then he shows them
- **Then:** they vanish at once, keep their place and move with the push while hidden, come back where the push left them, and one Undo undoes the hiding as part of his answer

---

### User Story 848:

- **Summary:** Larry selects ink for me
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testHideAndSelect`, `testSelectingAndControlsLeaveTheInkAsItIs`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry folds and selects*

#### Use Case:
- **As someone** Larry is pointing at ink for
- **I want to** have Larry select strokes as if I had circled them
- **so that** I can move or delete what he means in one gesture

#### Acceptance Criteria:
- **Scenario:** He selects
- **Given:** Larry's answer selects two strokes
- **When:** it lands
- **Then:** those two are selected on the board, and nothing else changes

---

### User Story 849:

- **Summary:** Larry hears the margin
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests`: `testTheMarginsGestures`, `testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`). A finger that draws on paper still draws in the margin too; not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the margin, the view and Undo*

#### Use Case:
- **As someone** asking for room by hand
- **I want to** have a finger tap, hold or drag in the board's left margin reach Larry
- **so that** he can open room where I asked

#### Acceptance Criteria:
- **Scenario:** A drag in the margin
- **Given:** the board open
- **When:** I drag a finger down the left margin
- **Then:** Larry's next turn has a margin drag with where it started on the board and how far it went; a tap and a hold there are told the same way

---

### User Story 850:

- **Summary:** Larry hears where I'm looking
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests.testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the margin, the view and Undo*

#### Use Case:
- **As someone** scrolling a long board
- **I want to** have Larry told what part of the board is on screen when I stop
- **so that** he can answer about what I see

#### Acceptance Criteria:
- **Scenario:** I scroll and stop
- **Given:** the board open
- **When:** I scroll down and let it rest
- **Then:** Larry's next turn has the part of the board on screen and the zoom, once per rest, not on every frame

---

### User Story 851:

- **Summary:** Larry hears me undo his change
- **Status:** implemented in [d5af5a6](https://github.com/idvorkin/context-grabber/commit/d5af5a6); verified by host tests (`BoardOpsControlsTests.testControlsAndViewEventsOnTheWire`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Larry
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry hears the margin, the view and Undo*

#### Use Case:
- **As someone** undoing a change of Larry's
- **I want to** have Larry told which of his changes I undid
- **so that** he doesn't build on a change I took back

#### Acceptance Criteria:
- **Scenario:** I undo his push
- **Given:** a push of Larry's on the board
- **When:** I tap Undo
- **Then:** his next turn has an undo naming that change

---

### User Story 852:

- **Summary:** A paste never lands on my ink: it finds clear paper or opens room
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardRoomTests`: the middle of an empty view, the clear patch nearest the middle never touching ink, room at the clear line nearest the middle by whole lines beyond the blank already there, hidden ink no obstacle); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** pasting text onto a full board
- **I want to** have the paste go to clear paper on screen, or have room open for it
- **so that** nothing I wrote is ever covered

#### Acceptance Criteria:
- **Scenario:** Clear paper on screen
- **Given:** a screen with ink at its middle and clear paper above it
- **When:** I paste two lines
- **Then:** they land in the clear paper nearest the middle and nothing moves

---

### User Story 869:

- **Summary:** A paste on a full screen opens room for itself
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardRoomTests`: the middle of an empty view, the clear patch nearest the middle never touching ink, room at the clear line nearest the middle by whole lines beyond the blank already there, hidden ink no obstacle); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** pasting onto a screen written on every line
- **I want to** have room open for the paste in one undo
- **so that** nothing I wrote is covered

#### Acceptance Criteria:
- **Scenario:** A full screen
- **Given:** writing on every line of the screen
- **When:** I paste
- **Then:** the ink from the middle down moves down whole lines, the paste sits in the room against the margin, and one Undo named Paste puts the board back exactly

---

### User Story 853:

- **Summary:** A paste lands selected with Delete beside it
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea), the Delete's test in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f); a simulator UI test, `WhiteboardOutlineUITests.testAPasteLandsSelectedAndDeleteTakesItAway`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** who pasted the wrong thing
- **I want to** take the paste straight back off the board
- **so that** an accidental paste costs one tap

#### Acceptance Criteria:
- **Scenario:** Delete it
- **Given:** a paste that just landed
- **When:** I tap Delete beside it
- **Then:** the paste goes, the room it opened stays, and Undo brings the paste back

---

### User Story 870:

- **Summary:** Delete goes once I move on from a paste
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea), the Delete's test in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f); a simulator UI test, `WhiteboardOutlineUITests.testAPasteLandsSelectedAndDeleteTakesItAway`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Paste makes room*

#### Use Case:
- **As someone** who pasted and carried on working
- **I want to** have the paste's Delete go away when I draw or select something else
- **so that** Delete is only offered for what just landed

#### Acceptance Criteria:
- **Scenario:** Move on
- **Given:** a paste that just landed, selected
- **When:** I draw or select something else
- **Then:** Delete goes away

---

### User Story 854:

- **Summary:** Erasing part of a group leaves plain ink
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardDissolveTests`: part of a group leaves plain ink with his other notes, a whole group is an ordinary erase, a kept text missing a letter is forgotten and `dissolved` goes on the wire); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Erasing part of a group dissolves it*

#### Use Case:
- **As someone** rubbing out part of something Larry drew as one
- **I want to** have what's left be plain ink
- **so that** it no longer moves or answers as a thing that is gone

#### Acceptance Criteria:
- **Scenario:** Part of his group
- **Given:** a group of Larry's three strokes
- **When:** I erase one of them
- **Then:** the other two stay where they are as plain ink, a push moves them one by one, and Larry's next turn names the group as dissolved

---

### User Story 871:

- **Summary:** Erasing a letter of Larry's kept text leaves plain ink
- **Status:** implemented in [ef701ea](https://github.com/idvorkin/context-grabber/commit/ef701ea); verified by host tests (`BoardDissolveTests`: part of a group leaves plain ink with his other notes, a whole group is an ordinary erase, a kept text missing a letter is forgotten and `dissolved` goes on the wire); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Erasing part of a group dissolves it*

#### Use Case:
- **As someone** rubbing out part of a text of Larry's I kept
- **I want to** have what's left be plain ink
- **so that** Larry no longer reads it as his text

#### Acceptance Criteria:
- **Scenario:** Part of a kept text
- **Given:** a text of Larry's I kept
- **When:** I erase one letter
- **Then:** the other letters stay as plain ink, and Larry no longer gets it as his text

---

### User Story 855:

- **Summary:** A margin tap makes a header, and another folds it
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: a margin tap makes a header once, a fold hides the indented lines and closes up whole lines and unfold puts everything back, a push never splits a fold from its header, unfold makes room for what was written under it, an undo that shows the ink opens the fold); a simulator UI test, `WhiteboardOutlineUITests.testAMarginTapMakesAHeaderAndAnotherFoldsIt`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** [#946](https://github.com/idvorkin/context-grabber/issues/946) (the iPad, 2026-11-18, build 69f912fb: two finger taps in the margin each came back from PaperKit as a selection change, a resize box with no elements showed, and the log went silent for 14 s before "I think I just hung"; not settled, so `main_stall` now says whether the main thread stopped answering); [#945](https://github.com/idvorkin/context-grabber/issues/945) (half a minute later "a bad state now for selection": from those margin taps on, the touch watcher logged no touch, while 223 strokes moved twice by a drag on the box with nothing selected; `paper_selection` and the watch state on `paper_ink` now say what PaperKit selected and what took the touches)

#### Use Case:
- **As someone** writing an outline on the board
- **I want to** turn a line into a header with one tap and fold what is under it
- **so that** a long board reads like an outline

#### Acceptance Criteria:
- **Scenario:** Make a header
- **Given:** a line of writing with indented lines under it
- **When:** I tap the margin beside it
- **Then:** a ▾ shows beside it in the margin

---

### User Story 872:

- **Summary:** A tap on a header's mark folds its section and another unfolds it
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: a margin tap makes a header once, a fold hides the indented lines and closes up whole lines and unfold puts everything back, a push never splits a fold from its header, unfold makes room for what was written under it, an undo that shows the ink opens the fold); a simulator UI test, `WhiteboardOutlineUITests.testAMarginTapMakesAHeaderAndAnotherFoldsIt`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing an outline on the board
- **I want to** fold the lines under a header and open them again
- **so that** a long board reads like an outline

#### Acceptance Criteria:
- **Scenario:** Fold and unfold
- **Given:** a header with three indented lines and a line at its indent below them
- **When:** I tap its mark
- **Then:** the three lines hide, the line below slides up under the header, the mark says ▸ 3; tapping again puts everything back where it was, and each is one Undo

---

### User Story 856:

- **Summary:** Folds nest, and a section ends where the ink returns to the header's indent
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: folds nest and the inner stays folded through the outer's unfold, blank paper never ends a section, a header whose next line isn't indented runs to the next at its indent); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing a deeper outline
- **I want to** fold a section with its sub-sections inside it
- **so that** folding behaves as in an outliner

#### Acceptance Criteria:
- **Scenario:** A folded section inside another
- **Given:** a header with an indented header under it, itself folded
- **When:** I fold the outer one and unfold it again
- **Then:** the inner one is still folded

---

### User Story 873:

- **Summary:** Blank paper never ends a section
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: folds nest and the inner stays folded through the outer's unfold, blank paper never ends a section, a header whose next line isn't indented runs to the next at its indent); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing an outline with gaps in it
- **I want to** have a section run on past blank paper to the next line at its header's indent
- **so that** folding takes the whole section

#### Acceptance Criteria:
- **Scenario:** Blank paper
- **Given:** a header whose indented lines run on after a gap of blank paper
- **When:** I fold it
- **Then:** the lines after the gap fold too, up to the first line back at the header's indent

---

### User Story 857:

- **Summary:** Larry knows folded ink is folded, not erased
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests`: the fold's wire and folded names, `testFoldsGoBesideTheStrokesToTheCockpit`) and the fake Cockpit's check (`test-fake-cockpit-ops.py`: folds taken, a fold without lines refused); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad, nor against the real Cockpit
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** talking with Larry about a folded board
- **I want to** have Larry told which strokes are folded under which header
- **so that** he doesn't think I erased them, or wrote them again when I unfold

#### Acceptance Criteria:
- **Scenario:** A folded section
- **Given:** a header folded over three lines
- **When:** Larry's turn comes
- **Then:** the strokes he gets leave the folded ones out and list them under the header's strokes, with the number of lines folded

---

### User Story 858:

- **Summary:** Press and hold: room in the margin, a menu on the page
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f), the Pencil in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardRoomTests.testRoomByHandOpensWholeLinesAndClosesOnlyBlankPaper`); a simulator UI test, `WhiteboardOutlineUITests.testAHoldBringsTheMenuAndAMarginDragMakesRoom`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** needing room in the middle of my writing
- **I want to** hold and drag in the margin, or hold for a menu
- **so that** I make room, paste or mark a header without leaving the board

#### Acceptance Criteria:
- **Scenario:** Drag in the margin
- **Given:** writing above and below
- **When:** I hold a finger or the Pencil in the margin, drag down two lines and lift
- **Then:** the ink below that clear line moves down two lines, one Undo

---

### User Story 930:

- **Summary:** The Pencil held in the margin opens room
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing with the Pencil and needing room
- **I want to** hold the Pencil still in the margin and drag it down
- **so that** I make room without putting the Pencil down

#### Acceptance Criteria:
- **Scenario:** Hold and drag
- **Given:** writing above and below a clear line
- **When:** I hold the Pencil still in the margin beside it for half a second, drifting a little as a hand does, drag down two lines and lift
- **Then:** the ink below moves down two lines, one Undo, and no stroke of the Pencil's is left in the margin

---

### User Story 931:

- **Summary:** The Pencil held still in the margin brings the menu
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing with the Pencil
- **I want to** hold it still in the margin and lift
- **so that** I get Make room here, Paste and the header choices without a finger

#### Acceptance Criteria:
- **Scenario:** Hold and lift
- **Given:** a line of writing
- **When:** I hold the Pencil still in the margin beside it for half a second, within about 12 points, and lift
- **Then:** the menu shows there, and the Pencil left no dot

---

### User Story 932:

- **Summary:** The Pencil that moves at once still draws in the margin
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** writing or marking in the margin
- **I want to** have a quick Pencil stroke there stay ink
- **so that** margin notes and quick marks still work

#### Acceptance Criteria:
- **Scenario:** A quick stroke
- **Given:** the margin
- **When:** I draw a quick bullet or dash in it, moving further than about 12 points within the first half second
- **Then:** the stroke stays as ink and nothing moves

---

### User Story 933:

- **Summary:** Every margin hold says in the log what became of it
- **Issues:** Igor on the iPad, build 6e2ee969, 2026-11-16: "push down doesn't seem to fire at all"
- **Status:** implemented in [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192); verified by host tests (`BoardMarginHoldTests`), `just test` and the Mac build (`just native-build-mac`); the Pencil hold not yet seen on the iPad: the simulator can't hold a Pencil
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** debugging a hold that didn't fire on the iPad
- **I want to** read each margin hold in the session log
- **so that** the next report settles whether it was the finger, the Pencil, the timing or PaperKit

#### Acceptance Criteria:
- **Scenario:** A hold that fails
- **Given:** the board open
- **When:** I hold in the margin with a finger or the Pencil
- **Then:** the log has its start (which, where) and whether it became a hold or why not: moved first, lifted too soon, or never seen held

---

### User Story 874:

- **Summary:** A hold on the page brings a menu
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f); verified by host tests (`BoardRoomTests.testRoomByHandOpensWholeLinesAndClosesOnlyBlankPaper`); a simulator UI test, `WhiteboardOutlineUITests.testAHoldBringsTheMenuAndAMarginDragMakesRoom`, passes on the iPad simulator (the whiteboard and chat UI classes, `WhiteboardPaperGhostsUITests` again after [9c1f3d6](https://github.com/idvorkin/context-grabber/commit/9c1f3d6)), and again with HI as four single strokes after [e647a4f9](https://github.com/idvorkin/context-grabber/commit/e647a4f9) (#996; rung 2, 2026-11-20); `just test` and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** needing room, a paste or a header in the middle of my writing
- **I want to** hold a finger still for a menu
- **so that** I do them without leaving the board

#### Acceptance Criteria:
- **Scenario:** Hold for the menu
- **Given:** a finger held still on the page, or in the margin without dragging
- **When:** the hold is long enough
- **Then:** a menu offers Make room here, Paste, and Make header (or Not a header) beside a line

---

### User Story 859:

- **Summary:** The Pencil held on a word picks it up
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the word lands when the Pencil lifts, not live; in the margin a held Pencil is the hold, not the pick-up, since [ef7be79](https://github.com/idvorkin/context-grabber/commit/ef7be79), [c09a192](https://github.com/idvorkin/context-grabber/commit/c09a192)); verified by host tests (`BoardOutlineTests.testAHeldPencilPicksUpTheWordUnderIt`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad: the simulator can't hold a Pencil, so the iPad is where it is seen
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** rearranging what I wrote
- **I want to** hold the Pencil still on a word and drag it somewhere else
- **so that** I move a word without the lasso

#### Acceptance Criteria:
- **Scenario:** Move a word
- **Given:** a line of words
- **When:** I hold the Pencil still on one word for under half a second, drag and lift
- **Then:** that word, and only it, lands where I lifted, my Pencil's stroke isn't kept, and one Undo puts it back

---

### User Story 875:

- **Summary:** The Pencil held on a word and lifted selects it
- **Status:** implemented in [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the word lands when the Pencil lifts, not live); verified by host tests (`BoardOutlineTests.testAHeldPencilPicksUpTheWordUnderIt`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad: the simulator can't hold a Pencil, so the iPad is where it is seen
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Press and hold (#918)*

#### Use Case:
- **As someone** choosing a word I wrote
- **I want to** hold the Pencil on it and lift
- **so that** it is selected without the lasso

#### Acceptance Criteria:
- **Scenario:** Hold and lift
- **Given:** a word
- **When:** I hold the Pencil on it and lift without moving
- **Then:** the word is selected

---

### User Story 860:

- **Summary:** Fold all, Unfold all, and collapse to a level
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b) (levels, collapse) and [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the menu on a header's mark); verified by host tests (`BoardOutlineTests.testLevelsAndCollapsingToOne`, `testUnfoldAllOpensFoldsInsideFolds`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** reading a long outline
- **I want to** fold everything, open everything, or show the outline to a depth
- **so that** I see the shape of the board at a glance

#### Acceptance Criteria:
- **Scenario:** Collapse to level 1
- **Given:** an outline two levels deep
- **When:** I hold a header's mark and choose 1
- **Then:** only the top headers show, each folded

---

### User Story 876:

- **Summary:** Collapse to level 2 shows the sub-headers folded
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b) (levels, collapse) and [997ce4f](https://github.com/idvorkin/context-grabber/commit/997ce4f) (the menu on a header's mark); verified by host tests (`BoardOutlineTests.testLevelsAndCollapsingToOne`, `testUnfoldAllOpensFoldsInsideFolds`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** reading a long outline
- **I want to** show it to two levels
- **so that** I see its shape a level deeper

#### Acceptance Criteria:
- **Scenario:** Collapse to level 2
- **Given:** the same outline
- **When:** I choose 2
- **Then:** the top headers stay open, their sub-headers show folded, and a top header with no sub-headers folds

---

### User Story 861:

- **Summary:** A line that looks like a header is offered as one
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b); verified by host tests (`BoardOutlineTests.testABigOrUnderlinedLineIsOffered`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** writing titles bigger or underlining them
- **I want to** see such a line offered as a header
- **so that** making headers is one tap where I already marked them

#### Acceptance Criteria:
- **Scenario:** A big line
- **Given:** a board with four ordinary lines and one written much bigger
- **When:** it is drawn
- **Then:** a faint H shows in the margin beside the big line; nothing folds until I tap the margin there, which makes it a header

### User Story 877:

- **Summary:** An underlined line is offered as a header
- **Status:** implemented in [711d91b](https://github.com/idvorkin/context-grabber/commit/711d91b), [11f70d23](https://github.com/idvorkin/context-grabber/commit/11f70d23) (a stroke running far past the line is a rule, not offered); verified by host tests (`BoardOutlineTests.testABigOrUnderlinedLineIsOffered`, `BoardInkHeadersTests.testARuleTouchingTheLastLineLeavesThatLineInTheSection`); `just test` and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** underlining my titles
- **I want to** see an underlined line offered as a header
- **so that** making headers is one tap where I already marked them

#### Acceptance Criteria:
- **Scenario:** An underlined line
- **Given:** a line with a straight stroke under most of it that doesn't run far past it (no more than half as wide again as the line, plus a line's height)
- **When:** it is drawn
- **Then:** the faint H shows beside it

---

### User Story 890:

- **Summary:** A fast zigzag over ink scratches it out
- **Status:** implemented in [767fdd4](https://github.com/idvorkin/context-grabber/commit/767fdd4) (the Cockpit's web board's `scratchOut`, ported); verified on the host (`WhiteboardScratchOutTests`, the web board's own zigzags, humps and loops; `just native-test`). The Pencil's feel and the one undo are the iPad's to show. Staying gone when he writes on (#999) fixed in [19fa533e](https://github.com/idvorkin/context-grabber/commit/19fa533e); verified on the simulator (`WhiteboardScratchOutUITests`, failing before the fix: the word stayed on the sheet), the Pencil's zigzag on the iPad still to see. A scribble that drifts along the word (context-grabber-4kj) in [eb73c30](https://github.com/idvorkin/context-grabber/commit/eb73c30); verified on the Linux rung (`WhiteboardScratchOutTests`, Igor's real scribbles of 2026-11-21 replayed, failing before the fix on *short sweeps*), the iPad still to see
- **Issues:** [#999](https://github.com/idvorkin/context-grabber/issues/999), context-grabber-4kj (a scribble that drifts along the word stayed ink, *short sweeps*, Igor 2026-11-21)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** writing on a board with the Pencil
- **I want to** scribble over a word to delete it, without picking up the eraser
- **so that** fixing a mistake doesn't break my flow, as on Larry's web board

#### Acceptance Criteria:
- **Scenario:** Scratching out a word
- **Given:** a board on paper with a word written on it and another word beside it
- **When:** I draw a quick zigzag, turning back at least three times, over the first word
- **Then:** the strokes the zigzag touched and the zigzag itself are gone, and stay gone, on the sheet and in what Larry gets, when I write on; the word beside it stays, and one undo brings the scratched-out word back without the zigzag

- **Scenario:** Scribbling over a word the way a hand does
- **Given:** a board on paper with a word written on it
- **When:** I scribble fast over the word, turning back five times or more, drifting along it so no sweep spans the whole scribble
- **Then:** the word and the scribble are gone, as for a straight zigzag

---

### User Story 891:

- **Summary:** Writing that only looks like a zigzag stays ink
- **Status:** implemented in [767fdd4](https://github.com/idvorkin/context-grabber/commit/767fdd4); verified on the host (`WhiteboardScratchOutTests.testHandwritingNeverQualifies`, `testAZigzagThatIsNotAScratchOutStaysInk`, `testAZigzagBesideAWordRatherThanOverItStaysInk`). The session log's `scratch` line says why each near miss stayed ink, for the iPad; narrowed to writing in [dedaa13](https://github.com/idvorkin/context-grabber/commit/dedaa13) (#1000): a fast zigzag over bare paper or beside a word is stories 1051 and 1052; hatching that wanders along stays ink unsaid in [eb73c30](https://github.com/idvorkin/context-grabber/commit/eb73c30) (context-grabber-4kj; Igor's hatching from his boards in the test's fixture)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** writing words like *mmm*, *www* or *minimum*
- **I want to** never lose ink to a scratch-out I didn't mean
- **so that** I can trust the board with my handwriting

#### Acceptance Criteria:
- **Scenario:** Near misses
- **Given:** a board with writing on it
- **When:** I write *mmm* over a word, or draw a slow zigzag over it
- **Then:** what I drew stays as ink, nothing else is removed, and the session log says why it wasn't a scratch-out (*marches along*, *slow*). A fast zigzag on bare paper, or one that only clips the end of a long word, is stories 1051 and 1052 (#1000)

- **Scenario:** Shading
- **Given:** a board with a drawn box on it
- **When:** I hatch fast beside the box or inside it, back and forth along a line
- **Then:** the hatching stays as ink, without a word, and the box stays (*short sweeps*, or *wanders, beside ink*)

---

### User Story 892:

- **Summary:** Claude and Larry wait until I've stopped writing, by my own rhythm
- **Status:** implemented in [c9219b9](https://github.com/idvorkin/context-grabber/commit/c9219b9) (the web board's `WritingVad`, ported; replaces story 660's fixed half second); verified on the host (`WhiteboardWritingVadTests`; `just native-test`). How it feels is the iPad's to show
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *When he has stopped writing*

#### Use Case:
- **As someone** writing a sentence on the board
- **I want to** be answered when I've finished a thought, not between two words
- **so that** ghosts and Larry's turns follow what I mean, not a timer

#### Acceptance Criteria:
- **Scenario:** A pause mid-sentence and one at the end of a line
- **Given:** Ghosts are on and I write a few words at my usual pace
- **When:** I pause for a second in the middle of the line, then later stop at the end of the line
- **Then:** the mid-line pause asks nothing, and the pause at the end asks after about four times my usual gap between strokes, never less than 1.5 s nor more than 5 s; the session log's `vad` line says the wait, its cue and my usual gap

---

### User Story 893:

- **Summary:** An end-of-thought cue asks sooner
- **Status:** implemented in [c9219b9](https://github.com/idvorkin/context-grabber/commit/c9219b9); verified on the host (`WhiteboardWritingVadTests.testAQuestionMarkEndsTheThoughtAtOnce`, `testThePencilHoveringAtANewLineCutsThePauseToTheFloor`, `testTheHandLeavingIsSeenOnlyWhereTheHoverIs`). The Pencil's hover exists only on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *When he has stopped writing*

#### Use Case:
- **As someone** asking the board a question in ink
- **I want to** be answered as soon as the question is finished
- **so that** a longer wait for my rhythm doesn't hold up a thought that is plainly over

#### Acceptance Criteria:
- **Scenario:** A question mark, a new line, the hand gone
- **Given:** Ghosts are on and I have written a line
- **When:** I end it with a question mark, or move the hovering Pencil to the start of the next line, or lift my hand away from the screen
- **Then:** the turn is asked 1.5 s after my last lift (at once if that has passed), and the session log's `vad` line names the cue

---

### User Story 894:

- **Summary:** Putting the Pencil down cancels a turn that hasn't landed
- **Status:** implemented in [c9219b9](https://github.com/idvorkin/context-grabber/commit/c9219b9); verified on the host (`WhiteboardGhostTurnsTests.testThePencilGoingDownCancelsATurnNotYetLanded` and its neighbours). The request being dropped on the wire is the iPad's to show
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *When he has stopped writing*

#### Use Case:
- **As someone** who starts writing again just after a pause
- **I want to** have the stale turn dropped
- **so that** Claude answers the board as it is when I next stop, not a picture I've already moved past

#### Acceptance Criteria:
- **Scenario:** Writing again while Claude is being asked
- **Given:** a pause has asked Claude and no answer has landed yet, and I spoke some words with it
- **When:** I put the Pencil down to write again
- **Then:** that request is dropped, any of its marks already shown go, the bar says nothing went wrong, and my words go with the next turn after my next pause

---

### User Story 895:

- **Summary:** Keep all of Larry's marks at once, in the order he drew them
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4) (the web board's `keepAll`, without moving my ink); verified on the host (`WhiteboardTidyTests`; `just native-test`) and on the simulator (`WhiteboardTurnUITests.testKeepingAllOfLarrysMarksMakesThemInkInOneStep`, rung 2)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** whose board Larry answered with several labels
- **I want to** keep them all in one go, each clear of my writing and still in order
- **so that** his answer reads as he wrote it without my tapping every mark

#### Acceptance Criteria:
- **Scenario:** Larry's labels, one landing on my writing
- **Given:** Larry's marks show on my board and the first of his labels sits on a line I wrote
- **When:** I tap Keep all beside the count of marks to keep
- **Then:** every one of his marks becomes ink in his colour, the label on my writing moves just under it and the marks below it move down with it, my own ink doesn't move, and one undo takes all of them back

---

### User Story 896:

- **Summary:** Tidy overlaps moves kept labels off my writing
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4) (the web board's `tidy`, without moving my ink); verified on the host (`WhiteboardTidyTests.testTidyMovesOnlyTheLabelsThatSitOnInk`, `testTidySeparatesTwoLabelsOnEachOther`, `testTidyTwiceChangesNothing`); `just native-test`. Not yet seen on the simulator or the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** who kept labels that landed on my own writing
- **I want to** tidy them off it in one step
- **so that** the board stays readable without moving anything by hand

#### Acceptance Criteria:
- **Scenario:** A kept label over my words
- **Given:** a label I kept sits on a line I wrote, and another sits on bare paper
- **When:** I choose Board → Tidy overlaps
- **Then:** the label on my words moves down to the first clear space under them, the other stays, my ink doesn't move, and one undo puts it back

---

### User Story 897:

- **Summary:** Tidy overlaps on a tidy board says so
- **Status:** implemented in [b40e8bf](https://github.com/idvorkin/context-grabber/commit/b40e8bf) and [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4); verified on the host (`WhiteboardTidyTests.testTidyTwiceChangesNothing`) and on the simulator (`WhiteboardPaperGhostsUITests.testTidyOverlapsOnATidyBoardSaysNothingOverlaps`, rung 2)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** who chose Tidy overlaps on a board with nothing to tidy
- **I want to** be told nothing overlaps
- **so that** I know the tidy ran and the board is already clear

#### Acceptance Criteria:
- **Scenario:** Nothing to tidy
- **Given:** no kept label sits on other ink
- **When:** I choose Board → Tidy overlaps
- **Then:** nothing moves and the bar says *Nothing overlaps*

---

### User Story 898:

- **Summary:** Folded ink is never scratched out, kept around or tidied
- **Status:** implemented in the review round after [ee847e4](https://github.com/idvorkin/context-grabber/commit/ee847e4); verified by the lint rung and the Mac build (`just native-build-mac`) only. Folding and the Pencil's zigzag are the iPad's to show
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*; [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *Keep all and Tidy overlaps*

#### Use Case:
- **As someone** who folds sections of a board away under their headers
- **I want to** have what is folded left alone by a scratch-out, a Keep all or a tidy
- **so that** unfolding brings back exactly what I folded, where I left it

#### Acceptance Criteria:
- **Scenario:** A zigzag over a word just under a folded header
- **Given:** a folded section whose hidden ink sits under the lines below its header, and a word on one of those lines
- **When:** I scratch the word out
- **Then:** only the word goes; unfolding the header shows all of its ink where it was

---

### User Story 899:

- **Summary:** A zigzag over a gap the pixel eraser left leaves the stroke alone
- **Status:** implemented in [e91e8bb5](https://github.com/idvorkin/context-grabber/commit/e91e8bb5); verified on the host (`WhiteboardScratchOutTests.testAZigzagOverTheGapTheEraserLeftStaysInk`, `testAZigzagOverWhatIsLeftTakesTheStroke`, `testWhatTheEraserLeftIsReadFromTheVisibleRanges`; `just native-test`) and the Mac build (`just native-build-mac`); a real pixel eraser's rub then a zigzag over the gap is the iPad's to see
- **Issues:** context-grabber-p5hy (a zigzag over a gap the pixel eraser left took the whole stroke around it; codex review 2026-11-21)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** who rubs part of a stroke away with the pixel eraser
- **I want to** have a scratch-out touch only the ink still on the board
- **so that** a zigzag over bare paper never takes the ink around it

#### Acceptance Criteria:
- **Scenario:** A zigzag over a gap the pixel eraser left
- **Given:** a board on paper with a stroke whose middle I rubbed out with the pixel eraser
- **When:** I draw a quick zigzag over the gap, touching neither part that is left
- **Then:** nothing of that stroke goes, as the gap is bare paper

---

### User Story 920:

- **Summary:** Selected handwriting becomes typed text
- **Status:** implemented in [6a1894d](https://github.com/idvorkin/context-grabber/commit/6a1894d); verified by host tests (`BoardToTextTests`: `testTheRequestIsThePictureAndTheBoardAsTheWebBoardSendsThem`, `testTheCropIsTheInkWithAirRoundItNeverOffTheBoard`, `testTheWordsAreTheAnswer`, `testOneTypedLinePerLineReadAtTheInksTopLeftSizedToIt`; `just test`) and the Mac build (`just native-build-mac`), and on the simulator against the fake Cockpit (`WhiteboardToTextUITests.testToTextPutsTheWordsInTheInksPlace`, rung 2); not yet seen on the iPad, nor against the real Cockpit
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*

#### Use Case:
- **As someone** writing on the board with the Pencil
- **I want to** lasso some of my handwriting and tap To text
- **so that** the words are typed where I wrote them, for me and for Larry

#### Acceptance Criteria:
- **Scenario:** Two written lines
- **Given:** I lasso two lines of my handwriting on a board drawn on here
- **When:** I tap To text beside the selection and the Cockpit reads it
- **Then:** the ink goes and its words show in its place as two typed lines in the print lettering and the ink's colour, one kept text that Larry gets back as text; one undo brings the ink back

---

### User Story 921:

- **Summary:** A To text that fails leaves the ink and says why
- **Status:** implemented in [6a1894d](https://github.com/idvorkin/context-grabber/commit/6a1894d); verified by host tests (`BoardToTextTests.testAFailureSaysTheCockpitsReason`; `just test`) and the Mac build (`just native-build-mac`), and on the simulator against the fake Cockpit (`WhiteboardToTextUITests.testAFailureLeavesTheInkWithACopyableProblem`, rung 2); not yet seen on the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*

#### Use Case:
- **As someone** turning handwriting into text
- **I want to** be told why when the Cockpit can't read it
- **so that** I know whether to try again, and my ink is never lost

#### Acceptance Criteria:
- **Scenario:** The Cockpit fails
- **Given:** some ink lassoed, and a Cockpit that is away or answers with an error
- **When:** I tap To text
- **Then:** the ink stays exactly as it was and a copyable problem says "To text failed:" with the Cockpit's reason, naming the board, the Cockpit and its status

---

### User Story 922:

- **Summary:** No writing, or too much, leaves the ink and says so
- **Status:** implemented in [6a1894d](https://github.com/idvorkin/context-grabber/commit/6a1894d); verified by host tests (`BoardToTextTests.testNoWritingOrTooMuchLeavesTheInk`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *To text*

#### Use Case:
- **As someone** lassoing a drawing or a whole page
- **I want to** hear that there was no writing, or too much for one text
- **so that** I can select something else instead of losing what I drew

#### Acceptance Criteria:
- **Scenario:** A drawing with no words
- **Given:** I lasso a doodle with no writing in it, or more than 500 characters of writing
- **When:** I tap To text
- **Then:** the ink stays and the board's note says "No writing found there", or "Too much writing for one text (500 characters): select less"

---

### User Story 923:

- **Summary:** A line held at its end snaps straight
- **Status:** implemented in [f2d3e1d](https://github.com/idvorkin/context-grabber/commit/f2d3e1d); verified by host tests (`BoardShapeSnapTests`: `testANearlyStraightStrokeSnapsToTheLineFromItsStartToItsEnd`, `testAWobblyOrShortStrokeStaysInk`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator (no Pencil to hold) or the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *Shapes that snap*

#### Use Case:
- **As someone** drawing a line with the Pencil
- **I want to** hold the Pencil still at its end to make it straight
- **so that** my diagrams look clean without a ruler or a shape tool

#### Acceptance Criteria:
- **Scenario:** A nearly straight line
- **Given:** I draw a slightly wobbly line on a board drawn on here
- **When:** I hold the Pencil still at its end for about half a second, then lift
- **Then:** the line is replaced by a straight one from where I started to where I stopped, in my pen's ink, colour and width; one undo gives my raw line back

---

### User Story 924:

- **Summary:** A box or a loop held at its end snaps to a rectangle or an ellipse
- **Status:** implemented in [f2d3e1d](https://github.com/idvorkin/context-grabber/commit/f2d3e1d); verified by host tests (`BoardShapeSnapTests`: `testANearlySquareBoxSnapsToItsBox`, `testATiltedBoxStaysInk`, `testANearlyRoundLoopSnapsToTheEllipseInItsBoxFromWhereItStarted`, `testAnOpenLoopStaysInk`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the simulator or the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *Shapes that snap*

#### Use Case:
- **As someone** boxing or circling things on the board
- **I want to** hold the Pencil at the end of a box or a loop to clean it up
- **so that** the board reads as tidy as the web board's

#### Acceptance Criteria:
- **Scenario:** A box and a loop
- **Given:** I draw a nearly square box, and a closed loop, each ending where it started
- **When:** I hold the Pencil still at the end of each for about half a second, then lift
- **Then:** the box becomes a rectangle square to the page and the loop an ellipse in its box; a tilted box or an open loop stays as I drew it; one undo gives each raw stroke back

---

### User Story 925:

- **Summary:** Nothing snaps without the hold
- **Status:** implemented in [f2d3e1d](https://github.com/idvorkin/context-grabber/commit/f2d3e1d); verified by host tests (`BoardShapeSnapTests`: `testOnlyAPencilHeldStillHalfASecondAtTheEndAsks`, `testWritingNeverSnaps`; `just test`) and the Mac build (`just native-build-mac`); a held lift whose stroke a margin hold, a pick-up or a scratch-out took no longer arms the next stroke, in [acb476c](https://github.com/idvorkin/context-grabber/commit/acb476c); not yet seen on the iPad
- **Spec:** [Handwriting to text, and shapes that snap](../superpowers/specs/2026-11-16-whiteboard-to-text-and-snap-design.md), *Shapes that snap*

#### Use Case:
- **As someone** writing and drawing freely
- **I want to** have my strokes left exactly as drawn unless I hold the Pencil at their end
- **so that** my handwriting and sketches never change under me

#### Acceptance Criteria:
- **Scenario:** A line lifted at once
- **Given:** I draw a nearly straight line, and a word of writing
- **When:** I lift the Pencil at the end of each without holding it still
- **Then:** both stay exactly as I drew them

---

### User Story 910:

- **Summary:** I join two things with an arrow I drew
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb), and [7097c4e](https://github.com/idvorkin/context-grabber/commit/7097c4e) (Connect sits clear of To text, which covered it); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; on the simulator, `WhiteboardConnectUITests` (`testALassoedArrowBetweenTwoWordsConnectsThem`, passing after 7097c4e); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** sketching how ideas connect
- **I want to** lasso an arrow I drew between two things and tap Connect
- **so that** the arrow stays joined to them, as on the web board

#### Acceptance Criteria:
- **Scenario:** Connect a drawn arrow
- **Given:** two words of mine on the board and an arrow I drew from one to the other, circled with the lasso
- **When:** I tap Connect beside the selection
- **Then:** my arrow's ink is replaced by a clean arrow from the first word's facing side to the second's, and one Undo named Connect gives my arrow back

---

### User Story 911:

- **Summary:** A connector follows what it joins
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** rearranging a diagram
- **I want to** move one end of a connector
- **so that** the arrow goes with it without my redrawing it

#### Acceptance Criteria:
- **Scenario:** Move an end
- **Given:** a connector between two things
- **When:** I lasso-move one of them, or a push, a paste or a fold moves it
- **Then:** the arrow is drawn again from where they are now, and the Undo of that move puts the arrow back too

---

### User Story 912:

- **Summary:** A connector bends once around something in its way
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** reading a diagram
- **I want to** see an arrow go around a box rather than through it
- **so that** the arrows stay readable

#### Acceptance Criteria:
- **Scenario:** A group in the way
- **Given:** a connector between two things, and a kept text or one of Larry's groups put on the straight line between them
- **When:** the board redraws the connector
- **Then:** it bends once, an L with a level leg and an upright one, that crosses nothing; when the thing in the way moves off, it is straight again

---

### User Story 913:

- **Summary:** Larry joins two things by name
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As Larry,** Igor's coach, drawing on the board
- **I want to** draw a connector between two things by their names
- **so that** my diagram on Igor's board stays joined when he rearranges it

#### Acceptance Criteria:
- **Scenario:** Connector by names
- **Given:** a group of mine and a kept text on the board
- **When:** my answer asks for a connector from the group's name to the text's
- **Then:** an arrow joins them, part of my answer's one Undo; a name the board lacks draws nothing and my next turn lists it missing

---

### User Story 914:

- **Summary:** Larry joins two things by pointing at them
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As Larry,** drawing on the board from its picture
- **I want to** give a connector's ends as points
- **so that** I can join what I see without knowing its names

#### Acceptance Criteria:
- **Scenario:** Connector by points
- **Given:** two things on the board
- **When:** my connector's ends are points on each
- **Then:** it joins the smallest thing under each point (a word of Igor's becomes one thing); with an end on bare paper it is a plain arrow

---

### User Story 915:

- **Summary:** A connector whose end is gone stays as plain ink
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As someone** erasing part of a diagram
- **I want to** rub out one thing an arrow points at
- **so that** I don't lose the arrow I still see

#### Acceptance Criteria:
- **Scenario:** Erase an end
- **Given:** a connector between two things
- **When:** I erase one of them
- **Then:** the arrow stays where it was, as plain ink that no longer follows anything

---

### User Story 916:

- **Summary:** Larry gets connectors back with the board's strokes
- **Status:** implemented in [c39ea97](https://github.com/idvorkin/context-grabber/commit/c39ea97) and [c93c4bb](https://github.com/idvorkin/context-grabber/commit/c93c4bb); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Step 5: connectors*

#### Use Case:
- **As Larry,** reading Igor's board
- **I want to** know which strokes are connectors and what they join
- **so that** I can reason about the diagram, not only its picture

#### Acceptance Criteria:
- **Scenario:** The strokes snapshot
- **Given:** a connector on the board
- **When:** the board sends Larry its strokes
- **Then:** the connector is a stroke under its name, drawn in every picture I render, whose notes say it is a connector, what it joins, its sides and its route

---

### User Story 900:

- **Summary:** Larry's picture shows a folded section whole, flagged folded
- **Status:** implemented in [568bd4a](https://github.com/idvorkin/context-grabber/commit/568bd4a) (header and "▸ N lines folded"); changed to the whole section in [a043ea5c](https://github.com/idvorkin/context-grabber/commit/a043ea5c) (#1013); verified by host tests (`BoardFoldMarkerTests`, `BoardFoldPictureTests`); `just test` and the Mac build (`just native-build-mac`); the iPad simulator (rung 2, `WhiteboardOutlineUITests.testLarrysPictureShowsAFoldedSectionWholeAndShaded`); the picture not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*
- **Issues:** [#1013](https://github.com/idvorkin/context-grabber/issues/1013) (Igor, 2026-11-20, W4 on PR #912: "the picture shows the whole section, flagged as folded")

#### Use Case:
- **As someone** folding sections of a board I talk over with Larry
- **I want to** have the picture Larry gets show a folded section in full, marked as folded
- **so that** he never loses what I set aside, and still knows I set it aside

#### Acceptance Criteria:
- **Scenario:** A folded section in Larry's picture
- **Given:** a header folded over two lines, with more writing below the section
- **When:** Larry's turn takes a picture of the board (or I Send it, or Claude takes its turn)
- **Then:** the picture shows the two folded lines under the header, shaded light grey across the page, with a grey "folded" in the margin at their top and a grey ▸ beside the header; the writing below comes after them, and a fold folded inside the section is drawn whole inside the shading
- **And:** the picture has no "▸ 2 lines folded", and the board on the iPad stays folded

---

### User Story 901:

- **Summary:** A folded header says on the board how many lines it holds
- **Status:** implemented in [568bd4a](https://github.com/idvorkin/context-grabber/commit/568bd4a); verified by host tests (`BoardFoldMarkerTests`); `just test` and the Mac build (`just native-build-mac`); the simulator (`WhiteboardOutlineUITests`, 197 s), `testAFoldShowsItsLinesBesideTheHeader`; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** folding sections on the board
- **I want to** see "▸ N lines folded" beside a folded header
- **so that** I know what the fold holds and have something to erase to take it

#### Acceptance Criteria:
- **Scenario:** Folding a header
- **Given:** a header with two indented lines under it
- **When:** I tap the margin beside it to fold it
- **Then:** "▸ 2 lines folded" shows in small grey letters just right of the header's row, moves with it, and goes when I unfold

---

### User Story 902:

- **Summary:** The eraser across a fold's marker erases the whole section
- **Status:** implemented in [040dbd8](https://github.com/idvorkin/context-grabber/commit/040dbd8), its file's import in [bbb34db](https://github.com/idvorkin/context-grabber/commit/bbb34db); verified by host tests (`BoardFoldEraseTests.testTheEraserAcrossTheMarkerErasesTheWholeFoldAndClosesUp`, `testErasingAFoldTakesTheFoldsFoldedInsideIt`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad. A called-off eraser stroke erased the fold anyway (context-grabber-0m2d): stories 906 and 907, fixed in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** done with a folded section
- **I want to** rub the eraser across its "▸ N lines folded" and have the header and everything folded under it go
- **so that** a section I folded away is erased in one stroke, without unfolding it first

#### Acceptance Criteria:
- **Scenario:** Erasing a fold by its marker
- **Given:** a folded header with a line of ink below the fold
- **When:** I draw the eraser across "▸ N lines folded"
- **Then:** the header, its folded lines and any folds folded inside it are erased, and the ink below closes up to where the header was, in whole lines

---

### User Story 904:

- **Summary:** One Undo brings a fold erased by its marker back, still folded
- **Status:** implemented in [040dbd8](https://github.com/idvorkin/context-grabber/commit/040dbd8); verified by host tests (`BoardFoldEraseTests.testAnUndoBringsTheFoldBackStillFolded`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** who erased a folded section by mistake
- **I want to** have one Undo bring it all back as it was
- **so that** erasing a whole section in one stroke is never a loss

#### Acceptance Criteria:
- **Scenario:** Undo brings it back folded
- **Given:** a fold I just erased by its marker
- **When:** I tap Undo once
- **Then:** the header comes back still folded, with "▸ N lines folded" beside it, and the ink below is back where it was

---

### User Story 903:

- **Summary:** The eraser across a folded header erases the whole section
- **Status:** implemented in [040dbd8](https://github.com/idvorkin/context-grabber/commit/040dbd8), its file's import in [bbb34db](https://github.com/idvorkin/context-grabber/commit/bbb34db); verified by host tests (`BoardFoldEraseTests.testTheHeadersInkTakesTheFoldOnlyWhenAsked`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad. A called-off eraser stroke erased the fold anyway (context-grabber-0m2d): stories 906 and 907, fixed in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** erasing a folded header
- **I want to** have its folded lines go with it
- **so that** no folded ink is left hidden on the board with no header to unfold it

#### Acceptance Criteria:
- **Scenario:** Erasing a folded header's ink
- **Given:** a folded header
- **When:** I draw the eraser across the header's own ink
- **Then:** the header and everything folded under it are erased and the ink below closes up; Undo twice brings the header back still folded (the eraser's own step, then the fold's)

---

### User Story 905:

- **Summary:** A scratch-out over a fold's marker or its header line erases the whole section
- **Status:** implemented in [1cee727](https://github.com/idvorkin/context-grabber/commit/1cee727), its file's import in [bbb34db](https://github.com/idvorkin/context-grabber/commit/bbb34db); verified by host tests (`BoardFoldEraseTests.testAScratchOutOverTheMarkerTakesTheFold`); `just test` and the Mac build (`just native-build-mac`); not yet seen with the Pencil on the iPad. Staying gone on the sheet and to Larry (#1015: PaperKit refused the board's markup and kept the section) fixed in [cb1ab206](https://github.com/idvorkin/context-grabber/commit/cb1ab206); verified on the iPad simulator (`WhiteboardScratchOutUITests.testAScratchedOutFoldStaysGoneWhenHeWritesOn`, failing before the fix: wanted 1 stroke, PaperKit held 3)
- **Issues:** [#1015](https://github.com/idvorkin/context-grabber/issues/1015)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*; [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*

#### Use Case:
- **As someone** who scratches out what I'm done with
- **I want to** scratch out a folded section by its marker or its header line and have it all go
- **so that** scratch-out takes a fold the way the eraser does, with no folded ink left hidden

#### Acceptance Criteria:
- **Scenario:** Scratching out a fold
- **Given:** a folded header with a line of ink below the fold
- **When:** I scratch out its "▸ N lines folded" or its header line with a fast zigzag
- **Then:** the header, everything folded under it and the zigzag go, on the sheet and in what Larry gets, and stay gone when I write on; the ink below closes up to where the header was, and one Undo brings the section back still folded with the ink below where it was

---

### User Story 906:

- **Summary:** An eraser stroke the iPad calls off takes no fold by its marker
- **Status:** implemented in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f); verified by the host test `BoardFoldEraseTests.testACalledOffEraserTakesAFoldOnlyWhereTheHeadersInkWent`, `just native-test` and `just native-build-mac`; the called-off touch not yet seen on the iPad (its `erase_fold_cancelled` line will say)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** whose palm lands while I'm erasing near a folded section
- **I want to** have an eraser stroke the iPad calls off leave the fold alone
- **so that** a whole section is erased only by a stroke I finished

#### Acceptance Criteria:
- **Scenario:** A called-off eraser stroke across the marker
- **Given:** a folded header with a line of ink below the fold
- **When:** I draw the eraser across "▸ N lines folded" and the iPad calls the touch off before it lifts (a palm landing, a system gesture taking it)
- **Then:** the header stays folded with its "▸ N lines folded", and the ink below stays where it was

---

### User Story 907:

- **Summary:** A called-off eraser stroke that took a folded header's ink takes its section too
- **Status:** implemented in [530ebf7a](https://github.com/idvorkin/context-grabber/commit/530ebf7a), its decision renamed in [cbf0304f](https://github.com/idvorkin/context-grabber/commit/cbf0304f); verified by the host test `BoardFoldEraseTests.testACalledOffEraserTakesAFoldOnlyWhereTheHeadersInkWent`, `just native-test` and `just native-build-mac`; whether the iPad keeps the eraser's own erase when it calls the touch off is not yet seen (the `erase_fold_cancelled` line will say)
- **Issues:** context-grabber-0m2d
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Headers fold their sections*

#### Use Case:
- **As someone** whose eraser stroke across a folded header was called off
- **I want to** have the section go only if the header's ink went
- **so that** no folded lines are left hidden under no header, and none are lost under a header that stayed

#### Acceptance Criteria:
- **Scenario:** A called-off eraser stroke across the header's ink
- **Given:** a folded header
- **When:** I draw the eraser across the header's own ink, the iPad calls the touch off before it lifts, and the eraser took all of the header's ink anyway
- **Then:** the header and everything folded under it are erased and the ink below closes up, as for a finished stroke; had any of the header's ink stayed, the section would stay folded as it was

---

### User Story 950:

- **Summary:** The board's cheat sheet is one tap away
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) the ? opened *How this board works* listing every gesture the test names; its close and the fixed test's full pass not yet seen (the Mac's screen was locked for the rerun); not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*

#### Use Case:
- **As someone** drawing on a board whose gestures I don't all remember
- **I want to** open a list of them with one tap on the board, as on Larry's web board
- **so that** I find the margin, hold and Pencil gestures without asking anyone

#### Acceptance Criteria:
- **Scenario:** Open the cheat sheet
- **Given:** a board drawn on this iPad
- **When:** I tap **?** at the board's top right
- **Then:** *How this board works* opens and lists the margin tap, the margin hold with a finger or the Pencil, the hold
  on the page, the Pencil on a word, scratch-out, the lasso's *To text*, the shape snap, *Keep all*, *Fold all* and the
  levels, and Feedback; *Done* closes it and the board is as it was

---

### User Story 951:

- **Summary:** The cheat sheet's buttons leave the top bar alone
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) the Board menu, Paste, the mic, Ghosts, Larry's turn and Send stayed in the top bar with ? and Feedback on the board; at the lower right the Pencil's tool palette took their taps, so they moved to the top right in 2a01b5c; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*
- **Issues:** [#848](https://github.com/idvorkin/context-grabber/issues/848) (the Board menu must stay in the iPad's bar and close on a pick)

#### Use Case:
- **As someone** who reaches for the Board menu, Larry's turn and Send many times a board
- **I want to** have **?** and Feedback added beside the paper, not to the top bar or the Board menu
- **so that** nothing I already use moves under *More* or makes the menu too tall to close

#### Acceptance Criteria:
- **Scenario:** The bar after the change
- **Given:** a board drawn on this iPad
- **When:** it opens
- **Then:** the Board menu, Paste, the mic, Ghosts, Larry's turn and Send are in the top bar as before, and **?** and
  Feedback float at the board's top right; a look-only board shows Feedback only

---

### User Story 952:

- **Summary:** Feedback from the board is one tap
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) a tap on Feedback opened *Report a problem* over the board; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*

#### Use Case:
- **As someone** who reports the board's bugs to Larry from the board itself
- **I want to** tap Feedback on the board and get the report sheet with the board's picture and the log
- **so that** I don't have to shake the iPad or leave the board to report

#### Acceptance Criteria:
- **Scenario:** Report from the board
- **Given:** a board open
- **When:** I tap Feedback at the board's top right
- **Then:** the *Report a problem* sheet opens over the board with a picture of the board as it was and the session
  log, as a shake would open it

---

### User Story 953:

- **Summary:** The board says the feedback was logged
- **Status:** implemented in [e839408](https://github.com/idvorkin/context-grabber/commit/e839408), [2a01b5c](https://github.com/idvorkin/context-grabber/commit/2a01b5c); `just test` and the Mac build (`just native-build-mac`) green. On the iPad simulator (rung 2, `WhiteboardHelpFeedbackUITests`, 2026-11-17) not yet seen: the run that would log a note and see *Feedback logged ✓* was the rerun the locked screen stopped; not yet seen on the iPad
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *How this board works, and Feedback*

#### Use Case:
- **As someone** who just sent feedback from the board
- **I want to** see on the board that it was taken
- **so that** I know it landed without going to look for it

#### Acceptance Criteria:
- **Scenario:** Log it
- **Given:** the report sheet opened from the board, with a note written
- **When:** I tap *Log it*
- **Then:** the sheet closes and *Feedback logged ✓* shows beside the board's buttons for a few seconds; *logged*, not
  *sent*, as the report is saved and queued for iCloud and the app is not told when it arrives

---

### User Story 970:

- **Summary:** A refused change of Larry's says so on the board
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry: "show a chip so I'm not guessing" when Larry's push is refused
- **Issues:** `testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard` on main 2510b8c6, 2026-11-17: the chip moved under ? and Feedback (#929), and a tap on its bare × glyph went through to the paper and drew a dot (`ui_touch_begin` on `PKTiledGestureView` at 797, 202.5; no `board_blocked dismissed`)
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`); and on the simulator (`WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`, rung 2). Retry and × take a finger's width in [753c9ec](https://github.com/idvorkin/context-grabber/commit/753c9ec); verified by `just test`, the Mac build, and on the simulator (`WhiteboardPaperGhostsUITests`, the chip test included, and `WhiteboardHelpFeedbackUITests`, rung 2)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** writing while Larry edits the board
- **I want to** see when one of his changes couldn't be applied
- **so that** I'm not left wondering why nothing moved

#### Acceptance Criteria:
- **Scenario:** Refused
- **Given:** I wrote after Larry looked
- **When:** his change comes back refused
- **Then:** a chip in his purple says *Larry's edit blocked · Retry*, with × beside it, and nothing on the board moved

---

### User Story 971:

- **Summary:** Retry hands Larry the board again
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`); and on the simulator (`WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`, rung 2)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** whose board moved on before Larry's change arrived
- **I want to** tap Retry
- **so that** Larry looks at the board as it is and sends a fresh change

#### Acceptance Criteria:
- **Scenario:** Retry
- **Given:** the chip shows
- **When:** I tap Retry
- **Then:** the chip goes and it is Larry's turn, with the board as it is now and what happened to his last change; his refused change is never replayed

---

### User Story 972:

- **Summary:** × puts the chip away
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`); and on the simulator (`WhiteboardPaperGhostsUITests.testARefusedPushShowsTheChipAndRetryHandsLarryTheBoard`, rung 2)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** who doesn't need Larry to try again
- **I want to** put the chip away
- **so that** it doesn't sit on the board once I've seen it

#### Acceptance Criteria:
- **Scenario:** Dismiss
- **Given:** the chip shows
- **When:** I tap ×
- **Then:** the chip goes and nothing is sent to Larry

---

### User Story 973:

- **Summary:** A selection dropped onto writing pushes the writing down
- **Issues:** Igor on the iPad, 2026-11-17, via Larry: "same as reflowing stuff below, as opposed to drop on top"; [#945](https://github.com/idvorkin/context-grabber/issues/945) (2026-11-18: a box PaperKit showed after a margin tap dragged 223 strokes onto writing, twice, and nothing was pushed: the move came with no selection, so it was never taken for a drop)
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by host tests (`BoardRoomDropTests`), `just test` and the Mac build (`just native-build-mac`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *A dragged selection makes room*

#### Use Case:
- **As someone** rearranging my notes
- **I want to** lasso a few lines and drag them down between others
- **so that** they slot in and the lines below make room, instead of landing on top of them

#### Acceptance Criteria:
- **Scenario:** Dropped on writing
- **Given:** lines of writing down the page
- **When:** I lasso one, drag it and let go over a line further down
- **Then:** what I dragged stays where I let go, and from the clear line nearest its top everything below slides down by whole lines, half a line of air under what I dropped; ink above that line doesn't move

---

### User Story 974:

- **Summary:** The drag and the push are one Undo
- **Issues:** Igor on the iPad, 2026-11-17, via Larry
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by host tests (`BoardRoomDropTests`), `just test` and the Mac build (`just native-build-mac`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *A dragged selection makes room*

#### Use Case:
- **As someone** who dropped a selection in the wrong place
- **I want to** tap Undo once
- **so that** both the selection and the ink it pushed go back where they were

#### Acceptance Criteria:
- **Scenario:** One Undo
- **Given:** a drop that pushed the ink below
- **When:** I tap Undo once
- **Then:** the dragged ink is back where it started and the ink below is back up; the Undo is named *Move*

---

### User Story 975:

- **Summary:** A drop on clear paper moves only what I dragged
- **Issues:** Igor on the iPad, 2026-11-17, via Larry
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by host tests (`BoardRoomDropTests`), `just test` and the Mac build (`just native-build-mac`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *A dragged selection makes room*

#### Use Case:
- **As someone** moving a note into blank space
- **I want to** drop it there
- **so that** nothing else on the board shifts

#### Acceptance Criteria:
- **Scenario:** Clear paper
- **Given:** blank paper between two lines
- **When:** I drop a selection there, or so it only touches a line at its edge
- **Then:** only what I dragged moves

---

### User Story 976:

- **Summary:** A newer refusal replaces the chip
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** writing while Larry edits the board
- **I want to** see only his latest blocked change
- **so that** the board never fills with chips

#### Acceptance Criteria:
- **Scenario:** One chip
- **Given:** the chip shows
- **When:** another change of his is refused
- **Then:** the one chip stays, for the newer change

---

### User Story 977:

- **Summary:** Leaving the board forgets the chip
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** who leaves a board mid-change
- **I want to** find no chip for a board I've left
- **so that** nothing speaks for a board nobody is looking at

#### Acceptance Criteria:
- **Scenario:** Leaving the board
- **Given:** a change of his waiting for my Pencil
- **When:** I leave the board
- **Then:** no chip shows anywhere

---

### User Story 978:

- **Summary:** A change that applies clears the chip
- **Issues:** Igor on the iPad, build e61a582b, 2026-11-17, via Larry
- **Status:** implemented in [56e7f09](https://github.com/idvorkin/context-grabber/commit/56e7f09); verified by host tests (`BoardBlockedEditTests`), `just test` and the Mac build (`just native-build-mac`)
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *When Larry's edit is blocked*

#### Use Case:
- **As someone** whose board Larry has caught up with
- **I want to** have the chip go once his next change lands
- **so that** it never lingers after it stops being true

#### Acceptance Criteria:
- **Scenario:** Applied
- **Given:** the chip shows
- **When:** a later change of his applies
- **Then:** the chip goes

---

### User Story 979:

- **Summary:** Undo and Redo of a move never push
- **Issues:** Igor on the iPad, 2026-11-17, via Larry
- **Status:** implemented in [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a); verified by host tests (`BoardRoomDropTests`), `just test` and the Mac build (`just native-build-mac`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *A dragged selection makes room*

#### Use Case:
- **As someone** stepping back and forth through a move
- **I want to** have Undo and Redo put ink only where it was
- **so that** stepping through history never opens room again

#### Acceptance Criteria:
- **Scenario:** Undo never pushes
- **Given:** a move undone
- **When:** I tap Redo, or Undo again
- **Then:** nothing else opens room

---

### User Story 969:

- **Summary:** A word slid along its own line moves nothing else
- **Issues:** review of stories 973–975, 2026-11-17: a word slid sideways onto its neighbour pushed its own line down
- **Status:** implemented in the review fix that follows [5fd311a](https://github.com/idvorkin/context-grabber/commit/5fd311a) on this branch; verified by host tests (`BoardRoomDropTests`); the drag itself not yet seen on the iPad: the simulator can't work the lasso
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *A dragged selection makes room*

#### Use Case:
- **As someone** rearranging words within a line
- **I want to** slide one along its line, even over its neighbour
- **so that** the line stays put and only the word moves

#### Acceptance Criteria:
- **Scenario:** Along its own line
- **Given:** a line of words
- **When:** I lasso one and drop it further along the same line, over the word beside it
- **Then:** only what I dragged moves

---

### User Story 940:

- **Summary:** A finger tap on a kept text rewords it in place
- **Issues:** bead context-grabber-yfrl (the UI test read the old words before the new ones were drawn: a flake, not the app)
- **Status:** implemented in [ea93cbb](https://github.com/idvorkin/context-grabber/commit/ea93cbb); verified by host tests (`BoardRewordTests`: `testItWrapsAtTheWiderOfItsOwnWidthAndTheWebBoardsWithinThePage`, `testWordsWrapByWordKeepTheirOwnBreaksAndALongWordBreaks`, `testTheNewWordsStartWhereTheOldOnesDid`; `just test`) and the Mac build (`just native-build-mac`); on the simulator against the fake Cockpit (`WhiteboardRewordUITests.testATapOnAKeptTextRewordsItInPlace`, rung 2); the test waits for the new words before reading them in [cafe6cc1](https://github.com/idvorkin/context-grabber/commit/cafe6cc1) (context-grabber-yfrl), passing 3 runs of 3 on the iPad simulator (rung 2); not yet seen on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As someone** with one of Larry's texts, a To text result or my own typed text on the board
- **I want to** tap it and change its words where it is
- **so that** fixing a word doesn't mean erasing the whole text and starting again

#### Acceptance Criteria:
- **Scenario:** A word changed
- **Given:** a kept text reading "hello" on a board drawn on here, and no marks of Larry's showing
- **When:** I tap it with a finger, change the words to "hello world" and press Return
- **Then:** the text shows "hello world" from the same top-left in its own lettering, size and colour, wrapped by word to its width; one undo brings "hello" back

---

### User Story 941:

- **Summary:** Emptied words delete the text; unchanged words change nothing
- **Status:** implemented in [ea93cbb](https://github.com/idvorkin/context-grabber/commit/ea93cbb); verified by host tests (`BoardRewordTests.testNewWordsAreTrimmedAndCappedEmptyDeletesSameChangesNothing`; `just test`) and the Mac build (`just native-build-mac`); the opening tap's dot taken back in [9191a96](https://github.com/idvorkin/context-grabber/commit/9191a96); on the simulator against the fake Cockpit (`WhiteboardRewordUITests.testEmptyWordsDeleteTheText`, rung 2); not yet seen on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As someone** editing a kept text
- **I want to** empty it to delete it, and leave it untouched to change nothing
- **so that** the editor is also the quickest way to remove a text, and opening it by mistake costs nothing

#### Acceptance Criteria:
- **Scenario:** Emptied, and left alone
- **Given:** a kept text open for editing
- **When:** I delete all its words and press Return, or open another and tap off it without typing
- **Then:** the first text goes, one undo bringing it back; the second stays exactly as it was, with no undo step for it

---

### User Story 942:

- **Summary:** Larry knows a reworded text as the same text
- **Status:** implemented in [ea93cbb](https://github.com/idvorkin/context-grabber/commit/ea93cbb); verified by host tests (`BoardRewordTests`: `testAnUndoneWordingsVersionDoesntDissolveTheText`, `testLarryHearsWhichTextWasReworded`; `just test`) and the Mac build (`just native-build-mac`); not yet seen against the real Cockpit or on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *Rewording a kept text*

#### Use Case:
- **As** Larry, reading Igor's board
- **I want to** see a reworded text under the id I knew it by, with its new words
- **so that** a later move or answer can still name it

#### Acceptance Criteria:
- **Scenario:** Reworded
- **Given:** a kept text Larry knows as `text-1`
- **When:** Igor rewords it
- **Then:** Larry hears a strokes change that names `text-1` as reworded, and the board he reads has `text-1` with the new words; an undo gives him the old words under `text-1` again

---

### User Story 943:

- **Summary:** A held shape shows clean before the Pencil lifts
- **Status:** implemented in [2640a36](https://github.com/idvorkin/context-grabber/commit/2640a36); verified by host tests (`BoardShapeSnapTests`: `testHeldStillTheCleanShapeShowsBeforeTheLift`, `testWritingHeldStillShowsNothing`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad (the simulator has no Pencil to hold)
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A snap you see before you lift*

#### Use Case:
- **As someone** drawing a box or a line with the Pencil
- **I want to** see the clean shape as soon as I hold still, before I lift
- **so that** I know it will snap, and to what, while I can still change my mind

#### Acceptance Criteria:
- **Scenario:** Held, then lifted
- **Given:** I draw a nearly square box on a board drawn on here
- **When:** I hold the Pencil still at its end for about half a second, with it still down
- **Then:** the box shows as a clean rectangle in my pen's colour and width at once; lifting keeps it, one undo giving my raw box back

---

### User Story 944:

- **Summary:** Moving on after the clean shape shows brings the raw stroke back
- **Status:** implemented in [2640a36](https://github.com/idvorkin/context-grabber/commit/2640a36); verified by host tests (`BoardShapeSnapTests.testMovingOnTakesTheShapeAwayUntilHeldAgain`; `just test`) and the Mac build (`just native-build-mac`); not yet seen on the iPad
- **Spec:** [Rewording a kept text, and a snap you see before you lift](../superpowers/specs/2026-11-17-whiteboard-reword-and-live-snap-design.md), *A snap you see before you lift*

#### Use Case:
- **As someone** who held still by accident in the middle of a drawing
- **I want to** keep drawing and have my stroke stay mine
- **so that** a pause never turns a sketch into a shape I didn't ask for

#### Acceptance Criteria:
- **Scenario:** Held, then moved on
- **Given:** a line I drew whose clean shape is showing, the Pencil still down
- **When:** I move the Pencil on to draw a curl, and lift without holding still again
- **Then:** the clean line goes as I move, the raw stroke shows again, and it lands exactly as I drew it

---

### User Story 917:

- **Summary:** Larry's connector mark shows as the arrow it would be
- **Status:** implemented in [4749f2a](https://github.com/idvorkin/context-grabber/commit/4749f2a) and [1ade3f5](https://github.com/idvorkin/context-grabber/commit/1ade3f5); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build (`just native-build-mac`), and on the simulator (`WhiteboardConnectUITests.testLarrysConnectorMarkKeepsAsAConnector`, rung 2); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's connector marks*

#### Use Case:
- **As Larry,** answering Igor on the board
- **I want to** put a connector among my reply's marks, by names or by points on my picture
- **so that** Igor sees the live arrow I mean, routed as it will be, before he keeps it

#### Acceptance Criteria:
- **Scenario:** A connector mark
- **Given:** a reply of mine with a connector mark between two things on Igor's board
- **When:** it lands on the board
- **Then:** a ghost arrow runs from one thing's facing side to the other's, around anything in its way, beside my other marks

---

### User Story 918:

- **Summary:** Keeping Larry's connector mark makes a real connector
- **Status:** implemented in [4749f2a](https://github.com/idvorkin/context-grabber/commit/4749f2a) and [1ade3f5](https://github.com/idvorkin/context-grabber/commit/1ade3f5); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build (`just native-build-mac`), and on the simulator (`WhiteboardConnectUITests.testLarrysConnectorMarkKeepsAsAConnector`, rung 2); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's connector marks*

#### Use Case:
- **As someone** keeping Larry's diagram
- **I want to** keep his arrows as connectors
- **so that** they stay joined when I make room or fold, as on the web board

#### Acceptance Criteria:
- **Scenario:** Keep a connector mark
- **Given:** Larry's connector mark between two things, showing as a ghost
- **When:** I tap Keep, or Keep all
- **Then:** it becomes a connector joining them (with Keep all, in the one Undo), and a push between them redraws it to where they are

---

### User Story 919:

- **Summary:** A connector mark that can't land is plain or nothing
- **Status:** implemented in [4749f2a](https://github.com/idvorkin/context-grabber/commit/4749f2a) and [1ade3f5](https://github.com/idvorkin/context-grabber/commit/1ade3f5); verified by host tests (`BoardConnectorsTests`), `just test` and the Mac build (`just native-build-mac`), and on the simulator (`WhiteboardConnectUITests.testLarrysConnectorMarkKeepsAsAConnector`, rung 2); not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry's connector marks*

#### Use Case:
- **As someone** keeping Larry's marks
- **I want to** see nothing broken when his connector can't join
- **so that** his marks stay readable

#### Acceptance Criteria:
- **Scenario:** A mark with an end nowhere
- **Given:** Larry's connector mark with an end on bare paper, or one naming something the board doesn't have
- **When:** it lands
- **Then:** the one on bare paper shows and keeps as a plain arrow where he drew it; the one naming nothing shows nothing and is set aside as if dismissed

---

### User Story 990:

- **Summary:** Larry replays a change on a copy of Igor's board and sees the result before sending it
- **Status:** implemented on branch `native/board-ops-harness`; verified by host tests (`BoardReplayTests`), `just test` and `just board-ops` on the night's three fixtures
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry checks a change before he sends it*
- **Issues:** [#936](https://github.com/idvorkin/context-grabber/issues/936)

#### Use Case:
- **As Larry,** about to change Igor's board
- **I want to** run my change on a copy of his board with the board's own rules and see the board after
- **so that** I never test on his real board, and a mess shows up on my screen instead of his

#### Acceptance Criteria:
- **Scenario:** A change checked on a copy
- **Given:** a copy of a board as it sends me its strokes, and a batch of my changes
- **When:** I run `just board-ops` with the two, on the Mac
- **Then:** within seconds I get the `op_result` the iPad would answer, the names my change moved, erased, drew and left as ghosts, a picture of the board before and after with those marked, and the board after
- **And:** tonight's three failures replay as they happened on the iPad: the Judge label missing (#937), the list landing on ink (#938) and the delete of ghosts missing (#939)

---

### User Story 991:

- **Summary:** A label Larry groups with his box lands with it, as ink
- **Status:** implemented on branch `native/board-ops-937-grouped-label`; verified by host tests (`BoardOpsInkTests`, `BoardReplayTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's Judge batch; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry groups ink*
- **Issues:** [#937](https://github.com/idvorkin/context-grabber/issues/937)

#### Use Case:
- **As Larry,** drawing a labelled block on Igor's board
- **I want to** send a box and its label grouped in one change
- **so that** both land together and move as one, with nothing left for Igor to keep

#### Acceptance Criteria:
- **Scenario:** A grouped box and label
- **Given:** a change of mine that draws a box, adds a text, and groups the two
- **When:** it applies on the board
- **Then:** the box and the label are both ink on the board at once, in my colour, with no ghost to keep
- **And:** my next turn has the label as a kept text under my name, no missing ids, and moving the group moves both
- **And:** one Undo takes both away

---

### User Story 992:

- **Summary:** Larry's text makes room instead of landing on my writing
- **Status:** implemented on branch `native/board-ops-938-text-room`; verified by host tests (`BoardRoomTests`, `BoardReplayTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's list batch; keeping a ghost with ink under it is not yet seen on the simulator or the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry writes plain text*
- **Issues:** [#938](https://github.com/idvorkin/context-grabber/issues/938)

#### Use Case:
- **As someone** writing on the board while Larry answers
- **I want to** have his text push my ink down the way a paste does
- **so that** his words and mine never sit on top of each other

#### Acceptance Criteria:
- **Scenario:** His list lands where I wrote
- **Given:** two lines of my writing under my diagram, and a change of Larry's that adds his list of lines there
- **When:** it applies
- **Then:** my two lines and everything under them move down in whole lines until they sit under his last line, my diagram above doesn't move, and none of his lines touch my ink
- **And:** one Undo puts my ink back up

- **Scenario:** His text on clear paper
- **Given:** a text of his that lands on blank paper
- **When:** it applies
- **Then:** nothing moves

- **Scenario:** I keep his ghost after writing under it
- **Given:** a ghost of his text, and my writing that has since reached under it
- **When:** I tap Keep on it
- **Then:** my writing below moves down clear of it, and one Undo takes back both

---

### User Story 993:

- **Summary:** Larry's change reaches his text ghost by the name he gave it
- **Status:** implemented on branch `native/board-ops-939-ghost-ids`; verified by host tests (`BoardReplayTests`, `WhiteboardGhostTurnsTests`), `just test`, the Mac build (`just native-build-mac`) and `just board-ops` on the night's delete batch; not yet seen on the iPad
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry writes plain text*
- **Issues:** [#939](https://github.com/idvorkin/context-grabber/issues/939)

#### Use Case:
- **As Larry,** taking back text I put on Igor's board
- **I want to** delete or move my text by its name whether Igor has kept it yet or not
- **so that** what I take back is gone, and never comes back when he taps Keep later

#### Acceptance Criteria:
- **Scenario:** Delete a text still showing as a ghost
- **Given:** five lines of mine still showing as ghosts
- **When:** my change deletes them by name
- **Then:** the five ghosts go, my change reports no missing ids, and there is nothing left for Igor to keep

- **Scenario:** Move a ghost by name
- **Given:** a text of mine still showing as a ghost
- **When:** my change moves it by its name
- **Then:** the ghost moves, and once kept it is a kept text under the same name

---

### User Story 994:

- **Summary:** A label inside one of Larry's boxes can be tapped on its words
- **Status:** implemented in [75eef936](https://github.com/idvorkin/context-grabber/commit/75eef936) (the reproduction: `just board-ops` replays his marks and tries a tap on each), [491cab14](https://github.com/idvorkin/context-grabber/commit/491cab14), [13e47d0a](https://github.com/idvorkin/context-grabber/commit/13e47d0a) and [80f9873a](https://github.com/idvorkin/context-grabber/commit/80f9873a) (the nearest mark takes the tap); verified by host tests (`BoardMarksReplayTests`, failing on the old rule first), `just test`, the Mac build (`just native-build-mac`), `just board-ops` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests`, rung 2, 2026-11-17); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*; [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry checks a change before he sends it*
- **Issues:** [#941](https://github.com/idvorkin/context-grabber/issues/941): Larry's four named boxes of 18:26, 2026-11-17 (board 13f700bf, build 10b84a5f): all eleven marks showed (`paper_ghosts` count 11, past_side false); Igor's three taps each chose a box or a line and he kept those three; a tap on the upper half of a name went to its box (38–57% of each name's box, by `just board-ops`); and Larry's next reply replaced the eight left, the four names among them

#### Use Case:
- **As someone** keeping Larry's labelled boxes one at a time
- **I want to** tap a name inside a box and get the name, and tap the box's side and get the box
- **so that** no mark of his is out of my reach because another was drawn first

#### Acceptance Criteria:
- **Scenario:** A name inside its box
- **Given:** Larry's box with a name inside it, the box first in his reply
- **When:** I tap on the name's letters, or between them
- **Then:** Keep and Dismiss show beside the name, not the box

---

### User Story 996:

- **Summary:** A tap on the side of Larry's labelled box chooses the box
- **Status:** implemented in [75eef936](https://github.com/idvorkin/context-grabber/commit/75eef936) (the reproduction: `just board-ops` replays his marks and tries a tap on each), [491cab14](https://github.com/idvorkin/context-grabber/commit/491cab14), [13e47d0a](https://github.com/idvorkin/context-grabber/commit/13e47d0a) and [80f9873a](https://github.com/idvorkin/context-grabber/commit/80f9873a) (the nearest mark takes the tap); verified by host tests (`BoardMarksReplayTests`, failing on the old rule first), `just test`, the Mac build (`just native-build-mac`), `just board-ops` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests`, rung 2, 2026-11-17); not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#941](https://github.com/idvorkin/context-grabber/issues/941)

#### Use Case:
- **As someone** keeping Larry's labelled boxes one at a time
- **I want to** tap a box's side and get the box, not the name inside it
- **so that** the box stays in reach once its name is nearest the middle

#### Acceptance Criteria:
- **Scenario:** The box's side
- **Given:** Larry's box with a name inside it
- **When:** I tap on the box's side
- **Then:** Keep and Dismiss show beside the box

---

### User Story 997:

- **Summary:** Larry sees which of his marks a tap can't reach before he sends them
- **Status:** implemented in [75eef936](https://github.com/idvorkin/context-grabber/commit/75eef936); verified by host tests (`BoardMarksReplayTests`), `just test` and `just board-ops` on the 18:26 reply, on the Mac; off the Mac (Linux, #943, rung 1L not run) there are no fonts, so his labels are dropped and the step says so
- **Spec:** [Larry edits the board](../superpowers/specs/2026-11-16-whiteboard-board-ops-design.md), *Larry checks a change before he sends it*
- **Issues:** [#941](https://github.com/idvorkin/context-grabber/issues/941)

#### Use Case:
- **As Larry,** drawing marks for Igor to keep
- **I want to** replay my reply on a copy of his board and see where every mark lands and what a tap on each chooses
- **so that** I never send him a mark he can't reach

#### Acceptance Criteria:
- **Scenario:** Larry checks his marks first
- **Given:** a reply of his with marks and a copy of the board
- **When:** he runs `just board-ops` with them
- **Then:** the picture shows his marks where the iPad would, and every mark a tap can't reach is named, with the mark that takes the tap instead

---

### User Story 995:

- **Summary:** One tap keeps all of a reply of Larry's, as one group
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942): Igor, 2026-11-17 19:15, via Larry: "accept the group", after keeping his four named boxes one mark at a time; [#966](https://github.com/idvorkin/context-grabber/issues/966): Igor, 2026-11-19, board 302d5345, via Larry: he kept Larry's whole reply group, it sat on top of his own plan, and undo couldn't take it back (story 1007)

#### Use Case:
- **As someone** Larry answered with a little drawing of several marks
- **I want to** keep the whole of his reply with one tap, as one thing
- **so that** his drawing lands whole and moves as one, and one Undo takes it all back

#### Acceptance Criteria:
- **Scenario:** Keep group
- **Given:** Larry's reply of several marks showing, and I tap one of them
- **When:** I tap *Keep group* between Keep and Dismiss
- **Then:** every mark of that reply still showing becomes ink in his colours where it showed, none is left to keep, and one Undo takes them all back

---

### User Story 998:

- **Summary:** A reply of Larry's kept as a group moves as one
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** who kept Larry's drawing as a group
- **I want** it to move as one thing, whoever moves it
- **so that** his drawing never comes apart on my board

#### Acceptance Criteria:
- **Scenario:** It moves as one
- **Given:** a reply I kept as a group
- **When:** Larry moves it by the group's name, or a push opens room through it
- **Then:** all of it moves together, and Larry hears its strokes under that one group

---

### User Story 999:

- **Summary:** Keep group is offered only when more than one mark of the reply shows
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** keeping Larry's marks
- **I want** *Keep group* only when there is a group to keep
- **so that** the buttons beside one mark stay Keep and Dismiss

#### Acceptance Criteria:
- **Scenario:** One mark left
- **Given:** only one mark of his reply still shows
- **When:** I tap it
- **Then:** Keep and Dismiss show, and no *Keep group*

---

### User Story 1000:

- **Summary:** The buttons beside a chosen mark sit clear of the board's corner and wholly on screen
- **Status:** implemented in [1beb97f1](https://github.com/idvorkin/context-grabber/commit/1beb97f1); verified by host tests (`WhiteboardKeepGroupTests`, `BoardMarksReplayTests`: kept as one group, moved as one by its name), `just test`, the Mac build (`just native-build-mac`), `just board-ops --keep-group` on the 18:26 reply, and on the simulator (`WhiteboardPaperGhostsUITests.testKeepGroupKeepsHisWholeReplyAndOneUndoTakesItBack`, rung 2, 2026-11-17: Keep group · 3, buttons 36 points tall, one undo); the corner's clearance and a push through a kept group not yet seen on the iPad; the buttons narrowed to the view's width in a view too narrow for them, by host tests (`WhiteboardKeepGroupTests`)
- **Spec:** [Claude and Larry draw back](../superpowers/specs/2026-11-01-whiteboard-shapes-design.md), *A tap on a mark offers Keep and Dismiss*
- **Issues:** [#942](https://github.com/idvorkin/context-grabber/issues/942)

#### Use Case:
- **As someone** tapping one of Larry's marks near the edge of the board
- **I want** its buttons where I can tap them, clear of ? and Feedback
- **so that** a tap meant for Keep never opens help or misses the button

#### Acceptance Criteria:
- **Scenario:** Never under the corner
- **Given:** the mark I tapped is near the board's top right, where ? and Feedback (and *Larry's edit blocked*) sit
- **When:** the buttons show
- **Then:** they sit clear of that corner and wholly on screen, each at least 36 points each way, and a tap on them never reaches the paper

---

### User Story 1007:

- **Summary:** A keep stays one Undo, whatever the board does just after it
- **Status:** implemented in [3a4d2979](https://github.com/idvorkin/context-grabber/commit/3a4d2979); verified by host tests (`BoardUndoProbeTests`: PaperKit's step on top taken back, a keep on top left on the stack with nothing said to Larry and one Undo still taking the whole group back, with a fake stack and Foundation's `UndoManager`), `just test` and the Mac build (`just native-build-mac`); the simulator not run (the Mac's screen was locked, so UI tests could not start), and the iPad still to do: the log's `paper_undo` and `paper_undo_left_ours` lines will say whether the take-back ever reached a keep there
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *Every keep is a step of Undo of its own, and keeps it*
- **Issues:** [#966](https://github.com/idvorkin/context-grabber/issues/966): Igor, 2026-11-19, board 302d5345, via Larry: he kept Larry's whole reply group, it sat on top of his own plan, and undo couldn't take it back

#### Use Case:
- **As someone** who kept one of Larry's replies and then went on working round it
- **I want** Undo to take the keep back, whatever I did with the board straight after
- **so that** a keep I regret never gets stuck on top of my own writing

#### Acceptance Criteria:
- **Scenario:** The board's own take-back comes just after a keep
- **Given:** I have just tapped *Keep group* (or *Keep*, *Keep all* or *Tidy overlaps*), and the board then takes back a step of PaperKit's of its own, for a tap's dot, a zigzag or a dropped selection, before PaperKit's step is on top
- **When:** I press Undo until the keep is reached
- **Then:** the keep is still a step of its own, named for it, and one Undo takes every mark it kept back off the board

---

### User Story 1008:

- **Summary:** Undo and Redo on the board's own bar
- **Status:** implemented in [11536e97](https://github.com/idvorkin/context-grabber/commit/11536e97), [73d8e538](https://github.com/idvorkin/context-grabber/commit/73d8e538); verified by host tests (`BoardUndoButtonsTests`: dimmed on a new board, *Undo Keep group* for a named step, plain *Undo* for his stroke, PencilKit's *Add Strokes* read as plain *Undo*, no name on a dimmed button), `just test` and the Mac build (`just native-build-mac`); on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testTheBarsUndoAndRedoTakeAStepBackAndNameAKeptGroup`: 44 points wide, the bar's 36 high, plain *Undo* for a stroke, *Undo Keep group* taking the group back); not yet seen on the iPad
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *Undo and Redo on the board's own bar*
- **Issues:** [#965](https://github.com/idvorkin/context-grabber/issues/965): Igor, 2026-11-19, drawn on board 302d5345, via Larry: "an Undo button on the board itself"

#### Use Case:
- **As someone** drawing on a board with a finger or the Pencil
- **I want** Undo and Redo buttons on the board's bar
- **so that** I can take back a step without hunting for the tool picker's

#### Acceptance Criteria:
- **Scenario:** Undo a stroke and bring it back
- **Given:** a board drawn on here, and I have just drawn a stroke
- **When:** I tap *Undo* in the board's bar, then *Redo*
- **Then:** the stroke goes, then comes back; each button is at least 44 points wide and the bar's own height (36 points on the iPad), and each is dimmed when there is nothing for it to do

---

### User Story 1009:

- **Summary:** VoiceOver says what Undo will take back
- **Status:** implemented in [11536e97](https://github.com/idvorkin/context-grabber/commit/11536e97), [73d8e538](https://github.com/idvorkin/context-grabber/commit/73d8e538); verified by host tests (`BoardUndoButtonsTests`: dimmed on a new board, *Undo Keep group* for a named step, plain *Undo* for his stroke, PencilKit's *Add Strokes* read as plain *Undo*, no name on a dimmed button), `just test` and the Mac build (`just native-build-mac`); on the iPad simulator (rung 2, 2026-11-20, `WhiteboardPaperGhostsUITests.testTheBarsUndoAndRedoTakeAStepBackAndNameAKeptGroup`: 44 points wide, the bar's 36 high, plain *Undo* for a stroke, *Undo Keep group* taking the group back); not yet seen on the iPad
- **Spec:** [Whiteboard](../superpowers/specs/2026-11-01-whiteboard-design.md), *Undo and Redo on the board's own bar*
- **Issues:** [#965](https://github.com/idvorkin/context-grabber/issues/965)

#### Use Case:
- **As someone** using the board with VoiceOver
- **I want** the Undo and Redo buttons to name the step they act on
- **so that** I know a press takes back Larry's kept group and not my last stroke

#### Acceptance Criteria:
- **Scenario:** A named step on top
- **Given:** I have just kept a group of Larry's marks
- **When:** VoiceOver reaches the Undo button
- **Then:** it reads *Undo Keep group*; for my own stroke it reads *Undo*, and with nothing to undo it says the button is dimmed

---

### User Story 1030:

- **Summary:** An underline drawn under a line of my writing makes it a header
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); `WhiteboardOutlineUITests.testAnUnderlineDrawnUnderALineMakesItAHeader` written for the iPad simulator but not yet run (the Mac's screen was locked); not yet seen with the Pencil on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *An underline makes the line above it a header*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who underlines my headings as I would in a notebook
- **I want to** draw a line under a line of my writing and have it become a header
- **so that** I never reach for the margin to make one

#### Acceptance Criteria:
- **Scenario:** Underlining a line
- **Given:** a line of my writing with indented lines under it
- **When:** I draw a straight line under it across most of its width and lift the Pencil
- **Then:** a ▾ shows beside the line, and a tap on the ▾ folds the indented lines, the underline staying with the header

---

### User Story 1031:

- **Summary:** A # written at the start of a line makes it a header
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); a # can't be drawn by a UI test (straight drags only), so host only; not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *A # at the start of a line makes it a header*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967), [#1004](https://github.com/idvorkin/context-grabber/issues/1004) (it was recognised; its ▾ hid under the # written in the margin: story 1041)

#### Use Case:
- **As someone** who thinks in Markdown
- **I want to** write a # at the start of a line and have the line become a header
- **so that** a heading on the board reads as one in my notes

#### Acceptance Criteria:
- **Scenario:** Writing a #
- **Given:** a blank line
- **When:** I write a # (two level strokes crossing two upright ones) with no ink left of it
- **Then:** a ▾ shows beside it as soon as the # is finished, before I write the words

---

### User Story 1032:

- **Summary:** What I write on a header's line joins the header
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Writing more on a header's line*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who writing a header's words after its #
- **I want** the words I write on a header's line to be part of the header
- **so that** the fold's marker never lands on my words and the line stays one header

#### Acceptance Criteria:
- **Scenario:** Words after a #
- **Given:** a line made a header by a #
- **When:** I write words after the # on the same line, then fold it
- **Then:** the words fold and move with the header, "▸ N lines folded" sits past the last word, and there is one ▾

---

### User Story 1033:

- **Summary:** One Undo takes an underline or a #'s last bar and the header it made; Redo brings both back
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab), [11f70d23](https://github.com/idvorkin/context-grabber/commit/11f70d23); verified by host tests (`BoardInkHeadersTests`, the # by `testOneUndoOfAHashsLastBarTakesTheHeader`), `just test` and the Mac build (rung 1.5, 2026-11-19); a # can't be drawn by a UI test, so host only; the Undo itself not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Undoing a wrong guess*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** whose underline or # was only emphasis
- **I want** one Undo to take back a header the board guessed from my mark
- **so that** a wrong guess costs one tap

#### Acceptance Criteria:
- **Scenario:** Undoing the mark
- **Given:** a line made a header by the underline or the # I just drew
- **When:** I tap Undo, then Redo
- **Then:** Undo takes the underline or the #'s last bar and the ▾ goes; Redo brings both back

---

### User Story 1034:

- **Summary:** Not a header keeps my underline as ink and the board never makes it a header again
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Undoing a wrong guess*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who who underlined for emphasis and wants to keep the line
- **I want** to keep my underline but not the header
- **so that** the board stops treating that line as a header for good

#### Acceptance Criteria:
- **Scenario:** Not a header
- **Given:** a line made a header by an underline
- **When:** I choose *Not a header* from the hold menu and go on drawing elsewhere
- **Then:** the underline stays as ink, there is no ▾, and the line never becomes a header again on its own

---

### User Story 1035:

- **Summary:** A rule drawn across the page ends the sections above it
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab), [11f70d23](https://github.com/idvorkin/context-grabber/commit/11f70d23); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19); a rule can't be told from the simulator's straight "writing" by a UI test, so host only; not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *A rule across the page ends the sections above it*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967)

#### Use Case:
- **As someone** who whose next lines belong to no header
- **I want** to end a header's section where I draw a line across the page
- **so that** folding a header never takes what comes after the rule

#### Acceptance Criteria:
- **Scenario:** Ending a section
- **Given:** a header with indented lines, then a long line drawn across the page, then more indented lines
- **When:** I fold the header
- **Then:** only the lines above the rule fold (the last one too, even when the rule touches it), and the rule and what is below it slide up under the header

---

### User Story 1036:

- **Summary:** Larry's picture shows which lines are headers
- **Status:** implemented in [fda25548](https://github.com/idvorkin/context-grabber/commit/fda25548), [6bb7c2ab](https://github.com/idvorkin/context-grabber/commit/6bb7c2ab); verified by host tests (`BoardInkHeadersTests`), `just test` and the Mac build (rung 1.5, 2026-11-19) (the ▾ marks a picture would draw, `openHeaderMarks`); the drawn picture not yet seen on the simulator or the iPad. #1001: labelled "▾ header" past the line and kept in the picture's frame in [475f9070](https://github.com/idvorkin/context-grabber/commit/475f9070); verified by host tests (`BoardInkHeadersTests`: the label is clear of the ink and inside the picture), the Mac build (rung 1.5) and the iPad simulator's whiteboard UI classes (rung 2, 2026-11-20); Larry reading the label needs the iPad. An open sub-header inside a folded section, labelled in the opened picture, kept in its frame in [d2e5300b](https://github.com/idvorkin/context-grabber/commit/d2e5300b); verified by host tests (`BoardFoldPictureTests.testTheFrameTakesInAnOpenSubheadersLabelInsideAFold`, failing before the fix: the label cut off), `just test` and the Mac build (rung 1.5, 2026-11-21)
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Larry sees the headers*
- **Issues:** [#967](https://github.com/idvorkin/context-grabber/issues/967), [#1001](https://github.com/idvorkin/context-grabber/issues/1001), context-grabber-e91y

#### Use Case:
- **As someone** who talking the board over with Larry
- **I want** Larry to see which lines the board takes for headers
- **so that** he reads my board's outline as I see it

#### Acceptance Criteria:
- **Scenario:** A header in Larry's picture
- **Given:** an open header on the board
- **When:** Larry gets a picture of the board (his turn, Send or Claude's turn)
- **Then:** the header is labelled "▾ header" in grey just past the end of its line, clear of its ink and inside the picture however far in the line starts

---

### User Story 1040:

- **Summary:** A line tints for a moment when it becomes a header
- **Status:** implemented in [8e0a8e6e](https://github.com/idvorkin/context-grabber/commit/8e0a8e6e), [cb503b46](https://github.com/idvorkin/context-grabber/commit/cb503b46), [ddea0bc3](https://github.com/idvorkin/context-grabber/commit/ddea0bc3); verified by `WhiteboardOutlineUITests.testHeaderMarksShareOneSpotStandOnTheLineAndTintWhenMade` on the iPad simulator (rung 2, 2026-11-20: the tint appears on a margin tap's header and fades, the `header_tint` event in the session log) and `just test`; not yet seen with the Pencil on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Seeing the headers*
- **Issues:** [#1004](https://github.com/idvorkin/context-grabber/issues/1004)

#### Use Case:
- **As someone** who makes headers with the Pencil as I write
- **I want** the board to show me the moment it takes a line for a header
- **so that** I never wonder whether my # or underline was recognised

#### Acceptance Criteria:
- **Scenario:** A header made
- **Given:** a line of my writing
- **When:** it becomes a header (an underline, a #, a margin tap or *Make header*)
- **Then:** its row is tinted for about a second, then the tint fades; writing more on the line doesn't tint it again

---

### User Story 1041:

- **Summary:** Every header's ▾ sits in one spot in the margin, on the line's baseline, over the ink, easy to tap
- **Status:** implemented in [8e0a8e6e](https://github.com/idvorkin/context-grabber/commit/8e0a8e6e), [cb503b46](https://github.com/idvorkin/context-grabber/commit/cb503b46), [ddea0bc3](https://github.com/idvorkin/context-grabber/commit/ddea0bc3); verified by host tests (`BoardHeaderMarksTests`, the # row from the iPad's 2026-11-20 log), `just test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests.testHeaderMarksShareOneSpotStandOnTheLineAndTintWhenMade` on the iPad simulator (rung 2, 2026-11-20: two headers' marks at one x, each foot on its line's ink read from the screen's pixels, a tap on the mark folds); a # in the margin can't be drawn by a UI test, so over-the-ink is host and screenshot only; not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Seeing the headers*
- **Issues:** [#1004](https://github.com/idvorkin/context-grabber/issues/1004) (a # written in the margin hid its own ▾, so "#Affirmations" looked unrecognised)

#### Use Case:
- **As someone** who folds my board's sections with a finger
- **I want** each header's ▾ in the same place, standing on its line, never under my ink and big enough to hit
- **so that** I can see at a glance which lines are headers and fold one without aiming

#### Acceptance Criteria:
- **Scenario:** Headers at different indents, one started with a # in the margin
- **Given:** two headers, one indented and one whose # I wrote in the margin's left corner
- **When:** I look at the margin and tap a ▾, or up to 22 points above or below its middle
- **Then:** both ▾ sit at the same place across, each on its line's baseline and over the ink, and the tap folds that header

---

### User Story 1059:

- **Summary:** A scratch-out never puts back ink I had just moved
- **Status:** implemented in [820ec0ae](https://github.com/idvorkin/context-grabber/commit/820ec0ae); verified by host tests (`WhiteboardScratchOutTests.testATakeBackIsRedoneWhenTheStepItUndidWasNotTheZigzags`, failing before the fix for a step that moved ink), `just test`, the Mac build (rung 1.5) and the iPad simulator's whiteboard UI classes (rung 2, 2026-11-21, `WhiteboardScratchOutUITests` among them); PaperKit taking back the wrong step happens only on the iPad (the log's `base: redone`)
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Scratch out*
- **Issues:** context-grabber-geaz (from [#999](https://github.com/idvorkin/context-grabber/issues/999)'s review)

#### Use Case:
- **As someone** who tidies my board with the lasso and scratches out words as I go
- **I want** a scratch-out to take only what it covers
- **so that** ink I just moved never jumps back to where it was

#### Acceptance Criteria:
- **Scenario:** A move, then a scratch-out
- **Given:** a board on paper where I have just moved a word with the lasso
- **When:** I scratch out another word with a quick zigzag
- **Then:** the scratched-out word and the zigzag are gone, and the word I moved stays where I put it

---

### User Story 1065:

- **Summary:** A line started with ## or ### is a header of that level, and its margin mark says so
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests`: ##, ###, a fourth # as ink, a # by an underline or after the words as ink), `just test`, the Mac build (rung 1.5) and `WhiteboardOutlineUITests.testHashHashMakesASubheaderThatFoldsWithTheHashAbove` on the iPad simulator (rung 2, 2026-11-20: # and ## drawn with drags, marks ▾ and ▾ ##); a # under a tall # header kept as its own line's in [f346d8cc](https://github.com/idvorkin/context-grabber/commit/f346d8cc) and a tight ## whose bars overlap accepted in [f7293684](https://github.com/idvorkin/context-grabber/commit/f7293684), host tests; not yet written with the Pencil on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who outlines my board in Markdown's way as I write
- **I want** ## and ### written at a line's start to make a level-2 and a level-3 header
- **so that** my notes get sub-headings without reaching for the margin

#### Acceptance Criteria:
- **Scenario:** Writing ## then ###
- **Given:** a line I start with a #, which makes it a header (▾)
- **When:** I write a second # right beside the first, then a third
- **Then:** the margin's mark reads ▾ ## after the second and ▾ ### after the third, in the same spot; a fourth # is plain ink on the line

---

### User Story 1066:

- **Summary:** A ## section ends at the next ## or #, and folding the # above folds it too
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests`: a ## ending at the next ## or #, an indented body then an unindented ##, a shallower # ending a ## wherever its indent, the # folding its ##s and their folds kept, the outline's levels), `just test`, and `WhiteboardOutlineUITests.testHashHashMakesASubheaderThatFoldsWithTheHashAbove` on the iPad simulator (rung 2, 2026-11-20: folding the # hides the ## and its line); not yet seen on the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who folds my board's sections
- **I want** a ## section to sit inside the # section above it, as in Markdown
- **so that** folding a top-level header tucks away everything under it, sub-headings included

#### Acceptance Criteria:
- **Scenario:** A # with two ## under it
- **Given:** a # header, then a ## header with lines under it, then another ## with lines, all at one indent
- **When:** I fold the first ##, then the #
- **Then:** the first ##'s fold hides only its own lines (the second ## ends it); folding the # hides both ## and all their lines, and unfolding it brings them back as they were

---

### User Story 1067:

- **Summary:** One Undo of the last # takes a header back a level
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests.testOneUndoOfTheLastHashTakesOneLevel`) and `just test`; redrawing an undone # takes the level back in [f346d8cc](https://github.com/idvorkin/context-grabber/commit/f346d8cc) (`testRedrawingAnUndoneHashsLastBarTakesTheHeaderDeeperAgain`); the bar's Undo of a real # is for the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who sometimes writes one # too many
- **I want** Undo of the # that deepened a header to take back only that level
- **so that** a slip costs one Undo and never the header itself

#### Acceptance Criteria:
- **Scenario:** A ### undone
- **Given:** a line I made a ### header
- **When:** I Undo once, then Redo
- **Then:** the mark reads ▾ ## after the Undo and ▾ ### again after the Redo; the line stays a header throughout

---

### User Story 1068:

- **Summary:** Larry's picture labels a deeper header with its level
- **Status:** implemented in [8b770def](https://github.com/idvorkin/context-grabber/commit/8b770def); verified by host tests (`BoardInkHeadersTests.testLarrysPictureLabelsADeeperHeaderWithItsLevel`) and `just test`; the picture Larry gets is not yet seen from the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** [#1034](https://github.com/idvorkin/context-grabber/issues/1034)

#### Use Case:
- **As someone** who talks my board over with Larry
- **I want** Larry to see which headers are sub-headings
- **so that** he reads my outline's shape, not only which lines are headers

#### Acceptance Criteria:
- **Scenario:** A picture with a # and a ## header
- **Given:** an open # header and an open ## header under it
- **When:** a turn sends Larry a picture of the board
- **Then:** the # is labelled "▾ header" and the ## "▾ ## header" past their lines, clear of the ink

---

### User Story 1069:

- **Summary:** Redrawing an erased bar of a ### header's middle # brings back ###
- **Status:** implemented in [e801768f](https://github.com/idvorkin/context-grabber/commit/e801768f); verified by host tests (`BoardInkHeadersTests.testRedrawingAnErasedBarOfTheMiddleHashBringsBackEveryHash`, failing before the fix: ▾ ##) and `just test`; the eraser and the Pencil's bar are for the iPad
- **Spec:** [Headers drawn in ink](../superpowers/specs/2026-11-19-whiteboard-ink-headers-design.md), *Header levels: ## and ###*
- **Issues:** context-grabber-2zud (from [#1034](https://github.com/idvorkin/context-grabber/issues/1034)'s review)

#### Use Case:
- **As someone** who fixes a wobbly # with the eraser
- **I want** a bar I erase and redraw to give back the level the #s on the board say
- **so that** a ### stays a ### after a touch-up, never quietly a ##

#### Acceptance Criteria:
- **Scenario:** The middle # of a ### touched up
- **Given:** a line I made a ### header
- **When:** I erase one bar of the second # with the eraser, then draw that bar again
- **Then:** the mark reads ▾ after the erase and ▾ ### again after the redraw; the line stays a header throughout

---

### User Story 1060:

- **Summary:** A board whose drawing can't be read or moved aside is left as it was, and nothing saves over it
- **Status:** implemented in [2a9b1f0e](https://github.com/idvorkin/context-grabber/commit/2a9b1f0e); verified by host tests (`BoardKeepingTests`: bad bytes and a failed move leave the original and an older set-aside copy untouched through an edit's save, a relaunch and a reopen; a later open that can move it sets it aside beside the older one and the board saves again; a healthy board and a new one are never held), the Mac build, and the iPad simulator (rung 2, 2026-11-21: the 14 other whiteboard classes green on this change; `WhiteboardOnPaperUITests.testAnUnreadableBoardThatCannotBeMovedAsideOpensLookOnly`'s first open showed the copyable problem and *look only*, the session log `editable: false`, `kept_at: null` and the move's permission error; its rerun after taking out a drag a look-only board reads as swipe back waits on the Mac's screen unlocking). Not yet seen on the iPad
- **Issues:** [#1042](https://github.com/idvorkin/context-grabber/issues/1042) (bead context-grabber-75cg): a source review, 2026-11-21, "a subsequent save can overwrite the recoverable original"
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The board is kept*

#### Use Case:
- **As someone** whose board file has gone bad on a device that won't let it be moved
- **I want to** see a problem I can copy, and have the board open look-only
- **so that** nothing I draw that time saves over a drawing that might still be recovered

#### Acceptance Criteria:
- **Scenario:** An unreadable board that can't be moved aside
- **Given:** a board of mine on paper whose saved drawing can't be read, and whose file can't be moved aside
- **When:** I open it, leave, and open it again
- **Then:** each time a copyable problem names the board and says it was left as it was, the board says *Couldn't be read: look only* and takes no ink, and the file and any copy set aside before are exactly as they were

---

### User Story 1061:

- **Summary:** A board whose newer version fails to come down from iCloud keeps showing the last one that did
- **Status:** implemented in [b00acbce](https://github.com/idvorkin/context-grabber/commit/b00acbce); verified by host tests (`BoardKeepingTests`: a failed copy, an unreadable or missing drawing and an interrupted asset each leave the old drawing and picture untouched and nothing removed first; a retry brings the new version; a failed first download leaves no file; a missing or failed picture still takes the drawing and says so) and the Mac build; still in the list while its newer version fails in [d4103e05](https://github.com/idvorkin/context-grabber/commit/d4103e05) (`BoardIndexTests`). The simulator has no iCloud account, so the CloudKit path itself waits for the iPhone and the iPad
- **Issues:** [#1043](https://github.com/idvorkin/context-grabber/issues/1043) (bead context-grabber-nuyw): a source review, 2026-11-21, "a copy failure can leave a reading device without its last viewable replica"
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** looking at the iPad's board on the iPhone
- **I want to** keep seeing the last version that arrived when a newer one fails to come down
- **so that** a bad sync never leaves me with a blank board until the next good one

#### Acceptance Criteria:
- **Scenario:** A refresh that fails over a board already here
- **Given:** the iPhone has a board from the iPad, and the iPad has drawn more on it
- **When:** the iPhone's sync of the newer version fails partway, and I open the board offline, then sync again with the network back
- **Then:** offline it shows the version it had, the list says boards aren't syncing, and the next sync brings the newer version, with its picture drawn on the iPhone if iCloud's came without one

---

### User Story 1062:

- **Summary:** A broken copy of another device's board is repaired by the next good sync
- **Status:** implemented in [584037a4](https://github.com/idvorkin/context-grabber/commit/584037a4); verified by host tests (`BoardKeepingTests`: a held copy of another device's board is replaced by the next good copy and let go; a held board of this device's isn't replaced and still refuses saves). The simulator has no iCloud account, so the CloudKit path itself waits for the iPhone and the iPad
- **Issues:** [#1043](https://github.com/idvorkin/context-grabber/issues/1043) (bead context-grabber-nuyw): a held replica made every sync fail, so the list said boards weren't syncing until that board was opened
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** looking at the iPad's board on the iPhone
- **I want to** have a copy that went bad on the iPhone replaced by iCloud's good one
- **so that** one broken copy never leaves the board unreadable or the whole sync failing

#### Acceptance Criteria:
- **Scenario:** A broken copy of another device's board is repaired
- **Given:** the iPhone's copy of the iPad's board can't be read and couldn't be moved aside
- **When:** the iPhone syncs and iCloud has a good copy of that board
- **Then:** the good copy replaces the broken one, the board opens to look at again, and the list doesn't say boards aren't syncing

### User Story 1063:

- **Summary:** A stroke of an ink the app doesn't know never closes the board
- **Status:** implemented in 61540121; verified by host tests (WhiteboardInkTests) and the Mac build; on the iPad and the iPhone since 2026-11-21 (311c4711); which ink it was is still owed, from the iPad's log
- **Issues:** [#1083](https://github.com/idvorkin/context-grabber/issues/1083), with [#1080](https://github.com/idvorkin/context-grabber/issues/1080), [#1081](https://github.com/idvorkin/context-grabber/issues/1081), [#1082](https://github.com/idvorkin/context-grabber/issues/1082), [#1084](https://github.com/idvorkin/context-grabber/issues/1084), [#1085](https://github.com/idvorkin/context-grabber/issues/1085), [#1092](https://github.com/idvorkin/context-grabber/issues/1092)–[#1095](https://github.com/idvorkin/context-grabber/issues/1095): the iPad closed three times in two minutes on 2026-11-21, each just after a stroke landed, when the board asked that stroke's ink for its kind
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *Ink the app doesn't know never crashes the board*

#### Use Case:
- **As someone** writing on the iPad's board
- **I want to** keep writing whatever ink a stroke turns out to carry
- **so that** the board never closes under my Pencil and loses the thought I was on

#### Acceptance Criteria:
- **Scenario:** A stroke of an unknown ink lands on the board
- **Given:** a board open on the iPad
- **When:** a stroke arrives whose ink is of a kind the app has no name for
- **Then:** the board stays open, the stroke draws and saves, Larry gets it with its kind as the ink spells it, and the session log names that kind once

### User Story 1064:

- **Summary:** The log says which tool Igor picked, beside the one the board thinks it holds
- **Status:** implemented in 57255cf5; verified by `just native-test` (lint, host tests, script checks) and the Mac build; the iPad's log with both tools on a touch is still owed
- **Issues:** [#1078](https://github.com/idvorkin/context-grabber/issues/1078): "Switched to eraser still drew normally"; every touch the iPad has logged names a black pen, including 11 that erased ink and the strokes Igor drew in blue
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *The log says which tool Igor picked*

#### Use Case:
- **As someone** who reports that a tool did the wrong thing
- **I want to** have the log say which tool I had picked and which one the board used
- **so that** the fix goes after the real cause, not a guess

#### Acceptance Criteria:
- **Scenario:** Igor picks the eraser and writes
- **Given:** a board open on the iPad with the pen in hand
- **When:** Igor picks the eraser in the tool picker and touches the board with the Pencil
- **Then:** the log has a line for the change naming the eraser the picker shows and the tool the board holds, and the touch's line names both

---

### User Story 1090:

- **Summary:** A board whose first download from iCloud failed stays out of the list until its drawing arrives
- **Status:** implemented in [d4103e05](https://github.com/idvorkin/context-grabber/commit/d4103e05); verified by host tests (`BoardIndexTests`: another device's board, and this device's own board back after a reinstall, are listed only once their drawing is here) and the Mac build. The simulator has no iCloud account, so the CloudKit path waits for the iPhone and the iPad
- **Issues:** bead context-grabber-1jb4 (codex review 2026-11-21, finding 4): the list showed a board from iCloud before its drawing came down, so a failed first download opened it blank; on the iPad that drew it, back after a reinstall, the blank board took ink and would have gone up over iCloud's copy
- **Spec:** [Whiteboard with Claude](../superpowers/specs/2026-11-01-whiteboard-design.md), *A board that fails to come down keeps the one that did*

#### Use Case:
- **As someone** opening the iPad's board on the iPhone, or my own boards on a reinstalled iPad
- **I want to** see a board in the list only once its drawing is on this device
- **so that** I never open a blank board by mistake, or draw over one and lose what iCloud holds

#### Acceptance Criteria:
- **Scenario:** The first download fails
- **Given:** iCloud lists a board this device has never had the drawing of
- **When:** the sync fails to bring its drawing down
- **Then:** the board isn't in the list, the list says boards aren't syncing, a link to it says its drawing hasn't come down, and the next good sync puts it in the list with its ink
