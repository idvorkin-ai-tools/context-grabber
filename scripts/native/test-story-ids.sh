#!/usr/bin/env bash
# Host test for scripts/native/story-ids.py (#993, story 789): hand-written story trees, each with the exact failures
# a reader finds in it; its reserve command against a fake gh and a fake main (stories 791, 792, 794); the pre-merge
# check on a throwaway repository (story 793); then the repo's own docs/stories, which must pass. Runs anywhere with
# python3 and git.
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

# A journey of several files (story 796): A spans 01-a.md and 01-a-more.md, sharing its IDs column.
split() {
  mkdir -p "$tmp/$1"
  cat >"$tmp/$1/README.md" <<'F'
| Journey | What it covers | IDs |
|---|---|---|
| A: [one](01-a.md), [more](01-a-more.md) | the first | 001–009, 020 |
| [B](02-b.md) | the second | 010–019 |
F
}

split parts
story parts 01-a.md 1 2
story parts 01-a-more.md 3 20
story parts 02-b.md 10
expect "a journey's IDs hold across all its files" parts 0 ""

split partdup
story partdup 01-a.md 1 2
story partdup 01-a-more.md 2
story partdup 02-b.md 10
expect "an ID used in two files of one journey is named with both places" partdup 1 "FAIL story 2 is used 2 times: 01-a-more.md:1, 01-a.md:7"

split partout
story partout 01-a.md 1
story partout 01-a-more.md 3 15
story partout 02-b.md 10
expect "an ID outside its journey's ranges in its second file fails" partout 1 "FAIL 01-a-more.md:7: story 15 is outside its journey's IDs (1–9, 20)"

split partunlisted
story partunlisted 01-a.md 1
story partunlisted 01-a-more.md 3
story partunlisted 01-a-extra.md 4
story partunlisted 02-b.md 10
expect "a part file the row doesn't link fails" partunlisted 1 "FAIL 01-a-extra.md: not in README.md's journey table"

split partmissing
story partmissing 01-a.md 1
story partmissing 02-b.md 10
expect "a linked part that is missing fails" partmissing 1 "FAIL README.md:3: 01-a-more.md is listed but not there"

mkdir -p "$tmp/tworows"
cat >"$tmp/tworows/README.md" <<'F'
| A: [one](01-a.md), [shared](01-x.md) | the first | 001–009 |
| B: [one](02-b.md), [shared](01-x.md) | the second | 010–019 |
F
story tworows 01-a.md 1
story tworows 02-b.md 10
story tworows 01-x.md 2
expect "a file linked by two journeys fails" tworows 1 "FAIL README.md:2: 01-x.md is listed twice"

# --- reserve (stories 791, 792, 794; bead context-grabber-jg3w): a fake gh, a dir standing in for main, a ledger in $tmp.
mkdir -p "$tmp/prs"
cat >"$tmp/gh" <<'F'
#!/usr/bin/env bash
# The fake gh: open PRs are the files $FAKE_PRS/<n>.diff; FAKE_GH_FAIL makes the listing fail like gh offline.
case "$1 $2" in
  "pr list") [ -z "${FAKE_GH_FAIL:-}" ] || { echo "error connecting to api.github.com" >&2; exit 1; }
    ls "$FAKE_PRS" | sed -n 's/\.diff$//p' | python3 -c 'import json,sys; print(json.dumps([{"number": int(l)} for l in sys.stdin]))' ;;
  "pr diff") if [ "$(cat "$FAKE_PRS/$3.diff")" = TOOLARGE ]; then
      echo "could not find pull request diff: HTTP 406: Sorry, the diff exceeded the maximum number of files (300)" >&2; exit 1
    fi
    cat "$FAKE_PRS/$3.diff" ;;
  # A PR whose diff is too large (bead context-grabber-1338): its file list is $FAKE_PRS/<n>.files (one {f, p} per
  # line, as the --jq gives), its head is "head<n>", and a file on that head is $FAKE_PRS/<n>.head.<basename>.
  # Its changed-file count is the list's length, or $FAKE_PRS/<n>.changed when GitHub's list would come up short.
  "api --paginate") n=$(sed -n 's|.*/pulls/\([0-9]*\)/files.*|\1|p' <<<"$3"); [ -e "$FAKE_PRS/$n.files" ] || exit 1
    cat "$FAKE_PRS/$n.files" ;;
  "pr view") if [ -e "$FAKE_PRS/$3.changed" ]; then c=$(cat "$FAKE_PRS/$3.changed"); else c=$(grep -c . "$FAKE_PRS/$3.files"); fi
    printf '{"headRefOid": "head%s", "changedFiles": %s}\n' "$3" "$c" ;;
  "api -H") n=$(sed -n 's|.*?ref=head||p' <<<"$4"); f=$(sed -n 's|.*/contents/\([^?]*\)?.*|\1|p' <<<"$4")
    cat "$FAKE_PRS/$n.head.$(basename "$f")" ;;
  *) exit 2 ;;
esac
F
chmod +x "$tmp/gh"
now=1800000000
reserve() {  # reserve <ledger> <args>...: stdout only, the IDs
  local ledger=$1
  shift
  FAKE_PRS=$tmp/prs STORY_IDS_GH=$tmp/gh STORY_IDS_MAIN=$tmp/main STORY_IDS_LEDGER=$ledger STORY_IDS_NOW=$now \
    STORY_IDS_BRANCH=b scripts/native/story-ids.py reserve "$@" --dir "$tmp/res" 2>"$tmp/reserve.err"
}
check() {  # check <name> <got> <want>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $(tr '\n' ' ' <<<"$2"), want $(tr '\n' ' ' <<<"$3")"; sed 's/^/     /' "$tmp/reserve.err"; fail=1; fi
}
tree res
story res 01-a.md 1 2
story res 02-b.md 10
mkdir -p "$tmp/main"
cp "$tmp/res/README.md" "$tmp/main/"
story main 01-a.md 3 7
printf 'diff --git a/docs/stories/01-a.md b/docs/stories/01-a.md\n+### User Story 4:\n ### User Story 11:\n-### User Story 12:\n' >"$tmp/prs/41.diff"
cat >"$tmp/ledger.json" <<F
{"reservations": [{"id": 5, "journey": "01-a.md", "branch": "x", "at": $((now - 100))},
 {"id": 6, "journey": "01-a.md", "branch": "x", "at": $((now - 2 * 86400))},
 {"id": 7, "journey": "01-a.md", "branch": "x", "at": $((now - 100))}]}
F
check "reserve skips the branch's stories, main's, an open PR's and a live reservation; takes an expired one's" \
  "$(reserve "$tmp/ledger.json" 01-a.md 3)" "6
8
9"
check "the ledger drops a reservation past 24 h and one whose ID is on main, and keeps the new ones" \
  "$(python3 -c 'import json,sys; print(" ".join(str(r["id"]) for r in json.load(open(sys.argv[1]))["reservations"]))' "$tmp/ledger.json")" "5 6 8 9"
check "a journey named by a word from its row" "$(reserve "$tmp/ledger2.json" second)" "11"
check "an open PR's unchanged and removed story lines take no ID" "$(reserve "$tmp/ledger2.json" second 2)" "12
13"
out=$(reserve "$tmp/ledger.json" 01-a.md 2)
check "a journey with too few free IDs hands out none and says to add a block" "$out|$?|$(grep -c 'next unused block, 100–199' "$tmp/reserve.err")" "|1|1"
check "a full journey's message names the journey as its row does (bead context-grabber-0e04)" \
  "$(grep -c "the journey 'A' (01-a.md) has 1 free ID(s) of the 2 asked for in its IDs (1–9, 20)" "$tmp/reserve.err")" "1"
check "a full journey's message gives every journey's free IDs" "$(grep -c 'Free IDs per journey: A 1, B 9$' "$tmp/reserve.err")" "1"
printf 'diff --git a/docs/stories/02-b.md b/docs/stories/02-b.md\n+### User Story 250:\n' >"$tmp/prs/42.diff"
out=$(reserve "$tmp/ledger.json" 01-a.md 2)
check "a full journey's next block starts above an ID an open PR adds past every row" "$(grep -c 'next unused block, 300–399' "$tmp/reserve.err")" "1"
sed -i.bak 's/| 010–019 |/| 010–019, 500–599 |/' "$tmp/main/README.md"
out=$(reserve "$tmp/ledger.json" 01-a.md 2)
check "a full journey's next block starts above a block main's table holds that the branch's doesn't" "$(grep -c 'next unused block, 600–699' "$tmp/reserve.err")" "1"
mv -f "$tmp/main/README.md.bak" "$tmp/main/README.md"
rm -f "$tmp/prs/42.diff"
out=$(reserve "$tmp/ledger3.json" the)
check "a word that names two journeys fails" "$out|$?|$(grep -c 'names 2 journeys' "$tmp/reserve.err")" "|1|1"
out=$(FAKE_GH_FAIL=1 reserve "$tmp/ledger3.json" second)
check "with the open PRs unreadable it hands out nothing" "$out|$?|$([ -e "$tmp/ledger3.json" ] && echo written || echo untouched)" "|1|untouched"
# A PR whose diff gh refuses as too large is read from its file list (bead context-grabber-1338): a story file's
# patch gives the IDs it adds; a story file with no patch (too large itself) gives every heading on the PR's head.
echo TOOLARGE >"$tmp/prs/43.diff"
cat >"$tmp/prs/43.files" <<'J'
{"f":"native/App/Big.swift","p":"+### User Story 17:"}
{"f":"docs/stories/01-a.md","p":"@@ -1 +1 @@\n+### User Story 11:\n ### User Story 16:"}
{"f":"docs/stories/02-b.md","p":null}
J
printf '### User Story 10:\n### User Story 12:\n' >"$tmp/prs/43.head.02-b.md"
check "a too-large PR's story patches and its patchless story file's headings take their IDs; other files don't" \
  "$(reserve "$tmp/ledger4.json" second 2)" "13
14"
check "a too-large PR read from its file list warns about nothing" "$(grep -c WARN "$tmp/reserve.err")" "0"
echo TOOLARGE >"$tmp/prs/44.diff"
out=$(reserve "$tmp/ledger5.json" second)
check "a PR that can be read neither way is named in a warning and doesn't block the reservation" \
  "$out|$?|$(grep -c 'WARN reserve: open PR #44 could not be read' "$tmp/reserve.err")" "13|0|1"
echo 3001 >"$tmp/prs/43.changed"
out=$(reserve "$tmp/ledger6.json" second)
check "a too-large PR whose file list is cut short of its changed files is named in a warning" \
  "$out|$?|$(grep -c 'WARN reserve: open PR #43 could not be read.*gives 3 of its 3001 changed files' "$tmp/reserve.err")" "11|0|1"
rm -f "$tmp/prs"/43.* "$tmp/prs"/44.*
for k in 1 2 3 4 5 6; do STORY_IDS_HOLD=0.3 reserve "$tmp/race.json" 02-b.md >"$tmp/race.$k" & done
wait
check "six reservations at once, each holding the ledger a while, get six different IDs" "$(cat "$tmp"/race.? | sort -n | tr '\n' ' ')" "11 12 13 14 15 16 "

# --- pre-merge (story 793): two branches that each pass alone but add the same ID fail once merged with main.
g() { git -c user.name=t -c user.email=t@t -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }
repo=$tmp/repo
entry() { printf '### User Story %s:\n\n- **Summary:** s%s\n\n---\n\n' "$1" "$1"; }
g init -q --bare "$tmp/origin.git"
g clone -q "$tmp/origin.git" "$repo" 2>/dev/null
split pm
story pm 01-a.md 1
story pm 01-a-more.md 3
story pm 02-b.md 10
mkdir -p "$repo/docs" && cp -R "$tmp/pm" "$repo/docs/stories"
(cd "$repo" && g checkout -q -b main && g add -A && g commit -qm base && g push -q origin main
 g checkout -q -b dup && entry 2 >>docs/stories/01-a-more.md && g commit -qam "story 2" && g push -q origin dup
 g checkout -q main && g checkout -q -b fine && entry 4 >>docs/stories/01-a-more.md && g commit -qam "story 4" && g push -q origin fine
 g checkout -q main && entry 2 >>docs/stories/01-a.md && g commit -qam "main: story 2" && g push -q origin main
 g checkout -q -b clash origin/main~1 && sed -i.bak 's/s1$/one/' docs/stories/01-a.md && rm -f docs/stories/01-a.md.bak && g commit -qam clash
 g checkout -q fine && g checkout -q -b behind && entry 2 >>docs/stories/01-a-more.md && g commit -qam "pipeline: story 2" && g push -q origin behind && g reset -q --hard HEAD~1
 g checkout -q main && sed -i.bak 's/s1$/uno/' docs/stories/01-a.md && rm -f docs/stories/01-a.md.bak && g commit -qam uno && g push -q origin main) >/dev/null 2>&1
premerge() { (cd "$repo" && g checkout -q "$1" && "$OLDPWD/scripts/native/pre-merge.sh"); }
out=$(premerge dup 2>&1)
check "pre-merge fails a branch that collides with main once merged, naming both places" \
  "$?|$(grep '^FAIL story' <<<"$out")" "1|FAIL story 2 is used 2 times: 01-a-more.md:7, 01-a.md:7"
out=$(premerge fine 2>&1)
check "pre-merge passes a branch whose IDs are still free on main" "$?|$(grep -c '^ok   pre-merge' <<<"$out")" "0|1"
out=$(premerge behind 2>&1)
check "pre-merge judges the branch as pushed when the checkout is behind it" \
  "$?|$(grep -c '^note pre-merge: checking origin/behind' <<<"$out")|$(grep -c '^FAIL story 2 is used 2 times' <<<"$out")" "1|1|1"
out=$(premerge clash 2>&1)
check "pre-merge fails a branch that conflicts with main" "$?|$(grep -c 'conflicts with origin/main' <<<"$out")" "1|1"

if out=$(scripts/native/story-ids.py docs/stories); then
  echo "ok   docs/stories: ${out#ok   story-ids: }"
else
  echo "FAIL docs/stories"
  sed 's/^/     /' <<<"$out"
  fail=1
fi
exit $fail
