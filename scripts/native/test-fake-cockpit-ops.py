#!/usr/bin/env python3
"""Stories 814-818: the fake Cockpit's board ops, which WhiteboardPaperGhostsUITests relies on, checked without a
simulator. Armed with POST /fake/larry-ops, Larry's next board answer is a batch of changes on the message's own rev
(one behind it when stale), with room below the picture's middle and a line of text in the gap, and only once; GET
/fake/ops says the rev and op_result each board message carried."""

import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
failed = False


def check(ok, what):
    global failed
    print(("ok   " if ok else "FAIL ") + "fake ops: " + what)
    failed |= not ok


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


port = free_port()
base = "http://127.0.0.1:%d" % port
report = tempfile.NamedTemporaryFile(delete=False).name
fake = subprocess.Popen(
    [os.path.join(ROOT, "scripts/native/fake-cockpit.py"), str(port), report],
    env={**os.environ, "FAKE_COCKPIT_LARRY_DELAY": "0.1"}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def call(path, body=None):
    request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=5) as answer:
        return json.loads(answer.read())


def larry_rows(key):
    time.sleep(0.5)
    return [m for m in call("/chat/" + key)["messages"] if m["who"] == "larry"]


try:
    for _ in range(50):
        try:
            call("/fake/ops")
            break
        except OSError:
            time.sleep(0.1)
    frame = {"x": 100, "y": 200, "w": 400, "h": 600, "scale": 2}
    turn = {"id": "p1", "text": "turn", "board": "b1", "picture_id": "p1", "frame": frame, "title": "Plan", "rev": 7,
            "op_result": None, "events": [{"type": "pen", "state": "down", "idle_ms": 0, "t": 1}]}
    call("/fake/larry-ops", {})
    key = call("/chat", turn)["thread"]
    rows = larry_rows(key)
    ops = rows[-1].get("ops") if rows else None
    check(ops is not None and rows[-1]["text"] == "made room", "an armed answer is a batch: %s" % rows)
    if ops:
        check(ops["board"] == "b1" and ops["base_rev"] == 7 and ops["label"] == "make room", "on the message's rev")
        push, text = ops["list"]
        check(push == {"op": "translate", "below_y": 500, "dy": 120}, "room below the picture's middle: %s" % push)
        check(text["op"] == "add_text" and text["id"] == "fake-text-1" and text["font"] == "plain"
              and text["y"] == 530 and text["x"] == 140, "text in the gap: %s" % text)
    check(not call("/fake/ops")["armed"], "once")

    call("/fake/larry-ops", {"stale": True, "dy": 50})
    second = dict(turn, id="p2", picture_id="p2", rev=8,
                  op_result={"label": "make room", "ok": True, "rev": 8}, events=[])
    call("/chat/" + key, second)
    stale = larry_rows(key)[-1].get("ops") or {}
    check(stale.get("base_rev") == 7 and stale.get("list", [{}])[0].get("dy") == 50, "stale is one behind: %s" % stale)

    call("/chat/" + key, dict(turn, id="p3", picture_id="p3", rev=8, op_result=None, events=[]))
    last = larry_rows(key)[-1]
    check("ops" not in last and last.get("shapes"), "unarmed, he draws marks as before")
    reports = call("/fake/ops")["reports"]
    check([r["rev"] for r in reports] == [7, 8, 8], "each board message's rev: %s" % reports)
    check(reports[0]["events"] == 1 and reports[1]["op_result"] == {"label": "make room", "ok": True, "rev": 8},
          "and its events and op_result: %s" % reports)
    call("/fake/larry-ops", {"kind": "ink_and_button"})
    call("/chat/" + key, dict(turn, id="p4", picture_id="p4", rev=9, op_result=None, events=[]))
    ink = larry_rows(key)[-1].get("ops") or {}
    kinds = [op["op"] for op in ink.get("list", [])]
    check(ink.get("base_rev") == 9 and kinds == ["add_strokes", "overlay"], "his ink and a button: %s" % ink)
    check(ink["list"][1]["tap_event"] == {"type": "make_room"} and ink["list"][0]["strokes"][0]["points"][0] == [140, 830],
          "the line and the button sit below the picture")
    answer = call("/whiteboard/events", {"board": "b1", "rev": 9, "events": [{"type": "tap", "target_id": "x"}]})
    check(answer["ok"] and answer["woke"] is False and answer["rev"] == 9 and "ts_ms" in answer,
          "a plain tap is taken but wakes nobody: %s" % answer)
    tap = {"type": "overlay_tap", "target_id": "x", "event": {"type": "make_room"}}
    answer = call("/whiteboard/events", {"board": "b1", "rev": 9, "events": [tap]})
    posts = call("/fake/ops")["event_posts"]
    check(answer["woke"] and posts[-1]["woke"] and posts[-1]["events"][0]["target_id"] == "x",
          "a tap on his control wakes him: %s" % posts)
    for bad, why in (({"type": "Make-Room"}, "a type out of pattern"), ({"type": "x", "pad": "y" * 9000}, "over 8 KB")):
        try:
            call("/whiteboard/events", {"board": "b1", "rev": 9, "events": [bad]})
            check(False, "%s is refused" % why)
        except urllib.error.HTTPError as error:
            check(error.code in (400, 413), "%s is refused: %s" % (why, error.code))
    picture = {"board": "b1", "picture_id": "p9", "frame": frame}
    text = {"kind": "text", "id": "t1", "text": "hi", "font": "print", "x": 1, "y": 2, "w": 3, "h": 4, "color": "#000000",
            "t": 5}
    ink = {"id": "s1", "color": "#000000", "width": 3, "tool": "pen", "points": [[0, 0], [1, 1]]}
    check(call("/whiteboard/strokes", dict(picture, strokes=[ink, text]))["count"] == 2, "a text the Cockpit takes")
    for bad, why in ((dict(text, points=[[0, 0]]), "a text with more"), (dict(text, font="plain"), "a font it doesn't know"), ({"id": "s2", "points": []}, "a stroke with none"),
                     (dict(ink, kind="label"), "another kind")):
        try:
            call("/whiteboard/strokes", dict(picture, strokes=[bad]))
            check(False, why + " is refused")
        except urllib.error.HTTPError as e:
            check(e.code == 400, why + " is refused")
finally:
    fake.kill()
    os.unlink(report)

sys.exit(1 if failed else 0)
