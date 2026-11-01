# Whiteboard with Claude

Igor, 2026-11-01: "can we do an ipad whiteboard app (on phone it should be viewable), and I want the interface with
draw with the pen (and eraser) … minimum you take input … but I think you extend my drawing like we both draw
together and maybe you get voice input, and need a back link to larry too while doing this." The brainstorm ran on a
Lavish page with a working board: four rounds of drawing, and Igor's answers to the open questions. Stories:
[10-whiteboard.md](../../stories/10-whiteboard.md).

## Goals

- **A board on the iPad.** Draw with the Pencil and erase. Drawing should feel as good as Notes, because it's the
  same ink.
- **Room to keep going.** The board doesn't end at the screen's edge. Two fingers pan and pinch, and there's plenty
  of board in every direction.
- **Larry sees it.** One button sends the board to Larry as a new chat thread with the picture attached. His reply
  arrives in Chat, like any other thread.
- **Then we draw together** (later steps). When Igor lifts the pen, faint suggestions appear on the board. A tap keeps
  one, and drawing on dismisses the rest (Igor's pick: ghost suggestions, "b + c"). Igor's voice steers the
  suggestions. Larry can draw too, during a call.
- **The phone can view.** Boards drawn on the iPad can be seen on the phone (a later step).

## Non-goals

- No shapes palette, layers, text boxes or templates. The Pencil and the tool picker are the whole interface.
- Not a notes app. One board for now, kept until Igor clears it.

## What Igor sees (v0: this build)

- A **Whiteboard** tile on home. It opens the board full screen.
- The **tool picker** sits along the edge: pen, marker, pencil, eraser, lasso, ruler, undo and redo, and colors.
  This is the system's own picker, so the Pencil's double tap or squeeze switches to the eraser, as it does in
  Notes.
- **Who draws:**
  - With a Pencil paired, only the Pencil draws, and a finger moves the board. A palm resting on the glass never
    leaves a mark.
  - Without a Pencil (the iPhone, or an iPad with none paired), a finger draws and two fingers move the board.
  - This follows the system's "Only Draw with Apple Pencil" setting.
- **The board is big.** It opens centered on what's already drawn, or on its middle when it's empty. It stretches
  several screens in every direction. Pinching out shows the whole drawing; pinching in goes up to 3× for detail.
- **The board is kept.** Leaving, quitting or restarting the app never loses a stroke, and neither does a link that
  opens another screen. The board saves a moment after each stroke, and again on close or when the app goes to the
  background. If a saved board can't be read, it's kept aside and the screen says so.
- **Send to Larry** (top bar): sends a picture of everything drawn, on white, as a new chat thread titled
  *Whiteboard, <date>*.
  - The bar says *Sent to Larry: his reply shows in Chat*.
  - With no network, the board waits in the Inbox outbox like any other message and goes when the network is back.
  - An empty board can't be sent; the button is disabled.
- **Done** (top bar) closes the board.

## Later steps (not in this build)

1. **Ghost suggestions.** After about 1.5 s with the pen lifted, the board asks the Cockpit for suggestions. A fast
   model looks at the board picture and the strokes, and suggestions must arrive within about 2 s. They're drawn
   faint and dashed in Claude's color. A tap keeps one, and keeping makes it a real stroke that the eraser and undo
   treat like Igor's own. Drawing on dismisses them. Pen-down cancels a request still in flight. The Lavish
   prototype showed that a mark that could mean two things is best answered with both readings as ghosts, and that
   Claude can't read cursive, so words come from Igor's voice.
2. **Voice.** An open mic with the level meter (the Inbox's mic UI). What Igor says goes with the strokes and steers
   the ghosts. "Your turn" said out loud gets a full drawing turn.
3. **Larry.** A call with the board as Larry's context while Igor keeps drawing, and Larry gets the same drawing turn
   Claude does. His replies would need to carry strokes, not only pictures, which is Cockpit work.
4. **The phone.** The boards, viewed through the Cockpit: a list, then a picture you can pinch.

Claude's side runs through the Cockpit on the Mac (Igor's pick), so no model key goes on the device. The cost is
that ghosts need the tailnet.

## Acceptance

- On the iPad, the Pencil draws, a finger pans, and the eraser removes strokes.
- Close the board, kill the app, reopen it: the drawing is there, framed in view.
- Pan or pinch several screens past the first view, and the board is still there to draw on.
- Send to Larry with a drawing: a new thread appears in Chat with the picture, its ink dark on white even when the
  iPad is in dark mode.
