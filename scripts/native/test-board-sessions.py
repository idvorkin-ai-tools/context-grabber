#!/usr/bin/env python3
"""Story 1173: the vendored board sessions are scrubbed, and the scrub fails closed. The committed copies hold no free
text and no stroke that isn't a straight line (board-sessions.py check); and on made-up sessions, a field the scrub
doesn't know stops it, an unscrubbed text or a drawn stroke fails the check, and a word left readable is found."""

import importlib.util
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("board_sessions", os.path.join(HERE, "board-sessions.py"))
bs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bs)
failed = False


def check(ok, what):
    global failed
    print(("ok   " if ok else "FAIL ") + "board sessions: " + what)
    failed |= not ok


check(bs.check(bs.OUT) == [], "the vendored sessions hold no free text and every stroke is flattened")

header = {"step": "header", "contract": 1, "name": "made-up", "about": "", "thread": "t-1", "board": "b-1",
          "recorded_from": {"first": "a", "last": "b"}, "notes": []}
post = {"step": "post", "route": "/chat/t-1", "at": "2026-11-22T10:00:00-08:00",
        "body": {"id": "m-1", "text": "Lunch with Pat downtown", "board": "b-1", "board_title": "Secret plans"},
        "expect": {"status": 200}}
strokes = {"step": "post", "route": "/whiteboard/strokes", "at": "2026-11-22T10:00:00-08:00",
           "body": {"board": "b-1", "picture_id": "p-1", "strokes": [
               {"id": "s1", "color": "#000000", "points": [[0, 0], [10, 20], [5, 3], [30, 40]]}]},
           "expect": {"status": 200, "response": {"count": 1, "new": 1, "erased": 0}}}

free = []
out = bs.scrub(post, free=free)
check(out["body"]["text"] == "Xxxxx xxxx Xxx xxxxxxxx" and out["body"]["board_title"] == "Xxxxxx xxxxx",
      "free text becomes x's of the same shape")
check(sorted(free) == ["Lunch with Pat downtown", "Secret plans"], "the scrub collects what it scrubbed")
flat = bs.scrub(strokes)["body"]["strokes"][0]["points"]
check(flat[0] == [0, 0] and flat[-1] == [40, 40] and len(flat) == 4 and flat[1] == [13.3, 13.3],
      "a stroke keeps its point count on a straight line across its box snapped out to the grid")
h = [bs.flatten(s) for s in ([[103, 80], [103, 110]], [[103, 95], [118, 95]], [[118, 80], [118, 110]])]
check(h[0] == h[1] == h[2], "the three strokes of a printed H become the same line")
check(bs.leaked(["Lunch with Pat downtown"], {"with"}, "x · op_result ok for 'Lunch with Pat…' at rev 3") == {"lunch"},
      "a word of the writing left in the copy (a cut label in a hint) is found; one the session's fields use is not")
check(bs.leaked(["Draw the board"], set(), "draw back: chat.py reply --shapes · board b") == set(),
      "the hint's own words are never a leak")
try:
    bs.scrub({"step": "post", "body": {"about": "my secret"}})
    check(False, "an about field anywhere but the header stops the scrub")
except bs.Unknown:
    check(True, "an about field anywhere but the header stops the scrub")

try:
    bs.scrub({"step": "post", "body": {"diary": "dear diary"}})
    check(False, "an unknown string field stops the scrub")
except bs.Unknown:
    check(True, "an unknown string field stops the scrub")
try:
    bs.scrub({"step": "post", "body": {"board": "has spaces, so free text"}})
    check(False, "a known field holding free text stops the scrub")
except bs.Unknown:
    check(True, "a known field holding free text stops the scrub")

check(bs.letters_to_x("Встреча at 12:07, café") == "Xxxxxxx xx 00:00, xxxx", "letters of every script and digits are scrubbed")
check(bs.unscrubbed("Xxxx é") and bs.unscrubbed("xx 12") and not bs.unscrubbed("Xx, 00 (0)"),
      "the check sees a letter of any script, or a digit, left")
try:
    bs.scrub({"step": "post", "body": {"events": [{"type": "pen", "path": [[1, 2], [3, 4]]}]}})
    check(False, "a path of points outside a stroke stops the scrub")
except bs.Unknown:
    check(True, "a path of points outside a stroke stops the scrub")

tmp = tempfile.mkdtemp(prefix="board-sessions-test-")
try:
    def write(lines, golden):
        with open(os.path.join(tmp, "made-up.jsonl"), "w") as f:
            f.write("".join(json.dumps(x) + "\n" for x in lines))
        with open(os.path.join(tmp, "made-up.golden.json"), "w") as f:
            json.dump(golden, f)

    write([header, bs.scrub(post), bs.scrub(strokes)], {"contexts": {}})
    check(bs.check(tmp) == [], "a scrubbed made-up session passes the check")
    write([header, post, bs.scrub(strokes)], {"contexts": {}})
    check(any("not scrubbed" in p for p in bs.check(tmp)), "an unscrubbed text fails the check")
    write([header, bs.scrub(post), strokes], {"contexts": {}})
    check(any("not flattened" in p for p in bs.check(tmp)), "a drawn stroke fails the check")
    write([header, bs.scrub(post)], {"contexts": {}, "render": []})
    check(any("only contexts" in p for p in bs.check(tmp)), "a golden with the render fails the check")
    write([header, bs.scrub(post)], {"contexts": {"m-1": "x · op_result ok for 'Lunch with Pat' at rev 3"}})
    check(any("unscrubbed label" in p for p in bs.check(tmp)), "an unscrubbed label in a hint fails the check")
finally:
    shutil.rmtree(tmp)
sys.exit(1 if failed else 0)
