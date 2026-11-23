#!/usr/bin/env bash
# Host test for scripts/native/story-commits.py (beads context-grabber-t309, context-grabber-lldg): a throwaway
# repository with reachable and stale commit links, including uppercase abbreviations and a shallow clone;
# then the repo's own docs/stories, which must pass.
set -uo pipefail
cd "$(dirname "$0")/../.."
here=$PWD
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-commits.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0
U=https://github.com/idvorkin/context-grabber/commit

g() { git -C "$tmp/repo" -c user.name=t -c user.email=t@example.com "$@"; }
mkdir -p "$tmp/repo/docs/stories"
g init -q -b main
g commit -q --allow-empty -m one
kept=$(g rev-parse HEAD)
g checkout -q -b side
g commit -q --allow-empty -m before-rebase
gone=$(g rev-parse HEAD)
g checkout -q main
g branch -q -D side
g reflog expire --expire=now --all
g gc -q --prune=now

story() {  # story <body> [checkout]: the one story file, then the check's output and status
  local stories="${2:-$tmp/repo}/docs/stories"
  printf '%s\n' "$1" >"$stories/01-a.md"
  out=$("$here/scripts/native/story-commits.py" "$stories")
  status=$?
}
expect() {  # expect <name> <exit> <exact output>
  if [ "$status" != "$2" ] || [ "$out" != "$3" ]; then
    echo "FAIL $1: exit $status (want $2), output:"
    echo "$out"
    fail=1
  else
    echo "ok   $1"
  fi
}

story "- **Status:** implemented in [${kept:0:7}]($U/${kept:0:7})"
expect "a short sha in the history" 0 "story-commits: 1 commit links, every one in this branch's history"
story "- **Status:** in [x]($U/$kept) and [y]($U/${kept:0:8})"
expect "a full and an 8-character sha" 0 "story-commits: 2 commit links, every one in this branch's history"
story "first line
- **Status:** implemented in [${gone:0:7}]($U/${gone:0:7})"
expect "a sha from before a rebase" 1 "FAIL 01-a.md:2: links commit ${gone:0:7}, which is not in this branch's history (a sha from before a rebase? name the commit as it is on the branch)"

upper_kept=$(printf '%s' "${kept:0:8}" | tr 'a-f' 'A-F')
upper_gone=$(printf '%s' "$gone" | tr 'a-f' 'A-F')
story "Implemented in [kept]($U/$upper_kept) and [stale]($U/$upper_gone)"
expect "uppercase commit hashes" 1 "FAIL 01-a.md:1: links commit $upper_gone, which is not in this branch's history (a sha from before a rebase? name the commit as it is on the branch)"

g commit -q --allow-empty -m current || exit 1
tip=$(g rev-parse HEAD)
g clone -q --depth=1 "file://$tmp/repo" "$tmp/shallow" || exit 1
mkdir -p "$tmp/shallow/docs/stories" || exit 1
story "Implemented in [current]($U/$tip)" "$tmp/shallow"
expect "a shallow clone can verify a recent commit" 0 "story-commits: 1 commit links, every one in this branch's history"
story "Implemented in [older]($U/$kept) and [stale]($U/$gone)" "$tmp/shallow"
expect "a shallow clone fails if it cannot verify a link" 1 "FAIL 01-a.md:1: links commit $kept, which is not in this checkout's available history
FAIL 01-a.md:1: links commit $gone, which is not in this checkout's available history
story-commits: this clone is shallow. Fetch the full history (git fetch --unshallow) and rerun."

if out=$(scripts/native/story-commits.py docs/stories); then
  echo "ok   the repo's own stories: $out"
else
  echo "FAIL the repo's own stories:"
  echo "$out"
  fail=1
fi
exit $fail
