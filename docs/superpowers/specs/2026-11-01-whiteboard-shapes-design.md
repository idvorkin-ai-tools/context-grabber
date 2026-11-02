# Whiteboard: Claude and Larry draw back (ghosts and shapes)

Igor, 2026-11-01: "what about the ghosting idea, does that work? How does Larry write back? I don't grok that yet",
then "make an issue for cockpit, build your side". Builds on [the whiteboard](2026-11-01-whiteboard-design.md)
(stories 344 and 349–355). The Cockpit half is [cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85).

## The idea in one line

Claude and Larry don't paint pixels. They answer with **shapes**: a short list of lines, arrows, boxes, circles,
freehand curves and labels, placed on the board. The app draws those shapes faint, as **ghosts**, in Claude's or
Larry's colour. A tap keeps one as real ink. Nothing they suggest changes the board until Igor keeps it.

## What Igor sees

### Ghosts from Claude (stories 344, 350–352, 354)

- He draws, then lifts the Pencil. After about **1.5 s** with nothing new, faint shapes appear in Claude's colour
  (orange): the box his arrow points at, a label, the third circle.
- While ghosts show, the bar says how many and *tap one to keep it*.
- **A tap on a ghost keeps it** (a finger tap; the Pencil draws). It becomes real ink in Claude's colour, and his eraser and undo treat it like his own
  strokes.
- **Drawing on dismisses the ghosts.** The Pencil touching down clears every ghost not kept, and a request still on
  its way is dropped when it lands.
- **A tap off the ghosts dismisses them all.**
- **Where a finger draws** (an iPhone, an iPad with no Pencil, or with the system's Pencil-only setting off), it stops
  drawing while ghosts show: it taps and pans, so keeping a ghost leaves no dot. With no ghost left it draws again.
- A ghost turn gives up after **3 s**: a late answer would land on a drawing that has moved on. No ghost is shown when
  it gives up.
- **Ghosts** is a switch in the board's bar, on by default and remembered. Off, nothing is asked after a pause: Claude's
  ghosts go and a turn of his on its way is dropped. Larry's marks stay, because a tap asked for them.
- Ghosts need the Cockpit. When it can't be reached the board draws as before; the bar says *Ghosts: the Cockpit
  isn't answering* until a turn gets through.
- Only on the device that draws the board. A board that is look-only gets no ghosts.
- A point in an answer that lies past anywhere the board could reach is ignored, and a shape left with too few points
  isn't shown: a model's bad number never breaks the board. A label with nothing to draw (an emoji has no outline)
  isn't shown or counted either.

### Larry's turn (stories 349, 353, 355)

- **Larry's turn** in the board's bar sends the board to Larry and waits for him (up to a minute), saying *Larry is
  looking…*.
- His answer comes back as ghosts in Larry's colour (blue), kept by a tap like Claude's, plus one line from him in the
  bar.
- His words also land in a chat thread named after the board, so the talk goes on in Chat. The same board's next turn
  of Larry's goes to the same thread; Claude's ghost turns have no thread.
- Asking him drops a ghost turn pending or on its way, and when his answer lands so is any later one: Claude's ghosts
  never replace his marks.
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
- On a device where a finger draws: a tap on a ghost keeps it with no dot drawn, and a tap off the ghosts dismisses
  them; then the finger draws again.
- Turn Ghosts off: lifting the Pencil asks nothing (the session log shows no turn). Larry's blue ghosts stay showing.
- Tap Larry's turn: blue ghosts and a line from Larry; Chat has a thread named after the board with his words.
- Cockpit unreachable: drawing works as before and the bar says ghosts aren't answering; Larry's turn shows a
  copyable problem.
