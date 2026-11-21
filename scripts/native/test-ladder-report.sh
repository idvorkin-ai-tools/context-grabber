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
exit $fail
