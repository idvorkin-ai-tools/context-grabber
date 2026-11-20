#!/usr/bin/env bash
# Prints the UDID of the simulator named $1 on the newest available runtime, or $1 itself when it is already a
# UDID. `simctl` addresses devices by name, and every Xcode update leaves a second "iPhone 17" on the older
# runtime behind: a boot by name and a launch by name can then land on different devices (Xcode 27, 2026-09-15).
# Usage: scripts/sim-udid.sh "iPhone 17"   (in build lane 3: the udid of "iPhone 17 lane 3")
set -euo pipefail
name=${1:?simulator name or UDID}
if [[ "$name" =~ ^[0-9A-Fa-f-]{36}$ ]]; then echo "$name"; exit 0; fi
# Story 980 (#954): in build lane N past 1, the name means the lane's own copy, "<name> lane N", made once.
if [ "${BUILD_LANE:-1}" -gt 1 ] 2>/dev/null; then name=$("$(dirname "$0")/build-lane.sh" sim "$name") || exit 1; fi
# The listing groups devices under "-- <runtime> --" headers in ascending version order; the last match wins.
udid=$(xcrun simctl list devices available | grep -F -- "    $name (" | tail -1 | grep -oE "[0-9A-F-]{36}" | head -1 || true)
if [ -z "$udid" ]; then
  echo "FAIL  no available simulator named '$name' (xcrun simctl list devices available)" >&2
  exit 1
fi
echo "$udid"
