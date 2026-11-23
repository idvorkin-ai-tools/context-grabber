#!/usr/bin/env bash
# Bead context-grabber-wq2j: every Board*, Whiteboard* and Paper* test file is placed on purpose, in BoardCoreTests
# (`boardTests` in native/ContextCore/Package.swift) or in ContextCoreTests (`boardTestsInContextCore`), never in both
# and never in neither. A new board test file lands in ContextCoreTests by default, where the board's internals are out of
# reach; this names it instead of leaving the agent to read an "inaccessible" error.
set -uo pipefail
cd "$(dirname "$0")/../../native/ContextCore" || exit 2
listed() { awk -v name="$1" '$0 ~ "^let " name " = \\[" {on=1; next} on && /^\]/ {on=0} on' Package.swift | grep -oE '"[^"]+\.swift"' | tr -d '"'; }
board=$(listed boardTests | sort)
stay=$(listed boardTestsInContextCore | sort)
fail=0
for f in $(cd Tests/ContextCoreTests && ls Board*.swift Whiteboard*.swift Paper*.swift 2>/dev/null); do
  in_board=$(grep -cxF "$f" <<<"$board")
  in_stay=$(grep -cxF "$f" <<<"$stay")
  if [ "$in_board" = 0 ] && [ "$in_stay" = 0 ]; then
    echo "FAIL $f is in neither boardTests nor boardTestsInContextCore in native/ContextCore/Package.swift (boardTests unless it needs ContextCore)"
    fail=1
  elif [ "$in_board" != 0 ] && [ "$in_stay" != 0 ]; then
    echo "FAIL $f is in both boardTests and boardTestsInContextCore"
    fail=1
  fi
done
for f in $board $stay; do
  [ -f "Tests/ContextCoreTests/$f" ] || { echo "FAIL Package.swift lists $f, which is not in Tests/ContextCoreTests"; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   every board test file is in BoardCoreTests or listed as staying in ContextCoreTests"
exit $fail
