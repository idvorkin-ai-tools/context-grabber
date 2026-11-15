# Decision cards in Chat — Plan

Spec: [2026-11-14-chat-decision-cards-design.md](../specs/2026-11-14-chat-decision-cards-design.md) (#878).

## The Cockpit's routes (read from idvorkin-ai-tools/cockpit `main` at c094fd5, `serve.py`; shapes confirmed by GET on the live Cockpit, 2026-11-14)

Every POST sends `Content-Type: application/json` and the Cockpit's own `Origin` (`InboxSend.origin`), as the chat
routes do; the write boundary refuses anything else.

- `GET /asks` (`list_open_asks`): `{"ok": true, "fetched_at", "asks": [...], "version"}`, open `human`-labelled beads
  only, snoozed ones left out (`?snoozed=1` puts them back), already in the queue order (`ask_queue_key`: an expiry
  first, soonest first; then priority; then oldest). 502 `{"ok": false, "error"}` when `bd` fails. Each ask
  (`normalize_ask`): `id` (the bead id, `igor2-88g.1445`), `title`, `context` (markdown), `options` `[{key, label,
  detail, image?}]`, `recommendation_key`, `recommendation_text`, `priority`, `issue_type`, `status`, `created_at`,
  `updated_at` (the revision token), `default`, `default_label`, `expires_at` (ISO UTC or ""), `seconds_left` (int or
  null, at response time), `expired` (bool), `thread` (cockpit 12956e570, cockpit-7fr: the chat key the ask
  continues, or null — its bd parent when that parent has a chat, else its own id when it has one). An expired ask is
  not closed or refused: it only reads as past its mark.
- `POST /act` — answer. `{"id", "action": "respond", "response": "DECISION: <label>", "base_updated_at"}` (the
  Cockpit's own card, `submit()` in `index.html`). `"action": "dismiss"` also exists; the app doesn't use it.
  200 `{"ok": true, "id", "action", "title"}`. 409 `{"ok": false, "error": "already closed", "ask"}` or `{"error":
  "changed since you loaded it (server at …)", "ask"}` with the fresh ask. 400 bad id / no response / fixture marker;
  404 no such bead; 502 bd failed; 503 the delivery record couldn't be written. The app also sends `"post_to_chat":
  true` (the literal true) and `"source": "app"` (as on `/chat`): once bd has the decision, the Cockpit appends Igor's
  row to the ask's `thread`, `Decided: <label>`, with an id derived from the bead (a retry posts nothing twice), and the
  200 gains `chat: {posted: true, thread, message, duplicate}` or `{posted: false, thread, error}` (no thread: `"the ask
  has no chat thread"`). A chat failure never changes the 200; without the flag nothing changes.
- `POST /close` — close or abandon. `{"id", "reason", "action": "close" | "abandon", "base_updated_at"}`. A close needs a
  reason (400 otherwise), an abandon doesn't (`Abandoned` alone). 409 `{"error": "already closed" | "changed since …",
  "id"}` — no fresh ask here. 200 `{"ok": true, "id", "action", "title"}`. Takes `post_to_chat` and `source` as `/act`
  does: `Closed: <reason>`, `Abandoned[: <reason>]`.
- `POST /snooze` — `{"id", "preset"}`, preset one of `later`, `tomorrow`, `next_week` (the card's menu), `4h`, `1d`, `1w`
  (the Inbox's swipe), `clear`. 200 `{"ok": true, "id", "snoozed_until"}` (ISO UTC). 409 `already closed`. No revision
  guard, and no `post_to_chat`.

How an ask maps to a chat: **an ask is on the chat its `thread` names** (null: on none). A Cockpit older than
12956e570 sends no `thread` key at all; then an ask is on a chat when `ask.id == thread.key` (a chat thread's key is its
bead's id, and so is an ask's), as the Cockpit's own thread page found it (`findAsk(THREAD_DATA.key)`). A present
`null` is not the fallback. *Open chat* opens `thread`, or else the ask's own id (`GET /chat/<ask id>` answers an empty
thread for one nobody has). On the live Cockpit, 2026-11-14 19:30, all 8 open asks had `"thread": null`.

After an answer, close or abandon from a thread with `chat.posted == true`, the app reads that thread again (the
Cockpit's row is Igor's message) before the card leaves, and shows no line; otherwise the line as before. The
`decision_answer` / `decision_menu` event carries `chat_posted` (true / false) and, when false, `chat_error` (the
Cockpit's `error`, or `no chat field` from an older Cockpit); a snooze carries neither.

## The app

- `ContextCore/Chat/ChatDecisions.swift`: `ChatAsk` (decoding `/asks`, `thread` and `chat` for the join), the
  requests for the four verbs, `Outcome` (`.done(snoozedUntil:chat:)` with `ChatDecisions.Posted`, `.changed(ChatAsk)`,
  `.alreadyAnswered`, `.refused(String)`), `waiting(threads:asks:)` (the keys whose row
  is marked), `expiry(_:now:)`, the snooze and abandon presets, the log fields. Host tests: `ChatDecisionsTests`, against
  `Fixtures/asks-open.json` (the live response's shape, invented asks: the repo is public).
- `App/Chat/ChatDecisionsModel.swift`: the asks read, each card's state (sending, the line it gave way to, its problem),
  the verbs run through an injected transport, the session-log events.
- `App/Chat/ChatDecisionViews.swift`: the card, its menu and the close prompt, the *Decisions* screen; `ChatViews.swift`
  places the card in a thread's top inset, the mark on `ThreadRow`, the row under Larry's.
- `scripts/native/fake-cockpit.py`: `POST /fake/asks {"open": true|false}` adds (resetting) or removes three asks and
  their two chats, each with its `thread`; `GET /asks`, `POST /act`, `/close`, `/snooze` as above, `post_to_chat`
  appending Igor's row to that fake chat; `GET /fake/answers` lists what was posted.
  Off by default, so no other class sees an extra row.
- `UITests/ChatDecisionUITests.swift`, in the chat area of `test-ladder.sh`, its map check and `test-chat-ui.sh`.
