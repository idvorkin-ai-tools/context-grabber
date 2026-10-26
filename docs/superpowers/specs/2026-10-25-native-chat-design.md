# Chat with Larry in Grabber Native — Design Spec

Igor, 2026-10-25: *"can we iterate on inbox feature so it's more like chat? … I want to be able to have chat threads
there and stop needing telegram if I don't want it."* On sharing: *"share to a new thread."* On hearing back: *"A and
B"* — the app refreshes while open and counts unread replies, and a background check notifies of Larry's replies.
This is the "later spec" the [Inbox spec](2026-10-17-native-share-inbox-design.md) left room for; it replaces the
Inbox's list. Part of the [Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

The Inbox becomes **Chat**: a list of conversations with Larry, each a thread of Igor's messages and Larry's replies.
Every share from another app starts a new thread. The threads are the Cockpit's chat threads — the same ones the
Cockpit's Chat tab shows and Larry already answers — so a conversation started on the phone can be picked up on the
laptop and back. Writing still works with no network, as the Inbox does today. While the app is open the thread
updates by itself; while it is not, the phone checks now and then and notifies Igor of a reply.

## Goals

- Talk to Larry in threads from the phone, without Telegram.
- Every share starts its own thread, with the shared thing as its first message.
- Nothing written is lost: a message waits on the phone until the Cockpit has it, and reaches it once.
- Igor can tell, without opening each thread, which ones Larry has answered.

## Non-goals

- Instant alerts like Telegram's. That needs real push and a paid developer account; a later spec (option C) if
  wanted. Telegram stays available for anything that must arrive at once.
- Larry starting a conversation that only Telegram carries. Threads Larry starts on the Cockpit do appear here.
- Searching, renaming, closing or deleting threads from the phone. Closing is done on the Cockpit, as now.
- A voice conversation inside a thread (the Call screen is that). Speaking a message is in (#448): it becomes text
  Igor reads before he sends.

## What Igor sees

**The tile.** The home-screen *Inbox* tile becomes *Chat*, with the same raccoon-and-mailbox picture. Its number is
the conversations with a reply Igor has not read, plus any of his messages not yet sent.

**The list.** Newest activity first. Each row: the thread's title, the last message's first line and who wrote it,
when, and an unread mark when Larry has replied since Igor last looked. Finished threads fold under *Done*, by the
same rule the Cockpit uses, so the phone and the laptop agree. The round **+** stays at the lower right; it starts a
new thread. Pull to refresh. With no network, the quiet offline line from the Inbox stays.

**A thread.** Bubbles: Igor's on the right, Larry's on the left, oldest at the top, opening at the newest. Images
show inline, tap to see full size. Links are tappable. Under each of Igor's messages, its state: **Not sent yet**,
sent, 👀 when Larry has seen it, 🏆 when the thing is done (with Larry's note). Opening a thread marks it read here
and on the laptop. The thread updates by itself every few seconds while it is open, and the list on each return to
it.

**Writing.** One bar at the bottom: a growing text field with the keyboard's dictation mic, a *Paste image* control
when the clipboard holds an image (preview, remove), and *Send*. Send needs text or an image. A sent message appears
at once with **Not sent yet** until the Cockpit has it, and the bar empties at once, text and image, with the keyboard
still up for the next message — typed or dictated alike (#449). A new thread from the **+** asks for its first message only;
its title is that message's first line.

**Speaking a message** (#448). Igor, 2026-10-26: *"transcription based, use a good model like we do in cockpit (need a
stored key is fine)."* The bar has a mic button beside the field. Tap it to record; it turns red and shows the
seconds counting; tap it again to stop. The recording goes to the same transcription service and model the Cockpit's
mic uses (Deepgram, nova-3, primed with the Cockpit's list of names to spell right — Igor, Larry, Tori, Zach, Amelia,
Kettlebility, beads, Cockpit), and while it is out the button shows it is working. The words land **in the field**, after anything
already typed — never sent. Igor reads them, fixes what he likes, and taps Send. A clip of silence, or a recording
with nothing heard, leaves the field as it was and says *Nothing heard*. The recording itself is not kept.

- **The key.** The service needs Igor's Deepgram key, pasted once in *Settings → Voice in Chat* and kept in the
  phone's Keychain, on this phone only. Settings says whether one is saved, never shows it, and can remove it. Until
  one is saved, the mic button says where to add it instead of recording.
- **The microphone.** The first tap asks for the microphone (the same permission calls use). Declined, the button
  says how to allow it in the phone's Settings.
- **A live call.** While a call with Larry is live, the mic is the call's: the button is dimmed and says so, and a
  call that starts mid-recording stops the recording and leaves the field as it was. Recording never changes a live
  call's sound.
- **An interruption.** A phone call or Siri mid-recording stops the clock; what was recorded so far is transcribed
  into the field as if Igor had tapped stop (still never sent), and a line under the bar says the recording was
  stopped by an interruption.
- **Music.** Recording pauses whatever was playing, as dictation does; it may resume when the recording stops.
- **Failures** (no network, a refused key, the service down) are copyable errors above the bar, with what the service
  said; the recording is dropped and the field is unchanged.

**Sharing in.** The share card is unchanged — preview, optional note, *Add to Inbox* becomes *Start a chat*. Each
share becomes a new thread whose first message is the shared thing with the note. The title is the note's first
line, else the text's, else the link's site, else *Photo, <date>*. It works in aeroplane mode and while the app is
not running, as now.

**Sending.** The same rules the Inbox has: tried when the app opens or comes to the front, when the network returns
and after a failed send's network change, oldest first, never while offline. A message resent after a lost answer
appears once on the thread, and a share resent after a lost answer makes one thread, not two. A message the Cockpit
refuses (too big, an unreadable image) reads *Larry refused it* with the reason, copyable, and is not resent; a swipe
deletes it. Unreachable keeps it **Not sent yet**.

**Hearing back.** iOS runs a background check now and then — it decides when, so a reply may wait minutes or hours.
When the check finds a reply Igor has not seen, one notification per thread: *Larry* and the thread's title, with the
reply's first line. Tapping it opens that thread. A reply already read on the laptop raises nothing, nor does a
thread marked Done. The very first check after install only takes note of what is already there, so weeks of
unread laptop threads do not arrive as a burst; only replies after it notify. Notifications
need Igor's permission, asked once, the first time he sends a message; declining leaves everything else working.

**What was in the Inbox.** Items still waiting when this ships each become a new thread, as a share would. Items
already sent to Larry's inbox stay readable under one *Earlier shares* row at the bottom of the list, read-only, and
can be swiped away.

**What the phone keeps.** A message stays on the phone until the Cockpit's thread shows it; once Igor sees it there,
in an open thread, the phone's copy (and its picture) is dropped, so the phone does not fill up with old chat.

## Explaining itself

- `chat` events in the session log: sent / refused / failed (thread, message id, the Cockpit's answer; never the
  text; a new thread's sent line names where it landed), offline_skipped and network_back as the Inbox logs them,
  refreshed (count of unread), and background_check (when iOS ran it, what it found, notifications raised).
- `chat_voice` events: record start / stop (seconds, bytes), interrupted, transcribed (status, characters, round trip), failed (the
  stage, the status, the service's message), refused (no key, no microphone, a live call). Never the words, never the
  key.
- A thread that cannot be read logs one error when the problem starts or changes, not one per poll.
- Every error on screen is copyable, with the thread and the Cockpit's answer.

## Acceptance criteria

- The tile reads *Chat* and counts unread conversations plus unsent messages.
- The list shows every Cockpit chat thread, Done folded the same as the Cockpit; opening one marks it read on both.
- A message typed or dictated in a thread appears at once, reads **Not sent yet** offline, and reaches the Cockpit
  once when the network returns; Larry's reply appears in the open thread within seconds without a manual refresh.
- Sharing a Safari link, a Notes text and a Photos image makes three new threads with sensible titles, in aeroplane
  mode too, each delivered once.
- 👀 and 🏆 appear under Igor's messages as Larry marks them.
- With the app closed, a reply from Larry eventually raises one notification for its thread; tapping it opens the
  thread; a reply already read elsewhere, or in a Done thread, raises none; the first check after install raises
  none.
- A refused message says why, copyably, and is never resent.
- With a key saved, tap the mic, speak, tap again: the words appear in the field after what was typed, nothing is
  sent until Send; silence leaves the field unchanged. With no key the mic says where to add it; during a live call it
  is dimmed and says why; a failed transcription is a copyable error and the field is unchanged.
- Waiting Inbox items become threads on first launch; sent ones stay under *Earlier shares*.

## Depends on the Cockpit

Two small changes there (a PR to idvorkin-ai-tools/cockpit), before the phone half:

- Messages from the phone are recognised as the phone's, alongside the page, the command line and Telegram.
- A message or new thread resent with the same id is recognised as one already taken, as Larry's inbox does today.
