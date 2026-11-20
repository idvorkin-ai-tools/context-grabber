#!/usr/bin/env bash
# Never start a simulator rung while more xcodebuilds run than the Mac has build lanes: startup waits fail under the
# load, so a run under contention proves nothing (docs/TESTING.md, stories 683 and 785). Waits while as many other
# xcodebuilds run as there are lanes (scripts/native/build-lane.sh count; on a one-lane Mac, any other), saying so, and
# refuses with 75 after XCODEBUILD_IDLE_WAIT seconds (default half an hour).
# Usage: xcodebuild-idle.sh   — before anything that drives the simulator
set -uo pipefail
limit=${XCODEBUILD_IDLE_WAIT:-1800}
poll=${XCODEBUILD_IDLE_POLL:-15}
lanes=$("$(dirname "$0")/build-lane.sh" count)
waited=0
running() { pgrep -x xcodebuild 2>/dev/null | wc -l | tr -d ' '; }
[ "$(running)" -ge "$lanes" ] || exit 0
if [ "$lanes" -le 1 ]; then
  echo "another xcodebuild is running: waiting up to ${limit}s, because a simulator run under contention counts as failed"
else
  echo "$(running) other xcodebuilds are running, as many as this Mac's $lanes build lanes: waiting up to ${limit}s, because a simulator run under contention counts as failed"
fi
while [ "$(running)" -ge "$lanes" ]; do
  if [ "$waited" -ge "$limit" ]; then
    if [ "$lanes" -le 1 ]; then
      echo "refused: another xcodebuild was still running after ${waited}s; nothing started" >&2
    else
      echo "refused: $lanes or more other xcodebuilds were still running after ${waited}s; nothing started" >&2
    fi
    exit 75
  fi
  sleep "$poll"
  waited=$((waited + poll))
done
if [ "$lanes" -le 1 ]; then
  echo "no other xcodebuild now, after ${waited}s"
else
  echo "fewer than $lanes other xcodebuilds now, after ${waited}s"
fi
