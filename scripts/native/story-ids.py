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
"""
import os
import re
import sys

HEADING = re.compile(r"^### User Story (\d+):")
LINK = re.compile(r"\]\(([^)#]+\.md)\)")
SPAN = re.compile(r"^(\d+)(?:\s*[–-]\s*(\d+))?$")


def fmt(spans):
    return ", ".join(str(a) if a == b else f"{a}–{b}" for a, b in spans)


def main(root):
    problems = []
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        print(f"FAIL no {readme}")
        return 1
    ranges = {}  # journey (its first file) -> spans
    journey = {}  # file -> its journey
    with open(readme, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\n").strip()
            if not (line.startswith("|") and line.endswith("|")):
                continue
            cells = [c.strip() for c in line[1:-1].split("|")]
            files = LINK.findall(cells[0]) if len(cells) >= 2 else []
            if not files:
                continue
            name, column = files[0], cells[-1]
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


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/stories"))
