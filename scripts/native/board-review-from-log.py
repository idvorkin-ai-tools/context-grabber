#!/usr/bin/env python3
"""A board review record (spec 2026-11-23-board-interaction-review-design.md, story 1262) from a pulled iPad session log.

One-off, for the review's test fixtures: replays one board's whiteboard events in a log into the record's form, and
writes the steps inside a window, with the board as it stood when the window opened as the record's header.

  board-review-from-log.py <log.jsonl> <board-id> <from-ms> <to-ms> <session-name> <out.jsonl>

The log carries counts, boxes and move ranges, not stroke ids, so units are synthesized: each stroke Igor wrote is a unit
(its `added_box`); the board as first opened is one unit (`board`, its `ink` box); a kept reply is one unit (its group,
which moves whole). A move takes the units inside its `from` box; a rigid move shifts them by `at - from`, an uneven one
maps each from `from` onto `at`. Rooms and drops push the units at or below the cut, and the script checks the counts
the log gives against the units it moved. Only observations reach the record (boxes, moves, pens, spans, whether a
selection was held again), never the log's own verdicts (`apart`, `verdict`, `pickup`). No words are in a log's board
events, so there is nothing to scrub beyond leaving out every other event.
"""
import json
import sys

SLACK = 1.5


def inside(box, outer):
    x, y, w, h = box
    ox, oy, ow, oh = outer
    return x >= ox - SLACK and y >= oy - SLACK and x + w <= ox + ow + SLACK and y + h <= oy + oh + SLACK


def main(log, board, lo, hi, name, out):
    lo, hi = int(lo), int(hi)
    units = {}  # id -> {owner, box, n}
    order = []
    selected = []
    steps = []
    header = None
    pending_move = None
    pending_tap_lost = None
    hold_at = None
    last_keep = None
    build = None
    observed_started = False

    def snapshot():
        return [
            {"id": i, "owner": units[i]["owner"], "box": units[i]["box"], **({"n": units[i]["n"]} if units[i]["n"] > 1 else {})}
            for i in order if i in units
        ]

    def emit(step):
        nonlocal header
        if lo <= step["t"] <= hi:
            steps.append(step)

    def change(i, before, after):
        c = {"id": i, "before": before, "after": after}
        return c

    def move_units(ids, fn):
        out = []
        for i in ids:
            before = list(units[i]["box"])
            units[i]["box"] = [round(v, 1) for v in fn(before)]
            out.append(change(i, before, units[i]["box"]))
        return out

    with open(log) as fh:
        for line in fh:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("type") == "session_start":
                build = e.get("sha")
            if e.get("board") != board:
                continue
            t = e.get("t", 0)
            if t > hi:
                break
            if header is None and t >= lo and units:
                header = {"record": 1, "board": board, "session": name, "surface": "ipad", "build": build,
                          "observes": {"selection": "yes", "pen": "yes", "kept": "yes"}, "ink": snapshot()}
            a = e.get("action")
            if a == "paper_open" and not units and e.get("strokes", 0) > 0:
                units["board"] = {"owner": "igor", "box": e["ink"], "n": e["strokes"]}
                order.append("board")
            elif a == "paper_ink" and e.get("added", 0) > 0 and e.get("moved", 0) == 0 and e.get("removed", 0) == 0:
                uid = f"s{e['strokes']}"
                units[uid] = {"owner": "igor", "box": e["added_box"], "n": e["added"]}
                order.append(uid)
                emit({"t": t, "kind": "ink", "by": "pencil",
                      "changes": [{"id": uid, "owner": "igor", "after": e["added_box"], **({"n": e["added"]} if e["added"] > 1 else {})}]})
            elif a == "paper_keep":
                uid = f"keep{t}"
                units[uid] = {"owner": "larry", "box": e["ink"], "n": e["strokes"]}
                order.append(uid)
                last_keep = {"t": t, "kind": "keep", "by": "menu", "name": "Keep",
                             "changes": [{"id": uid, "owner": "larry", "after": e["ink"], "n": e["strokes"]}],
                             "seen": {"pen_before": e["tool_before"], "pen_after": e["tool_after"], "kept": []}}
                emit(last_keep)
            elif a == "paper_kept_ink" and last_keep is not None:
                last_keep["seen"]["kept"].append({"shown": e["ink_span"], "expected": e["expected_ink_span"],
                                                  "ink_px": e["ink_px"], "dark_px": e["dark_px"]})
            elif a == "hold_menu":
                hold_at = (e["x"], e["y"])
            elif a == "room" and e.get("type") == "board_room":
                cut, dy = e["cut"], e["dy"]
                aim = [i for i in order if i in units and hold_at and inside([hold_at[0], hold_at[1], 0, 0], units[i]["box"])]
                pushed = [i for i in order if i in units and units[i]["box"][1] >= cut]
                assert len(pushed) == e["moved"], (t, len(pushed), e["moved"])
                ch = move_units(pushed, lambda b: [b[0], b[1] + dy, b[2], b[3]])
                emit({"t": t, "kind": "room", "by": "menu", "name": "Make room", "aim": {"ids": aim},
                      "room": {"cut": cut, "dy": dy}, "changes": ch})
            elif a == "paper_selection":
                box = e.get("box") or []
                selected = [i for i in order if i in units and box and inside(units[i]["box"], box)] if box else []
                emit({"t": t, "kind": "select" if selected else "deselect", "by": "finger",
                      **({"aim": {"ids": selected}} if selected else {})})
            elif a == "group_tap_lost":
                pending_tap_lost = {"t": t, "kind": "selection_lost", "by": "system", "aim": {"ids": list(selected)},
                                    "seen": {"held_after": False}}
                emit(pending_tap_lost)
            elif a == "group_tap_lost_after" and pending_tap_lost is not None:
                pending_tap_lost["seen"]["held_after"] = bool(e.get("held"))
                pending_tap_lost = None
            elif a == "paper_ink" and e.get("moved", 0) > 0 and e.get("added", 0) == 0:
                pending_move = e
            elif a == "paper_drop" and pending_move is not None and "moved" in pending_move:
                m = pending_move
                pending_move = None
                frm, at = e["from"], e["at"]
                moved = [i for i in order if i in units and inside(units[i]["box"], frm)]
                assert sum(units[i]["n"] for i in moved) == m["moved"], (t, sum(units[i]["n"] for i in moved), m["moved"])
                before = {i: list(units[i]["box"]) for i in moved}
                if m.get("moved_alike"):
                    dx, dy = at[0] - frm[0], at[1] - frm[1]
                    ch = move_units(moved, lambda b: [b[0] + dx, b[1] + dy, b[2], b[3]])
                else:
                    sx, sy = at[2] / frm[2], at[3] / frm[3]
                    if len(moved) == 1:
                        ch = move_units(moved, lambda b: list(at))
                    else:
                        ch = move_units(moved, lambda b: [at[0] + (b[0] - frm[0]) * sx, at[1] + (b[1] - frm[1]) * sy,
                                                          b[2] * sx, b[3] * sy])
                for c in ch:
                    c["owner"] = units[c["id"]]["owner"]
                if e.get("room"):
                    cut, dy = e["cut"], e["dy"]
                    pushed = [i for i in order if i in units and i not in moved and units[i]["box"][1] >= cut]
                    assert sum(units[i]["n"] for i in pushed) == e["pushed"], (t, pushed, e["pushed"])
                    ch += move_units(pushed, lambda b: [b[0], b[1] + dy, b[2], b[3]])
                held = m.get("selected", 0) > 0
                start = {"CanvasElementResizeHandle": "knob" if held else "handle",
                         "CanvasElementResizeView": "inside"}.get(m.get("start_view"), None)
                step = {"t": t, "kind": "drop" if e.get("room") else "move", "by": "finger" if held else "system",
                        "name": "Move", "aim": {"ids": moved if held else [], **({"start": start} if start else {})},
                        "changes": ch}
                emit(step)
                pending_move = {"_before": before}
            elif a == "paper_apart" and pending_move and "_before" in pending_move:
                before = pending_move["_before"]
                whose = {"mine": "igor", "theirs": "larry"}[e["whose"]]
                back = [i for i in before if units[i]["owner"] == whose]
                assert sum(units[i]["n"] for i in back) == e["back"], (t, back, e["back"])
                ch = []
                for i in back:
                    ch.append(change(i, list(units[i]["box"]), before[i]))
                    units[i]["box"] = before[i]
                emit({"t": t, "kind": "apart", "by": "rule", "changes": ch})
                pending_move = None
    if header is None:
        header = {"record": 1, "board": board, "session": name, "surface": "ipad", "build": build,
                  "observes": {"selection": "yes", "pen": "yes", "kept": "yes"}, "ink": snapshot()}
    with open(out, "w") as fh:
        fh.write(json.dumps(header, sort_keys=True) + "\n")
        for s in steps:
            fh.write(json.dumps(s, sort_keys=True) + "\n")
    print(f"{out}: {len(header['ink'])} units at the start, {len(steps)} steps")


if __name__ == "__main__":
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    main(*sys.argv[1:])
