#!/usr/bin/env bash
# Story 1311 (context-grabber-7xv6): print the board's Pencil-to-frame latency lines (`board_pen_latency`) from the session
# logs pulled off the devices, oldest first: device and session, count, p50, p90, slowest (ms) and the refresh rate.
# Usage: scripts/native/pen-latency.sh [logs-dir]   (default ~/tmp/agent/grabber-logs; run `just pull-logs` first)
set -euo pipefail
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi
dir="${1:-$HOME/tmp/agent/grabber-logs}"
[ -d "$dir" ] || { echo "pen-latency: no logs at $dir (just pull-logs)" >&2; exit 1; }
python3 - "$dir" <<'PY'
import glob, json, os, sys
root = sys.argv[1]
rows = 0
for path in sorted(glob.glob(os.path.join(root, "*", "logs", "*.jsonl")), key=os.path.basename):
    device = os.path.basename(os.path.dirname(os.path.dirname(path)))
    with open(path, errors="replace") as f:
        for line in f:
            if "board_pen_latency" not in line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("action") != "board_pen_latency":
                continue
            rows += 1
            print("{} {}: {} moments, p50 {} ms, p90 {} ms, slowest {} ms, {} Hz".format(
                device, os.path.basename(path), e.get("count"), e.get("p50_ms"), e.get("p90_ms"),
                e.get("slowest_ms"), e.get("hz")))
if rows == 0:
    print("pen-latency: no board_pen_latency lines yet (write a few lines with the Pencil on a build with story 1311)")
PY
