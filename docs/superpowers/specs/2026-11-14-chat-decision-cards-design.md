# Decision cards in Chat — Design Spec

Igor, 2026-11-14 (#878): *"decision cards like we have in the inbox, which we can open from chat."* The "inbox" is the
Cockpit's Inbox of asks: Larry's questions to Igor, each with options, often a default and an expiry, which Igor answers,
closes, snoozes or abandons on the Cockpit page. Igor confirmed the draft on #878 the same day: all three ways in (the
card in its thread, a mark on the thread's row, a *Decisions* list), drawn as the app's own buttons, not the Cockpit's
page in a web view. Part of [Chat with Larry](2026-10-25-native-chat-design.md); the Cockpit's side and the app's
types are in the [plan](../plans/2026-11-14-chat-decision-cards-plan.md).

## Summary

Igor answers Larry's decisions without leaving Chat. An ask is a decision waiting on him; a chat thread is a
conversation on one of Larry's beads, and when the ask continues that chat (Larry asked it from there, or it is the
chat's own bead), the thread carries the ask's card at its top and its row in the list says *Decision waiting*. Every open ask, whether or not it has a chat, is one tap away in
*Decisions (N)*, under Larry's pinned thread. A tap on an option answers it exactly as the Cockpit's own card does.

## Goals

- Answer a decision in one tap from the phone, with the same effect as answering it on the Cockpit.
- See from the list where a decision is waiting, and reach all of them at once.
- Close, snooze or abandon an ask from the phone, as on the Cockpit's card.
- Find an ask, open or long answered, by a few words of it, as on the Cockpit's Inbox.
- Answer in Igor's own words when no option fits, or when he doesn't understand them, from every card (Igor,
  2026-11-22: *"When we have a decision card it always needs to have an other so I can add another option."*)
- A failure never loses the card: it stays, with a copyable problem.

## Non-goals

- Making or editing asks (Larry files them).
- Typing a note alongside an option: talk in the ask's chat for that. (An answer in Igor's own words is *Other*, below.)
- The Cockpit's *looks done?* chip on an ask.
- Pictures on an option (later): an option with a picture shows its words only.
- Notifications for a new ask. Larry's message about it, if he sends one, notifies as any reply does.

## What Igor sees

**The card.** The ask's question as its heading, Larry's context under it (the first few lines; a tap shows the rest),
and one button per option: its label, and its detail in smaller type under it. The option Larry named as the default
is marked *Default*; with no default, the one he recommends is marked *Recommended*. Under the options, when the ask has
an expiry: *Expires in 5 h*, or *Expired 2 d ago* in orange. An expired ask is still open and still answerable: nothing
happens by itself when it expires, as on the Cockpit. A **⋯** menu on the card holds the other ways to finish it.

**Other.** Under the options, every card has one more button, *Other…*, for an answer in Igor's own words. A tap opens
a text field under it with the microphone beside *Send*, as in a chat: he types or dictates, reads what he said, and
*Send* answers the ask with his words. *Send* stays off until there are words. The words dictated here stay in this
field; the thread's own message bar never takes them, nor this field the bar's. When Larry's own options already
include an *own answer* option, the card adds no second one: Larry's is the way in, and a tap on it opens the same
field instead of answering. An option is Larry's own answer when the Cockpit keys it *other*, whatever its label, or
when its label means "my own answer": *Other*, *Something else*, *Type your own answer*, *Your own answer*, *None of
these*, *None of the above*, in any case, with or without punctuation around it, alone or as one half of a label such
as *Something else / Type your own answer* (Igor, 2026-11-22: he picked *Something else / Type your own answer*, the
phone sent *DECISION: Something else* with no words, and no text box opened). A label that only contains the word,
such as *Other team* or *Another*, is an ordinary option. It never answers with the option's bare label, nor with no
words at all; only Igor's words go. A card with no options at all still has *Other…*.

**Answering.** A tap on an option answers at once; there is no second step. While it goes, the buttons are dimmed and
can't be tapped again. Once the Cockpit has it, the ask is gone from *Decisions* and the row's mark goes. Larry receives
the answer exactly as one given on the Cockpit's card (the same words, recorded on the ask), and the Cockpit's Inbox no
longer shows it. The answer also goes into the ask's chat as Igor's own message, *Decided: \<label>*: in the thread the
card gives way to that message, at the bottom of the conversation where Larry's reply will follow it, and it is there
for good, on the laptop too. When the ask has no chat, or the Cockpit couldn't write the message, the card gives way to
one line instead, *You decided: \<label>*, which stays on that screen until Igor leaves it. On *Decisions* an answered
card always gives way to that line.

**Answering in his own words.** *Send* under *Other…* answers as the Cockpit's Inbox does with a free-text answer: Larry
receives *DECISION: \<the words\>*. Everything after is as for an option: the buttons and the field are dimmed while it
goes, the answer becomes Igor's message *Decided: \<the words\>* in the ask's chat, or the card gives way to *You decided:
\<the words\>*, and a refusal leaves the card, the words still in the field, with a copyable problem.

**The menu.** **⋯** on the card offers:
- *Snooze*: *Later today*, *Tomorrow morning* or *Next week*, the Cockpit's three. A snoozed ask leaves the card,
  the row's mark and *Decisions* until it wakes; the card gives way to *Snoozed until Mon 8:00 AM*.
- *Close…*: asks for a one-line reason (*what finished it*), which the Cockpit requires; *Close* stays off until there is
  one. In its chat the card gives way to Igor's message *Closed: \<reason>*; on *Decisions*, or when the message couldn't
  be written, to *Closed*.
- *Abandon*: *Doesn't matter anymore*, *Stale*, *Already handled*, *Not now*, or *No reason*, the Cockpit's presets. In
  its chat the card gives way to Igor's message *Abandoned* (with the reason, when there is one); on *Decisions*, or
  when the message couldn't be written, to *Abandoned*.

A snooze writes nothing in the chat: the ask will be back.

**Folding a card** (Igor, 2026-11-22, bead context-grabber-fjh0: *"anytime in chat I see a decision card, I should be
able to collapse it"*). Every decision card in Chat, at the top of its thread and on *Decisions*, has a fold control
(a chevron) beside its **⋯**, including while an answer or menu action is on its way. A tap folds the card to one line:
the question-mark icon, the question cut with *…* to the width, and a chevron pointing down. Folding answers nothing,
closes nothing and tells the Cockpit nothing: the row's
*Decision waiting* and the count on *Decisions (N)* stay as they were. A tap anywhere on the folded line opens the card
again, with its context still expanded if Igor had opened it on this screen, and with any own answer he had begun
under *Other…* still in its field, unsent (a recording under way stops when the card folds; its words stay). The fold is remembered for that ask on
this device: the card stays folded when Igor leaves the thread and comes back, when he opens it from the other place
(folded in its thread, it is folded on *Decisions* too), and
after the app restarts, until he opens it again. Another device's cards are not folded by it. Once the ask is finished
the fold no longer matters; the app forgets the oldest folds once it holds a few hundred.

**A long card at the top of its thread** (Larry, 2026-11-22, bead context-grabber-o2i2: *"an expanded chat
message/card grows to its full height instead of scrolling within a bounded height"*). The card at the top of a thread
stays put while the conversation scrolls under it, so a card opened in full (its context opened, a long list of
options, *Other…* open, a problem under it) used to grow past the screen: the conversation and the message bar went
under it, and its own last options could not be reached. There the card stops at about 60% of the thread's height
(never less than a few lines' worth), and what is past that scrolls inside the card. Its heading row, the question
with the fold chevron and the **⋯**, stays at the top of the card and is never scrolled away, so the card can always
be folded; the conversation and the message bar keep the rest of the screen. A tap on the opened context still closes
it to its first few lines, and the card shrinks back to fit. A card short enough to fit is drawn as before, at its own
height, with nothing to scroll. On *Decisions*, which scrolls as a whole, a card is not bounded.

**When it fails.** A refused or failed answer, snooze, close or abandon leaves the card as it was, buttons live again,
with a copyable problem under it saying what was tried and what the Cockpit said (or that it couldn't be reached, or that
the phone is offline). Nothing is retried by itself.

**Answered elsewhere.** When the ask changed after the phone loaded it — answered on the laptop, closed by Larry, or
edited — the Cockpit refuses the answer, and the phone says so in place of the problem:
- already answered or closed: *Already answered elsewhere*, and the card leaves;
- still open but changed: *This decision changed since it loaded — look again*, and the card shows the ask as it now
  is, for a fresh tap.

Either way the open asks are read again.

**In a thread.** A thread that an open ask continues shows the card pinned at the top of the thread, above the links
strip, where scrolling the messages doesn't move it. An ask continues a chat when Larry filed it from that chat, or when
it is that chat's own bead. When two open asks continue the same chat, the card is the first in the Cockpit's order, and
the next takes its place once it is answered. A thread with no open ask looks as it does today.

**On the list.** That thread's row says *Decision waiting* under its last line, with a question-mark icon, until the
ask is answered, snoozed, closed or abandoned — at once when it was done on this phone, on the next read of the list
when done elsewhere.

**Decisions.** When any ask is open, a row *Decisions (N)* sits under Larry's pinned thread, above a skill's and the
rest; with none open there is no row. It opens every open ask as cards, the soonest to expire first and the ones with no
expiry after (the Cockpit's own order). Each card answers and has its menu as in a thread, and *Open chat* under it
opens the ask's chat — the chat it continues, or else the thread on its own bead, empty if nobody has written there
yet — to talk it over with Larry. Pull
to refresh. A Decisions list that can't be read shows a copyable problem; *Select* mode in the list hides the row.
On *Decisions* a finished card gives way to its line at once, the first as much as the last (#1072): it never stays on
screen after the Cockpit has taken the answer, where a further tap would only answer it again.

**Searching the asks** (Igor, 2026-11-22, bead context-grabber-4dme: *"search in the Inbox by title and content"*,
the same search as the Cockpit's own Inbox). *Decisions* has a search box at its top, *Search asks: title, context,
options, answers*. As Igor types, and once he pauses, the asks that say every one of his words show in place of the
cards: each word anywhere in the ask, in any order, case ignored, and characters like `.` or `<` are just characters.
An ask is searched whole: its question, all of Larry's context, its options and their details, its answer, Igor's notes
on it and the rest of its conversation. The open asks are found (a snoozed one too, since it is still his) in the
Cockpit's order; answered and closed ones only with **Answered too** ticked beside the box, newest first after the open
ones.
- A line beside the box counts what matched: *1 open · 0 answered*, or *0 open · 3 answered (tick to show)* while
  answered ones match but are hidden. It counts the search, never the open asks the *Decisions (N)* row counts.
- Each found ask is a row: its question with Igor's words marked, *Snoozed* or *Answered* where it is, and, when the
  words were found past the question, up to three lines under it naming where (*context*, *option*, *answer*, *note*,
  *in thread*) with the words around the match, the words marked there too.
- No ask matches: *No asks match.*, with the count line still saying what ticking would show.
- A tap on a row opens the ask: an open ask on *Decisions* opens the chat its card is in, with the card at the top; any
  other opens its own chat in the app when Chat has it, and otherwise its page on the Cockpit, as an Inbox link does.
- Emptying the box, its clear button, *Cancel* or Escape on a keyboard bring the cards back as they were; leaving
  *Decisions* forgets the search.
- A search that fails (the Cockpit can't be reached, the phone is offline, or the Cockpit refuses it) shows a copyable
  problem in place of the rows, naming the words searched and the status, and the next change to the words tries again.

The box is on *Decisions*, so it is there while any ask is open; with none open there is no row to reach it by (a
follow-up may give the search a way in of its own).

**When the asks are read.** When the Chat list opens or is pulled, when a thread opens, when *Decisions* opens, and after
each answer, snooze, close or abandon. Not on the open thread's four-second poll. Offline, or with no Cockpit address,
nothing is read and no card, mark or row shows. A failed read leaves the cards and marks as they were, shows nothing on
the list or in a thread (only *Decisions* says so), and is logged once until a read succeeds.

## Explaining itself

The session log says when a card was shown (which ask, where: thread or list), each answer and its outcome (answered,
changed, already answered, refused, with the status and the Cockpit's reason), each menu action and its outcome,
whether the answer went into the chat (and why not, when it didn't), each fold and opening of a card (which ask,
where), and a failed read of the asks. A card opened again from its fold is a card shown again, and says so. A shown card says
whether it offered *Other…*, and a tap on *Other…* is logged; an answer in Igor's words is logged as an answer with its
length. Never the option's words, Igor's own words or the reason typed for a close beyond their length. Each search says how many words
and characters it had, whether answered asks were in it, what it found (open, answered, rows) or why it failed, and a
tap on a found row says which ask and where it went; never the words searched, which only a failed search's copyable
problem carries. Every problem is copyable, naming the screen, the operation and the ask.

## Acceptance criteria

- A thread that an open ask continues (filed from it, or its own bead) shows its card at the top: the question, the
  options as buttons, the default marked, and the expiry.
- Tapping an option answers it; the Cockpit records the answer as the Cockpit's card would; in the thread the card gives
  way to Igor's message *Decided: \<label>*, and where no message could be written, to *You decided: \<label>*.
- That thread's row says *Decision waiting* until the ask is answered, and not after.
- *Decisions (N)* sits under Larry's thread with the count of open asks, opens them as cards, each answerable and each
  with *Open chat*; with no open ask there is no row.
- A card answered, closed or abandoned on *Decisions* gives way to its line there at once, the last card too, and is
  not left on screen answered and still tappable (#1072).
- Every card has *Other…* under its options; it opens a field with the microphone and *Send*, and *Send* answers the ask
  with Igor's words exactly as the Inbox's free-text answer (*DECISION: \<the words\>*), giving way to *Decided: \<the
  words\>* in the ask's chat as an option does. *Send* is off with no words.
- An ask whose own options include an own-answer option (keyed *other*, or labelled *Other*, *Something else*, *Type
  your own answer* and the like) shows no second *Other…*; a tap on Larry's opens the same field, and the Cockpit never
  receives its bare label (*DECISION: Something else*) or an empty answer from it, only Igor's words.
- *Snooze*, *Close…* and *Abandon* from the card's menu do what they do on the Cockpit, and the card leaves; a close or
  an abandon is also Igor's message in the ask's chat.
- A card at the top of its thread, opened in full with a context longer than the screen, is no taller than about
  60% of the thread: its question, fold chevron and **⋯** stay visible, the rest scrolls inside the card down to its
  last option, the conversation and the message bar stay on screen, and a tap on the context closes it again.
- Every card, in its thread and on *Decisions*, folds to one line from a visible control without answering; a tap on
  the line opens it again; the fold is still there after leaving the thread or restarting the app, and in the ask's
  other place; the row's mark and the count are unchanged by it.
- A refused answer leaves the card with a copyable problem, and the buttons work again.
- An ask answered elsewhere says *Already answered elsewhere* and leaves; one changed says so and shows the new version.
- Typing words into *Decisions*' search box shows, once he pauses, the asks that say every word anywhere (the question,
  context, options, answer, notes or conversation), case ignored; a match past the question has a line naming where,
  with the words marked; the count line reads *N open · M answered*, with *(tick to show)* while answered matches are
  hidden; *Answered too* shows them after the open ones; *No asks match.* when none shows; a tap opens the ask; an
  emptied box brings the cards back; a failed search is a copyable problem with its words and status.
- Offline or with no address: no cards, no marks, no row, and nothing else in Chat changes.

## Depends on the Cockpit

The Cockpit lists the open asks (without the snoozed ones), each with the chat it continues, if any; answers one with an
option's label, closes or abandons one with a reason, snoozes one to a preset, and refuses any of those for an ask that
changed since it was read, sending the ask as it now is. Asked to, it also writes an answer, a close or an abandon into
the ask's chat as Igor's message, once only however often it is asked, and says whether it did.

It searches the asks by words (cockpit story 206): the open ones, and the answered and closed ones when asked, counting
both either way, each with up to three places past its question where the words were found, and the words split as it
split them for marking.

A Cockpit from before those two (Larry, 2026-11-14) lists no chat for an ask and writes nothing into one. With it, an
ask is on a chat only when it is that chat's own bead, and the card always gives way to its one line.
