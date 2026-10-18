# Share inbox (#305): implementation plan

Spec: [2026-10-17-native-share-inbox-design.md](../specs/2026-10-17-native-share-inbox-design.md). Stories 038
(phase 1) and 039 (phase 2). Cockpit contract: idvorkin-ai-tools/cockpit#63 (`POST /inbox`, shipped 2026-10-18).

## Storage: a directory in the App Group, one file per item

The share extension and the app are two processes, so the Inbox is not in the app's SQLite database (one writer,
the app). It lives in the App Group container under `Inbox/`:

- `<id>.json`: the item (`InboxItem`), written atomically and written last.
- `<id>.<ext>`: an image's bytes as shared, written first, so a `.json` always has its image.

The extension only creates items. The app reads the directory, records sending in place (`sent_at`, or `refused`
with the reason), and deletes. A `.json` the app cannot decode is left alone and logged.

| Choice | Why |
|---|---|
| Files, not SQLite | SQLite across two processes needs WAL, a shared path and care with locks; one file per item has no shared write. |
| The app records sends | Only one process ever rewrites an item. |
| The original image kept, converted at send time | Sharing stays instant and low-memory in the extension (its limit is about 120 MB); JPEG conversion runs in the app. |

## ContextCore (host-tested)

- `InboxItem`: id (a lowercase UUID, fits the Cockpit's `[A-Za-z0-9_-]{1,64}`), kind (link / text / image),
  shared_at (ms), url, text, note, image file name, sent_at, refused reason. `status`: waiting / sent / refused.
- `InboxStore(directory:)`: `add`, `items()` (newest first), `waiting()` (oldest first), `waitingCount`,
  `markSent`, `markRefused`, `delete` (the item and its image).
- `InboxSend`:
  - `request(item:image:cockpit:)` builds the `POST /inbox` request: JSON per the contract, `Origin` set to the
    Cockpit's https origin (no token is set up), `shared_at` as ISO 8601.
  - `outcome(status:body:)` reads the answer: 200 ok (with `duplicate`) means sent; 4xx means refused with the
    reason, never retried; 5xx or no answer means retry.
- `InboxImage.jpeg(from:maxBytes:)` re-encodes HEIC or anything else to JPEG with ImageIO, which runs on the host
  too. It steps the size down (4096, 3072, 2048 px on the long side) until the JPEG fits 10 MB. PNG, GIF and WebP
  go as they are.
- `InboxSender`: sends waiting items oldest first with an injected transport, records each outcome, and stops at
  the first retry (the Cockpit is unreachable, so the rest would fail too). It logs `inbox` sent / refused / failed.

## The share extension (`GrabberShare`, new XcodeGen target)

- `com.apple.share-services`. The activation rule allows one web URL, text, or one image.
- A `UIViewController` hosting a SwiftUI card with a preview, a note field, *Add to Inbox* and *Cancel*. It reads
  the `NSItemProvider` (URL first, then image, then text), writes the item with `InboxStore`, and completes the
  request. No network.
- Sources: `Share/` and `Shared/` (the App Group id). The App Group entitlement matches the widgets'. Its bundle id
  is `com.idvorkin.grabbernative.share`.

## The app

- An `inbox` home row, with the waiting count on its tile and a `tray` glyph until it has drawn art (ponytail:
  the art comes with Igor's pick, as the other tiles' did).
- `InboxView`: the list, swipe to delete, each item's status. A refused item shows its reason in
  `BugProblemView`, so it can be copied.
- `AppModel`, on launch and on becoming active:
  1. log `inbox` added for items not seen before (kept in settings as the last seen ids);
  2. run `InboxSender` against `CockpitPage.url`.
- The launch hook `GRABBER_INBOX=open` opens the Inbox, and `GRABBER_INBOX_FIXTURE=1` writes three items so the
  simulator smoke and a UI test can see them.

## Verification

- Host: `InboxStoreTests`, `InboxSendTests` (the body per item kind, the Origin header, every answer class) and
  `InboxImageTests` (a HEIC made on the host comes out as JPEG under the cap).
- Simulator (build turn): the build, the fixture Inbox, a swipe, the tile count. The share sheet itself can't be
  driven by simctl.
- Phone: sharing from Safari, Notes and Photos in aeroplane mode, then a send over the tailnet.
