#!/usr/bin/env bash
# The whiteboard turn, paste and boards-list UI tests on the simulator (stories 344, 345, 349, 354, 357, 360, 371, 378, 380, 382, 383, 386, 388, 390, 391, 392, 393, 396, 399, 402, 403, 435–439, 524–534, 590–626, 637–641, 643–646, 650, 652–657, 880–885, 954, 956–958, 1098, 1127), with a fake Cockpit:
# scripts/native/fake-cockpit.py on a local port.
# The tests read the address as GRABBER_FAKE_COCKPIT (xcodebuild passes TEST_RUNNER_* through to the runner).
# Usage: test-whiteboard-ui.sh <simulator udid or name>   — an iPad simulator's: an iPhone only looks at boards (story 746)   — run it in the build lane:
#   scripts/native/build-lane.sh run ~/gits/mac-driver/bin/time-limit 40 caffeinate -i \
#     scripts/native/test-whiteboard-ui.sh "iPad Pro 11-inch (M5)"   (a name is the lane's own device: story 785)
set -uo pipefail
udid=$("$(dirname "$0")/sim-udid.sh" "${1:?simulator udid or name}") || exit 1
port=${CHAT_PORT:-$((8799 + ${BUILD_LANE_PORT_OFFSET:-0}))}
report=$(mktemp -t fake-cockpit)
cd "$(dirname "$0")/../.."
cockpit=
# Story 980: the simulator is left booted for the next run. Story 987: the shut-down ones' wallpaper snapshots go.
trap 'kill $cockpit 2>/dev/null || true; scripts/native/sim-poster-prune.sh || true' EXIT
# Keys reach the app only in the first test after a boot that presses any, so the suite boots a fresh simulator once and
# has one test that presses keys (WhiteboardPasteUITests' ⌘V and ⌘Z, on both canvases).
xcrun simctl shutdown "$udid" 2>/dev/null
scripts/native/sim-boot.sh "$udid" || exit 1
scripts/native/fake-cockpit.py "$port" "$report" >/dev/null 2>&1 &
cockpit=$!
sleep 1
kill -0 "$cockpit" 2>/dev/null || { echo "the fake Cockpit did not start on port $port" >&2; exit 1; }
# SUITE_PREBUILT=1 (the ladder's --full, after its own build-for-testing): run what was built rather than build again.
action=test done="TEST SUCCEEDED"
[ "${SUITE_PREBUILT:-}" = 1 ] && action=test-without-building done="TEST EXECUTE SUCCEEDED"
TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" scripts/native/xcodebuild-log.sh whiteboard-ui "$done" \
  xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
  -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
  -only-testing:GrabberNativeUITests/WhiteboardTurnUITests -only-testing:GrabberNativeUITests/WhiteboardPasteUITests -only-testing:GrabberNativeUITests/WhiteboardPlaybackUITests -only-testing:GrabberNativeUITests/WhiteboardRowDeleteUITests -only-testing:GrabberNativeUITests/WhiteboardOnPaperUITests -only-testing:GrabberNativeUITests/WhiteboardPaperGhostsUITests -only-testing:GrabberNativeUITests/WhiteboardPaperLinesUITests -only-testing:GrabberNativeUITests/WhiteboardPaperPasteUITests -only-testing:GrabberNativeUITests/WhiteboardQuestionUITests -only-testing:GrabberNativeUITests/WhiteboardOutlineUITests -only-testing:GrabberNativeUITests/WhiteboardToTextUITests -only-testing:GrabberNativeUITests/WhiteboardConnectUITests -only-testing:GrabberNativeUITests/WhiteboardHelpFeedbackUITests -only-testing:GrabberNativeUITests/WhiteboardRewordUITests -only-testing:GrabberNativeUITests/WhiteboardScratchOutUITests -only-testing:GrabberNativeUITests/WhiteboardLetteringUITests -only-testing:GrabberNativeUITests/WhiteboardEraserUITests -only-testing:GrabberNativeUITests/WhiteboardLinkChipUITests -only-testing:GrabberNativeUITests/WhiteboardGroupTapUITests -only-testing:GrabberNativeUITests/WhiteboardTheirsTapUITests "$action"
status=$?
grep -q 'Igor just said: draw a circle' "$report" || { echo "the spoken words never reached the fake Cockpit"; status=1; }
echo "fake Cockpit: $(grep -c "\"turn\": \"claude\"" "$report") ghost turns, $(grep "\"body\"" "$report" | grep -c "\"picture_id\"") board pictures to Larry"
exit $status
