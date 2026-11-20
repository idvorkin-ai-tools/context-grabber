# Whiteboard: Larry's clock and the conversation strip

Issue [#879](https://github.com/idvorkin/context-grabber/issues/879) (Igor, from the iPad, 2026-11-12): "know how long
Larry has been thinking and if my requests are going simultaneously", "some kind of collapse expand conversation", and,
written on the board itself, "This seems very slow, are we crashing/hung?" Extends
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md) (*Who answers the pause*, *Larry's turn*).
Stories: [10-whiteboard.md](../../stories/10-whiteboard.md).

## What happened

The session log of that report: 14 pictures went to Larry in four minutes, every one was delivered and answered, and
his answers took 5 to 63 seconds. The bar said *Larry is looking…* the whole time, in grey, in the middle of two lines
of other text. Second 5 and second 60 looked the same, and so did slow and broken. Igor shook the iPad 57 seconds into
the longest wait.

## Goals

- From the corner of his eye, while drawing, Igor can tell that Larry is working and for how long.
- A wait that ended without an answer says so, and what it says can be copied.
- Slow and unreachable never look the same.

## Non-goals (for this step)

- Changing what gets sent or when. The one-picture-at-a-time rule (story 662) stays as it is.
- Calling a picture back. One that has gone can't be. The 20-second controls below (Igor, 2026-11-14) free the board's
  turn or send the same picture again; none of them unsends anything.
- A clock for the fast responders (Haiku, Sonnet). They answer in about two seconds. Larry's clock shows whenever a
  turn of his is out, which on a Haiku or Sonnet board means after *Larry's turn* or *Send to Larry*.

## Larry's clock (built first)

- **Where.** The bar's note under the top bar. While Larry is looking, the note **begins** with his state, so it is
  never the part that gets cut off: **Larry · 0:42**. Everything else the note carries follows it.
- **It starts when the picture is taken**, the moment the bar used to start saying *Larry is looking…*, and counts up
  once a second: *0:07*, *1:12*.
- **It stops when his answer is seen.** The state goes and his line shows as today.
- **A newer picture restarts it at 0:00.** The clock always times the picture Larry is now looking at.
- **At three minutes the board stops waiting**, as it does today. New: it says so. The bar shows **Larry didn't
  answer** as a problem that can be copied. The copied text names the screen and the operation and carries the state
  that explains it: when the picture went, how long the board waited, whether ink or words were waiting behind it,
  and whether the Cockpit was answering. If ink or words were waiting they go as a fresh picture, as today, and the
  clock starts again for that one. The problem stays until Igor dismisses it or Larry next answers.
- **The Cockpit not answering is the one "hung" signal.** When the board's looks at the thread have been failing, the
  state reads **Larry · 0:48 · Cockpit not answering** and the clock keeps counting. It clears itself when the
  Cockpit answers again.
- **Away and back.** If the app goes to the background while Larry is looking, the clock shows the true time since
  the picture went when it returns.
- **VoiceOver** reads the state as *Larry has been looking for 42 seconds*, when asked, not on every tick.
- **The Pencil keeps drawing** throughout; the clock never takes a touch.

## A repeat tap sends nothing (Igor, 2026-11-12; changes story 662)

Six taps on *Larry's turn* and one on *Send to Larry* in twelve seconds each sent Larry the same picture. He had to
say so himself.

- **While Larry is looking at a picture and nothing has changed since it went** (no new ink, no words waiting, the
  same part of the board on screen), *Larry's turn* and *Send to Larry* send nothing.
- **The tap is answered.** For two seconds the note's state reads **Larry already has this · 0:12**, then goes back to
  the clock.
- **Anything new and the tap sends as before**: new ink, waiting words or another part of the board on screen go at
  once as a fresh picture and the clock restarts.
- **With no turn out, *Larry's turn* always sends**, new ink or not: asking him to look again is a real request.
  *Send to Larry* keeps its own rule (off until the next stroke).
- **Every tap changes something on screen within a quarter of a second**: the clock appears or restarts, or the note
  says why nothing went.

## Where the picture is: sent, or with Larry (Larry, 2026-11-12; story 773)

The Cockpit marks each of Igor's messages *received* when it lands, *seen* when Larry picks it up and *done* when he
has answered. Chat shows those marks; the board now reads them for the picture it is waiting on, the message that
carries that picture. Larry marks board pictures *seen* and *done* from 2026-11-14. One reading of the mark names the
state here and decides the controls in *After 20 seconds*, below.

- **While the Cockpit has the picture and Larry hasn't picked it up** (*received*), the state reads **Sent · 0:03**.
  The clock is the same clock, counted from when the picture went.
- **Once he has it** (*seen*), the state reads **Larry · 0:42**, as before.
- **A picture that sits unpicked for 20 seconds** reads **Sent · 0:21 · not picked up yet**. That is the honest slow
  signal: Larry is busy with something else, or isn't running. Twenty seconds is the same threshold as the controls'.
- **A picture the Cockpit hasn't taken yet** (no mark on its message) reads **Larry · 0:07**, as before; from twenty
  seconds it is stuck (below).
- **His answer ends the wait** whatever the mark said: an answer with no *seen* before it is still an answer.
- **The other states are unchanged and say more than the mark**: *Cockpit not answering* shows as before (the mark
  can't be read then, so the state keeps what it last knew), *Larry already has this* still answers a repeat tap, and
  *Larry didn't answer* still comes at three minutes. Its copied state now also says where the picture was.
- **VoiceOver** says *Sent 3 seconds ago, not picked up yet* or *Larry has been looking for 42 seconds*.
- **The panel's live row** says the same as the line.
- **A Cockpit that sends no marks** (an older one): the state reads *Larry · 0:42* throughout, as before.

## After 20 seconds: Retry, Dismiss or Interrupt (Igor, 2026-11-14; stories 775–777)

Written on the board: "I think Larry got stuck. I need interrupt/retry button after 20s!" The clock says how long; it
doesn't say whether the picture ever reached him, or offer anything to do about it.

- **Twenty seconds after a picture goes** with no answer, the board looks at where the picture is (above: the same
  reading that names the state) and offers one small control. Before twenty seconds, nothing is offered.

| Where the picture is | Before 20 s | From 20 s |
|---|---|---|
| The Cockpit never took it: no mark on its message, or no such message, on a thread whose other pictures do carry marks | *Larry · 0:07* | *Larry hasn't got the picture*, with **Retry** and **Dismiss** |
| *Received*: the Cockpit has it, Larry hasn't picked it up | *Sent · 0:03* | *Sent · 0:21 · not picked up yet*, and **Interrupt** |
| *Seen*: Larry has it | *Larry · 0:12* | *Larry · 0:42*, and **Interrupt** |
| Not known: the Cockpit marks nothing, or the board hasn't read the thread yet | *Larry · 0:07* | *Larry · 0:42*, and **Interrupt**; never *Retry* |
| *Done*, or his answer | the state goes | nothing |

- **No mark at all: stuck.** The Cockpit hasn't taken the picture: it is still on its way or its answer was lost. The
  bar shows **Larry hasn't got the picture** as a problem that can be copied (when the picture went, how long it has
  waited, whether it is still going up, whether the Cockpit is answering, and where the picture is), with **Retry**
  and **Dismiss** beside it, where *Larry didn't answer* sits. A picture whose sending the Cockpit answered is never
  stuck: the Cockpit has it.
  - **Retry** sends the very same picture again: the same picture and the same message, so if the first did land the
    Cockpit keeps one and Larry is asked once. The clock goes back to 0:00 and the twenty seconds start again.
  - **Dismiss** stops waiting: the turn is free, words that went with the picture wait for the next one, and nothing
    more is said about that picture.
- **Only a Cockpit that marks messages can say a picture is stuck.** An older one marks nothing, so there a missing
  mark says nothing: its pictures are offered *Interrupt*, never *Retry*, and no turn on it looks stuck.
- **Received or seen, not done: the Cockpit has it.** It is Larry's to pick up or to answer. The note's line, after the
  clock, carries a quiet **Interrupt**. It frees the turn, so the next pause or tap is a fresh ask instead of being
  held for his answer. What Larry draws or says later still lands. Words waiting for the next picture still go with it.
  Sending it again would not wake him, so there is no *Retry* here.
- **Interrupt on a picture still going up** (a board's first picture, or one on a Cockpit that marks nothing, whose
  sending hasn't been answered) lets go of that sending too: the next tap sends at once and nothing more is said about
  that picture, as with *Dismiss*. The words that went with it wait for the next one, unless the Cockpit's mark says
  it already has the picture.
- **After Interrupt or Dismiss the next tap always sends**: no turn is out, so *Larry already has this* can't answer
  it.
- **Done, or his answer: nothing is offered**, and the control goes with the clock.
- **Small and out of the way.** Retry and Dismiss sit in the bar's problem row, Interrupt in the note's line. Neither
  covers the board, and the Pencil keeps drawing.
- **Only *Larry's turn* and the pictures the board hands him itself.** A *Send to Larry* goes through the outbox, which
  already keeps trying and shows its own state, so its turn is offered none of these controls. Its state still reads
  *Sent* or *Larry* from its mark.
- **One problem at a time, the newest wins.** The 3-minute wait is unchanged: if it runs out with the picture still
  stuck, *Larry didn't answer* takes the problem row's place. A picture stuck later takes the place of *Larry didn't
  answer*. *Larry hasn't got the picture* goes on its own when the mark comes, when he answers, and on *Retry* or
  *Dismiss*; it never takes another problem away.
- **A sending that Retry, Dismiss or Interrupt replaced** no longer speaks for the board: when it ends, it frees
  nothing and shows nothing. One that a newer picture replaced still says it failed, and its words still wait.
- **The session log says each change** (stuck, working, back to waiting or nothing) and each press, with the picture
  and where it was.

## One line that opens (Igor, 2026-11-12: "some kind of collapse expand conversation")

### Closed: one line

The note is one line and never two. It doesn't change height, so it never moves the paper: with nothing to say yet,
on a board just opened, its line is kept empty, so the paper doesn't jump when Larry's state or a message first shows.

- **First: Larry's state**, when a turn is out: the clock, then what is waiting to go when he answers, as
  **next: ink**, **next: words** or **next: ink + words**.
- **Then the newest thing said, by whoever said it last**: Larry's line, or what the mic last heard (*You: …*), or
  *Listening…* with the mic open and nothing heard. When Igor's words don't fit, the end is kept and the start is
  cut, because the newest words are the ones he is checking. Larry's line keeps its start.
- **Last: how many suggestions are showing** (*3 to keep*) and a chevron.
- The note's other messages (a paste cut short, *Sent to Larry*, a look-only reason, Ghosts being off when the mic is
  tapped) take the middle for a few seconds and give it back.
- **A message about something still wrong stays**: *Ghosts: the Cockpit isn't answering* and *Larry's marks: the
  Cockpit isn't answering* hold the middle until the Cockpit answers again, however long that is.
- With nothing to say, there is no line, as today.
- **Words alone are said, never drawn** (Igor, 2026-11-12, #898). A reply of Larry's that is words with no marks
  and no changes to the board is his line in the note and a message in the panel, and nothing else: nothing lands on
  the board, nothing is offered to keep, and his marks already showing stay as they were. Only marks he sends as marks,
  or text he places with a change to the board, appear on it.

### Open: the conversation

A finger tap on the line opens a panel under it, over the top of the board.

- **It lies over the board and doesn't move it.** At most a fifth of the board tall, and never less room than about
  four lines; past that it doesn't grow, its messages scroll inside it (Igor, 2026-11-16, #917: "when chat expands it
  needs to scroll not grow"; at a third it covered nearly half the page). What is live and *Open in Chat* stay at its
  foot, under the messages, while the messages scroll.
- **It shows the newest.** It opens scrolled to the bottom, the newest line in view, and a new line scrolls it back
  there. A finger can scroll up to read older messages.
- **It shows the recent end of the board's thread as it stands**: Larry's words in full, and for each picture of
  Igor's the words that went with it and its mark from the Cockpit (received, seen, done). Newest at the bottom, where
  it opens. Up to the last ten messages. *Open in Chat* opens the whole thread.
- **The Cockpit's own lines are left out** (*Moved to a new chat*, where a message was sent on to a chat of its own):
  they are neither Igor's nor Larry's, and Chat shows them.
- **Under them, what is live**: the turn that's out with its clock, what is waiting to go next with the waiting words
  in full, and what the mic is hearing.
- **A board with no thread yet** shows only what is live.
- **Text can be selected and copied.**
- **The Pencil never acts on the panel**: it neither draws through it nor scrolls it. A stroke that starts on the
  board below draws as usual and the panel stays open. Fingers scroll and tap it.
- **It closes on a tap on the line.** It doesn't close when Larry answers or when Igor draws. Open or closed is
  remembered for the next board.
- **Suggestions under the panel can't be tapped** while it is open; the line's *3 to keep* is the hint to close it.
- **On an iPhone** there is no panel: a tap on the line opens the board's thread in Chat, when it has one.
- **Not here:** how each picture was sent, how much ink was new, how long each answer took. That is for a page on
  the Cockpit.

## Under discussion (not built; on #879)

- **Larry's side:** a progress note while he works (it would follow the clock: *Larry · 0:42 · reading the board*),
  words before marks, and timings on the Cockpit's thread page. Larry has taken these as `cockpit-dj8`.

## Acceptance

- Send Larry a picture: within a second the note begins *Larry · 0:00* and counts up each second.
- He answers: the state goes and his line shows.
- He answers in words only, with his marks from before still showing: his words are the note's line and in the
  panel, nothing new is on the board or offered to keep, and his earlier marks are where they were.
- Draw, pause, and tap *Larry's turn* while he is looking: the clock goes back to 0:00.
- He never answers: at three minutes the note shows *Larry didn't answer*; copying it gives the board, the time the
  picture went, the wait, what was waiting and whether the Cockpit was answering.
- Ink was waiting at the three-minute mark: a fresh picture goes and a new clock starts; the problem is still there.
- The picture doesn't reach the Cockpit: at twenty seconds *Larry hasn't got the picture* shows with *Retry* and
  *Dismiss*. *Retry* sends the same picture and the clock starts again; *Dismiss* frees the turn.
- The Cockpit has the picture and Larry hasn't finished: at twenty seconds the note's line offers *Interrupt*; a tap
  frees the turn, and the next pause or tap sends a fresh picture (never *Larry already has this*).
- A Cockpit that marks nothing: no turn ever shows *Larry hasn't got the picture* or *Retry*; from twenty seconds the
  note's line offers *Interrupt*.
- *Retry* on a picture that did land the first time: the thread holds it once.
- The Cockpit stops answering mid-wait: the state adds *Cockpit not answering* and keeps counting; it goes when the
  Cockpit is back.
- Leave the app for twenty seconds mid-wait and come back: the clock is twenty seconds further on.
- A long reply of Larry's and a long *Heard:* line are both showing: the state is still fully visible at the start.
- A pause on a Haiku or Sonnet board starts no clock; *Larry's turn* on one does.
- The board shows one problem at a time: a later failure takes the place of *Larry didn't answer*.
- *Dismiss* beside *Larry didn't answer* removes it.
- Tap *Larry's turn* twice with nothing drawn between: one picture is on his thread, and the second tap's answer is
  *Larry already has this*.
- Tap *Larry's turn* while he is looking, after drawing a stroke: a second picture goes and the clock restarts.
- Tap *Larry's turn* while he is looking, after scrolling to another page: a picture of that page goes.
- The Cockpit stops answering after Larry has spoken: the note says so for as long as it lasts, not for five seconds.
- Larry's long reply and a long *Heard:* are showing: the note is one line, the clock whole at its start.
- Draw while he is looking: the state gains *next: ink*.
- Tap the line: the panel opens over the board, the ink below hasn't moved, and Larry's whole reply can be read.
- With more messages than fit, the panel is a fifth of the board tall, shows the newest message at its bottom, and
  scrolls with a finger to the older ones; another reply arrives and the panel stays the same height, the reply in view.
- Draw with the Pencil below the open panel: the stroke lands and the panel stays open.
- Close the board with the panel open and open another: the panel is open there.
- On an iPhone, tap the line on a board with a thread: Chat opens on that thread.
- Send Larry a picture, the Cockpit takes it and he hasn't picked it up: the note begins *Sent · 0:00* and counts.
- He picks it up: the state changes to *Larry ·* and the clock doesn't restart.
- Twenty seconds pass with the picture not picked up: the state adds *not picked up yet* and *Interrupt* shows.
- He answers without ever marking it: the state goes and his line shows.
- Three minutes pass and it was never picked up: the copied problem says where the picture was.
