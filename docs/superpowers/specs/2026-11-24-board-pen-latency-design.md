# How fast the board answers the Pencil

See [story 1311](../../stories/10-whiteboard-boards.md#user-story-1311) for implementation and verification status.

Igor, 2026-11-24 ~05:00 (via Larry): on drawing on the iPad, the native PaperKit board against the web board, "measure
pen latency on both first, then decide." The web board measures itself at 16 ms median from Pencil input to frame, at
60 Hz, in Safari (cockpit-kp5).

## What Igor sees

Nothing on the board changes. After he writes a few lines on a board on the iPad, the session log holds a line that
says how long the board took, from the Pencil touching to the next frame going to the screen:

- how many Pencil moments it measured,
- the median (p50) and the 90th percentile (p90), in milliseconds,
- the slowest it measured, in milliseconds,
- the screen's refresh rate, in frames per second (120 on a ProMotion iPad, 60 otherwise).

A line goes in the log about every 200 Pencil moments, and when he lifts the Pencil after at least 20, so a short
note on the board still yields a number. Larry, or anyone with the logs, can read the number off the log without
filming the screen. One command prints every such line from the logs pulled off the iPad.

## What it measures, honestly

- **Start:** the moment the iPad stamps on the Pencil's touch, the same clock the web reads in its pointer event.
- **End:** the time the next frame is due on the glass, as the screen's frame clock says, for the first frame after the
  board heard that touch.
- So it is **input to frame presentation**, the same span the web board measures, not input to photons. It leaves out
  the panel's own response, which is the same for both boards on one iPad.
- The ink of that touch may appear one frame later than the frame measured, if PaperKit draws it a frame after it
  hears it. The number is then low by at most one frame (8 ms at 120 Hz, 17 ms at 60 Hz). The spec says so rather
  than guess, and the comparison with the web holds as long as the web counts the same way.
- It samples, never every touch: one Pencil moment in four, so the measuring costs nothing a stroke can feel.
- The Pencil's predicted touches (where iOS guesses the pen is going) are not measured; only touches it really saw.

## Non-goals

- It decides nothing: whether the board stays on PaperKit or moves to the web page is Igor's call after both numbers
  are in.
- No setting, no screen and nothing for Igor to switch on.
- No filming and no photon timing.
- The iPhone and the Mac have no Pencil and log nothing.

## Acceptance criteria

- After a few lines written with the Pencil on an iPad board, the session log has a pen-latency line with the count,
  p50, p90, slowest and the refresh rate.
- A Pencil lifted after fewer than 20 measured moments logs nothing for that stroke; the moments carry over to the
  next.
- Finger touches are never measured.
- Writing feels exactly as before: the measuring adds no work to drawing beyond reading two clocks.
- One command prints the pen-latency lines from the pulled logs.
