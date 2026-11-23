#!/usr/bin/env python3
"""Story 1174: the fake Cockpit plays a recorded board session back as the Cockpit answered it, checked without a
simulator. Each session's posts go to it in their recorded order: every strokes answer is the recorded one, the hint it
would wake Larry with for each message is the Cockpit's recorded hint (the session's golden), Larry's rows are his
recorded ones, and each of Igor's messages ends at the furthest receipt recorded for it."""

import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SESSIONS = os.path.join(ROOT, "native/ContextCore/Tests/ContextCoreTests/Fixtures/board-sessions")
RANK = {"received": 1, "seen": 2, "done": 3}
failed = False


def check(ok, what):
    global failed
    print(("ok   " if ok else "FAIL ") + "fake session: " + what)
    failed |= not ok


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


port = free_port()
base = "http://127.0.0.1:%d" % port
report = tempfile.NamedTemporaryFile(delete=False).name
fake = subprocess.Popen(
    [sys.executable, os.path.join(ROOT, "scripts/native/fake-cockpit.py"), str(port), report],
    env={**os.environ, "FAKE_COCKPIT_LARRY_DELAY": "0.01"}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def call(path, body=None):
    request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as answer:
        return json.loads(answer.read())


def settle():
    for _ in range(200):
        if not call("/fake/session")["session"]["pending"]:
            return
        time.sleep(0.01)


def replay(name):
    with open(os.path.join(SESSIONS, name + ".jsonl"), encoding="utf-8") as f:
        steps = [json.loads(line) for line in f if line.strip()]
    with open(os.path.join(SESSIONS, name + ".golden.json"), encoding="utf-8") as f:
        golden = json.load(f)["contexts"]
    thread = call("/fake/session", {"name": name})["thread"]
    check(thread == steps[0]["thread"], "%s plays on its own thread" % name)
    answers_ok = True
    for step in steps[1:]:
        if step["step"] != "post":
            continue
        body = {k: v for k, v in step["body"].items() if k != "attachments_recorded"}
        got = call(step["route"], body)
        if step["route"] == "/whiteboard/strokes" and step.get("expect"):
            answers_ok &= {k: got[k] for k in ("count", "new", "erased")} == step["expect"]["response"]
        settle()
    check(answers_ok, "%s: every strokes post answered with the counts the Cockpit gave" % name)
    hints = call("/fake/session")["session"]["hints"]
    check(hints == golden, "%s: each message's hint is the Cockpit's recorded one%s" % (
        name, "" if hints == golden else ": " + json.dumps(
            {k: [hints.get(k), golden.get(k)] for k in set(hints) | set(golden) if hints.get(k) != golden.get(k)})[:600]))
    messages = call("/chat/" + thread)["messages"]
    keys = ("text", "shapes", "ops", "frame", "board", "picture_id")
    larry = [{k: m[k] for k in keys if k in m} for m in messages if m["who"] == "larry"]
    want = [{k: s["expect"]["row"][k] for k in keys if k in s["expect"]["row"]} for s in steps if s["step"] == "reply"]
    check(larry == want, "%s: Larry's %d rows are his recorded ones" % (name, len(want)))
    furthest = {s["body"]["id"]: "received" for s in steps if s["step"] == "post" and s["route"].startswith("/chat/")}
    for s in steps:
        if s["step"] == "receipt" and s["state"] in RANK:
            for t in s["targets"]:
                if RANK[s["state"]] > RANK[furthest[t]]:
                    furthest[t] = s["state"]
    folded = {m["id"]: m.get("receipt", {}).get("state", "received") for m in messages if m["who"] == "igor"}
    check(folded == furthest, "%s: each of Igor's messages ends at its furthest recorded receipt" % name)


try:
    for _ in range(50):
        try:
            call("/fake/session")
            break
        except OSError:
            time.sleep(0.1)
    names = sorted(n[: -len(".jsonl")] for n in os.listdir(SESSIONS) if n.endswith(".jsonl"))
    check(len(names) >= 4, "the four recorded sessions are vendored (%s)" % ", ".join(names))
    for name in names:
        replay(name)
    # A batch replayed on another board and revision: its board is the message's, its base as far behind.
    call("/fake/session", {"name": "ops-move", "thread": "igor2-88g.900"})
    turns = [json.loads(line) for line in open(os.path.join(SESSIONS, "ops-move.jsonl"), encoding="utf-8")]
    chats = [s for s in turns if s["step"] == "post" and s["route"].startswith("/chat/")]
    for i, s in enumerate(chats):
        body = {k: v for k, v in s["body"].items() if k != "attachments_recorded"}
        body.update(id="moved-%02d-turn" % i, board="sim-board")
        if "rev" in body:
            body["rev"] += 1000
        call("/chat/igor2-88g.900", body)
        settle()
    batches = [m["ops"] for m in call("/chat/igor2-88g.900")["messages"] if m.get("ops")]
    check([(b["board"], b["base_rev"]) for b in batches] == [("sim-board", 1256), ("sim-board", 1257)],
          "a session on another board's thread names that board, its batches' bases shifted with its revisions")
    check(call("/fake/session", {"name": None})["thread"] is None, "a session stops")
finally:
    fake.terminate()
    fake.wait()
    os.unlink(report)
sys.exit(1 if failed else 0)
