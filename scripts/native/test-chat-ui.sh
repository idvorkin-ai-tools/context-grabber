#!/usr/bin/env bash
# The chat UI tests on the simulator (stories 262, 263, 301, 303; #536), with a fake Cockpit for the ones that send:
# scripts/native/fake-cockpit.py on a local port, its POST /chat held a few seconds so a new chat's waiting state shows.
# The tests read the address as GRABBER_FAKE_COCKPIT (xcodebuild passes TEST_RUNNER_* through to the runner).
# Usage: test-chat-ui.sh <simulator udid>   — run it in the build lane:
#   lockf -k -t 3600 ~/tmp/agent/locks/build.lock ~/gits/mac-driver/bin/time-limit 30 caffeinate -i \
#     scripts/native/test-chat-ui.sh <udid>
set -uo pipefail
udid=$1
port=${CHAT_PORT:-8798}
report=$(mktemp -t fake-cockpit)
cd "$(dirname "$0")/../.."
FAKE_COCKPIT_NEW_DELAY=${FAKE_COCKPIT_NEW_DELAY:-3} scripts/native/fake-cockpit.py "$port" "$report" >/dev/null 2>&1 &
cockpit=$!
trap 'kill $cockpit 2>/dev/null || true' EXIT
sleep 1
kill -0 "$cockpit" 2>/dev/null || { echo "the fake Cockpit did not start on port $port" >&2; exit 1; }
TEST_RUNNER_GRABBER_FAKE_COCKPIT="http://localhost:$port" scripts/native/xcodebuild-log.sh chat-ui "TEST SUCCEEDED" \
  xcodebuild -project native/GrabberNative.xcodeproj -scheme GrabberNative -derivedDataPath native/Build \
  -destination "platform=iOS Simulator,id=$udid" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  GIT_SHA="$(git rev-parse --short HEAD)" GIT_BRANCH="$(git branch --show-current)" \
  -only-testing:GrabberNativeUITests/ChatNewThreadUITests -only-testing:GrabberNativeUITests/ChatVoiceUITests test
status=$?
echo "fake Cockpit: $(grep -c '"method": "POST", "path": "/chat"' "$report") POST /chat, $(grep -c '"path": "/chat/igor2' "$report") requests to a thread"
exit $status
