#!/usr/bin/env python3
"""Where a UI test run's time went, from its xcodebuild log (Igor, 2026-11-10: "detailed logging so we can speed
them up").

Usage: ui-timings.py <xcodebuild log> [--run <name>] [--jsonl <file>] [--top N] [--quarantine <file>] [--flaky-out <file>]

For every test case: its total, the launch (from the start until the app is up and idle, the first step that is not
setting the app up), the steps XCUITest retried, the attachments taken, and the slow gaps (a second or more between
two activity lines, named by the line that ended them). Prints the slowest cases, the per-class totals and the
largest gap kinds; with --jsonl appends one line per case so runs can be compared over time.

A case that failed and then passed on xcodebuild's retry passed only on retry: a flake, which the run counts as a
failure (story 1017), unless the quarantine file names it with the bead that tracks it. --flaky-out writes the flakes
that count, one per line, for the wrapper to fail the run on. A run of a case after one that passed is a repeat (an
iteration asked for), not a retry.
"""

import argparse
import json
import os
import re
import sys
import time
from collections import defaultdict

CASE = re.compile(r"Test Case '-\[(\w+)\.(\w+) (\w+)\]' (started|passed|failed|skipped)(?: \(([\d.]+) seconds\))?")
STEP = re.compile(r"^\s+t =\s+([\d.]+)s\s+(.*)$")
# The activity lines that bring the app up, before the test's own first step.
LAUNCH = re.compile(
    r"(?:Start Test|Set Up|Launch |Setting up automation|Wait for .* to idle|Terminate |Open |Find the Target Application)"
)
GAP_S = 1.0
QUARANTINE = os.environ.get("UI_QUARANTINE") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui-quarantine.txt")
# What tracks a quarantined case: a bead or a GitHub issue. An entry without one is not a quarantine.
TRACKER = re.compile(r"^(context-grabber-[a-z0-9.]+|#\d+)$")


def load_quarantine(path, warn=None):
    """Story 1017: the known flakes, as {"Class" or "Class.test": tracker}. A line is `Class[.test] <bead or #issue>
    <why>`; '#' starts a comment line."""
    out = {}
    try:
        lines = open(path).read().splitlines()
    except OSError:
        return out
    for n, line in enumerate(lines, 1):
        parts = line.split()
        if not parts or parts[0].startswith("#"):
            continue
        if len(parts) < 2 or not TRACKER.match(parts[1]):
            if warn:
                warn(f"{path}:{n}: a quarantine names the bead or issue that tracks it, so this line is ignored: {line}")
            continue
        out[parts[0]] = parts[1]
    return out


def quarantined_by(quarantine, cls, test):
    return quarantine.get(f"{cls}.{test}") or quarantine.get(cls)


def kind(line):
    """A gap's name: the activity with its quoted element and numbers taken out, so like gaps add up."""
    line = re.sub(r"`[^`]*`|\"[^\"]*\"|'[^']*'", "…", line.strip())
    line = re.sub(r"\(attempt #\d+\)|\d+(\.\d+)?", "", line)
    return re.sub(r"\s+", " ", line).strip()[:70]


def parse(lines):
    cases, current, last, failed = [], None, {}, set()
    for line in lines:
        m = CASE.search(line)
        if m:
            _, cls, test, state, secs = m.groups()
            if state == "started":
                current = {"class": cls, "test": test, "steps": [], "secs": None, "state": None}
            elif current and current["test"] == test:
                current["state"], current["secs"] = state, float(secs or 0)
                key = (cls, test)
                # Story 1017: a retry follows a failed run of the case; a run after a pass is a repeat.
                current["retry"] = key in failed
                current["repeat"] = last.get(key) in ("passed", "skipped") and key not in failed
                current["flaky"] = state == "passed" and key in failed
                last[key] = state
                if state == "failed":
                    failed.add(key)
                cases.append(current)
                current = None
            continue
        s = STEP.match(line)
        if s and current is not None:
            current["steps"].append((float(s.group(1)), s.group(2)))
    return [summarise(c) for c in cases]


def summarise(case):
    steps = case.pop("steps")
    launch = 0.0
    for t, text in steps:
        if not LAUNCH.match(text):
            launch = t
            break
    gaps = defaultdict(float)
    for (t0, _), (t1, text) in zip(steps, steps[1:]):
        if t1 - t0 >= GAP_S:
            gaps[kind(text)] += t1 - t0
    case.update(
        launch_s=round(launch, 2),
        retries=sum("Retrying" in text for _, text in steps),
        attachments=sum("Added attachment" in text for _, text in steps),
        slow_gaps_s=round(sum(gaps.values()), 2),
        gaps={k: round(v, 2) for k, v in sorted(gaps.items(), key=lambda kv: -kv[1])},
    )
    return case


def flakes(cases, quarantine):
    """The cases that passed only on retry: (counted, quarantined), each a sorted list of (class, test[, tracker])."""
    counted, held = set(), set()
    for c in cases:
        if c.get("flaky"):
            q = quarantined_by(quarantine, c["class"], c["test"])
            c["quarantined"] = bool(q)
            if q:
                held.add((c["class"], c["test"], q))
            else:
                counted.add((c["class"], c["test"]))
    return sorted(counted), sorted(held)


def report(cases, top, quarantine=None):
    if not cases:
        return "ui timings: no test cases in the log"
    total = sum(c["secs"] for c in cases)
    launch = sum(c["launch_s"] for c in cases)
    distinct = {(c["class"], c["test"]) for c in cases}
    out = [
        f"ui timings: {len(distinct)} cases, {total:.0f} s in tests; launching the app {launch:.0f} s"
        f" ({100 * launch / total if total else 0:.0f}%), {sum(c['retries'] for c in cases)} retried steps,"
        f" {sum(c['attachments'] for c in cases)} attachments"
    ]
    # A case that failed and then passed on xcodebuild's retry: named, so a flake is never hidden by the retry, and
    # counted as a failure unless it is quarantined (story 1017).
    flaky, held = flakes(cases, quarantine or {})
    if flaky:
        out.append(f"  passed only on retry ({len(flaky)}), a flake, counted as a failure: "
                   + ", ".join(f"{k}.{t}" for k, t in flaky))
    if held:
        out.append(f"  passed only on retry ({len(held)}), quarantined, not counted: "
                   + ", ".join(f"{k}.{t} ({q})" for k, t, q in held))
    repeats = sum(1 for c in cases if c.get("repeat"))
    if repeats:
        out.append(f"  repeated runs of a passing case (asked for, not retries): {repeats}")
    per_class = defaultdict(lambda: [0, 0.0, 0.0])
    for c in cases:
        p = per_class[c["class"]]
        p[0] += not c["retry"]
        p[1] += c["secs"]
        p[2] += c["launch_s"]
    out.append("  by class (cases, seconds, of which launch):")
    for cls, (n, secs, lch) in sorted(per_class.items(), key=lambda kv: -kv[1][1]):
        out.append(f"    {secs:6.1f} s  {n:2d}  launch {lch:5.1f} s  {cls}")
    out.append(f"  slowest {min(top, len(cases))}:")
    for c in sorted(cases, key=lambda c: -c["secs"])[:top]:
        out.append(
            f"    {c['secs']:6.1f} s  launch {c['launch_s']:4.1f}  retries {c['retries']}  {c['class']}.{c['test']}"
            + ("" if c["state"] == "passed" else f"  [{c['state']}]")
        )
    gaps = defaultdict(float)
    for c in cases:
        for k, v in c["gaps"].items():
            gaps[k] += v
    out.append("  where the gaps of a second or more went:")
    for k, v in sorted(gaps.items(), key=lambda kv: -kv[1])[:8]:
        out.append(f"    {v:6.1f} s  {k}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("log")
    ap.add_argument("--run", default="", help="the run's name, kept on each JSON line")
    ap.add_argument("--jsonl", help="append one JSON line per case to this file")
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--quarantine", default=QUARANTINE, help="the known flakes, each with its bead (story 1017)")
    ap.add_argument("--flaky-out", help="write the flakes that count as failures here, one Class.test per line")
    args = ap.parse_args(argv)
    with open(args.log, errors="replace") as f:
        cases = parse(f)
    quarantine = load_quarantine(args.quarantine, warn=lambda m: print(m, file=sys.stderr))
    print(report(cases, args.top, quarantine))
    if args.flaky_out:
        counted, _ = flakes(cases, quarantine)
        with open(args.flaky_out, "w") as f:
            f.writelines(f"{k}.{t}\n" for k, t in counted)
    if args.jsonl and cases:
        stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        # #1038: the ladder's climb this run was part of, so the report can join its cases to the climb.
        run_id = {"run_id": os.environ["LADDER_RUN_ID"]} if os.environ.get("LADDER_RUN_ID") else {}
        try:
            with open(args.jsonl, "a") as f:
                for c in cases:
                    f.write(json.dumps({"t": stamp, "run": args.run, **run_id, **c}) + "\n")
        except OSError as error:
            print(f"ui-timings could not write timing records: {error}", file=sys.stderr)
            return os.EX_IOERR
    return 0


if __name__ == "__main__":
    sys.exit(main())
