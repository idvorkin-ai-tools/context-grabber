#!/usr/bin/env python3
"""Check story commit links against the commits reachable from HEAD.

A rebase can leave the old commit object in Git even though it is no longer in
the branch's history. The host check is documented in docs/TESTING.md.

Usage: story-commits.py [stories-dir]   (default docs/stories)
"""

import os
import re
import subprocess
import sys

LINK = re.compile(r"github\.com/idvorkin/context-grabber/commit/([0-9a-fA-F]{7,40})\b")


def git(*args, cwd):
    return subprocess.run(
        ["git", *args], cwd=cwd, capture_output=True, text=True, check=True
    ).stdout


def main(root):
    repo = git("rev-parse", "--show-toplevel", cwd=root).strip()
    shallow = git("rev-parse", "--is-shallow-repository", cwd=repo).strip() == "true"
    missing = (
        "which is not in this checkout's available history"
        if shallow
        else "which is not in this branch's history (a sha from before a rebase? name the commit as it is on the branch)"
    )
    by_prefix = {}
    for sha in git("rev-list", "HEAD", cwd=repo).split():
        by_prefix.setdefault(sha[:7], []).append(sha)
    problems = []
    links = 0
    for name in sorted(os.listdir(root)):
        if not name.endswith(".md"):
            continue
        with open(os.path.join(root, name), encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                for linked_sha in LINK.findall(line):
                    links += 1
                    sha = linked_sha.lower()
                    if any(h.startswith(sha) for h in by_prefix.get(sha[:7], ())):
                        continue
                    problems.append(
                        f"FAIL {name}:{n}: links commit {linked_sha}, {missing}"
                    )
    for p in problems:
        print(p)
    if problems:
        if shallow:
            print(
                "story-commits: this clone is shallow. Fetch the full history (git fetch --unshallow) and rerun."
            )
        return 1
    print(f"story-commits: {links} commit links, every one in this branch's history")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/stories"))
