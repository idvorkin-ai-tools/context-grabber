# Whiteboard: paste text onto the board

Igor, on the board, 2026-11-02: "I should be able to paste text" ([#597](https://github.com/idvorkin/context-grabber/issues/597)).
Stories 390–395. Builds on [the whiteboard](2026-11-01-whiteboard-design.md) and
[ghosts and shapes](2026-11-01-whiteboard-shapes-design.md).

## The idea in one line

A paste writes the clipboard's text on the board as real ink, in the middle of what's on screen, so it travels with
the board's picture to Larry and Claude.

## What Igor sees

- **Paste** in the board's bar. It is the system's own paste button, so iOS never asks *Allow Paste?* when he taps it,
  and iOS dims it when the clipboard holds no text. A board that is look-only has no Paste.
- **⌘V** does the same with a hardware keyboard attached, on a board he can draw on, whenever the clipboard holds text.
- **Strokes he copied keep working.** With a hardware keyboard, when the clipboard holds strokes copied with the lasso
  and no text, ⌘V pastes those strokes the way the system always does, on a board he can draw on. The bar's Paste is
  for text alone.
- The text lands **in the middle of what's on screen**, at a size that reads about the same however far he has zoomed out; zoomed in past 100% the letters are simply bigger on screen, because ink finer than that doesn't draw. Each line of
  the clipboard stays its own line, left-aligned. A line too wide for the screen wraps at the screen's width. A block
  taller than the screen starts at the top of the screen and runs on below it, and he pans to see the rest.
- The letters are thin outlined ink, drawn as pen strokes, dark on light and light on dark like his own default ink.
  In Larry's and Claude's picture they are dark on white.
- It is ink from then on. His eraser removes it stroke by stroke, a letter's outline at a time.
- **Undo takes the whole paste back at once**, like a kept ghost.
- A paste counts as a change: it saves, syncs, enables Send and Larry's turn, clears *Sent to Larry*, and starts
  Claude's pause like a drawn stroke. Ghosts showing stay.

### Limits

- A paste keeps at most **500 characters and 40 lines** (counted after wrapping). The rest is left off, and the bar
  says *Pasted the first 500 of 1,234 characters* until the next change on the board. The reason is what ink costs:
  every letter is a few strokes the canvas keeps drawing and iCloud keeps carrying.
- Space and blank lines around the text are dropped.
- A character with no outline, an emoji above all, draws nothing, and the rest of the text still lands. If nothing at
  all can be drawn, the board doesn't change and the bar says *Nothing in that text can be drawn*.

## Non-goals

- **Movable text blocks** (the issue's first wording). Once pasted, the letters are strokes; there is no block to drag
  or resize. The system lasso, where the tool picker offers it, is what moves them.
- Editing the pasted text, fonts or sizes.
- Pasting images.
- Long-press to paste on the canvas: a finger pans the board and taps ghosts, and the bar's button is one tap away.
- Sending the pasted words to the Cockpit as text. They reach Larry and Claude in the picture, and a long paste at
  the picture's resolution can be hard to read. If that matters, a later change can send the words alongside it.

## Acceptance

- Clipboard empty: Paste is dimmed, ⌘V does nothing, and no permission prompt ever appears from opening a board.
- Copy strokes with the lasso, with no text on the clipboard: Paste is dimmed, and ⌘V pastes the strokes as ink.
- Copy two lines of text and tap Paste: both lines appear as ink in the middle of the screen, no *Allow Paste?*
  prompt. Send's stroke count goes up, and about a second later Claude's ghosts come.
- Zoom out, pan and paste again: the new text sits in the middle of the new view at the same on-screen size. Zoom in
  past 100% and paste: the text is bigger on screen and every letter shows.
- Undo: the whole paste goes. Leave the board and come back: the paste is still there. It shows on the other device
  like any other ink.
- With a hardware keyboard: ⌘V pastes the same way.
- Copy 2,000 characters: 500 land and the bar says so.
- Copy only emoji: the board doesn't change and the bar says nothing could be drawn.
- A board drawn on another device: no Paste, and ⌘V does nothing.
