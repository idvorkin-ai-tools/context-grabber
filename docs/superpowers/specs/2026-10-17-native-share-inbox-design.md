# Share into Grabber Native, and Larry's inbox — Design Spec

Issue [#305](https://github.com/idvorkin/context-grabber/issues/305). Igor, 2026-10-13: *"enable us to be able to
share arbitrary content in … and we should be able to send it to Larry. We need to figure out how to give Larry an
inbox, because eventually we'll add chatting capability to this app."* He chose the phased plan, 2026-10-17. Part of
the [Swift-native app](2026-10-04-swift-native-app-design.md).

## Summary

Anything Igor can share on the phone — a link, some text, a photo, a screenshot — can be shared to Grabber Native.
It lands in an **Inbox** in the app at once, works with no network, and later goes on to Larry. The Inbox is the
first piece of a conversation with Larry inside the app.

## Goals

- One tap from any app's share sheet puts the thing in the Inbox, with an optional note.
- Nothing shared is lost: the Inbox keeps it on the phone until it has reached Larry.
- Phase 2: what is in the Inbox reaches Larry through the Cockpit, and the Inbox says which items have.

## Non-goals

- Chat with Larry (a later spec; the Inbox is shaped so a reply can sit beside what Igor sent).
- Sharing out of the app, or editing what was shared.
- Files other than text, links and images (PDFs, audio) in phase 1.

## What Igor sees

**Sharing.** In any app's share sheet, *Grabber Native* is a target. Tapping it shows a small card: a preview of
what is being shared (the link's title and address, the first lines of the text, or the image), an optional note,
and *Add to Inbox*. *Add to Inbox* closes the card at once; *Cancel* closes it with nothing kept. Sharing works in
aeroplane mode and while Grabber Native is not running. Any text the sheet offers is taken, marked-up text (RTF,
HTML) kept as plain text; a share the card cannot read says why, selectable and with *Copy*.

**The Inbox.** A launcher on the home screen, *Inbox*, with the number of items not yet sent to Larry on its tile. Its
picture is the felt raccoon of the other tiles sliding an envelope and a photo into a blue mailbox with its flag
up (Igor, 2026-10-18, #395: *"Inbox icon looks terrible. Should be racoon putting something into a mailbox"*).
It lists what was shared, newest first: what it is, the note, where it came from (a link's site; iOS does not tell
the app which app shared it), and when. A swipe deletes one. In
phase 1 every item reads *on the phone*; in phase 2, *sent to Larry* with the time, or **Not sent yet**.
While the phone has no network, one quiet line says “No network — these go to Larry when you're back online”.

**Phase 2: to Larry.** When the phone can reach the Cockpit, each item waiting goes to Larry's inbox there, oldest
first, once each. A failure leaves it waiting, never marked sent or removed, and is retried the next time the app
is opened or the network returns while the app is running. Larry sees the item, the note and when it was shared.

How it goes (the Cockpit's side shipped 2026-10-18, cockpit#63):

- **Only over the tailnet**, to the same Cockpit the app's Cockpit screen opens; reaching it is the permission, so
  nothing secret is set up on the phone.
- **When**: each time the app opens or comes to the front, and once more when a send ends if something was shared
  while it was out. No send starts until network availability is known, and none starts while offline. When the
  network returns while the app is running, the offline line disappears and waiting items send automatically.
  After a failed send, a meaningful network change (including the VPN tunnel returning while Wi-Fi stays up,
  or a change in metered or constrained access) retries waiting items too, also when the change came while that
  send was still out. A burst of such changes settles for
  half a second before one retry. Identical network updates do not start extra sends; a return or retry during
  a send requests at most one more pass after that send ends. Sharing from another app never waits on the network.
- **Once each**: an item resent after a lost answer is recognised by the Cockpit as one it already has, and reads
  *sent to Larry* like any other.
- **HEIC photos go as JPEG**; PNG, JPEG, GIF and WebP go as they are. Any photo is made smaller (as a JPEG) if
  needed so each fits the Cockpit's 10 MB.
- **Refused**: when the Cockpit says an item itself is wrong (too big, an unreadable image), it is not retried. It
  reads *Larry's inbox refused it* with the Cockpit's reason, which can be copied. A swipe deletes it as usual.
- **Unreachable or failing** (no tailnet, the Cockpit down): it stays **Not sent yet**, and the log says why.

## Adding from inside the app

Issue [#405](https://github.com/idvorkin/context-grabber/issues/405).

The Inbox toolbar has a **+** that opens an *Add to Inbox* sheet. A multi-line text field accepts typing,
pasting text and the keyboard's standard dictation mic. **Cancel** discards the draft.

Issue [#422](https://github.com/idvorkin/context-grabber/issues/422): each draft reads as one rounded box.
The note text, **Paste image** control, and any pasted picture's preview and **Remove image** control sit
together inside that box. **Add another** stays in a separate box below it. This grouping applies before and
after pasting; clipboard availability, replacing or removing a picture, and saving behave as before.

**Paste image** is available when the clipboard holds an image. Tapping it shows a small preview; the image can
be removed or replaced before adding. The picture is kept as it was copied, in its own format and the right way
up, as a share keeps it; a portrait photo stays portrait in the preview and for Larry. An image needs no text; text alongside it becomes its optional note.
Without an image, text becomes a text item, even if it looks like a link. Whitespace alone is empty and cannot
be added. One draft produces one item.

**Add** saves on the phone and closes the sheet. **Add another** saves, clears both text and image, and keeps the
sheet ready for the next item. Neither action waits for the network. A save failure keeps the draft and presents
a copyable error. Newly added items appear with the same waiting status as shares and immediately trigger the
existing send to Larry; without a connection they stay waiting for the next open.

Opening the sheet and every successful add produce a `ui` event. Adds record kind and byte size, never content.

Acceptance criteria:

- The + opens the sheet; typed or keyboard-dictated text can be added, and Add closes it.
- Add another keeps the sheet open with an empty draft after each successful save; Cancel adds nothing further.
- Paste image previews the clipboard image and adds it with any accompanying text as its note; a portrait photo
  stays upright.
- The note and Paste image share one rounded box, including the preview and Remove image when a picture is
  pasted; Add another remains separate below the item.
- Empty drafts cannot be added; failed saves preserve the draft with a copyable explanation.
- Each saved draft is one waiting item in the shared Inbox and triggers sending through the existing path.

## Explaining itself

- Each share is logged (`inbox`, action added, with the kind and size, never the content) when the app next opens
  and finds it.
- Each send in phase 2 is logged (`inbox`, action sent / refused / failed, with the item and the Cockpit's answer).
- Skipping a send while offline and sending when the network returns are logged (`inbox`, action offline_skipped /
  network_back, with the waiting count, never the content).

## Acceptance criteria

- Sharing a Safari link, a Notes text and a Photos image each puts one item in the Inbox, with the note, within a
  second, in aeroplane mode too.
- The Inbox tile shows the raccoon posting a letter and counts the items not yet sent; deleting one updates it.
- Phase 2: with the Cockpit reachable, every waiting item reaches Larry once and then reads *sent to Larry*;
  with it unreachable or failing, items remain **Not sent yet** and stay counted on the tile.
- With no network, the Inbox shows the quiet offline line and attempts no send; a network that comes up on demand
  (an on-demand VPN) counts as available, so the send is tried and no offline line shows. On network return while the app
  is running, the line disappears and waiting items send without reopening the app; repeated available-network
  updates with identical network details do not cause extra sends, and a send already in progress is never overlapped.
- After a failed send, reconnecting the tailnet while Wi-Fi or cellular stays available retries waiting items,
  even when the tailnet returned before that send failed; meaningful network changes in a burst cause one retry after settling, and an empty Inbox never retries.
- Phase 2: an item the Cockpit refuses reads *Larry's inbox refused it* with the reason, copyable, and is not sent
  again; a HEIC photo arrives at Larry as a JPEG.
