#!/usr/bin/env bash
# Host test for scripts/native/story-ids.py (#993, story 789): hand-written story trees, each with the exact failures
# a reader finds in it, then the repo's own docs/stories, which must pass. Runs anywhere with python3.
set -uo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cg-story-ids.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fail=0

# tree <case>: a README with two journeys, A (001–009, 020) and B (010–019); story adds the stories, by ID.
tree() {
  mkdir -p "$tmp/$1"
  cat >"$tmp/$1/README.md" <<'F'
| Journey | What it covers | IDs |
|---|---|---|
| [A](01-a.md) | the first | 001–009, 020 |
| [B](02-b.md) | the second | 010–019 |
F
}
story() {  # story <case> <file> <id>...
  local c=$1 f=$2
  shift 2
  for id in "$@"; do printf '### User Story %s:\n\n- **Summary:** s%s\n\n---\n\n' "$id" "$id" >>"$tmp/$c/$f"; done
}
expect() {  # expect <name> <case> <exit> <exact FAIL lines, one per line, or empty>
  local name=$1 c=$2 want=$3 lines=$4 out status
  out=$(scripts/native/story-ids.py "$tmp/$c")
  status=$?
  got=$(grep '^FAIL' <<<"$out" | sed "s|$tmp/$c/||")
  if [ "$status" -eq "$want" ] && [ "$got" = "$lines" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $status, want $want)"
    diff <(printf '%s\n' "$lines") <(printf '%s\n' "$got") | sed 's/^/     /'
    fail=1
  fi
}

tree good
story good 01-a.md 001 2 9 20
story good 02-b.md 10 19
expect "unique IDs, each in its journey's ranges, pass" good 0 ""

tree dup
story dup 01-a.md 1 2
story dup 02-b.md 10 11
story dup 01-a.md 2
story dup 02-b.md 10
expect "an ID used twice in one file is named with both places" dup 1 "FAIL story 2 is used 2 times: 01-a.md:7, 01-a.md:13
FAIL story 10 is used 2 times: 02-b.md:1, 02-b.md:13"

tree across
story across 01-a.md 1
story across 02-b.md 10 1
expect "an ID used in two journeys is named with both places" across 1 "FAIL 02-b.md:7: story 1 is outside its journey's IDs (10–19)
FAIL story 1 is used 2 times: 01-a.md:1, 02-b.md:7"

tree outside
story outside 01-a.md 1 10 21
story outside 02-b.md 11 9
expect "an ID outside its journey's ranges fails, even one inside another journey's" outside 1 "FAIL 01-a.md:7: story 10 is outside its journey's IDs (1–9, 20)
FAIL 01-a.md:13: story 21 is outside its journey's IDs (1–9, 20)
FAIL 02-b.md:7: story 9 is outside its journey's IDs (10–19)"

mkdir -p "$tmp/overlap"
cat >"$tmp/overlap/README.md" <<'F'
| [A](01-a.md) | the first | 001–012 |
| [B](02-b.md) | the second | 010–019 |
F
story overlap 01-a.md 1
story overlap 02-b.md 15
expect "two journeys' ranges sharing IDs fail" overlap 1 "FAIL ranges overlap: 01-a.md and 02-b.md both hold 10–12"

tree unlisted
story unlisted 01-a.md 1
story unlisted 02-b.md 10
story unlisted 03-c.md 30
expect "a story file the table doesn't list fails" unlisted 1 "FAIL 03-c.md: not in README.md's journey table"

tree missing
story missing 01-a.md 1
expect "a listed journey file that is missing fails" missing 1 "FAIL README.md:4: 02-b.md is listed but not there"

tree heading
story heading 01-a.md 1
printf '### User Story 3\n\n## User Story: 4\n' >>"$tmp/heading/01-a.md"
story heading 02-b.md 10
expect "a User Story heading in another form fails instead of going unchecked" heading 1 "FAIL 01-a.md:7: unreadable story heading '### User Story 3'
FAIL 01-a.md:9: unreadable story heading '## User Story: 4'"

mkdir -p "$tmp/column"
cat >"$tmp/column/README.md" <<'F'
| [A](01-a.md) | the first | 001–009, soon |
F
story column 01-a.md 1
expect "an IDs column it can't read fails" column 1 "FAIL README.md:1: 01-a.md: can't read 'soon' in its IDs column"

if out=$(scripts/native/story-ids.py docs/stories); then
  echo "ok   docs/stories: ${out#ok   story-ids: }"
else
  echo "FAIL docs/stories"
  sed 's/^/     /' <<<"$out"
  fail=1
fi
exit $fail
