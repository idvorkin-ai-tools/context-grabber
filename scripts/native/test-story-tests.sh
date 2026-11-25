#!/usr/bin/env bash
# Host test for scripts/native/story-tests.py (story 1624): a throwaway source tree and story file
# with live and stale test citations, a test file named for its class, another repo's test and a target
# folder; then the repo's own docs/stories against native/, which must pass.
set -uo pipefail
cd "$(dirname "$0")/../.."
here=$PWD
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-tests.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0

mkdir -p "$tmp/src/UITests" "$tmp/src/Tests/BoardWasmTests" "$tmp/stories"
cat >"$tmp/src/UITests/LiveUITests.swift" <<'EOF'
final class LiveUITests: XCTestCase {
  func testItWorks() {}
}
EOF
cat >"$tmp/src/UITests/CallSessionTests.swift" <<'EOF'
final class CallSessionHandoffTests: XCTestCase {
  func testASecondHandoffRedials() {}
}
EOF

check() {  # check <status line>: the one story, then the check's output and status
  printf -- '- **Status:** %s\n' "$1" >"$tmp/stories/01-a.md"
  out=$("$here/scripts/native/story-tests.py" "$tmp/stories" "$tmp/src")
  status=$?
}
expect() {  # expect <name> <exit> <output substring>
  if [ "$status" != "$2" ] || [[ "$out" != *"$3"* ]]; then
    echo "FAIL $1: exit $status (want $2), output:"
    echo "$out"
    fail=1
  else
    echo "ok   $1"
  fi
}

check 'verified by `LiveUITests` and `LiveUITests.testItWorks`'
expect "a live class and method pass" 0 "all 2 cited tests exist"
check 'verified by `testItWorks()` alone'
expect "a bare method found anywhere passes" 0 "all 1 cited tests exist"
check 'verified by `GoneUITests`'
expect "a missing class is named" 1 "no test class GoneUITests"
check 'verified by `LiveUITests.testGone`'
expect "a missing method of a live class is named" 1 "LiveUITests has no testGone"
check 'verified by `testNowhere`'
expect "a missing bare method is named" 1 "no test method testNowhere"
check 'verified by `CallSessionTests` and `CallSessionTests.testASecondHandoffRedials`'
expect "a test file's name counts as its class" 0 "all 2 cited tests exist"
check 'verified by `bug-kit:WhatsNewTests` and `think-a-card-trainer:LookalikeTests.testX`'
expect "another repo's tests are not looked for" 0 "all 0 cited tests exist"
check 'verified by `BoardWasmTests`'
expect "a test target folder counts" 0 "all 1 cited tests exist"
check 'verified by `just native-test` and `App.test.tsx`'
expect "commands and old TS files are not citations" 0 "all 0 cited tests exist"
printf -- '- **Status:** `GoneUITests`\nNot a status line: `AlsoGoneUITests`\n' >"$tmp/stories/01-a.md"
out=$("$here/scripts/native/story-tests.py" "$tmp/stories" "$tmp/src"); status=$?
expect "only Status lines are read" 1 "1 of 1 cited tests are gone"

out=$("$here/scripts/native/story-tests.py"); status=$?
expect "every Status in docs/stories cites a test that exists in native/" 0 "cited tests exist"

exit $fail
