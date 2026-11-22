# Whiteboard: question cards

Larry's web board (/ink) shows his open asks as live cards on the board (the Cockpit's FEATURES.md, *Ink*, "Question
cards"). This brings them to the app's board, so a question Larry asks about a drawing waits on that drawing and is
answered there, with the same effect as answering it in the Cockpit's Inbox. Part of
[Claude and Larry draw back](2026-11-01-whiteboard-shapes-design.md); the answering itself is Chat's
[decision cards](2026-11-14-chat-decision-cards-design.md), reused.

## Summary

An *ask* is a decision Larry is waiting on Igor for. When Larry asks one about a board, it lands on that board as a
card: one line, *? \<question> ···*, in Larry's purple. A tap opens it to answer. Once answered, the card stays on the
board, small and grey, as *✓ \<question>* over the answer, because a question answered is still worth seeing on the
drawing it was about. An answered card can fold to a one-line chip, and the eraser takes it away.

## Goals

- A question about a board is seen on that board, where the drawing it is about is.
- Answer it from the board in a tap, exactly as on the Cockpit's Inbox or Chat's decision card.
- Keep the question and its answer on the board afterwards, without the network.

## Non-goals

- Making or editing asks (Larry files them).
- Moving a card by hand, or a card pushing ink out of its way: a card lies over the board where it landed.
- Cards on another device's copy of the board, or on a board only looked at: the cards live with the board on the
  device that draws it, as its chat thread does.
- An option picked together with a note: an option answers in one tap, as in Chat; *your own answer* is the other way.

## What Igor sees

**Where a card comes from.** Either way, once per ask on a board:
- Larry's reply on the board's thread holds a question for an ask: the card lands where he put it, inside the page.
- An open ask names the board, by its thread or in its context: when the board opens, its card lands at the top of what
  is on screen, near the left margin; several land one under another.

**An open card.** One line: *? \<question> ···*, cut with *…* to the card's width, on a pale purple card edged in
Larry's purple. Until the Cockpit's asks have been read it says *? Question ···*. It sits on the paper and moves and
zooms with the board.

**Answering.** A tap on an open card opens it over the board: the ask's question, Larry's context, and its options as
Chat's decision card shows them (the default marked, the expiry, the ⋯ menu with Snooze, Close… and Abandon). A tap on
an option answers at once. Under the card, *Your own answer* and *Send* answer in Igor's words instead (needed for an ask
with no options). The card in the popup has no *Other…* of its own, as it has in Chat: this field is the
board's way to answer in Igor's words, already open. Larry's own-answer option (keyed *other*, or labelled *Other*,
*Something else*, *Type your own answer* and the like, as Chat's decision cards define it) is drawn, and a tap on it
answers nothing: it puts the cursor in *Your own answer* with the keyboard up, ready to type or dictate, and *Send*
stays off until there are words. The answer can be spoken: a mic sits immediately beside *Send*, after the field, both at least a
finger tall and wide (Igor, 2026-11-03, #625: the record button goes by Send on every input). It is Chat's mic: a tap
records, it turns red with the seconds, the words fill the field after what was typed, and a tap stops it; nothing is
sent until *Send*. *Send* or closing the popup stops a recording. A call, or another recording, holding the microphone
says so under the field, as in Chat. The Cockpit takes the answer exactly as the Inbox's (*DECISION: \<label>*, or *DECISION: \<words>*);
the popup closes and the card is answered. A snooze leaves the card open. A close or an abandon answers the card with
*Closed* or *Abandoned* and the reason under it.

**Folding an open card** (Igor, 2026-11-22, bead context-grabber-fjh0: *"I should also be able to re-collapse decision
cards"*). The opened question's decision card carries Chat's fold control beside its **⋯**. On the board a tap on it
folds the card back to its one line on the paper: the popup closes, nothing is answered, and the card is open as
before, a tap away. The control still works while an answer or menu action is on its way. If Igor opens another
question before that request finishes, the other popup stays open. The popup always opens with the decision card
whole, whatever its fold in Chat.

**When it fails.** As Chat's card: a refused answer leaves the popup open with a copyable problem, and its buttons live
again; one changed since it loaded says so and shows the ask as it now is. One already answered elsewhere, or no longer
open, closes the popup's question: the card fetches its answer (below), and the popup says *This question is no longer
open in the Cockpit (answered or closed).* when there is none to show.

**An answered card.** Grey, two small lines: *✓ \<question>* over the answer (the option's label, or the words, then
the note). It stays on the board, saved with it, and shows with no network.

**Answered elsewhere.** When the board opens and a card's ask is no longer open (answered in the Inbox, in Chat, or
closed by Larry), the card asks the Cockpit for that ask's question and answer and shows them. If the Cockpit has none
yet, the card says *✓ answered* and asks again the next time the board opens.

**Reading and folding.** A tap on an answered card opens it read-only: *✓ \<question>*, the answer in full, the note,
with *Collapse* and *Close*. *Collapse* folds the card to a one-line chip, *✓ \<question>*, only as wide as its words.
A tap on a chip opens it out again.

**The eraser.** With the eraser in hand, a stroke across an answered card or chip takes it off the board, as it would
ink. Only a touch that would erase ink takes it: the Pencil, or a finger while fingers draw; a finger that pans the
board takes nothing. An open card is still live: the eraser leaves it.

**When the asks are read.** When the board opens or comes back on screen, when a question of Larry's lands, and when a
card is opened. Offline, or with no Cockpit address, nothing is read: the cards on the board stay as they are, and an
open card's popup says the Cockpit's asks didn't load.

## Explaining itself

The session log says when cards landed (how many, from Larry's reply or from the open asks), when a card's answer came
from the Cockpit, each card opened (open or answered), each answer and its outcome (Chat's own decision events, from
the board), a fold (an open card's or an answered one's) and an opening-out, a card erased, and a failed read of the asks or the answers, once until one
works. Never the answer's words.

## Acceptance criteria

- Larry's reply holding a question for an ask puts one card for it on the board, at his place, once.
- An open ask that names the board's thread or the board shows as a card when the board opens.
- A tap on an open card opens it; an option or Igor's own words answer it as the Inbox would, and the card turns into
  *✓ \<question>* over the answer.
- Larry's own-answer option (keyed *other*, or labelled *Something else*, *Other* and the like) shows in the popup's
  card; a tap on it sends nothing and puts the cursor in *Your own answer*; only Igor's words are ever sent from it.
- A card whose ask was answered elsewhere shows that answer once the Cockpit gives it.
- An answered card opens read-only, folds to a one-line chip, and a tap opens the chip out.
- An opened card not yet answered folds back to its one line from the fold control, answering nothing.
- The eraser takes an answered card and leaves an open one.
- Offline or with no address nothing is read, and the board's cards stay as they were.

## Depends on the Cockpit

`GET /asks?snoozed=1` (the open asks, the snoozed ones too, so a snoozed ask's card stays open), `POST /act` (the
answer), and `GET /ink/answers?ids=` (the question and answer of closed asks, the decisions log first). Larry places a
card with a `question` shape in a reply on the board's thread: the ask's id and where, in the picture's pixels.
