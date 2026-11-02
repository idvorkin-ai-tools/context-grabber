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
- **Larry sees it.** One button sends the board to Larry on the board's chat thread with the picture attached. His
  reply arrives in Chat, like any other thread, and his marks on the board.
- **Then we draw together.** When Igor lifts the pen, faint suggestions appear on the board. A tap keeps one, and
  a tap off them dismisses the rest (Igor's pick: ghost suggestions, "b + c"). Igor's voice steers the suggestions.
  A later step: Larry draws during a call.
- **The phone can view.** Boards drawn on the iPad can be seen on the phone.

## Non-goals

- No shapes palette, layers, text boxes or templates. The Pencil and the tool picker are the whole drawing interface;
  [pasted text](2026-11-02-whiteboard-paste-design.md) lands as ink, not a text box.
- Not a notes app: boards have a name and a picture, with no folders, tags or search.
- No two devices drawing on one board. A board is drawn on the device that made it, and every other device shows it
  read-only, so there's never a conflict to merge.

## What Igor sees (v0: this build)

### The boards (Igor, 2026-11-01: "I should see each whiteboard as a list"; "on iPhone should see what was drawn, probably read only")

- A **Whiteboard** tile on home. It opens **the boards**: a grid of cards, newest change first. Each card shows the
  board's picture, its name, and when it last changed. A board from another device also says where it was drawn
  ("Drawn on iPad").
- **+ New board** opens a fresh, empty board named for the day (*Board, Nov 1*; a second that day is *Board, Nov 1
  (2)*). A new board that's left without a stroke is gone when it closes, so empty boards never pile up.
- A **long press** on a card offers *Rename* and *Delete*. Delete asks first, and it removes the board from every
  device. Only boards drawn on this device can be renamed or deleted.
- **Every device signed into Igor's iCloud sees every board.** A board saved on the iPad appears in the iPhone's
  list the next time the list opens or the app comes forward. It's usually there within a minute, and a pull on the
  list fetches it straight away.
- **Read-only elsewhere:** a board opens for drawing only on the device that made it. On any other device it opens
  to look at: pan and pinch, no tool picker, and a note in the bar saying where it's drawn.
- **Without iCloud** (signed out, or no network), the list shows what this device already has and says that boards
  aren't syncing. Drawing still works, and the board goes up the next time it can.
- **The board drawn before the list existed** becomes the first board in the list, and nothing on it is lost.
- **A reinstall** gives the device a new identity, so its old boards come back read-only there. Taking a board
  over on a new device is a later step.

### One board
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
  background. If a saved board can't be read, it's kept aside and the screen says so; if it can't even be moved
  aside, it's left untouched, nothing drawn that time is saved over it, and the screen says that too.
- **Send to Larry** (top bar): sends a picture of everything drawn, on white, on the board's chat thread, titled with
  the board's name: the first send or Larry's turn on a board starts the thread, and later ones go to it, so marks he
  draws in answer come back to the board.
  - The bar says *Sent to Larry: his reply shows in Chat*. One send makes one message: the button stays disabled
    until the next stroke, so a second tap never sends the same board twice.
  - With no network, the board waits in the Inbox outbox like any other message and goes when the network is back.
  - An empty board can't be sent; the button is disabled.
- **Back** (top bar) closes the board and returns to the boards, where **Done** leaves the Whiteboard.

## Later steps (not in this build)

Ghosts, Larry's turn and the board's open mic are built, and specified in
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md). The Lavish prototype showed that a mark that
could mean two things is best answered with both readings as ghosts, and that Claude can't read cursive, so words come
from Igor's voice.

1. **Voice.** A level meter on the open mic (the Inbox's mic UI). "Your turn" said out loud gets a full drawing turn.
2. **Larry.** A call with the board as Larry's context while Igor keeps drawing.

Claude's side runs through the Cockpit on the Mac (Igor's pick), so no model key goes on the device. The cost is
that ghosts need the tailnet.

## Acceptance

- On the iPad, the Pencil draws, a finger pans, and the eraser removes strokes.
- Close the board, kill the app, reopen it: the drawing is there, framed in view.
- Pan or pinch several screens past the first view, and the board is still there to draw on.
- Send to Larry with a drawing: the board's thread appears in Chat with the picture, its ink dark on white even when the
  iPad is in dark mode.
- The tile opens the boards, newest first. + New board opens an empty board; closing it without a stroke leaves no
  card behind.
- Draw on the iPad and close the board: within a minute, the iPhone's list shows it with the same picture. Opening
  it there shows the drawing with no tool picker, and a finger only pans.
- Rename and delete a board on the iPad: the iPhone follows on its next refresh.
- The single board from before the list is the first card after the update.
