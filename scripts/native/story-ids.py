#!/usr/bin/env python3
"""Story IDs are unique and each sits in its journey's ranges (#993, story 789).

Reads the journey table in <stories>/README.md (each row links a journey file; its last column lists that journey's
IDs, like "001–019, 440–459, 770") and every "### User Story <n>:" heading in the journey files. Fails, naming each:
  - an ID used by two stories (in one file or two)
  - an ID outside its own journey's ranges
  - two journeys whose ranges share an ID (how parallel PRs came to take the same one)
  - a story file the table doesn't list, a row whose file is missing, an IDs column it can't read
  - a "User Story" heading not in the "### User Story <n>:" form, which would otherwise go unchecked
Usage: story-ids.py [stories-dir]   (default docs/stories)
"""
import os
import re
import sys

HEADING = re.compile(r"^### User Story (\d+):")
ROW = re.compile(r"^\|\s*\[[^\]]*\]\(([^)]+\.md)\)\s*\|.*\|\s*([^|]*?)\s*\|\s*$")
SPAN = re.compile(r"^(\d+)(?:\s*[–-]\s*(\d+))?$")


def fmt(spans):
    return ", ".join(str(a) if a == b else f"{a}–{b}" for a, b in spans)


def main(root):
    problems = []
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        print(f"FAIL no {readme}")
        return 1
    ranges = {}
    with open(readme, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            m = ROW.match(line.rstrip("\n"))
            if not m:
                continue
            name, column = m.group(1), m.group(2)
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
            if not os.path.isfile(os.path.join(root, name)):
                problems.append(f"README.md:{n}: {name} is listed but not there")

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
        if name not in ranges:
            problems.append(f"{name}: not in README.md's journey table")
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
                if name in ranges and not any(a <= sid <= b for a, b in ranges[name]):
                    problems.append(f"{name}:{n}: story {sid} is outside its journey's IDs ({fmt(ranges[name])})")
    for sid in sorted(seen):
        if len(seen[sid]) > 1:
            problems.append(f"story {sid} is used {len(seen[sid])} times: {', '.join(seen[sid])}")

    for p in problems:
        print(f"FAIL {p}")
    if problems:
        print(f"story-ids: {len(problems)} problem(s); new stories take a free ID in their own journey's ranges")
        return 1
    print(f"ok   story-ids: {count} stories in {len(files)} journeys, every ID once and in its journey's ranges")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/stories"))
