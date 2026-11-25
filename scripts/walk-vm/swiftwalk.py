"""Shared pieces of the VM's Swift-repo walks (context-grabber, exercise-analyzer, audio-debugger).

Reference code for the walk-the-store skill, not committed into any app repo. The VM climbs only the Linux rung
(`swift test` under Linux Swift) and wasm; everything an XCTest class or `just` recipe needs a Mac for is written
as `skip` with "needs Mac", never left for judge to call missing. A ref that names a class, test, recipe or
script that is nowhere in the tree is written `missing`: the story cites a check that no longer exists.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

WALK = Path.home() / "gits/chop-conventions/.worktrees/walk-store/skills/walk-the-store/walk.py"
HEADING = re.compile(r"^(?:###\s+User Story\s+(\d+)|##\s+(\d+)\s+[—–-]\s+)")
CASE = re.compile(r"^Test Case '(?:[\w.]+\.)?(\w+)[./](\w+)' (passed|failed|skipped)")
SWIFT_TESTING = re.compile(r"Test (\w+)\(\) (passed|failed|skipped)")  # Swift Testing's own lines


def sh(argv, cwd, log: Path, timeout: int, env=None) -> int:
    """One capped stage; past its cap the whole process group is killed and it reads as 124."""
    print("+", " ".join(map(str, argv)), flush=True)
    with log.open("w") as fh:
        p = subprocess.Popen(list(map(str, argv)), cwd=cwd, stdout=fh, stderr=subprocess.STDOUT, env=env,
                             start_new_session=True)
        try:
            rc = p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, 9)
            p.wait()
            fh.write(f"\nWALK: stage killed after {timeout}s\n")
            rc = 124
    print(f"  exit {rc} -> {log}", flush=True)
    return rc


def select_stories(src: Path, dst: Path, whole: list[str], pick) -> list[str]:
    """Copy the stories the walk covers into dst: every story of the `whole` files, and the stories of the other
    files for which pick(text) is true. judge reads a directory, so the selection is a directory of story files."""
    dst.mkdir(parents=True, exist_ok=True)
    for old in dst.glob("*.md"):
        old.unlink()
    taken = []
    for f in sorted(src.glob("*.md")):
        if f.name.lower() == "readme.md":
            continue
        text = f.read_text(encoding="utf-8")
        if any(f.name.startswith(w) for w in whole):
            (dst / f.name).write_text(text, encoding="utf-8")
            taken.append(f.name)
            continue
        blocks, cur = [], None
        for line in text.splitlines(keepends=True):
            if HEADING.match(line):
                cur = [line]
                blocks.append(cur)
            elif line.startswith("#") and not line.startswith("####"):
                cur = None
            elif cur is not None:
                cur.append(line)
        kept = ["".join(b) for b in blocks if pick("".join(b))]
        if kept:
            (dst / f.name).write_text("# Selected for the walk\n\n" + "\n".join(kept), encoding="utf-8")
            taken.append(f"{f.name} ({len(kept)} stories)")
    return taken


def refs(stories: Path, kind: str, manifest: Path | None = None) -> list[str]:
    argv = [sys.executable, str(WALK), "refs", str(stories), "--kind", kind]
    if manifest:
        argv += ["--manifest", str(manifest)]
    return subprocess.run(argv, capture_output=True, text=True, check=True).stdout.split()


def linux_cases(log: Path) -> dict[str, dict]:
    """`Class.test` -> {outcome, detail} from a Linux `swift test` log (XCTest lines and Swift Testing lines)."""
    out: dict[str, dict] = {}
    if not log.exists():
        return out
    lines = log.read_text(errors="replace").splitlines()
    for i, line in enumerate(lines):
        if m := CASE.match(line):
            cls, test, verdict = m.groups()
            detail = ""
            if verdict == "failed":
                # XCTest prints the assertion just above the "failed" line
                detail = " | ".join(l.strip() for l in lines[max(0, i - 3) : i] if "error" in l)[:300]
            out[f"{cls}.{test}"] = {"outcome": {"passed": "pass", "failed": "fail", "skipped": "skip"}[verdict],
                                    "detail": detail}
    return out


CLASS_DEF = re.compile(r"^\s*(?:final\s+|@MainActor\s+|public\s+|private\s+)*(?:class|struct)\s+(\w+Tests)\b", re.M)
FUNC_DEF = re.compile(r"func\s+(test\w+|`[^`]+`)\s*\(")


def source_index(dirs: list[Path]) -> dict[str, dict]:
    """Class name -> {file, methods, apple_only}. A file is Apple-only when it is fenced by #if canImport/#if os."""
    idx: dict[str, dict] = {}
    for d in dirs:
        for f in d.rglob("*.swift"):
            if ".build" in f.parts:
                continue
            src = f.read_text(errors="replace")
            classes = CLASS_DEF.findall(src)
            if f.stem.endswith("Tests") and f.stem not in classes:
                classes.append(f.stem)  # Swift Testing: free @Test functions in MicControllerTests.swift
            if not classes:
                continue
            methods = set(FUNC_DEF.findall(src))
            fenced = bool(re.search(r"^\s*#if\s+!?(canImport|os)\(", src, re.M))
            # a test target cited by name (`BoardWasmTests`) is the classes under Tests/<target>/
            target = next((p for p in f.relative_to(d).parts[:-1] if p.endswith("Tests")), None)
            for c in classes + ([target] if target and target not in classes else []):
                e = idx.setdefault(c, {"files": [], "methods": set(), "apple_only": False, "dir": str(d), "classes": set()})
                e["classes"] |= set(classes)
                e["files"].append(str(f))
                e["methods"] |= methods
                e["apple_only"] |= fenced
    return idx


def xctest_checks(xrefs: list[str], cases: dict[str, dict], idx: dict[str, dict], mac_dirs: set[str],
                  linux_ran: bool, sha: str) -> dict[str, dict]:
    """Every xctest ref the stories name gets a row: the Linux results, else skip (needs Mac), else missing."""
    checks = {f"xctest:{k}": v for k, v in cases.items()}
    ran_classes = {k.split(".", 1)[0] for k in cases}
    for ref in xrefs:
        target = ref.split(":", 1)[1]
        cls, _, test = target.partition(".")
        if ref in checks:
            continue
        e = idx.get(cls)
        members = (e or {}).get("classes", set()) | {cls}
        rows = [v for k, v in cases.items() if k.split(".", 1)[0] in members] if not test else []
        if rows:
            # A class (or target) ref is the worst of ITS Linux cases. Written explicitly, so judge's prefix match
            # never folds in a stale `Class.testGone` row that another story cites.
            order = ["fail", "skip", "flaky", "pass"]
            w = min(rows, key=lambda r: order.index(r["outcome"]))
            bad = sum(1 for r in rows if r["outcome"] == "fail")
            checks[ref] = {"outcome": w["outcome"], "detail": f"{len(rows)} Linux cases" + (f", {bad} failing: {w['detail']}" if bad else "")}
            continue
        if e is None:
            checks[ref] = {"outcome": "missing", "detail": f"no class {cls} in the tree at {sha}"}
        elif test and test not in e["methods"]:
            checks[ref] = {"outcome": "missing", "detail": f"{cls} has no {test} at {sha}"}
        elif e["dir"] in mac_dirs:
            checks[ref] = {"outcome": "skip", "detail": f"needs Mac: {Path(e['files'][0]).parent.name} runs on the simulator"}
        elif e["apple_only"] or not linux_ran:
            checks[ref] = {"outcome": "skip", "detail": "needs Mac: compiled out on Linux (#if canImport/#if os)"
                           if linux_ran else "needs Mac: the Linux rung did not run"}
        else:
            checks[ref] = {"outcome": "missing", "detail": f"{cls}{'.' + test if test else ''} is in the tree but did not run on Linux"}
    return checks


def just_recipes(justfile: Path) -> set[str]:
    names = set()
    for line in justfile.read_text().splitlines():
        # a recipe line: `name [params, defaults may hold = and quotes]: [deps]`; not `name := value`
        if not re.match(r"^[\w-]+\s*:=", line) and (m := re.match(r"^([\w-]+)\b[^#]*?:(?!=)", line)):
            names.add(m.group(1))
        if m := re.match(r"^alias\s+([\w-]+)\s*:=", line):
            names.add(m.group(1))
    return names


def just_checks(jrefs: list[str], recipes: set[str], on_vm: dict[str, dict], sha: str) -> dict[str, dict]:
    out = {}
    for ref in jrefs:
        r = ref.split(":", 1)[1]
        if r not in recipes:
            out[ref] = {"outcome": "missing", "detail": f"no just recipe {r} at {sha}"}
        elif r in on_vm:
            out[ref] = on_vm[r]
        else:
            out[ref] = {"outcome": "skip", "detail": f"needs Mac: just {r} runs on the Mac (xcodebuild/xcrun/simulator)"}
    return out


def git_state(tree: Path) -> tuple[str, bool]:
    sha = subprocess.run(["git", "-C", str(tree), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "-C", str(tree), "status", "--porcelain", "--untracked-files=no"],
                                capture_output=True, text=True).stdout.strip())
    return sha, dirty


def judge(stories: Path, out: Path, manifest: Path | None, previous: Path | None) -> int:
    argv = [sys.executable, str(WALK), "judge", "--stories", str(stories), "--checks", str(out / "checks.json"),
            "--out", str(out)]
    if manifest and manifest.exists():
        argv += ["--manifest", str(manifest)]
    if previous and previous.exists():
        argv += ["--previous", str(previous)]
    return subprocess.run(argv).returncode


def write_checks(out: Path, run: dict) -> None:
    (out / "checks.json").write_text(json.dumps(run, indent=1))
