# Whiteboard: Claude and Larry draw back (ghosts and shapes)

Igor, 2026-11-01: "what about the ghosting idea, does that work? How does Larry write back? I don't grok that yet",
then "make an issue for cockpit, build your side". Builds on [the whiteboard](2026-11-01-whiteboard-design.md)
(stories 344, 349–359 and 370–377). Larry's half on the Cockpit is [cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85).

## The idea in one line

Claude and Larry don't paint pixels. They answer with **shapes**: a short list of lines, arrows, boxes, circles,
freehand curves and labels, placed on the board. The app draws those shapes faint, as **ghosts**, in Claude's or
Larry's colour. A ghost looks like ink, only fainter: a solid line with round ends, as wide as a kept stroke (Igor,
2026-11-02: "via ink strokes"), and a label is the outlines of its letters. A tap keeps one as real ink. Nothing they
suggest changes the board until Igor keeps it.

## What Igor sees

### Ghosts from Claude (stories 344, 350–352, 354, 357–359, 370–377)

- He draws, then lifts the Pencil. After about **1 s** with nothing new Claude is asked, and within a few seconds faint
  shapes draw themselves in, one after another, in Claude's colour (orange): the box his arrow points at, a label, the
  third circle. Only one turn is asked at a time; strokes made meanwhile get their own turn after the next
  pause, which waits for the tool to lift.
- **Claude's marks arrive one at a time** (cockpit#85), each as the model makes it, not all together at the end. Where
  a Cockpit answers all at once, they all arrive then and draw in one after another as before; the app asks in a way
  that gets either.
- While ghosts show, the bar says how many and *tap one to keep it*.
- **A tap on a ghost keeps it** (a finger tap; the Pencil draws). It becomes real ink in Claude's colour, and his eraser and undo treat it like his own
  strokes.
- **Ghosts stay while he draws** (Igor, 2026-11-02: drawing together, not taking turns). The Pencil touching down
  leaves them, and an answer that lands while he draws still shows. Each new answer from Claude replaces his unkept
  ghosts and leaves Larry's: the old set stays until the first new mark lands, so the board is never blank between
  them, and an answer with nothing to add clears them when it ends. Claude's fade by themselves **30 s** after the last
  of them appears; Larry's stay until kept or dismissed.
- **A tap off the ghosts dismisses them all.**
- **Where a finger draws** (an iPhone, an iPad with no Pencil, or with the system's Pencil-only setting off), it stops
  drawing while ghosts show: it taps and pans, so keeping a ghost leaves no dot. With no ghost left it draws again.
- A ghost turn gives up **10 s** after it was asked, however much has arrived by then (the Cockpit's model takes about
  3 s, and an answer to an older drawing still lands where that drawing was). If no mark has arrived, none is shown and
  the bar says *Ghosts: the Cockpit isn't answering*. **An answer cut off after a mark has arrived is no failure**: the
  marks already drawn stay, and the bar says nothing. A turn sent away (a dismissal, Ghosts off) stops showing marks at
  once, even with more on the way. A turn the Cockpit says came too soon (it
  takes one every 2 s) is quietly skipped: the bar says nothing and the ghosts on the board stay.
- **Ghosts** is a switch in the board's bar, on by default and remembered. Off, nothing is asked after a pause: Claude's
  ghosts go and a turn of his on its way is dropped. Larry's marks stay, because a tap asked for them.
- Ghosts need the Cockpit. When it can't be reached the board draws as before; the bar says *Ghosts: the Cockpit
  isn't answering* until a turn gets through.
- Only on the device that draws the board. A board that is look-only gets no ghosts.
- A point in an answer that lies past anywhere the board could reach is ignored, and a shape left with too few points
  isn't shown: a model's bad number never breaks the board. A label with nothing to draw (an emoji has no outline)
  isn't shown or counted either.

### Larry's turn (stories 349, 353, 355–357, 380–384)

Larry draws through his chat thread, in his own time: the real Larry answers in minutes, so nothing waits for him
(Igor, 2026-11-02).

- **Larry's turn** in the board's bar sends a picture of the board to the board's chat thread, saying *your turn on the
  board*, and the bar says *Larry has the board*. No spinner: Igor keeps drawing, and can hand him a newer picture at any time.
- **Each board has one thread**, named after the board. The board's first *Larry's turn* or *Send to Larry* starts it,
  and later ones of either kind go to it, on this device. Claude's ghost turns have no thread.
- **Larry's marks arrive on their own.** While a board that has a thread is open, the app looks at the thread about
  every 3 s. A new row of Larry's with marks shows them as ghosts in Larry's colour (blue), kept by a tap like Claude's.
  It makes no difference whether he is answering a turn, answering *Send to Larry*, or drawing unprompted.
- **Marks land where the picture was.** Every picture goes with its place on the board, and his row brings it back, so
  his marks sit on what he saw even after Igor has drawn elsewhere, panned or zoomed. A row of marks that doesn't say
  where its picture was is not shown (the session log says so).
- **His words show in the bar**: the text of each new row of his, as his line, in place of *Larry has the board*.
  A row of marks with no words clears it. The talk carries on in Chat.
- **What shows when a board opens:** only his newest row of marks, and its line, unless Igor already kept or dismissed
  something from that row on this device. Older rows never come back: they are in Chat. After that, every new row shows.
- **Each new row of marks replaces his unkept ones** and leaves Claude's alone; Claude's ghosts never replace his. His
  marks stay until kept or dismissed: no timer, and the Ghosts switch doesn't touch them.
- **A dismissed set doesn't come back**, on the next look or the next time the board opens. Keeping one mark settles
  that row the same way the next time the board opens: the ones he left show until the board closes.
- The looking stops when the board closes or the app goes to the background, and starts again when it comes back.
  While it can't reach the Cockpit the bar says so quietly after about 10 s (*Larry's marks: the Cockpit isn't
  answering*), the log says so once, and the bar clears itself when the Cockpit answers. Never an error box, never a
  repeating one.
- When the picture can't be handed to him, or the Cockpit refuses it, the bar shows a copyable problem with what was
  asked. A look-only board neither sends nor looks.

### Not yet

- Speaking while drawing (story 345) and Larry drawing during a call (story 346).
- Vectors instead of the picture: a turn sends a picture of what is drawn.

## Where it runs

On the Cockpit (Igor's pick: no model key on the device, and Larry is there). Claude's ghosts come from its ghost
endpoint, which takes the board's picture and answers with strokes: lines, arrows, polylines, circles, arcs and
labels. Larry's marks come over chat ([cockpit#85](https://github.com/idvorkin-ai-tools/cockpit/issues/85)): a picture
sent to him carries which board it is, a new id, and its place on the board, and the Cockpit keeps those on the row and
hands them back; his rows carry shapes in the picture's pixels, in the ghost endpoint's format or the older one.

## Acceptance

- Draw two circles on the iPad and lift the Pencil: within about 5 s faint orange shapes appear, solid like ink. Tap
  one: it becomes orange ink, the same line only stronger, that the eraser removes and undo takes back.
- With the Cockpit streaming, marks appear one at a time, and the session log says how long the first one took. With a
  Cockpit answering all at once, they appear together and everything else above holds.
- Cut the connection after the first mark: it stays and the bar says nothing. Cut it before any: the bar says ghosts
  aren't answering.
- Draw again before the ghosts come, or while they show: they stay, and the next pause brings a new set that replaces
  Claude's. Leave them alone: they fade after 30 s. Larry's blue marks stay through all of it.
- On a device where a finger draws: a tap on a ghost keeps it with no dot drawn, and a tap off the ghosts dismisses
  them; then the finger draws again.
- Turn Ghosts off: lifting the Pencil asks nothing (the session log shows no turn). Larry's blue ghosts stay showing.
- Tap Larry's turn: the bar says *Larry has the board* straight away and the Pencil keeps drawing. Chat has a thread
  named after the board holding the picture. Minutes later, with no tap, blue ghosts and his line appear on what he saw,
  even if the view has moved since.
- He draws unprompted on the thread: the same, with no tap by Igor. His next marks replace the unkept ones.
- Dismiss his marks: they don't return, not on the next look and not after closing and reopening the board. Leave them
  and reopen: only his newest set shows.
- Cockpit unreachable: drawing works as before and the bar says ghosts aren't answering, and that his marks aren't;
  Larry's turn shows a copyable problem; when the Cockpit is back the bar clears by itself.
