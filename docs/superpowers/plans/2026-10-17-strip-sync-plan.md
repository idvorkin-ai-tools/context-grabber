# Daily strip sync over iCloud: plan (#376)

Spec: [native home screen](../specs/2026-10-06-native-home-screen-design.md), *The same strip on the phone and the
iPad*. Story 153. This holds the implementation; the spec holds the behaviour.

## Transport: the iCloud key-value store (option A on the decisions page)

`NSUbiquitousKeyValueStore`, not a CloudKit database: the strip is about 5 values a day, the store syncs within a
minute, works offline and needs no container. Limits are 1 MB and 1024 keys per app, and a key is last-writer-wins,
so **each device writes only its own keys**, one per month:

    strip.<device-id>.<yyyy-mm>  →  JSON {"<yyyy-mm-dd>": {"<item>": [value, updated_at_ms]}}

iCloud carries the last 12 months (`StripSync.monthsKept`): each device removes its own older keys when it publishes, and ignores other devices' older months and any key that left (a key leaving is pruning, so the local copy stays, whatever each device's clock says). A year of every item every day is a few tens of KB per device, so even four devices stay far under 1 MB (Codex on #378). The device id is `UIDevice.identifierForVendor`, so a
backup restored onto another phone gets a new one; the last id is kept in `settings` (`strip_device_id`). When it
changes (only a restore or a transfer brings the database to a new id, and the phone it came from may still be in
use), this install's rows are handed over as the old id's peer rows, replaced by that id's keys when they arrive,
and this install starts its own rows empty, so the carried history counts once and nothing is deleted. The
hand-over is one transaction; if it fails the id is not saved and sync stays off until the next launch tries again.
The ids handed to are kept in `settings` (`strip_handed_over`) so an account change keeps their rows.

## Merge (ContextCore, host-tested)

- Each row is `(device, day, item, value, updated_at)`. This device's rows are the `daily_strip` table, which gains
  an `updated_at` column (0 for the rows from before). Other devices' rows go in a new `daily_strip_peers` table.
- **Counters** (balloons, magic): the day's value is the sum over devices. A long press lowers this device's own
  count, never below 0.
- **Checks** (gym, meditation, journal): the row with the latest `updated_at` across devices wins. A tap on this
  device writes a new row with now's time, so any device can check or uncheck.
- `days(item)` and `value(item, day)` read the merged view, so days since and the backdate sheet see the
  shared days. The derived gym and meditation days (the timer, breathing, Health) stay per device, as now.

## App (`native/App/Daily/`)

- `StripCloudSync` owns the store. At launch it publishes every month this device has (a no-op once synced) and
  calls `synchronize()`. After each `set` it publishes that day's month. On
  `didChangeExternallyNotification` it decodes the changed keys of other devices, replaces their rows for those
  months in `daily_strip_peers`, and asks `DailyStripModel` to refresh. On an account change (which may list no
  keys) it clears the peers (but the handed-over ids'), publishes every month again and rebuilds from the whole store. Decode reads each day
  and item on its own, so one bad entry skips only itself.
- Log: `strip_sync` with `action` `publish` (months, all, aged_out), `arrived` (device, months, reason), `account_change` (keys),
  `device_changed` (handed_over_rows);
  failures are `error` with `where` strip_sync_publish, strip_sync_hand_over,
  strip_sync_arrived or strip_sync_quota.
- Entitlement: `com.apple.developer.ubiquity-kvstore-identifier: $(TeamIdentifierPrefix)$(CFBundleIdentifier)`
  in `native/project.yml`. That's a native build and a provisioning update (automatic signing handles it).

## Verification

- Host: encode/decode round trip, key naming, the merge rules (counts sum, latest check wins, an untick from
  another device), the table migration, the 12-month window across year boundaries, and a full year of every item
  on four devices under half the 1 MB quota.
- Simulator: a launch hook can't see a second device. The smoke checks that the strip still works with no iCloud
  account (the store is a no-op there).
- Phone + iPad: the story's scenario, read from both devices' logs.
