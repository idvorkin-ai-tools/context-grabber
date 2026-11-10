#!/usr/bin/env bash
# ui-timings.py against two real test cases from a whiteboard run (fixtures/ui-timings.log, xcodebuild's own output):
# the totals, the launch, the retries and the JSON lines it appends.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail() { echo "FAIL ui-timings: $1" >&2; exit 1; }

out=$("$here/ui-timings.py" "$here/fixtures/ui-timings.log" --run fixture --jsonl "$dir/t.jsonl")
grep -q "^ui timings: 2 cases, 63 s in tests" <<<"$out" || fail "the headline: $out"
grep -q "52.0 s  launch  5.5  retries 2  WhiteboardPaperLinesUITests.testEveryColourShowsItsLinesAndKeepsTheInk" \
  <<<"$out" || fail "the slowest case, its launch and its retries: $out"
grep -q "Wait for com.idvorkin.grabbernative to idle" <<<"$out" || fail "the gap kinds: $out"

[ "$(wc -l <"$dir/t.jsonl")" -eq 2 ] || fail "one JSON line per case"
python3 - "$dir/t.jsonl" <<'PY' || fail "the JSON lines"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
slow = max(rows, key=lambda r: r["secs"])
assert slow["run"] == "fixture" and slow["retries"] == 2 and slow["state"] == "passed", slow
assert slow["launch_s"] == 5.46 and slow["attachments"] > 0 and slow["slow_gaps_s"] > 20, slow
PY

: >"$dir/empty.log"
"$here/ui-timings.py" "$dir/empty.log" --jsonl "$dir/none.jsonl" | grep -q "no test cases" || fail "an empty log"
[ ! -e "$dir/none.jsonl" ] || fail "an empty log writes no JSON"
echo "ok   ui-timings: totals, launch, retries, gap kinds, JSON lines"
