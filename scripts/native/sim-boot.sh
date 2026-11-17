#!/usr/bin/env bash
# Story 980: makes this simulator the one booted on the Mac, booting it only if it isn't up. Every other booted
# simulator is shut down first (one booted takes about 10 GB of the Mac's 16), and the target is left booted afterwards
# for the next run: an iOS 27 boot writes about 300 MB of wallpaper snapshots that are never evicted, and spikes the CPU.
# Run it inside the build lane, which keeps simulator work to one job at a time.
# Usage: sim-boot.sh <simulator name or udid>
set -uo pipefail
udid=$("$(dirname "$0")/sim-udid.sh" "${1:?simulator name or udid}") || exit
xcrun simctl list devices booted | grep -oE '\(([0-9A-F-]{36})\) \(Booted\)' | grep -oE '[0-9A-F-]{36}' |
  while IFS= read -r other; do
    [ "$other" = "$udid" ] || xcrun simctl shutdown "$other" 2>/dev/null
  done
# -b boots it only if it isn't booted, and returns at once if it is; a bare bootstatus after a failed boot waits forever.
xcrun simctl bootstatus "$udid" -b >/dev/null || { echo "the simulator $udid did not boot" >&2; exit 1; }
