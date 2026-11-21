#!/usr/bin/env bash
# #1038 (story 1016): ladder-report.py on a fixture of climbs that must stay apart in the report: a failure and its
# passing second attempt with a retried case, a wrong-device skip, a climb with no known delivery, one only uploaded
# to TestFlight, one that never finished, and an older climb read from its log.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
fx=$here/fixtures/ladder-report
dir=$(mktemp -d "${TMPDIR:-/tmp}/cg-ladder-report.XXXXXX")
trap 'rm -rf "$dir"' EXIT
fail=0
out=$dir/out
ok() { echo "ok   ladder report: $1"; }
bad() { echo "FAIL ladder report: $1"; sed 's/^/     /' "$out"; fail=1; }
has() { if grep -qF -- "$2" "$out"; then ok "$1"; else echo "     wanted: $2"; bad "$1"; fi; }

"$here/ladder-report.py" --ledger "$fx/runs.jsonl" --logs "$fx/*ladder*.log" --timings "$fx/ui-timings.jsonl" \
  --deploys "$fx/deploys.jsonl" --repo "$dir" --json "$dir/report.json" >"$out" 2>&1
status=$?
if [ "$status" -eq 0 ]; then ok "runs"; else bad "runs, exit $status"; fi
has "counts both sources, a logged climb the ledger holds once" "ladder report: 7 climbs (6 from the ledger, 1 from older logs)"
has "a failure: its first failing rung and step" "r-wb-1  whiteboard  #1  fail (first at rung 2 whiteboard classes)"
has "its second attempt: attempt 2, passed, the retried case named" "r-wb-2  whiteboard  #2  pass  queue 30  exec 600  retried 1"
has "a delivered change: the cable install" "cable 2026-11-21T10:00:00Z"
has "a warm build" "warm build"
has "a wrong-device skip: counted as skipped coverage" "skipped 1 [IPadUITests (wrong device)]"
has "a missing deploy: said so" "r-ipad  ipad  #1  pass"
has "a missing deploy: no delivery known" "no delivery known"
has "an upload alone is not a delivery" "uploaded 2026-11-21T11:00:00Z, not yet available"
has "a climb that never finished: censored" "r-crash  chat  #1  censored"
has "a climb a signal stopped: interrupted" "r-int  chat  #1  interrupted"
has "by area: chat's climbs that did not run apart from its failure" "chat         4  queue 10/40 (n=2)  exec 230/300 (n=2)  first-pass failures 1  not run 2  retried 0  skipped 0  delivered 0/3"
has "an older climb from its log" "old-ladder.log#1  chat  #1  fail (first at rung 2)  queue 40  exec 300"
has "by area: the whiteboard's first-pass failure, retry and delivery" \
  "whiteboard   2  queue 30/120 (n=2)  exec 600/900 (n=2)  first-pass failures 1  not run 0  retried 1  skipped 0  delivered 2/2"
has "by area: the iPad's skip and its missing delivery" "ipad         1  queue -/- (n=0)  exec 200/200 (n=1)  first-pass failures 0  not run 0  retried 0  skipped 1  delivered 0/1"
# The recorder writes what the report reads: a cable install of the iPad change makes it delivered.
LEAD_TIMES_DEPLOYS=$dir/deploys.jsonl "$here/record-deploy.sh" phone bbbb2222 cable >/dev/null
cat "$fx/deploys.jsonl" >>"$dir/deploys.jsonl"
"$here/ladder-report.py" --ledger "$fx/runs.jsonl" --logs '' --timings '' --deploys "$dir/deploys.jsonl" --repo "$dir" >"$out" 2>&1
has "a recorded install: the change is delivered" "ipad         1  queue -/- (n=0)  exec 200/200 (n=1)  first-pass failures 0  not run 0  retried 0  skipped 1  delivered 1/1"
LEAD_TIMES_DEPLOYS=$dir/deploys.jsonl "$here/record-deploy.sh" phone bbbb2222 shipped >"$out" 2>&1
if [ $? -eq 2 ]; then ok "the recorder: an unknown kind is refused"; else bad "the recorder: an unknown kind is refused"; fi
python3 - "$dir/report.json" <<'PY' && ok "the JSON: the ranking puts the costliest area first" || { : >"$out"; bad "the JSON ranking"; }
import json, sys
d = json.load(open(sys.argv[1]))
areas = [t["area"] for t in d["by_area"]]
assert areas[0] == "whiteboard", areas
wb = d["by_area"][0]
# The queue of both attempts (120 + 30 s), the failed attempt's 900 s and the 50 s retried case: 18.3 min, twice.
assert wb["avoidable_min"] == 18.3 and wb["rank_score"] == 36.6, wb
PY
# A locked screen does not use up the first attempt: the rerun's failure is the first pass's. A timeout's time is avoidable.
sel='"classes":{"chat":["ChatArchiveUITests"],"whiteboard":[],"places":[],"ipad":[],"other":[]},"smoke":"chat"'
cat >"$dir/rerun.jsonl" <<EOF
{"run_id":"r-lock","event":"start","at":"2026-11-21T08:00:00Z","sha":"ffff6666","base":"origin/main",$sel}
{"run_id":"r-lock","event":"finish","at":"2026-11-21T08:00:05Z","outcome":"unavailable","status":75}
{"run_id":"r-rerun","event":"start","at":"2026-11-21T09:00:00Z","sha":"ffff6666","base":"origin/main",$sel}
{"run_id":"r-rerun","event":"rung","at":"2026-11-21T09:05:00Z","rung":"2","name":"Simulator","secs":300,"waited_s":0,"status":65}
{"run_id":"r-rerun","event":"finish","at":"2026-11-21T09:05:00Z","outcome":"fail","status":65,"first_failure":{"rung":"2"}}
{"run_id":"r-hung","event":"start","at":"2026-11-21T10:00:00Z","sha":"9999aaaa","base":"origin/main",$sel}
{"run_id":"r-hung","event":"rung","at":"2026-11-21T10:30:00Z","rung":"2","name":"Simulator","secs":1800,"waited_s":0,"status":124}
{"run_id":"r-hung","event":"finish","at":"2026-11-21T10:30:00Z","outcome":"timeout","status":124,"first_failure":{"rung":"2"}}
EOF
"$here/ladder-report.py" --ledger "$dir/rerun.jsonl" --logs '' --timings '' --deploys '' --repo "$dir" \
  --json "$dir/rerun.json" >"$out" 2>&1
has "a climb that could not run: still the first attempt" "r-lock  chat  #1  unavailable"
has "the rerun after it: its failure is the first attempt's" "r-rerun  chat  #1  fail"
python3 - "$dir/rerun.json" <<'PY' && ok "first-pass failures count the rerun and the timeout; the timeout's 30 min is avoidable" || bad "rerun and timeout"
import json, sys
chat = json.load(open(sys.argv[1]))["by_area"][0]
# The failed rerun's 300 s and the timed-out climb's 1,800 s: 35 min; the locked screen ran nothing.
assert chat["first_pass_failures"] == 2 and chat["not_run"] == 1 and chat["avoidable_min"] == 35.0, chat
PY
exit $fail
