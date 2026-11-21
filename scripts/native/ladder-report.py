#!/usr/bin/env python3
"""Where a change's test time goes, from ladder selection to the phone (#1038, story 1016).

Usage: ladder-report.py [--ledger F] [--logs GLOB] [--timings GLOB] [--deploys F] [--sample N] [--json F]

Reads the ladder's run ledger (one JSON line per event of each climb, written by test-ladder.sh), the older climbs'
logs (`*ladder*.log`, whose "seconds per rung" lines are all they hold), the UI test timing lines (ui-timings.jsonl,
joined to a climb by its run id) and the deploys ledger, and prints:

  - each climb: its run id, source, area, what it selected and where, how it ended (pass, fail, unavailable,
    interrupted, censored), its queue and execution seconds, the cases retried, the coverage that skipped, and when
    the change first reached a device;
  - by change area: climbs, median and p90 queue and execution, first-pass failures, skipped coverage and the share
    with a known delivery time;
  - the areas ranked by climbs times avoidable lane minutes (the queue, failed attempts and retried cases).

Stdlib only. Nothing is written but --json.
"""

import argparse
import glob
import json
import math
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
LEDGER = os.environ.get("LADDER_LEDGER", f"{HOME}/tmp/agent/notes/ladder/runs.jsonl")
LOGS = f"{HOME}/tmp/agent/notes/*ladder*.log"
# Every pool slot's and this checkout's; ':' separates globs.
TIMINGS = (f"{HOME}/.treehouse/*/*/*/native/Build/logs/ui-timings.jsonl:"
           f"{os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))}/native/Build/logs/ui-timings.jsonl")
DEPLOYS = os.environ.get("LEAD_TIMES_DEPLOYS", f"{HOME}/tmp/agent/notes/lead-times/deploys.jsonl")
# The kinds of deploy that put a change on a device. An upload to TestFlight is not one until it is available.
DELIVERED = {"cable", "testflight_available"}
RUNG = re.compile(r"^  rung ([0-9.]+) ([^:]+): (ok|FAILED|skipped)(?:, (\d+) s)?(?:, after (\d+) s waiting)?")
STEP = re.compile(r"^  rung 2 (.+): (\d+) s$")
PLAN_UI = re.compile(r"^rung 2 UI tests(?: \(([^)]*)\))?: (.*)$")


def jsonl(path):
    out = []
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        out.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
    except OSError:
        pass
    return out


def pct(values, p):
    """The p-th percentile, nearest rank; None for no values."""
    v = sorted(x for x in values if x is not None)
    if not v:
        return None
    k = max(0, min(len(v) - 1, math.ceil(p / 100 * len(v)) - 1))
    return v[k]


def area_of(classes, host_only, unknown, changed):
    """A climb's change area: the UI area it selected, else what kind of change it was."""
    areas = [a for a in ("whiteboard", "chat", "places", "ipad", "other") if classes.get(a)]
    if len(areas) > 1:
        return "mixed"
    if areas:
        return areas[0]
    if host_only:
        return "host-only"
    if unknown:
        return "unmapped"
    return "no-ui" if changed else "unknown"


def from_ledger(events):
    runs = {}
    for e in events:
        rid = e.get("run_id")
        if not rid:
            continue
        r = runs.setdefault(rid, {"run_id": rid, "source": "ledger", "steps": [], "rungs": [], "lanes": [],
                                  "destination_skips": [], "outcome": "censored"})
        kind = e.get("event")
        if kind == "start":
            r.update(at=e.get("at"), sha=e.get("sha"), base=e.get("base"), fork=e.get("fork"),
                     changed=e.get("changed", []), classes=e.get("classes", {}), smoke=e.get("smoke"),
                     destinations=e.get("destinations", {}), host_only=e.get("host_only", []),
                     unknown=e.get("unknown", []), flags=e.get("flags", {}))
            r["area"] = area_of(r["classes"], r["host_only"], r["unknown"], r["changed"])
        elif kind == "lane":
            r["lanes"].append(e)
        elif kind == "step":
            r["steps"].append(e)
        elif kind == "rung":
            r["rungs"].append(e)
        elif kind == "destination_skip":
            r["destination_skips"].append(e)
        elif kind == "finish":
            r["outcome"] = e.get("outcome", "fail")
            r["finished"] = e.get("at")
            r["first_failure"] = e.get("first_failure")
    for r in runs.values():
        r["queue_s"] = sum(x.get("waited_s") or 0 for x in r["lanes"]) if r["lanes"] else None
        sim = [x for x in r["rungs"] if x.get("rung") == "2"]
        r["exec_s"] = sim[-1].get("secs") if sim else None
        r["lane_s"] = sum(x.get("secs") or 0 for x in r["rungs"] if x.get("rung") in ("1.5", "2"))
        ff = r.get("first_failure")
        if ff and not ff.get("step"):
            failed = next((s for s in r["steps"] if s.get("status") and s.get("rung", ff.get("rung")) == ff.get("rung")), None)
            if failed:
                ff["step"] = failed.get("label")
        compile_step = next((s for s in r["steps"] if s.get("label") == "compile"), None)
        r["warm"] = compile_step.get("warm") if compile_step else None
    return list(runs.values())


RUN_ID = re.compile(r"^ladder run id: (\S+)")


def from_logs(paths, known=()):
    """Older climbs, from their logs: a climb is one "seconds per rung" block, with the plan lines before it. A climb
    whose log names a run id the ledger holds is the ledger's, so it is not counted twice."""
    runs = []
    for path in paths:
        try:
            lines = open(path, errors="replace").read().splitlines()
        except OSError:
            continue
        # A log holds no times of its own: its file's last change stands in, for ordering and --sample.
        logged = datetime.fromtimestamp(os.path.getmtime(path), timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        classes, steps, n, rid = defaultdict(list), [], 0, None
        for i, line in enumerate(lines):
            m = RUN_ID.match(line)
            if m:
                rid = m.group(1)
                continue
            m = PLAN_UI.match(line)
            if m:
                label, names = m.groups()
                if not names.startswith("none"):
                    group = next((g.lower() for g in ("whiteboard", "chat", "places", "iPad") if label and g in label), "other")
                    classes[group] += names.split()
                continue
            s = STEP.match(line)
            if s and s.group(1) != "Simulator":
                steps.append({"label": s.group(1), "secs": int(s.group(2))})
                continue
            if line == "seconds per rung:":
                rungs, j = [], i + 1
                while j < len(lines) and RUNG.match(lines[j]):
                    rung, name, st, secs, waited = RUNG.match(lines[j]).groups()
                    rungs.append({"rung": rung, "name": name, "status": st, "secs": int(secs) if secs else None,
                                  "waited_s": int(waited) if waited else None})
                    j += 1
                sim = [x for x in rungs if x["rung"] == "2" and x["status"] != "skipped"]
                failed = [x for x in rungs if x["status"] == "FAILED"]
                tail = "\n".join(lines[j:j + 3])
                if "exit 75" in tail:
                    outcome = "unavailable"
                elif failed:
                    outcome = "fail"
                else:
                    outcome = "pass"
                if rid in known:
                    classes, steps, rid = defaultdict(list), [], None
                    continue
                n += 1
                runs.append({
                    "run_id": f"{os.path.basename(path)}#{n}", "source": "log", "at": logged,
                    "sha": None, "classes": dict(classes), "steps": steps,
                    "area": area_of(classes, [], [], [1]), "outcome": outcome,
                    "queue_s": sum(x["waited_s"] or 0 for x in rungs) or None,
                    "exec_s": sim[-1]["secs"] if sim else None,
                    "lane_s": sum(x["secs"] or 0 for x in rungs if x["rung"] in ("1.5", "2")),
                    "first_failure": {"rung": failed[0]["rung"]} if failed else None,
                    "destination_skips": [], "rungs": rungs,
                })
                classes, steps, rid = defaultdict(list), [], None
    return runs


def join_timings(runs, rows):
    by_id = defaultdict(list)
    for t in rows:
        if t.get("run_id"):
            by_id[t["run_id"]].append(t)
    for r in runs:
        cases = by_id.get(r["run_id"], [])
        r["cases"] = len({(c["class"], c["test"]) for c in cases})
        r["retried"] = sorted({f"{c['class']}.{c['test']}" for c in cases if c.get("retry")})
        r["retry_s"] = round(sum(c["secs"] for c in cases if c.get("retry")), 1)
        r["skipped"] = sorted({f"{c['class']}.{c['test']}" for c in cases if c.get("state") == "skipped"})
        if r["destination_skips"]:
            r["skipped"] += [f"{s.get('classes', '?')} (wrong device)" for s in r["destination_skips"]]


def is_ancestor(a, b, root, cache):
    if (a, b) not in cache:
        p = subprocess.run(["git", "-C", root, "merge-base", "--is-ancestor", a, b], capture_output=True)
        cache[(a, b)] = p.returncode == 0
    return cache[(a, b)]


def join_deploys(runs, deploys, root):
    cache = {}
    ordered = sorted(deploys, key=lambda d: d.get("at", ""))
    for r in runs:
        r["delivered"] = r["uploaded"] = None
        sha = r.get("sha")
        if not sha:
            continue
        for d in ordered:
            kind = d.get("kind", "cable")
            if not d.get("sha") or not (d["sha"].startswith(sha) or is_ancestor(sha, d["sha"], root, cache)):
                continue
            if kind in DELIVERED and r["delivered"] is None:
                r["delivered"] = {"at": d.get("at"), "kind": kind, "device": d.get("device")}
            elif kind == "testflight_upload" and r["uploaded"] is None:
                r["uploaded"] = d.get("at")


def attempts(runs):
    """A climb of the same source and selection as an earlier one is its next attempt."""
    seen = defaultdict(int)
    for r in sorted(runs, key=lambda r: (r.get("at") or "", r["run_id"])):
        key = (r.get("sha"), json.dumps(r.get("classes", {}), sort_keys=True)) if r.get("sha") else (r["run_id"],)
        seen[key] += 1
        r["attempt"] = seen[key]


def avoidable_s(r):
    """Lane time a better selection, a fixed flake or a free lane would have saved."""
    s = (r.get("queue_s") or 0) + (r.get("retry_s") or 0)
    if r["outcome"] in ("fail", "interrupted"):
        s += r.get("exec_s") or 0
    return s


def summarise(runs):
    by = defaultdict(list)
    for r in runs:
        by[r["area"]].append(r)
    table = []
    for area, rs in by.items():
        with_sha = [r for r in rs if r.get("sha")]
        table.append({
            "area": area, "climbs": len(rs),
            "queue_p50": pct([r.get("queue_s") for r in rs], 50), "queue_p90": pct([r.get("queue_s") for r in rs], 90),
            "exec_p50": pct([r.get("exec_s") for r in rs], 50), "exec_p90": pct([r.get("exec_s") for r in rs], 90),
            "queue_n": sum(r.get("queue_s") is not None for r in rs), "exec_n": sum(r.get("exec_s") is not None for r in rs),
            # A climb that could not start, was stopped or never finished is not a test's failure: counted apart.
            "first_pass_failures": sum(1 for r in rs if r.get("attempt", 1) == 1 and r["outcome"] in ("fail", "timeout")),
            "not_run": sum(1 for r in rs if r["outcome"] in ("unavailable", "interrupted", "censored")),
            "retried_cases": sum(len(r.get("retried", [])) for r in rs),
            "skipped_coverage": sum(len(r.get("skipped", [])) for r in rs),
            "delivered": sum(1 for r in with_sha if r.get("delivered")), "with_source": len(with_sha),
            "avoidable_min": round(sum(avoidable_s(r) for r in rs) / 60, 1),
        })
    for t in table:
        t["rank_score"] = round(t["climbs"] * t["avoidable_min"], 1)
    return sorted(table, key=lambda t: -t["rank_score"])


def by_class(rows, top=8):
    """The timing lines no climb claims (runs before the ledger, or outside the ladder), by class: the flakes' cost."""
    agg = defaultdict(lambda: {"cases": 0, "secs": 0.0, "retried": 0, "retry_s": 0.0, "failed": 0, "skipped": 0})
    for t in rows:
        if t.get("run_id"):
            continue
        a = agg[t["class"]]
        a["cases"] += 1
        a["secs"] += t.get("secs") or 0
        a["failed"] += t.get("state") == "failed"
        a["skipped"] += t.get("state") == "skipped"
        if t.get("retry"):
            a["retried"] += 1
            a["retry_s"] += t.get("secs") or 0
    out = [dict(cls=k, **{x: round(y, 1) if isinstance(y, float) else y for x, y in v.items()}) for k, v in agg.items()]
    return sorted(out, key=lambda c: (-(c["retry_s"] + c["failed"]), -c["secs"]))[:top]


def fmt(v):
    return "-" if v is None else str(v)


def report(runs, table, classes=()):
    out = [f"ladder report: {len(runs)} climbs ({sum(r['source'] == 'ledger' for r in runs)} from the ledger,"
           f" {sum(r['source'] == 'log' for r in runs)} from older logs)"]
    out.append("climbs (run, area, attempt, outcome, queue s, exec s, retried, skipped, delivered):")
    for r in sorted(runs, key=lambda r: (r.get("at") or "", r["run_id"])):
        sel = " ".join(f"{k}:{len(v)}" for k, v in sorted((r.get("classes") or {}).items()) if v)
        dest = ",".join(f"{k}={v}" for k, v in sorted((r.get("destinations") or {}).items()))
        if r.get("delivered"):
            dl = f"{r['delivered']['kind']} {r['delivered']['at']}"
        elif r.get("uploaded"):
            dl = f"uploaded {r['uploaded']}, not yet available"
        else:
            dl = "no delivery known" if r.get("sha") else "no source sha"
        ff = r.get("first_failure")
        out.append(
            f"  {r['run_id']}  {r['area']}  #{r.get('attempt', 1)}  {r['outcome']}"
            + (f" (first at rung {ff.get('rung')}{' ' + ff['step'] if ff.get('step') else ''})" if ff else "")
            + f"  queue {fmt(r.get('queue_s'))}  exec {fmt(r.get('exec_s'))}"
            + f"  retried {len(r.get('retried', []))}  skipped {len(r.get('skipped', []))}"
            + (f" [{'; '.join(r['skipped'])}]" if r.get("skipped") else "")
            + f"  {dl}" + (f"  [{sel}]" if sel else "") + (f"  on {dest}" if dest else "")
            + ("" if r.get("warm") is None else ("  warm build" if r["warm"] else "  cold build"))
        )
    out.append("by area (climbs; queue p50/p90 s and how many climbs knew it; exec p50/p90 s, likewise; first-pass failures; not run (unavailable, interrupted, censored); retried cases; skipped"
               " coverage; delivered/with source; avoidable lane min; rank = climbs x avoidable):")
    for t in table:
        out.append(
            f"  {t['area']:<10} {t['climbs']:3d}  queue {fmt(t['queue_p50'])}/{fmt(t['queue_p90'])} (n={t['queue_n']})"
            f"  exec {fmt(t['exec_p50'])}/{fmt(t['exec_p90'])} (n={t['exec_n']})  first-pass failures {t['first_pass_failures']}"
            f"  not run {t['not_run']}"
            f"  retried {t['retried_cases']}  skipped {t['skipped_coverage']}"
            f"  delivered {t['delivered']}/{t['with_source']}  avoidable {t['avoidable_min']} min  rank {t['rank_score']}"
        )
    if classes:
        out.append("UI test lines outside any climb, by class (cases run; minutes; failed; retried and its minutes; skipped):")
        for c in classes:
            out.append(f"  {c['cls']:<34} {c['cases']:4d}  {c['secs'] / 60:6.1f} min  failed {c['failed']:3d}"
                       f"  retried {c['retried']:3d} ({c['retry_s'] / 60:.1f} min)  skipped {c['skipped']}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--ledger", default=LEDGER)
    ap.add_argument("--logs", default=LOGS, help="globs of older climbs' logs, ':' between them; '' for none")
    ap.add_argument("--timings", default=TIMINGS, help="globs of ui-timings.jsonl files, ':' between them")
    ap.add_argument("--deploys", default=DEPLOYS)
    ap.add_argument("--repo", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--sample", type=int, default=0, help="only the latest N climbs")
    ap.add_argument("--json", help="write the climbs and the table here")
    a = ap.parse_args(argv)
    ledger = from_ledger(jsonl(a.ledger))
    logs = sorted(p for g in a.logs.split(":") if g for p in glob.glob(g))
    runs = ledger + from_logs(logs, {r["run_id"] for r in ledger})
    rows = [row for p in sorted({p for g in a.timings.split(":") if g for p in glob.glob(g)}) for row in jsonl(p)]
    join_timings(runs, rows)
    join_deploys(runs, jsonl(a.deploys), a.repo)
    attempts(runs)
    if a.sample:
        runs = sorted(runs, key=lambda r: (r.get("at") or "", r["run_id"]))[-a.sample:]
    table = summarise(runs)
    classes = by_class(rows)
    print(report(runs, table, classes))
    if a.json:
        with open(a.json, "w") as f:
            json.dump({"climbs": runs, "by_area": table, "unclaimed_by_class": classes}, f, indent=1, default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main())
