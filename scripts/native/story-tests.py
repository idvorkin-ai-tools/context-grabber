#!/usr/bin/env python3
"""Check that the tests a story's Status line names still exist in native/.

A Status line says where a story was verified, e.g. `WhiteboardTurnUITests.testGhostsOffAsksNothing`.
When a test class is renamed, merged or deleted, the story silently points at nothing (27 whiteboard
stories did on 2026-11-24). This check names every such citation.

A citation is a backticked token on a `**Status:**` line that is:
  - a test class: an identifier ending in Tests (`WhiteboardTurnUITests`)
  - a class and method: `Class.testMethod` or `Class/testMethod`
  - a bare method: `testMethod`
A test in another repo is written with its repo first, `bug-kit:WhatsNewTests` or
`think-a-card-trainer:LookalikeTests.testX`, and is not looked for here. A test target's own folder name
(`BoardWasmTests`) counts as its class.
The class must be declared (class/struct/extension) somewhere under native/, or be the name of a test
file there; the method must be a `func` in a file that declares, extends or is named for that class
(any file for a bare method).

Usage: story-tests.py [stories-dir] [source-dir]   (defaults docs/stories, native)
Exit 1 and one line per stale citation when any is found.
"""

import os
import re
import sys

STATUS = re.compile(r"\*\*Status:\*\*")
TICK = re.compile(r"`([^`]+)`")
EXTERNAL = re.compile(r"^[a-z][a-z0-9-]*:[A-Z]")
CLASS_TOKEN = re.compile(r"^[A-Z]\w*Tests$")
PAIR_TOKEN = re.compile(r"^([A-Z]\w*Tests)[./](\w+)\(?\)?$")
METHOD_TOKEN = re.compile(r"^(test\w+)\(?\)?$")
DECL = re.compile(r"\b(?:class|struct|extension|enum)\s+([A-Z]\w*Tests)\b")
FUNC = re.compile(r"\bfunc\s+(\w+)\s*\(")


def index(source):
    methods_of = {}
    every_method = set()
    for root, dirs, files in os.walk(source):
        dirs[:] = [d for d in dirs if d not in (".build", "Build", "DerivedData")]
        for d in dirs:
            if d.endswith("Tests"):
                methods_of.setdefault(d, set())
        for name in files:
            if not name.endswith(".swift"):
                continue
            with open(os.path.join(root, name), encoding="utf-8", errors="replace") as f:
                text = f.read()
            classes = set(DECL.findall(text))
            funcs = set(FUNC.findall(text))
            every_method |= funcs
            # A story may name the test file (CallSessionTests) rather than a class inside it.
            stem = name[: -len(".swift")]
            if stem.endswith("Tests"):
                classes.add(stem)
            for c in classes:
                methods_of.setdefault(c, set()).update(funcs)
    return methods_of, every_method


def main(stories, source):
    methods_of, every_method = index(source)
    problems = []
    cited = 0
    for name in sorted(os.listdir(stories)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(stories, name)
        with open(path, encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                if not STATUS.search(line):
                    continue
                for token in TICK.findall(line):
                    token = token.strip()
                    if EXTERNAL.match(token):
                        continue
                    pair = PAIR_TOKEN.match(token)
                    if pair:
                        cited += 1
                        cls, method = pair.groups()
                        if cls not in methods_of:
                            problems.append(f"{path}:{n}: `{token}`: no test class {cls} in {source}")
                        elif method not in methods_of[cls]:
                            problems.append(f"{path}:{n}: `{token}`: {cls} has no {method}")
                    elif CLASS_TOKEN.match(token):
                        cited += 1
                        if token not in methods_of:
                            problems.append(f"{path}:{n}: `{token}`: no test class {token} in {source}")
                    elif METHOD_TOKEN.match(token):
                        cited += 1
                        method = METHOD_TOKEN.match(token).group(1)
                        if method not in every_method:
                            problems.append(f"{path}:{n}: `{token}`: no test method {method} in {source}")
    for p in problems:
        print(p)
    if problems:
        print(f"story-tests: {len(problems)} of {cited} cited tests are gone; point each Status at the test that covers it now")
        return 1
    print(f"story-tests: all {cited} cited tests exist")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    sys.exit(main(args[0] if args else "docs/stories", args[1] if len(args) > 1 else "native"))
