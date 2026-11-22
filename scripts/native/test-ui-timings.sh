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

# A first step that names an "Open …" element is the test's own, not launching; and a gap kind that is the sixth
# largest in every case still counts toward the run's total.
synth() {
  echo "Test Case '-[GrabberNativeUITests.SynthUITests $1]' started."
  printf '    t =     0.00s Start Test at 2026-11-10 05:15:34.847\n    t =     0.03s Set Up\n'
  printf '    t =     2.00s Tap "Open another page" Link\n'
  t=2; for k in A B C D E; do t=$((t + 3)); printf '    t =    %d.00s Step %s\n' "$t" "$k"; done
  printf '    t =    %d.50s Step F\n' "$((t + 1))"
  echo "Test Case '-[GrabberNativeUITests.SynthUITests $1]' passed ($((t + 2)).000 seconds)."
}
{ for n in 1 2 3 4 5 6 7 8 9 10; do synth "testCase$n"; done; } >"$dir/synth.log"
out=$("$here/ui-timings.py" "$dir/synth.log")
grep -q "launching the app 20 s" <<<"$out" || fail "an Open … element is not launch: $out"
grep -q "15.0 s  Step F" <<<"$out" || fail "the sixth gap kind counts toward the run: $out"

# A case that failed, then passed on the retry, is named.
{ echo "Test Case '-[GrabberNativeUITests.SynthUITests testFlaky]' started."
  echo "Test Case '-[GrabberNativeUITests.SynthUITests testFlaky]' failed (3.000 seconds)."
  echo "Test Case '-[GrabberNativeUITests.SynthUITests testFlaky]' started."
  echo "Test Case '-[GrabberNativeUITests.SynthUITests testFlaky]' passed (2.000 seconds)."; } >"$dir/retry.log"
out=$("$here/ui-timings.py" "$dir/retry.log" --jsonl "$dir/retry.jsonl")
grep -q "passed only on retry (1), a flake, counted as a failure: SynthUITests.testFlaky" <<<"$out" ||
  fail "a retried case is named, as a failure: $out"
grep -q "^ui timings: 1 cases" <<<"$out" || fail "a retried case counts once: $out"
grep -qE "^ +5.0 s +1 +launch" <<<"$out" || fail "and once in its class: $out"
python3 - "$dir/retry.jsonl" <<'PY' || fail "the retry's JSON line is tagged"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["retry"] for r in rows] == [False, True], rows
assert [r["flaky"] for r in rows] == [False, True] and rows[1]["quarantined"] is False, rows
PY
# Story 1017: the flakes that count, for the wrapper; a quarantined one is named apart and doesn't count.
: >"$dir/q"
"$here/ui-timings.py" "$dir/retry.log" --quarantine "$dir/q" --flaky-out "$dir/flaky" >/dev/null
[ "$(cat "$dir/flaky")" = SynthUITests.testFlaky ] || fail "the counted flake is written out: $(cat "$dir/flaky")"
echo "SynthUITests.testFlaky context-grabber-abc chased" >"$dir/q"
out=$("$here/ui-timings.py" "$dir/retry.log" --quarantine "$dir/q" --flaky-out "$dir/flaky")
[ ! -s "$dir/flaky" ] || fail "a quarantined flake doesn't count: $(cat "$dir/flaky")"
grep -q "quarantined, not counted: SynthUITests.testFlaky (context-grabber-abc)" <<<"$out" || fail "it is named apart: $out"
# A run asked to repeat a passing case (-test-iterations N, #906's 40) repeats it; that is not a retry nor a flake.
{ for _ in 1 2 3; do
    echo "Test Case '-[GrabberNativeUITests.SynthUITests testAgain]' started."
    echo "Test Case '-[GrabberNativeUITests.SynthUITests testAgain]' passed (2.000 seconds)."
  done; } >"$dir/repeat.log"
out=$("$here/ui-timings.py" "$dir/repeat.log" --jsonl "$dir/repeat.jsonl" --flaky-out "$dir/flaky")
grep -q "repeated runs of a passing case (asked for, not retries): 2" <<<"$out" || fail "repeats are named as repeats: $out"
! grep -q "passed only on retry" <<<"$out" || fail "a repeat is no flake: $out"
[ ! -s "$dir/flaky" ] || fail "and writes no flake"
python3 - "$dir/repeat.jsonl" <<'PY' || fail "a repeat's JSON line is no retry"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["retry"] for r in rows] == [False] * 3 and [r["repeat"] for r in rows] == [False, True, True], rows
PY

: >"$dir/empty.log"
"$here/ui-timings.py" "$dir/empty.log" --jsonl "$dir/none.jsonl" | grep -q "no test cases" || fail "an empty log"
[ ! -e "$dir/none.jsonl" ] || fail "an empty log writes no JSON"
echo "ok   ui-timings: totals, launch, retries, flakes and the quarantine, repeats, gap kinds, JSON lines"
