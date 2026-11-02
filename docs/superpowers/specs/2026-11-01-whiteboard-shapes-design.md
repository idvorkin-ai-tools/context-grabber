# Whiteboard: Claude and Larry draw back (ghosts and shapes)

Draft for Igor, 2026-11-01. He asked "what about the ghosting idea, does that work? How does Larry write back? I
don't grok that yet". Builds on [the whiteboard](2026-11-01-whiteboard-design.md) (stories 344–346). Nothing here
is built.

## The idea in one line

Claude and Larry don't paint pixels. They answer with **shapes**: a short list of lines, arrows, boxes, circles,
freehand curves and labels, placed on the board. The app draws those shapes as ink, in Claude's or Larry's color. A
ghost suggestion is a set of those shapes drawn faint until Igor keeps them.

## What Igor sees

### Ghosts (story 344)

- He draws, then lifts the Pencil. After about **1.5 s** with nothing new, faint dashed shapes appear in Claude's
  color: the box his arrow points at, a label, the third circle.
- **A tap on a ghost keeps it.** It turns into real ink in Claude's color, and his eraser and undo treat it like his
  own strokes.
- **Drawing on dismisses the ghosts.** The Pencil touching down fades every ghost not kept, and a request still on
  its way is dropped.
- A ghost shows up within about **2 s** of the pause, or not at all. A late one would land on a drawing that has
  moved on.
- When a mark could mean two things, both readings can come back as ghosts (the Lavish prototype's "mug or Zoo").
- Claude can't read cursive. Words come from Igor's voice (story 345) or from printing.
- **Off** is one tap in the board's bar. Ghosts need the tailnet; without it, the board draws as before and says
  ghosts are off.

### Larry draws back (story 346)

- **In Chat:** Larry's reply to a sent board can carry shapes alongside his words. Opening that reply's board shows
  his shapes in Larry's color, on top of a copy of the board, so the original stays as it was. Igor keeps what he
  likes.
- **On a call from the board:** each time Igor pauses, the call gets the board's picture. Larry speaks to it, and
  his drawing turn arrives as shapes, as in Chat.

## Where it runs

On the Cockpit (Igor's pick: no model key on the device, and Larry is there). One new Cockpit endpoint takes the
board's picture, its strokes and anything Igor said. It answers with shapes and one line saying what they are. A
fast model answers ghosts, and Larry answers his own turns. This needs a Cockpit PR, which Igor merges.

## Open questions for Igor

1. Ghosts on every pause, or only once he says "your turn"? Every pause costs one small model call.
2. Does Larry draw on the board itself or on a copy? The draft says a copy, so his marks never change Igor's board
   unasked.
3. What colors? The draft uses Claude orange and Larry green.

## Acceptance (when built)

- Draw two circles on the iPad and lift the Pencil: within 2 s, a faint third circle appears. Tap it, and it becomes
  orange ink that the eraser removes.
- Draw again before the ghosts come: none appear.
- Send a board to Larry; his reply with shapes opens as a copy of the board, with his marks in his color.
