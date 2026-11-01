# The whiteboard

Drawing on the iPad with the Pencil, Larry seeing the board, and, later, Claude drawing with Igor. Spec:
[2026-11-01-whiteboard-design.md](../superpowers/specs/2026-11-01-whiteboard-design.md).

---

### User Story 340:

- **Summary:** Draw and erase on the iPad with the Pencil
- **Status:** implemented in [c733d8c](https://github.com/idvorkin/context-grabber/commit/c733d8c), the system's Pencil-only setting in [34873da](https://github.com/idvorkin/context-grabber/commit/34873da); built for the simulator, where with no Pencil paired a finger draws (the system's own Pencil-only setting); the Pencil, palm and eraser not yet tried on the iPad

#### Use Case:
- **As someone** who thinks better with a pen in hand
- **I want to** open a board and draw on it with the Pencil, and erase with it
- **so that** an idea gets out of my head the way it would on a whiteboard

#### Acceptance Criteria:
- **Scenario:** Pencil, palm and finger
- **Given:** the Whiteboard is open on the iPad, with my palm resting on the glass
- **When:** I draw with the Pencil, then double-tap it and rub out a stroke, then drag a finger
- **Then:** the Pencil leaves ink, my palm leaves nothing, the eraser removes the stroke, and the finger moves the board without drawing

---

### User Story 341:

- **Summary:** A board that keeps going past the screen
- **Status:** implemented in [c733d8c](https://github.com/idvorkin/context-grabber/commit/c733d8c); verified by host tests (`WhiteboardFrameTests`: where the view opens, kept on the board) and the simulator build; panning not yet tried on the iPad

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
- **Status:** implemented in [c733d8c](https://github.com/idvorkin/context-grabber/commit/c733d8c); saving on close, on a link and in the background in [34873da](https://github.com/idvorkin/context-grabber/commit/34873da); verified by host tests (`WhiteboardFrameTests`: centred on the drawing) and the simulator build; a relaunch not yet tried on the iPad

#### Use Case:
- **As someone** who comes back to a sketch later
- **I want to** find the board as I left it
- **so that** a half-finished idea is never lost

#### Acceptance Criteria:
- **Scenario:** Relaunch
- **Given:** I drew on the board and then quit the app
- **When:** I open the Whiteboard again
- **Then:** every stroke is there, and the view opens centred on the drawing

---

### User Story 343:

- **Summary:** Show Larry the board
- **Status:** implemented in [c733d8c](https://github.com/idvorkin/context-grabber/commit/c733d8c); verified by host tests (`WhiteboardFrameTests`: the picture's margin and size, the thread's title) and the simulator build; a thread in Chat not yet seen from the iPad

#### Use Case:
- **As someone** who sketches to think and then wants to talk it over
- **I want to** send the board to Larry in one tap
- **so that** he sees what I drew and answers in a chat thread

#### Acceptance Criteria:
- **Scenario:** Send to Larry
- **Given:** I have drawn on the board and the iPad is in dark mode
- **When:** I tap Send to Larry
- **Then:** the bar says the board is on its way, and Chat gets a new thread titled "Whiteboard, <date>" holding a picture of the whole drawing, dark ink on white

- **Scenario:** One send, one thread
- **Given:** I have just sent the board to Larry
- **When:** I tap Send to Larry again before drawing anything more
- **Then:** nothing is sent, because the button is disabled until my next stroke, and Chat holds one thread for that board

---

### User Story 344:

- **Summary:** Claude suggests the next strokes as I draw
- **Status:** not implemented (Igor picked ghost suggestions, model B, on the 2026-11-01 Lavish page; prototyped there only)

#### Use Case:
- **As someone** drawing alone
- **I want to** see faint suggested strokes when I pause
- **so that** it feels like drawing with someone

#### Acceptance Criteria:
- **Scenario:** A ghost, kept
- **Given:** I drew two circles and lifted the Pencil
- **When:** I wait about two seconds, then tap the faint third circle that appears
- **Then:** the ghost becomes a real stroke in Claude's colour that my eraser and undo treat like mine, and the other ghosts fade once I draw on

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

- **Summary:** See the iPad's board on the phone
- **Status:** not implemented

#### Use Case:
- **As someone** away from the iPad
- **I want to** look at the board on the phone
- **so that** the sketch is with me wherever I am

#### Acceptance Criteria:
- **Scenario:** View only
- **Given:** I drew on the iPad's board
- **When:** I open the boards on the phone
- **Then:** I see the latest picture of the board, which I can pinch but not draw on
