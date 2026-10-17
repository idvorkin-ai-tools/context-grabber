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
aeroplane mode and while Grabber Native is not running.

**The Inbox.** A launcher on the home screen, *Inbox*, with the number of items not yet sent to Larry on its tile.
It lists what was shared, newest first: what it is, the note, where it came from, and when. A swipe deletes one. In
phase 1 every item reads *on the phone*; in phase 2, *sent to Larry* with the time, or *waiting to send*.

**Phase 2: to Larry.** When the phone can reach the Cockpit, each item waiting goes to Larry's inbox there, oldest
first, once each. A failure leaves it waiting and is retried the next time the app is opened; it is never sent
twice. Larry sees the item, the note and when it was shared.

## Explaining itself

- Each share is logged (`inbox`, action added, with the kind and size, never the content).
- Each send in phase 2 is logged (`inbox`, action sent / failed, with the item and the Cockpit's answer).

## Acceptance criteria

- Sharing a Safari link, a Notes text and a Photos image each puts one item in the Inbox, with the note, within a
  second, in aeroplane mode too.
- The Inbox tile counts the items not yet sent; deleting one updates it.
- Phase 2: with the Cockpit reachable, every waiting item reaches Larry once and then reads *sent to Larry*;
  with it unreachable, items wait and go on the next open.
