# Chat with Larry — implementation plan

Spec: [2026-10-25-native-chat-design.md](../specs/2026-10-25-native-chat-design.md). Cockpit half: cockpit#64 (story
129: `source: app`, idempotency by the client's `id` on `POST /chat` and `POST /chat/<key>`).

## The outbox is the Inbox store

Nothing new on disk. `InboxItem` gains two optional fields:

- `thread` — the Cockpit thread key it is posted to. `nil` starts a new thread (every share, every **+**).
- `chat_thread` — the key it landed on, set with `sent_at`. A sent item with no `chat_thread` was sent to Larry's
  inbox before chat: it lives under *Earlier shares*.

So the spec's migration is free: an item still waiting at upgrade has no `thread`, and goes out as a new thread.

## Sending (ContextCore `ChatSend`, `InboxSender`)

Per waiting item, oldest first, stop at the first retry (as now):

1. An image: `InboxSend.sendable` (HEIC → JPEG, ≤ 10 MB), then `POST /attachments` with the raw bytes → `ref`. A 4xx is
   *refused*; anything else is a retry. A retried upload leaves an orphan file on the box (ponytail: harmless, the
   Cockpit's attachments are day directories).
2. `thread == nil`: `POST /chat {id, title, text, source: app, attachments}`; else `POST /chat/<key> {id, text, source,
   attachments}`. The item's id is the message id (`[a-z0-9-]{36}` fits the Cockpit's `[A-Za-z0-9_-]{8,64}`).
3. `200 ok` → sent, `chat_thread` = the answer's `thread`. 4xx → refused with the reason. Else retry.

Message text: a link is its URL, then a blank line and the note; text is the text, then the note; an image is its note.
Title of a new thread: the note's first line, else the text's, else the link's site, else *Photo, <date>*; ≤ 80 chars.

## Reading (ContextCore `ChatWire`)

`GET /chat` → summaries (`key, title, count, last_ts, last_who, last_text, unread, done, igor_receipt`).
`GET /chat/<key>` → messages (`id, ts, who, text, source, attachments: [ref], receipt {state, note}`).
`POST /chat-seen {thread}` when a thread is opened. Images at `<cockpit>/attachments/<ref>`.

A thread's screen merges the server's messages with this phone's outbox items for that thread whose id the server
does not have yet (shown **Not sent yet**, or *Larry refused it*). A new thread not yet sent is a list row of its own.

## Hearing back (`ChatNotify`, App `ChatBackground`)

Pure: given summaries and the `last_ts` each thread was last notified at, the threads to notify — Larry has the last
word, `unread > 0`, newer than what was notified. A `BGAppRefreshTask` (`com.idvorkin.grabbernative.chat`) fetches
`GET /chat`, posts one local notification per such thread (`threadIdentifier` = key, so iOS groups), records the
notified stamps, and schedules the next (earliest begin 15 min; iOS decides). The foreground refresh records them
too, so a reply read in the app never notifies later. Permission is asked once, at the first send. Tapping opens
`grabbernative://chat?thread=<key>`.

## UI (App)

- `ChatModel`: the list, one thread's messages, polling every 4 s while a thread is on screen, seen on open.
- `ChatListView` replaces the Inbox list; `ChatThreadView` with a compose bar (text, paste image, send); the round
  **+** opens a new-thread composer (first message only). The tile reads *Chat*; its count is unread threads +
  waiting items.
- Share extension: *Add to Inbox* → *Start a chat*.

## Verification

Host: `ChatSend`, `ChatWire`, `ChatNotify`, the sender against a fake transport (new thread, existing thread, image
upload then post, refused upload, retry stops the run, duplicate answer is sent). Simulator: a fake Cockpit for
`/chat` (extend `scripts/native/fake-bridge.py` or a small `fake-cockpit.py`), the list, a thread, sending. Phone: the
real Cockpit once cockpit#64 is merged and `serve.py` restarted.
