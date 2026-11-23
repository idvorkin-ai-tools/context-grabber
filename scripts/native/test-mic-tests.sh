#!/usr/bin/env bash
# Bead context-grabber-wm8y: scripts/native/mic-tests.txt lists every UI test that touches a mic control or a call,
# as one that opens the mic (skipped on a locked Mac) or one reviewed as not, and mic-tests.py check holds the UI tests
# to it. Checked here against fixtures (a test that taps the mic, itself or through a helper, and isn't listed fails; a
# listed test that is gone fails), then against the real UI tests.
set -uo pipefail
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
mkdir -p "$dir/ui"
cat >"$dir/ui/SynthUITests.swift" <<'SWIFT'
final class SynthUITests: XCTestCase {
  func testTapsTheVoiceButton() throws {
    app.buttons["inbox-add-voice"].tap()
  }

  func testDialsThroughAHelper() throws {
    dial(app)
  }

  func testDrawsOnly() throws {
    app.buttons["whiteboard-send"].tap()
  }

  private func dial(_ app: XCUIApplication) {
    app.buttons["call-larry"].tap()
  }
}
SWIFT
check() { scripts/native/mic-tests.py check --list "$dir/list" --tests "$dir/ui" 2>&1; }
printf '%s\n' "mic GrabberNativeUITests/SynthUITests/testTapsTheVoiceButton  # opens it" \
  "reviewed SynthUITests/testDialsThroughAHelper  # never answers" >"$dir/list"
out=$(check)
[ $? -eq 0 ] && ok "every test that touches a mic control is listed: it passes" || bad "a full list failed: $out"
printf '%s\n' "mic GrabberNativeUITests/SynthUITests/testTapsTheVoiceButton  # opens it" >"$dir/list"
out=$(check)
[ $? -ne 0 ] && ok "a test that reaches the mic through a helper and isn't listed fails the check" || bad "an unlisted helper call passed"
case $out in *"SynthUITests/testDialsThroughAHelper touches a mic control"*) ok "and names it";; *) bad "it said: $out";; esac
case $out in *testDrawsOnly*) bad "a test that touches no mic control was named: $out";; *) ok "and not one that touches none";; esac
printf '%s\n' "mic GrabberNativeUITests/SynthUITests/testTapsTheVoiceButton" "reviewed SynthUITests/testDialsThroughAHelper" \
  "mic GrabberNativeUITests/SynthUITests/testGone" >"$dir/list"
out=$(check)
[ $? -ne 0 ] && case $out in *"testGone is no UI test any more"*) true;; *) false;; esac && ok "a listed test that is gone fails the check" ||
  bad "a gone test: $out"
printf '%s\n' "mic SynthUITests/testTapsTheVoiceButton" >"$dir/list"
out=$(check)
[ $? -ne 0 ] && ok "a mic line without its test target is refused" || bad "a mic line without its target passed: $out"
printf '%s\n' "mic GrabberNativeUITests/SynthUITests/testTapsTheVoiceButton  # opens it" "reviewed SynthUITests/testDialsThroughAHelper" >"$dir/list"
[ "$(scripts/native/mic-tests.py list --list "$dir/list")" = "GrabberNativeUITests/SynthUITests/testTapsTheVoiceButton" ] &&
  ok "list prints the mic lines' ids for -skip-testing" || bad "list printed: $(scripts/native/mic-tests.py list --list "$dir/list")"
out=$(scripts/native/mic-tests.py check 2>&1)
[ $? -eq 0 ] && ok "the real UI tests: ${out#ok   }" || { bad "the real UI tests:"; echo "$out"; }
exit $fail
