#!/usr/bin/env python3
"""Story 1511 (bead context-grabber-yfsz): is the build on each of Igor's devices the one we last installed?

Reads the deploys ledger (record-deploy.sh's, LEAD_TIMES_DEPLOYS) for each device's last install, and the device's
newest session log under the pulled logs (pull-logs.sh: <root>/<device>/logs/grabber-*.jsonl, whose first line is the
session_start naming the build), and prints one line per device:

  MATCH           the newest session runs the last installed build (or a build posted over the air after it)
  MISMATCH        the newest session after the install runs another build; exit 1
  NO SESSION YET  no session started since the install
  UNKNOWN         no install recorded, or no session pulled

usage: device-build-check.py [ipad|phone ...] [--ledger PATH] [--logs ROOT]
"""

import argparse
import datetime as dt
import glob
import json
import os
import sys

INSTALLS = ("cable", "network")  # a build put on the device
OFFERS = ("ota_posted",)  # a build offered to the device, installed only if Igor taps it


def when(s):
    try:
        return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)
    except (TypeError, ValueError):
        return None


def ledger_entries(path):
    out = []
    try:
        with open(path) as f:
            for line in f:
                try:
                    e = json.loads(line)
                except ValueError:
                    continue
                if e.get("app", "context-grabber") == "context-grabber" and when(e.get("at")):
                    out.append(e)
    except OSError:
        pass
    return out


def newest_session(root, device):
    """The newest session's start: (sha, started datetime, file), from the first session_start line of each log."""
    best = None
    for path in glob.glob(os.path.join(root, device, "logs", "grabber-*.jsonl")):
        try:
            with open(path) as f:
                for _ in range(5):
                    line = f.readline()
                    if not line:
                        break
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    if e.get("type") == "session_start":
                        started = e.get("started", "")
                        t = when(started.split(".")[0].rstrip("Z") + "Z" if started else None)
                        if t and (best is None or t > best[1]):
                            best = (str(e.get("sha", "")), t, path)
                        break
        except OSError:
            continue
    return best


def same(a, b):
    a, b = (a or "").lower(), (b or "").lower()
    n = min(len(a), len(b))
    return n >= 7 and a[:n] == b[:n]


def short(sha):
    return (sha or "?")[:8]


def stamp(t):
    return t.strftime("%Y-%m-%d %H:%M:%SZ") if t else "?"


def check(device, entries, root):
    mine = [e for e in entries if e.get("device") == device]
    installs = [e for e in mine if e.get("kind", "cable") in INSTALLS]
    if not installs:
        return 0, f"{device}: UNKNOWN: no install recorded in the deploys ledger"
    last = max(installs, key=lambda e: when(e["at"]))
    at = when(last["at"])
    offers = [e for e in mine if e.get("kind") in OFFERS and when(e["at"]) >= at]
    session = newest_session(root, device)
    if session is None:
        return 0, f"{device}: UNKNOWN: no session log pulled (run just pull-logs); last install {short(last['sha'])} at {stamp(at)}"
    sha, started, path = session
    if started < at:
        return 0, (f"{device}: NO SESSION YET since the install of {short(last['sha'])} at {stamp(at)} "
                   f"(newest session {short(sha)} started {stamp(started)})")
    if same(sha, last["sha"]):
        return 0, f"{device}: MATCH {short(sha)} (installed {stamp(at)} by {last.get('kind', 'cable')}, session {stamp(started)})"
    for o in offers:
        if same(sha, o["sha"]):
            return 0, f"{device}: MATCH {short(sha)} (posted over the air {stamp(when(o['at']))}, session {stamp(started)})"
    return 1, (f"{device}: MISMATCH: the device runs {short(sha)} (session {stamp(started)}, {os.path.basename(path)}), "
               f"but the last install was {short(last['sha'])} at {stamp(at)} by {last.get('kind', 'cable')}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("devices", nargs="*", default=["ipad", "phone"])
    ap.add_argument("--ledger", default=os.environ.get(
        "LEAD_TIMES_DEPLOYS", os.path.expanduser("~/tmp/agent/notes/lead-times/deploys.jsonl")))
    ap.add_argument("--logs", default=os.environ.get("GRABBER_LOGS", os.path.expanduser("~/tmp/agent/grabber-logs")))
    a = ap.parse_args()
    entries = ledger_entries(a.ledger)
    worst = 0
    for d in a.devices:
        code, line = check(d, entries, a.logs)
        print(line)
        worst = max(worst, code)
    return worst


if __name__ == "__main__":
    sys.exit(main())
