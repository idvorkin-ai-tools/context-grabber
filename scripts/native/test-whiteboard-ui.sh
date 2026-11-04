#!/usr/bin/env bash
# The whiteboard turn, paste and boards-list UI tests on the simulator (stories 344, 345, 349, 351, 354, 357, 358, 360, 367, 370, 371, 373, 378, 380, 382, 383, 386, 388, 390, 391, 392, 393, 396, 399, 402, 403, 435–439, 524–534, 590–626), with a fake Cockpit:
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
cockpit=
trap 'kill $cockpit 2>/dev/null || true; xcrun simctl shutdown "$udid" 2>/dev/null || true' EXIT
# Keyboard events reach the app only in the first test run after a boot, so the ⌘V test needs a fresh simulator.
xcrun simctl shutdown "$udid" 2>/dev/null
xcrun simctl boot "$udid" && xcrun simctl bootstatus "$udid" >/dev/null || { echo "the simulator did not boot" >&2; exit 1; }
scripts/native/fake-cockpit.py "$port" "$report" >/dev/null 2>&1 &
cockpit=$!
sleep 1
kill -0 "$cockpit" 2>/dev/null || { echo "the fake Cockpit did not start on port $port" >&2; exit 1; }
TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" scripts/native/xcodebuild-log.sh whiteboard-ui "TEST SUCCEEDED" \
  xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
  -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
  -only-testing:GrabberNativeUITests/WhiteboardTurnUITests -only-testing:GrabberNativeUITests/WhiteboardPasteUITests -only-testing:GrabberNativeUITests/WhiteboardRowDeleteUITests -only-testing:GrabberNativeUITests/WhiteboardTrialOnPaperUITests -only-testing:GrabberNativeUITests/WhiteboardOnPaperUITests -only-testing:GrabberNativeUITests/WhiteboardPaperGhostsUITests -only-testing:GrabberNativeUITests/WhiteboardTurnOnPaperUITests -only-testing:GrabberNativeUITests/WhiteboardPasteOnPaperUITests -only-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests -skip-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests/test1CommandVOnPaperAndCommandZ test
status=$?
# Keys reach the app for one test per boot, and the old canvas's ⌘V test had this boot's: ⌘V on paper gets the next.
xcrun simctl shutdown "$udid" 2>/dev/null
xcrun simctl boot "$udid" && xcrun simctl bootstatus "$udid" >/dev/null || { echo "the simulator did not boot again" >&2; exit 1; }
TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" scripts/native/xcodebuild-log.sh whiteboard-keys "TEST SUCCEEDED" \
  xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
  -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
  -only-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests/test1CommandVOnPaperAndCommandZ test-without-building || status=1
grep -q 'Igor just said: draw a circle' "$report" || { echo "the spoken words never reached the fake Cockpit"; status=1; }
if grep -q 'draw a square' "$report"; then echo "words spoken with Ghosts off reached the fake Cockpit"; status=1; fi
echo "fake Cockpit: $(grep -c "\"turn\": \"claude\"" "$report") ghost turns, $(grep "\"body\"" "$report" | grep -c "\"picture_id\"") board pictures to Larry"
exit $status
