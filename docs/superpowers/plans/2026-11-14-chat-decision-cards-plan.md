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
  null, at response time), `expired` (bool). An expired ask is not closed or refused: it only reads as past its mark.
- `POST /act` — answer. `{"id", "action": "respond", "response": "DECISION: <label>", "base_updated_at"}` (the
  Cockpit's own card, `submit()` in `index.html`). `"action": "dismiss"` also exists; the app doesn't use it.
  200 `{"ok": true, "id", "action", "title"}`. 409 `{"ok": false, "error": "already closed", "ask"}` or `{"error":
  "changed since you loaded it (server at …)", "ask"}` with the fresh ask. 400 bad id / no response / fixture marker;
  404 no such bead; 502 bd failed; 503 the delivery record couldn't be written.
- `POST /close` — close or abandon. `{"id", "reason", "action": "close" | "abandon", "base_updated_at"}`. A close needs a
  reason (400 otherwise), an abandon doesn't (`Abandoned` alone). 409 `{"error": "already closed" | "changed since …",
  "id"}` — no fresh ask here. 200 `{"ok": true, "id", "action", "title"}`.
- `POST /snooze` — `{"id", "preset"}`, preset one of `later`, `tomorrow`, `next_week` (the card's menu), `4h`, `1d`, `1w`
  (the Inbox's swipe), `clear`. 200 `{"ok": true, "id", "snoozed_until"}` (ISO UTC). 409 `already closed`. No revision
  guard.

How an ask maps to a chat: a chat thread's key is its bead's id, and an ask's id is its bead's id, so **an ask is on a
chat when `ask.id == thread.key`** (a chat's bead promoted with `ask.py --promote`, or an ask's bead someone wrote to;
`GET /chat/<ask id>` answers an empty thread for one nobody has). The Cockpit's own thread page draws the ask card the
same way (`findAsk(THREAD_DATA.key)`). On the live Cockpit, 2026-11-14, none of the 8 open asks had a chat yet. An ask
filed with `--parent <chat bead>` is linked only in bd's parent chain, which `/asks` doesn't send: missing, asked of Larry.

## The app

- `ContextCore/Chat/ChatDecisions.swift`: `ChatAsk` (decoding `/asks`), the requests for the four verbs, `Outcome`
  (`.done`, `.changed(ChatAsk)`, `.alreadyAnswered`, `.refused(String)`), `waiting(threads:asks:)` (the keys whose row
  is marked), `expiry(_:now:)`, the snooze and abandon presets, the log fields. Host tests: `ChatDecisionsTests`, against
  `Fixtures/asks-open.json` (the live response's shape, invented asks: the repo is public).
- `App/Chat/ChatDecisionsModel.swift`: the asks read, each card's state (sending, the line it gave way to, its problem),
  the verbs run through an injected transport, the session-log events.
- `App/Chat/ChatDecisionViews.swift`: the card, its menu and the close prompt, the *Decisions* screen; `ChatViews.swift`
  places the card in a thread's top inset, the mark on `ThreadRow`, the row under Larry's.
- `scripts/native/fake-cockpit.py`: `POST /fake/asks {"open": true|false}` adds (resetting) or removes three asks and
  their two chats; `GET /asks`, `POST /act`, `/close`, `/snooze` as above; `GET /fake/answers` lists what was posted.
  Off by default, so no other class sees an extra row.
- `UITests/ChatDecisionUITests.swift`, in the chat area of `test-ladder.sh`, its map check and `test-chat-ui.sh`.
