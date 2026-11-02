# Whiteboard: Claude and Larry draw back (ghosts and shapes)

Igor, 2026-11-01: "what about the ghosting idea, does that work? How does Larry write back? I don't grok that yet",
then "make an issue for cockpit, build your side". Builds on [the whiteboard](2026-11-01-whiteboard-design.md)
(stories 344 and 349). The Cockpit half is [cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85).

## The idea in one line

Claude and Larry don't paint pixels. They answer with **shapes**: a short list of lines, arrows, boxes, circles,
freehand curves and labels, placed on the board. The app draws those shapes faint, as **ghosts**, in Claude's or
Larry's colour. A tap keeps one as real ink. Nothing they suggest changes the board until Igor keeps it.

## What Igor sees

### Ghosts from Claude (story 344)

- He draws, then lifts the Pencil. After about **1.5 s** with nothing new, faint shapes appear in Claude's colour
  (orange): the box his arrow points at, a label, the third circle.
- While ghosts show, the bar says how many and *tap one to keep it*.
- **A tap on a ghost keeps it** (a finger tap; the Pencil draws). It becomes real ink in Claude's colour, and his eraser and undo treat it like his own
  strokes.
- **Drawing on dismisses the ghosts.** The Pencil touching down clears every ghost not kept, and a request still on
  its way is dropped when it lands.
- A ghost turn gives up after **3 s**: a late answer would land on a drawing that has moved on. Nothing is shown when
  it gives up.
- **Ghosts** is a switch in the board's bar, on by default and remembered. Off, nothing is asked after a pause.
- Ghosts need the Cockpit. When it can't be reached the board draws as before; the bar says *Ghosts: the Cockpit
  isn't answering* until a turn gets through.
- Only on the device that draws the board. A board that is look-only gets no ghosts.

### Larry's turn (story 349)

- **Larry's turn** in the board's bar sends the board to Larry and waits for him (up to a minute), saying *Larry is
  looking…*.
- His answer comes back as ghosts in Larry's colour (blue), kept by a tap like Claude's, plus one line from him in the
  bar.
- His words also land in a chat thread named after the board, so the talk goes on in Chat. The same board's next turn
  goes to the same thread.
- When he can't be reached, or answers with an error, the bar shows a copyable problem with what was asked.

### Not yet

- Speaking while drawing (story 345) and Larry drawing during a call (story 346).
- Vectors instead of the picture: a turn sends a picture of what is drawn.

## Where it runs

On the Cockpit (Igor's pick: no model key on the device, and Larry is there): one endpoint takes the board's
picture and answers with shapes and one line. A fast model answers ghosts; Larry answers his own turns.

## Acceptance

- Draw two circles on the iPad and lift the Pencil: within about 2 s faint orange shapes appear. Tap one: it becomes
  orange ink that the eraser removes and undo takes back.
- Draw again before the ghosts come, or while they show: they go, and a late answer adds nothing.
- Turn Ghosts off: lifting the Pencil asks nothing (the session log shows no turn).
- Tap Larry's turn: blue ghosts and a line from Larry; Chat has a thread named after the board with his words.
- Cockpit unreachable: drawing works as before and the bar says ghosts aren't answering; Larry's turn shows a
  copyable problem.
