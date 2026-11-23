#!/usr/bin/env python3
"""Bead context-grabber-wm8y: the UI tests that open the mic, which a locked Mac crashes (stories 1022, 1023).

scripts/native/mic-tests.txt holds every UI test that touches a mic control or a call, one a line:
  mic <Target>/<Class>/<test>       it opens the mic, or a real call's audio input: skipped on a locked Mac
  reviewed <Class>/<test>           it touches a mic control but never opens the mic (a check of a button, a
                                    faked hearing, a synthetic call): it runs on a locked Mac
each with a `# why`. `check` fails when a UI test touches a mic control (itself, or through a helper in its file) and
isn't on the list, or when a listed test no longer exists, so a new mic test can't slip onto a locked Mac.
`list` prints the mic lines' ids, for xcodebuild's -skip-testing.

Usage: mic-tests.py check|list [--list FILE] [--tests DIR]
"""
import argparse
import pathlib
import re
import sys

# What a test that may open the mic touches: the mic buttons and menus, the voice button, dictation's states, a call.
MARKERS = [
    "inbox-add-voice", "Speak a message", "Stop recording", "Find microphones", "Microphone: ", "Talk to Claude",
    "whiteboard-mic", "report-dictate", "decision-other-mic", "whiteboard-question-mic", "-mic\"",
    "GRABBER_CALL\"", "GRABBER_CALL_AUDIO", "call-larry", "☎", "Hang up",
]
FUNC = re.compile(r"^  (?:private |fileprivate |static |@MainActor )*func (\w+)\s*\(", re.M)


def functions(src):
    """name -> body, for the functions at a class's top level (two-space indent), each to the next one."""
    marks = list(FUNC.finditer(src))
    out = {}
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(src)
        out[m.group(1)] = src[m.start():end]
    return out


def candidates(tests_dir):
    """(Class, test) for every test that touches a marker, itself or through a helper of its file it calls."""
    found = set()
    for path in sorted(pathlib.Path(tests_dir).glob("*.swift")):
        src = path.read_text()
        cls = re.search(r"class (\w+)\s*:\s*XCTestCase", src)
        if not cls:
            continue
        funcs = functions(src)
        touchy = {n for n, b in funcs.items() if any(k in b for k in MARKERS)}
        for name, body in funcs.items():
            if not name.startswith("test"):
                continue
            calls = {h for h in touchy if h != name and re.search(r"\b%s\(" % re.escape(h), body)}
            if name in touchy or calls:
                found.add((cls.group(1), name))
    return found


def read_list(path):
    entries = []
    for n, line in enumerate(pathlib.Path(path).read_text().splitlines(), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        kind, _, ident = line.partition(" ")
        ident = ident.strip()
        if kind not in ("mic", "reviewed") or not ident:
            sys.exit(f"{path}:{n}: expected 'mic <Target>/<Class>/<test>' or 'reviewed <Class>/<test>': {line}")
        parts = ident.split("/")
        if kind == "mic" and len(parts) != 3:
            sys.exit(f"{path}:{n}: a mic line names its test target too: <Target>/<Class>/<test>: {ident}")
        entries.append((kind, ident, tuple(parts[-2:]), n))
    return entries


def main():
    here = pathlib.Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["check", "list"])
    ap.add_argument("--list", default=str(here / "mic-tests.txt"))
    ap.add_argument("--tests", default=str(here.parent.parent / "native" / "UITests"))
    a = ap.parse_args()
    entries = read_list(a.list)
    if a.cmd == "list":
        for kind, ident, _, _ in entries:
            if kind == "mic":
                print(ident)
        return 0
    found = candidates(a.tests)
    listed = {key for _, _, key, _ in entries}
    every = set()
    for path in pathlib.Path(a.tests).glob("*.swift"):
        src = path.read_text()
        cls = re.search(r"class (\w+)\s*:\s*XCTestCase", src)
        if cls:
            every |= {(cls.group(1), n) for n in functions(src) if n.startswith("test")}
    bad = 0
    for cls, test in sorted(found - listed):
        print(f"FAIL {cls}/{test} touches a mic control or a call and isn't in {a.list}: read it, then list it as "
              "'mic <Target>/<Class>/<test>' (it opens the mic; skipped on a locked Mac) or 'reviewed <Class>/<test>' "
              "(it doesn't)")
        bad = 1
    for kind, ident, key, n in entries:
        if key not in every:
            print(f"FAIL {a.list}:{n}: {ident} is no UI test any more")
            bad = 1
    if not bad:
        mics = sum(1 for e in entries if e[0] == "mic")
        print(f"ok   every UI test that touches a mic control or a call is listed ({mics} open the mic, "
              f"{len(entries) - mics} reviewed)")
    return bad


if __name__ == "__main__":
    sys.exit(main())
