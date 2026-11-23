#!/usr/bin/env bash
# Story 1502 (bead context-grabber-2b54): docs/TESTING.md keeps the lists PRs add to one item a line, so parallel PRs
# touch different lines instead of one long table row. This checks each list names exactly what its script runs:
#   - "The host rung's script checks": the scripts/native/test-* checks in the justfile's native-test-host recipe
#   - "The chat suite's classes": the -only-testing classes in scripts/native/test-chat-ui.sh, in name order
#   - "The whiteboard suite's classes": those in scripts/native/test-whiteboard-ui.sh, in name order, and every
#     native/UITests/Whiteboard*UITests.swift; and the script's own list in name order (story 1503)
# Usage: test-testing-lists.sh [repo root]   (default: this script's repo)
set -uo pipefail
cd "${1:-$(dirname "$0")/../..}" || exit 2
doc=docs/TESTING.md
fail=0
# The first backticked word of each "- " line under the heading, up to the next heading.
section() { awk -v h="$1" '/^#/ {on = ($0 == h); next} on && /^- `/' "$doc" | sed -E 's/^- `([^`]+)`.*/\1/'; }
only_testing() { grep -oE 'only-testing:[A-Za-z0-9]+UITests/[A-Za-z0-9]+' "$1" | sed 's/.*\///'; }
same() { # name, what the doc lists, what the source holds, where the source is
  local missing extra
  [ -z "$3" ] && { echo "FAIL $1: found nothing in $4"; fail=1; return; }
  missing=$(comm -13 <(sort -u <<<"$2") <(sort -u <<<"$3") | grep .)
  extra=$(comm -23 <(sort -u <<<"$2") <(sort -u <<<"$3") | grep .)
  [ -n "$missing" ] && { echo "FAIL $1: $4 has, $doc does not list:"; sed 's/^/       /' <<<"$missing"; fail=1; }
  [ -n "$extra" ] && { echo "FAIL $1: $doc lists, $4 does not have:"; sed 's/^/       /' <<<"$extra"; fail=1; }
  [ -z "$missing$extra" ] && echo "ok   $1 matches $4"
}
sorted() { # name, the doc's list
  if [ -z "$2" ]; then echo "FAIL $1: no list under its heading in $doc"; fail=1
  elif [ "$2" != "$(LC_ALL=C sort <<<"$2")" ]; then echo "FAIL $1: not in name order in $doc"; fail=1
  else
    local dup; dup=$(uniq -d <<<"$2")
    [ -n "$dup" ] && { echo "FAIL $1: listed twice: $dup"; fail=1; }
  fi
}
host=$(section "## The host rung's script checks")
recipe=$(awk '/^native-test-host:/ {on=1; next} on && /^[^ \t]/ {on=0} on' justfile | grep -oE '^ +scripts/native/test-[A-Za-z0-9_.-]+' | tr -d ' ')
[ -z "$host" ] && { echo "FAIL host checks: no list under its heading in $doc"; fail=1; }
same "host checks" "$host" "$recipe" "justfile's native-test-host"
chat=$(section "### The chat suite's classes")
sorted "chat suite" "$chat"
same "chat suite" "$chat" "$(only_testing scripts/native/test-chat-ui.sh)" "scripts/native/test-chat-ui.sh"
board=$(section "### The whiteboard suite's classes")
sorted "whiteboard suite" "$board"
same "whiteboard suite" "$board" "$(only_testing scripts/native/test-whiteboard-ui.sh)" "scripts/native/test-whiteboard-ui.sh"
# Story 1503: the script's own list is one class a line in name order too, as PRs add to it.
script_board=$(only_testing scripts/native/test-whiteboard-ui.sh)
[ "$script_board" != "$(LC_ALL=C sort <<<"$script_board")" ] && { echo "FAIL whiteboard suite: not in name order in scripts/native/test-whiteboard-ui.sh"; fail=1; }
files=$(cd native/UITests && ls Whiteboard*UITests.swift 2>/dev/null | sed 's/\.swift$//')
same "whiteboard suite" "$board" "$files" "native/UITests/Whiteboard*UITests.swift"
exit $fail
