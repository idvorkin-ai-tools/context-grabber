#!/usr/bin/env python3
"""Every commit a story links is in this branch's history (beads context-grabber-t309, context-grabber-lldg).

A story's Status names the commit that built it, as a link to github.com/idvorkin/context-grabber/commit/<sha>. The
pipeline rebases a branch before it merges, so a sha written before the rebase names a commit that never reaches main:
the link 404s once the branch is gone, and the story no longer says where its change is. Fails, naming each file, line
and sha, when a linked sha is not the prefix of any commit reachable from HEAD (main's history plus this branch's own
commits, so a story may name a commit made on the branch it is on).

Usage: story-commits.py [stories-dir]   (default docs/stories)
A shallow clone, whose history is cut short, is not checked: it says so and passes.
"""
import os
import re
import subprocess
import sys

LINK = re.compile(r"github\.com/idvorkin/context-grabber/commit/([0-9a-f]{7,40})\b")


def git(*args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout


def main(root):
    repo = git("rev-parse", "--show-toplevel", cwd=root).strip()
    if git("rev-parse", "--is-shallow-repository", cwd=repo).strip() == "true":
        print("story-commits: a shallow clone, so the linked commits are not checked")
        return 0
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
                for sha in LINK.findall(line):
                    links += 1
                    if any(h.startswith(sha) for h in by_prefix.get(sha[:7], ())):
                        continue
                    problems.append(f"FAIL {name}:{n}: links commit {sha}, which is not in this branch's history"
                                    " (a sha from before a rebase? name the commit as it is on the branch)")
    for p in problems:
        print(p)
    if problems:
        return 1
    print(f"story-commits: {links} commit links, every one in this branch's history")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/stories"))
