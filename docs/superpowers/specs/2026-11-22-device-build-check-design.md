# Knowing which build is on Igor's devices

Bead context-grabber-yfsz, part 1. Igor via Larry, 2026-11-22, asking "do we auto-detect this kind of issue?"

## Why

On 2026-11-22 an agent told Larry that the iPad was on b3e9de18. In fact the iPad had been on 5569178f since about
22:57, when another install that nobody tracked had put it there. Igor's board posts, and the session log the app
starts on launch, both named 5569178f. Larry then pointed Igor at a feature the agent thought wasn't installed. Nothing
compared what agents believed with what the device said.

## Goals

- Record every install on Igor's devices: the network install of every paired device, the cable install, and a build
  posted over the air for the iPad.
- Answer "which build is on the iPad (or the phone), and is it the one we think?" with one command, from what the
  device itself last reported.
- Have a deploy ask that question once the device's next session shows up, so a wrong belief is caught minutes after
  an install, not when Igor asks.

## Non-goals

- Pushing anything to the device, or reading it live. The answer comes from the session logs that `just pull-logs`
  copies.
- TestFlight builds. TestFlight already has its own record of uploads.

## What it does

- **Every install is recorded** in the deploys ledger that already serves the lead-time and ladder reports. Each entry
  names the device, the commit, the time and how it got there:
  - `cable`: `just native-run-device`, as before.
  - `network`: the new `just deploy`, which runs BugKit's install on every paired device, or the ones named with
    `--only`, and records each device that reports "installed".
  - `ota_posted`: `just ota` posting a build for the iPad. That's only an offer, since the iPad installs it when Igor
    taps it on /builds, so the check accepts either that build or the last install before it.
- **`just device-build-check [ipad|phone …]`** reads, for each device, the newest session its logs hold and the build
  that session names. It compares that with the ledger's last install, and prints one line per device:
  - **MATCH:** the device runs the build we last installed.
  - **MISMATCH:** the build it runs, from when, against the one we think, from when. It exits 1.
  - **NO SESSION YET:** no session started since the last install, for example because the app hasn't been opened.
  - **UNKNOWN:** no install recorded, or no log pulled for that device.
- **After `just deploy`,** the logs are pulled and the check run for the devices just installed, waiting up to two
  minutes for the session that the install's launch starts. A mismatch is printed with both builds, and the deploy
  exits non-zero.
- **Agents install through `just deploy`,** not by calling BugKit's script directly, so no install goes unrecorded.

## Acceptance criteria

- An install by `just deploy --only ipad` adds an entry for the iPad with the commit installed and `network`.
- The iPad's newest session naming the installed commit reads MATCH. A session naming another commit after the
  install reads MISMATCH with both, and the check exits 1.
- No session after the install reads NO SESSION YET, not MATCH from an older session.
- A build posted over the air that the iPad then reports reads MATCH.
- A device with no install recorded, or no logs, reads UNKNOWN, and the check doesn't fail.
