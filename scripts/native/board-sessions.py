#!/usr/bin/env python3
"""The Cockpit's recorded board sessions, vendored scrubbed (bead context-grabber-09tx, story 1173).

The Cockpit records real board conversations (docs/board-contract.md, Recorded sessions, in the private
idvorkin-ai-tools/cockpit repo). This repo is public, so only a scrubbed copy is ever committed: every free text (what
Igor and Larry wrote, Larry's labels, a board's title) becomes x's of the same shape, and every stroke's points are laid
on a straight line across its own box snapped to a 40-point grid, so no writing can be read back. Ids, counts, revisions, frames, events, ops and
receipts stay as recorded, which is all a replay needs. The raw sessions never touch the repo: they are fetched into a
temporary directory outside it, scrubbed there, and only the result is written.

  scripts/native/board-sessions.py vendor [--sha SHA] [--out DIR]   fetch, scrub, check, write (default sha below)
  scripts/native/board-sessions.py check [DIR]                      the vendored files hold nothing unscrubbed

The scrub fails closed: a string field it doesn't know aborts it, and so does a path of points anywhere but a stroke
or Larry's own shapes, so a new field in a later contract can't slip writing through. Letters of every script become x
and digits 0. vendor also checks the output against the raw sessions: no word of four letters or more from their free
texts may appear anywhere in it, unless the raw sessions also use that word in a field that is not free text (an id,
a kind, a key) or it is one of the words of the Cockpit's hint to Larry. check needs no raw sessions: every free text in the vendored files must be x's, digits and punctuation,
and every other string must match its field's pattern.
"""

import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile

REPO = "idvorkin-ai-tools/cockpit"
SHA = "9ca45fe"
SRC = "fixtures/board/sessions"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "native/ContextCore/Tests/ContextCoreTests/Fixtures/board-sessions")

# Free text, by field name: scrubbed wherever it appears.
FREE = {"text", "label", "board_title", "note", "ask_text", "question"}
HEX = r"[0-9a-f]+"
ID = r"[A-Za-z0-9_.#-]{1,200}"
ISO = r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?([+-]\d\d:\d\d|Z)"
WORD = r"[a-z][a-z0-9_]{0,31}"
# Every other string field, by name: the pattern its value must match.
STRUCT = {
    "step": WORD, "route": r"/(whiteboard/strokes|whiteboard/events|chat/" + ID + ")", "at": ISO, "ts": ISO,
    "board": ID, "picture_id": ID, "id": ID, "thread": ID, "name": WORD.replace("_", "_-"), "first": ID, "last": ID,
    "color": r"#[0-9A-Fa-f]{6}", "tool": WORD, "font": r"print|hand|plain", "kind": WORD, "type": WORD,
    "state": r"[a-z][a-z_-]{0,31}", "gesture": WORD, "from": WORD, "op": WORD, "source": WORD, "who": WORD,
    "reason": WORD, "by": WORD, "client": r"Board debug page|Grabber app|Grabber Native|CLI",
    "build": HEX + r" [A-Za-z0-9._/-]+", "attachments_recorded": r"\d{4}-\d\d-\d\d/" + HEX + r"\.(jpg|png|pdf|txt)",
    "added": ID, "erased": ID, "moved": ID, "ids": ID, "targets": ID, "target_id": ID, "group": ID, "ask": ID,
    "missing_ids": ID, "to": ID, "mode": WORD, "responder": WORD, "dir": WORD, "edge": WORD, "what": WORD,
    "action": WORD, "tool_name": WORD, "side": WORD, "role": WORD, "route_name": WORD, "button": WORD,
}


class Unknown(Exception):
    pass


def letters_to_x(s):
    """Every letter of any script to x (X for a capital) and every digit to 0: only the shape of the writing stays."""
    return "".join("0" if c.isdigit() else ("X" if c.isupper() else "x") if c.isalpha() else c for c in s)


def unscrubbed(s):
    """A letter other than x or a digit other than 0, in any script."""
    return any((c.isalpha() and c not in "xX") or (c.isdigit() and c != "0") for c in s)


# The words of the Cockpit's hint to Larry (board contract, *What wakes the agent*): the only words a golden's hints
# may hold that the session's own fields don't.
HINT_WORDS = {"cockpit", "chat", "board", "draw", "back", "reply", "shapes", "move", "base_rev", "refused", "stale",
              "missing", "events", "whiteboard_events", "show", "thread", "strokes", "whiteboard_strokes", "render",
              "with", "from", "ops", "out", "png", "new", "rev", "ids", "for", "op_result", "at", "ok"}
POINT_LISTS = ("strokes[].points", "shapes[].points")


GRID = 40  # board points: about a line of writing, so every stroke of a letter lands on the same cell


def flatten(points):
    """A stroke as one straight line across its box snapped out to a 40-point grid: its id, point count and rough place
    stay; its shape goes, and the strokes of one printed letter (an H's three, a #'s four) become the same line."""
    if len(points) < 2:
        return points
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    x0, y0 = math.floor(min(xs) / GRID) * GRID, math.floor(min(ys) / GRID) * GRID
    x1, y1 = max(math.ceil(max(xs) / GRID) * GRID, x0 + GRID), max(math.ceil(max(ys) / GRID) * GRID, y0 + GRID)
    n = len(points) - 1
    return [[round(x0 + (x1 - x0) * i / n, 1), round(y0 + (y1 - y0) * i / n, 1)] for i in range(len(points))]


def scrub(o, key=None, path="", free=None):
    """o with every free text scrubbed and every stroke flattened; Unknown on a string field it doesn't know."""
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            if k == "points" and isinstance(v, list) and path.endswith("strokes[]"):
                out[k] = flatten(v)
            else:
                out[k] = scrub(v, k, path + "." + k, free)
        return out
    if isinstance(o, list):
        # A path of points is a drawing: only a stroke's (flattened above) or Larry's own shapes' may pass.
        if o and all(isinstance(p, list) and len(p) == 2 and all(isinstance(n, (int, float)) for n in p) for p in o):
            if not any(path.endswith(allowed) for allowed in POINT_LISTS):
                raise Unknown("a path of points at %s: add it to POINT_LISTS (or flatten it) on purpose" % path)
        return [scrub(v, key, path + "[]", free) for v in o]
    if not isinstance(o, str):
        return o
    if key in FREE or path.startswith(".notes"):
        if free is not None:
            free.append(o)
        return letters_to_x(o)
    if path == ".about":  # the header's own description, as the Cockpit's contract table words it
        return o
    pattern = STRUCT.get(key)
    if pattern is None:
        raise Unknown("unknown string field %s (%r...): add it to FREE or STRUCT on purpose" % (path, o[:20]))
    if not re.fullmatch(pattern, o):
        raise Unknown("%s = %r doesn't look like a %s; free text there?" % (path, o[:40], key))
    return o


def words(s):
    """Its words of four letters or more, in any script."""
    return {w.lower() for w in re.findall(r"[^\W\d_]{4,}", s)}


def structural_words(o, key=None, path=""):
    if isinstance(o, dict):
        found = set()
        for k, v in o.items():
            found |= words(k) | structural_words(v, k, path + "." + k)
        return found
    if isinstance(o, list):
        return set().union(*[structural_words(v, key, path + "[]") for v in o]) if o else set()
    if isinstance(o, str) and key not in FREE and not path.startswith(".notes"):
        return words(o)
    return set()


def leaked(free, struct, out):
    """The words of four letters or more from the free texts still in `out`, but for the ones the session's other
    fields (ids, kinds, keys) or the Cockpit's hint also use."""
    return (set().union(set(), *map(words, free)) - struct - HINT_WORDS) & words(out)


def scrub_golden(golden, labels):
    """The golden's hints only (the render digest is the server's picture of the raw strokes); a label in a hint is
    scrubbed as the label itself is."""
    contexts = {}
    for k, v in golden["contexts"].items():
        # The Cockpit quotes a label as Python does: in double quotes when it holds a single one.
        for label in sorted(labels, key=len, reverse=True):
            v = v.replace(label, letters_to_x(label))
        contexts[k] = v
    return {"contexts": contexts}


def gh_raw(path, sha):
    return subprocess.run(
        ["gh", "api", "repos/%s/contents/%s?ref=%s" % (REPO, path, sha), "-H", "Accept: application/vnd.github.raw"],
        check=True, capture_output=True).stdout


def vendor(sha, out):
    names = json.loads(subprocess.run(
        ["gh", "api", "repos/%s/contents/%s?ref=%s" % (REPO, SRC, sha), "--jq", "[.[].name]"],
        check=True, capture_output=True).stdout)
    sessions = sorted(n[: -len(".jsonl")] for n in names if n.endswith(".jsonl"))
    written = {}
    source = {"repo": REPO, "sha": sha, "path": SRC, "sessions": {}}
    with tempfile.TemporaryDirectory(prefix="board-sessions-raw-") as raw:
        for name in sessions:
            body = gh_raw("%s/%s.jsonl" % (SRC, name), sha)
            golden = json.loads(gh_raw("%s/%s.golden.json" % (SRC, name), sha))
            with open(os.path.join(raw, name + ".jsonl"), "wb") as f:
                f.write(body)
            steps = [json.loads(line) for line in body.decode().splitlines() if line.strip()]
            free, struct = [], set()
            lines = []
            for step in steps:
                lines.append(json.dumps(scrub(step, free=free), ensure_ascii=False, sort_keys=True))
                struct |= structural_words(step)
            labels = {s for s in free if s}
            text = "\n".join(lines) + "\n"
            gold = json.dumps(scrub_golden(golden, labels), ensure_ascii=False, indent=2, sort_keys=True) + "\n"
            leaks = leaked(free, struct, text + gold)
            if leaks:
                raise Unknown("%s: the scrubbed copy still holds %d of its free words, e.g. %s" % (
                    name, len(leaks), sorted(leaks)[:5]))
            written[name + ".jsonl"] = text
            written[name + ".golden.json"] = gold
            source["sessions"][name] = {
                "jsonl_sha256": hashlib.sha256(body).hexdigest(), "steps": len(steps), "free_texts": len(free)}
    source["scrub"] = ("free texts (%s) letters to x; stroke points onto a line across their box; golden: contexts only"
                       % ", ".join(sorted(FREE)))
    os.makedirs(out, exist_ok=True)
    for name, text in written.items():
        with open(os.path.join(out, name), "w", encoding="utf-8") as f:
            f.write(text)
    with open(os.path.join(out, "SOURCE.json"), "w", encoding="utf-8") as f:
        json.dump(source, f, indent=2, sort_keys=True)
        f.write("\n")
    problems = check(out)
    if problems:
        raise Unknown("; ".join(problems))
    print("vendored %d sessions from %s@%s into %s" % (len(sessions), REPO, sha, os.path.relpath(out, ROOT)))


def check(out):
    """What is wrong with the vendored files, if anything: an unscrubbed free text or an unknown string field."""
    problems = []
    names = sorted(n for n in os.listdir(out) if n.endswith(".jsonl"))
    if not names:
        return ["no sessions in %s" % out]
    for name in names:
        with open(os.path.join(out, name), encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                if not line.strip():
                    continue
                step = json.loads(line)
                free = []
                try:
                    again = scrub(step, free=free)
                except Unknown as e:
                    problems.append("%s:%d: %s" % (name, n, e))
                    continue
                bad = [s for s in free if unscrubbed(s)]
                if bad:
                    problems.append("%s:%d: free text not scrubbed: %r" % (name, n, bad[0][:30]))
                for stroke in _strokes(step):
                    if stroke.get("points") != flatten(stroke.get("points") or []):
                        problems.append("%s:%d: stroke %s is not flattened" % (name, n, stroke.get("id")))
                        break
                del again
        gold = os.path.join(out, name[: -len(".jsonl")] + ".golden.json")
        with open(gold, encoding="utf-8") as f:
            g = json.load(f)
        if set(g) != {"contexts"}:
            problems.append("%s: a golden holds only contexts, not %s" % (os.path.basename(gold), sorted(g)))
        for k, v in g.get("contexts", {}).items():
            for label in re.findall(r"op_result \S+(?: \([^)]*\))? for (.*?) at rev", v):
                if unscrubbed(label):
                    problems.append("%s: an unscrubbed label in %s's hint" % (os.path.basename(gold), k))
    return problems


def _strokes(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "strokes" and isinstance(v, list):
                yield from (s for s in v if isinstance(s, dict) and "points" in s)
            else:
                yield from _strokes(v)
    elif isinstance(o, list):
        for v in o:
            yield from _strokes(v)


def main(argv):
    if argv[:1] == ["vendor"]:
        sha = argv[argv.index("--sha") + 1] if "--sha" in argv else SHA
        out = argv[argv.index("--out") + 1] if "--out" in argv else OUT
        vendor(sha, out)
        return 0
    if argv[:1] == ["check"]:
        out = argv[1] if len(argv) > 1 else OUT
        problems = check(out)
        for p in problems:
            print("FAIL board sessions: " + p)
        if not problems:
            print("ok   board sessions: %s scrubbed (no free text, every stroke flattened)" % os.path.relpath(out, ROOT))
        return 1 if problems else 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Unknown as e:
        print("board-sessions: %s" % e, file=sys.stderr)
        sys.exit(1)
