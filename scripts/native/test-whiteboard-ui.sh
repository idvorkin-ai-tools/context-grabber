#!/usr/bin/env bash
# The whiteboard turn and paste UI tests on the simulator (stories 344, 345, 349, 351, 354, 357, 358, 360, 367, 370, 371, 373, 380, 382, 383, 386, 388, 390, 391, 392, 393), with a fake Cockpit:
# scripts/native/fake-cockpit.py on a local port.
# The tests read the address as GRABBER_FAKE_COCKPIT (xcodebuild passes TEST_RUNNER_* through to the runner).
# Usage: test-whiteboard-ui.sh <simulator udid>   — run it in the build lane:
#   lockf -k -t 3600 ~/tmp/agent/locks/build.lock ~/gits/mac-driver/bin/time-limit 30 caffeinate -i \
#     scripts/native/test-whiteboard-ui.sh <udid>
set -uo pipefail
udid=$1
port=${CHAT_PORT:-8799}
report=$(mktemp -t fake-cockpit)
cd "$(dirname "$0")/../.."
scripts/native/fake-cockpit.py "$port" "$report" >/dev/null 2>&1 &
cockpit=$!
trap 'kill $cockpit 2>/dev/null || true' EXIT
sleep 1
kill -0 "$cockpit" 2>/dev/null || { echo "the fake Cockpit did not start on port $port" >&2; exit 1; }
TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" scripts/native/xcodebuild-log.sh whiteboard-ui "TEST SUCCEEDED" \
  xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
  -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
  -only-testing:GrabberNativeUITests/WhiteboardTurnUITests -only-testing:GrabberNativeUITests/WhiteboardPasteUITests test
status=$?
grep -q 'Igor just said: draw a circle' "$report" || { echo "the spoken words never reached the fake Cockpit"; status=1; }
if grep -q 'draw a square' "$report"; then echo "words spoken with Ghosts off reached the fake Cockpit"; status=1; fi
echo "fake Cockpit: $(grep -c "\"turn\": \"claude\"" "$report") ghost turns, $(grep -c "\"picture_id\"" "$report") board pictures to Larry"
exit $status
