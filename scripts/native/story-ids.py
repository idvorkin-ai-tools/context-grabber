#!/usr/bin/env python3
"""Story IDs are unique and each sits in its journey's ranges (#993, story 789).

Reads the journey table in <stories>/README.md (each row's first column links the journey's file, or its several
files (story 796); its last column lists that journey's IDs, like "001–019, 440–459, 770") and every
"### User Story <n>:" heading in the journey files. Fails, naming each:
  - an ID used by two stories (in one file or two, of one journey or two)
  - an ID outside its own journey's ranges
  - two journeys whose ranges share an ID (how parallel PRs came to take the same one)
  - a story file the table doesn't list, a file listed twice, a listed file that is missing, an IDs column it can't read
  - a "User Story" heading not in the "### User Story <n>:" form, which would otherwise go unchecked
Usage: story-ids.py [stories-dir]   (default docs/stories)

       story-ids.py reserve <journey> [n] [--dir stories-dir]   (story 1027, bead context-grabber-jg3w)
Hands out the next n free IDs (one by default) in a journey's ranges, one per line on stdout and nothing else.
<journey> is one of its story files or a word from its row ("building", "whiteboard"). An ID is
free when it is in none of: the stories on origin/main (fetched first), the stories in stories-dir, the story
headings an open PR adds (gh pr diff), and the reservations in the ledger on this Mac that are under 24 hours old
and not yet on main. The ledger is read and written under a lock, so two reservations at once get different IDs.
Fails, handing out nothing, when main can't be fetched or the open PRs can't be listed.
Overrides, for the tests: STORY_IDS_LEDGER (default ~/tmp/agent/locks/story-ids.json), STORY_IDS_GH (the gh command),
STORY_IDS_MAIN (a stories dir read as main instead of origin/main), STORY_IDS_NOW (epoch seconds),
STORY_IDS_BRANCH (the branch the ledger records).
"""
import fcntl
import json
import os
import re
import shlex
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

HEADING = re.compile(r"^### User Story (\d+):")
LINK = re.compile(r"\]\(([^)#]+\.md)\)")
SPAN = re.compile(r"^(\d+)(?:\s*[–-]\s*(\d+))?$")


def fmt(spans):
    return ", ".join(str(a) if a == b else f"{a}–{b}" for a, b in spans)


def table(root, problems):
    """The journey table: (journey -> spans, file -> journey, journey -> its row but the IDs column)."""
    ranges = {}  # journey (its first file) -> spans
    journey = {}  # file -> its journey
    titles = {}  # journey -> its row but the IDs column, for reserve's journey words
    with open(os.path.join(root, "README.md"), encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\n").strip()
            if not (line.startswith("|") and line.endswith("|")):
                continue
            cells = [c.strip() for c in line[1:-1].split("|")]
            files = LINK.findall(cells[0]) if len(cells) >= 2 else []
            if not files:
                continue
            name, column = files[0], cells[-1]
            titles[name] = " ".join(cells[:-1])
            spans = []
            for part in column.split(","):
                s = SPAN.match(part.strip())
                if not s:
                    problems.append(f"README.md:{n}: {name}: can't read {part.strip()!r} in its IDs column")
                    continue
                a = int(s.group(1))
                b = int(s.group(2) or a)
                if b < a:
                    problems.append(f"README.md:{n}: {name}: range {a}–{b} runs backwards")
                spans.append((a, b))
            if name in ranges:
                problems.append(f"README.md:{n}: {name} has two rows")
            ranges[name] = spans
            for f in files:
                if f in journey and not (f == name and journey[f] == name):
                    problems.append(f"README.md:{n}: {f} is listed twice")
                journey.setdefault(f, name)
                if not os.path.isfile(os.path.join(root, f)):
                    problems.append(f"README.md:{n}: {f} is listed but not there")
    return ranges, journey, titles


def main(root):
    problems = []
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        print(f"FAIL no {readme}")
        return 1
    ranges, journey, _ = table(root, problems)

    names = sorted(ranges)
    for i, x in enumerate(names):
        for y in names[i + 1:]:
            for a, b in ranges[x]:
                for c, d in ranges[y]:
                    lo, hi = max(a, c), min(b, d)
                    if lo <= hi:
                        problems.append(f"ranges overlap: {x} and {y} both hold {fmt([(lo, hi)])}")

    seen = {}
    count = 0
    files = sorted(f for f in os.listdir(root) if f.endswith(".md") and f != "README.md")
    for name in files:
        if name not in journey:
            problems.append(f"{name}: not in README.md's journey table")
        own = ranges.get(journey.get(name))
        with open(os.path.join(root, name), encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                m = HEADING.match(line)
                if not m:
                    if line.startswith("#") and "User Story" in line:
                        problems.append(f"{name}:{n}: unreadable story heading {line.strip()!r}")
                    continue
                count += 1
                sid = int(m.group(1))
                seen.setdefault(sid, []).append(f"{name}:{n}")
                if own is not None and not any(a <= sid <= b for a, b in own):
                    problems.append(f"{name}:{n}: story {sid} is outside its journey's IDs ({fmt(own)})")
    for sid in sorted(seen):
        if len(seen[sid]) > 1:
            problems.append(f"story {sid} is used {len(seen[sid])} times: {', '.join(seen[sid])}")

    for p in problems:
        print(f"FAIL {p}")
    if problems:
        print(f"story-ids: {len(problems)} problem(s); new stories take a free ID in their own journey's ranges")
        return 1
    print(f"ok   story-ids: {count} stories in {len(ranges)} journeys ({len(files)} files), every ID once and in its journey's ranges")
    return 0


ADDED = re.compile(r"^\+### User Story (\d+):", re.M)
DAY = 24 * 3600


def ids_in(texts):
    return {int(m.group(1)) for t in texts for line in t.splitlines() if (m := HEADING.match(line))}


def tree_ids(root):
    texts = []
    for f in os.listdir(root):
        if f.endswith(".md") and f != "README.md":
            with open(os.path.join(root, f), encoding="utf-8") as fh:
                texts.append(fh.read())
    return ids_in(texts)


def run(cmd, cwd=None):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed ({r.returncode}): {(r.stderr or r.stdout).strip()[:300]}")
    return r.stdout


def main_ids(root):
    """The story IDs on main: origin/main fetched now, or STORY_IDS_MAIN's dir for the tests."""
    fake = os.environ.get("STORY_IDS_MAIN")
    if fake:
        return tree_ids(fake)
    top = run(["git", "rev-parse", "--show-toplevel"], cwd=root).strip()
    rel = os.path.relpath(os.path.realpath(root), os.path.realpath(top))
    run(["git", "fetch", "-q", "origin", "main"], cwd=top)
    names = run(["git", "ls-tree", "--name-only", "origin/main", rel + "/"], cwd=top).split()
    texts = [run(["git", "show", f"origin/main:{n}"], cwd=top) for n in names if n.endswith(".md") and not n.endswith("README.md")]
    return ids_in(texts)


def pr_ids():
    """The story IDs every open PR's diff adds (from any machine)."""
    gh = shlex.split(os.environ.get("STORY_IDS_GH", "gh"))
    prs = json.loads(run(gh + ["pr", "list", "--state", "open", "--limit", "500", "--json", "number"]))
    with ThreadPoolExecutor(8) as pool:
        diffs = list(pool.map(lambda p: run(gh + ["pr", "diff", str(p["number"])]), prs))
    return {int(i) for d in diffs for i in ADDED.findall(d)}, len(prs)


def find_journey(query, ranges, journey, titles):
    if query in journey:
        return journey[query]
    if os.path.basename(query) in journey:
        return journey[os.path.basename(query)]
    q = query.lower()
    hits = sorted(j for j in ranges if q in titles[j].lower())
    if len(hits) == 1:
        return hits[0]
    raise RuntimeError(f"{query!r} names {len(hits)} journeys{': ' + ', '.join(hits) if hits else ''}; give one of its story files")


def reserve(root, query, n):
    problems = []
    ranges, journey, titles = table(root, problems)
    name = find_journey(query, ranges, journey, titles)
    on_main = main_ids(root)
    in_prs, n_prs = pr_ids()
    taken = on_main | in_prs | tree_ids(root)
    ledger = os.path.expanduser(os.environ.get("STORY_IDS_LEDGER", "~/tmp/agent/locks/story-ids.json"))
    os.makedirs(os.path.dirname(ledger), exist_ok=True)
    now = float(os.environ.get("STORY_IDS_NOW") or time.time())
    branch = os.environ.get("STORY_IDS_BRANCH")
    if branch is None:
        r = subprocess.run(["git", "branch", "--show-current"], cwd=root, capture_output=True, text=True)
        branch = r.stdout.strip() or "?"
    # The lock is a file beside the ledger, held from read to write: locking the ledger itself would be lost when
    # it is replaced.
    with open(ledger + ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(ledger, encoding="utf-8") as fh:
                held = json.load(fh).get("reservations", [])
        except FileNotFoundError:
            held = []
        live = [r for r in held if now - r["at"] < DAY and r["id"] not in on_main]
        busy = taken | {r["id"] for r in live}
        got = []
        for a, b in ranges[name]:
            for i in range(a, b + 1):
                if len(got) < n and i not in busy:
                    got.append(i)
        if len(got) < n:
            raise RuntimeError(
                f"{name} has {len(got)} free ID(s) of the {n} asked for ({fmt(ranges[name])}); add the next unused block of "
                "twenty to its row in the journey table")
        live += [{"id": i, "journey": name, "branch": branch, "at": now,
                  "until": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now + DAY))} for i in got]
        tmp = f"{ledger}.{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"reservations": live}, fh, indent=1)
        os.replace(tmp, ledger)
    for i in got:
        print(i)
    print(f"reserved {', '.join(map(str, got))} in {name} for {branch} for 24 h (main, {n_prs} open PR(s) and the ledger {ledger} "
          "checked)", file=sys.stderr)
    return 0


def reserve_cli(args):
    root = "docs/stories"
    if "--dir" in args:
        k = args.index("--dir")
        root = args[k + 1]
        args = args[:k] + args[k + 2:]
    if not 1 <= len(args) <= 2 or (len(args) == 2 and not args[1].isdigit()) or (len(args) == 2 and int(args[1]) < 1):
        print("usage: story-ids.py reserve <journey> [n] [--dir stories-dir]", file=sys.stderr)
        return 2
    try:
        return reserve(root, args[0], int(args[1]) if len(args) == 2 else 1)
    except (RuntimeError, OSError, ValueError) as e:
        print(f"FAIL reserve: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "reserve":
        sys.exit(reserve_cli(sys.argv[2:]))
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/stories"))
