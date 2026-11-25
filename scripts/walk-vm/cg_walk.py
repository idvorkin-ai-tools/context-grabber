#!/usr/bin/env python3
"""Dry-run `just walk` for context-grabber's whiteboard: the VM's rungs once, checks.json, judge.

Reference runner for the walk-the-store skill. Not committed into context-grabber.

    cg_walk.py --tree <detached upstream/main worktree> --out <dir> [--previous <walk.json>] [--stages ...]

Stories walked: every story of docs/stories/10-whiteboard-*.md, and the board stories of the other journeys (title,
summary or Status names a board, the whiteboard, BoardWasm or the wasm). Stages, -j 2 under nice 19, each capped:
  linux     ContextCore's `swift test` under Linux Swift (ContextCoreTests, BoardCoreTests, BoardWasmTests)
  wasm      scripts/native/test-board-wasm.sh: BoardWasm for WASI, replayed under node (test-board-wasm.mjs)
  boardops  the board-ops harness on the Judge fixture, as test-linux.sh runs it
  scripts   the Linux-portable script checks the board stories name
  retry     each failed XCTest case once, serially (--skip-build --filter)
UI test classes (native/UITests, native/ContractTests), Apple-only units and Mac recipes are written "needs Mac".
"""

import argparse
import datetime as dt
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import swiftwalk as sw  # noqa: E402

HERE = Path(__file__).resolve().parent
LIB = HERE.parent / "swiftlib"
INC = Path.home() / "tmp/agent/skill/swift-deps/root/usr/include"
TOOLCHAIN = Path.home() / ".local/share/swiftly/toolchains/6.4.2/usr/bin"
NICE = ["nice", "-n", "19", "ionice", "-c", "3"]
BOARD = re.compile(r"\b(white)?boards?\b|BoardWasm|\bwasm\b|BoardCore|board-ops", re.I)
# scripts/native checks that need no Mac (test-linux.sh's list, plus the fake Cockpit's own Python checks)
PORTABLE_SCRIPTS = {
    "test-ladder-map.sh", "test-breath-clips.py", "test-ui-timings.sh", "test-ladder-report.sh", "test-smoke-lock.sh",
    "test-linux-imports.sh", "test-build-lane.sh", "test-story-ids.sh", "test-story-commits.sh",
    "test-board-sessions.py", "test-testing-lists.sh", "test-mic-tests.sh", "test-fake-cockpit-ops.py",
    "test-fake-cockpit-session.py", "test-pen-latency.sh",
}
# just recipes the VM climbs, and the stage whose exit code answers for each
VM_RECIPES = {"wasm-test": "wasm", "wasm": "wasm", "board-ops": "boardops", "test-linux": "linux"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--previous", type=Path)
    ap.add_argument("--stages", default="linux,wasm,boardops,scripts,retry")
    a = ap.parse_args()
    tree, out = a.tree.resolve(), a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    stages = set(a.stages.split(",")) if a.stages else set()
    started = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
    sha, dirty = sw.git_state(tree)
    stories = HERE / "stories"
    taken = sw.select_stories(tree / "docs/stories", stories, ["10-whiteboard-"], lambda t: bool(BOARD.search(
        " ".join(l for l in t.splitlines() if re.search(r"^#|\*\*(Summary|Status)", l)))))
    (out / "selection.txt").write_text("\n".join(taken) + "\n")
    env = {**os.environ, "PATH": f"{TOOLCHAIN}:{os.environ['PATH']}", "LD_LIBRARY_PATH": str(LIB),
           "LINUX_LIB_DIR": str(LIB), "JOBS": "2", "WASM_BUILD": str(out / "wasm-build"),
           "WASM_OUT": str(out / "BoardWasm.wasm")}
    core = tree / "native/ContextCore"
    swift_flags = ["-j", "2", "--scratch-path", out / "linux", "-Xlinker", f"-L{LIB}", "-Xcc", f"-I{INC}"]
    rc: dict[str, int] = {}
    for name in ("linux", "wasm", "boardops"):
        f = out / f"{name}.rc"
        if f.exists():
            rc[name] = int(f.read_text())
    if "linux" in stages:
        rc["linux"] = sw.sh(NICE + ["swift", "test", *swift_flags], core, out / "linux-test.log", 3000, env)
    if "wasm" in stages:
        rc["wasm"] = sw.sh(NICE + [tree / "scripts/native/test-board-wasm.sh"], tree, out / "wasm.log", 2400, env)
    if "boardops" in stages:
        fx = "Tests/ContextCoreTests/Fixtures/board-ops"
        r = sw.sh(NICE + ["swift", "run", *swift_flags, "board-ops-harness", "--board", f"{fx}/judge-board.json",
                          "--ops", f"{fx}/judge-ops.json", "--out", out / "board-ops/judge"], core,
                  out / "board-ops.log", 1200, env)
        svg, res = out / "board-ops/judge.svg", out / "board-ops/judge.result.json"
        ok = r == 0 and svg.exists() and "<svg" in svg.read_text() and re.search(r'"action" ?: ?"applied"', res.read_text())
        rc["boardops"] = 0 if ok else (r or 1)
    for k, v in rc.items():
        (out / f"{k}.rc").write_text(str(v))

    cases = sw.linux_cases(out / "linux-test.log")
    failed = sorted(k for k, v in cases.items() if v["outcome"] == "fail")
    if failed:  # a re-judge (--stages "") reads the retry logs an earlier run left
        for k in failed[:20]:
            log = out / f"retry-{k}.log"
            if "retry" in stages:
                sw.sh(NICE + ["swift", "test", "--skip-build", *swift_flags, "--filter", k.replace(".", "/")], core, log, 600, env)
            again = sw.linux_cases(log).get(k)
            if again and again["outcome"] == "pass":
                cases[k] = {"outcome": "flaky", "detail": "failed in the walk, passed a serial retry: " + cases[k]["detail"][:200]}

    idx = sw.source_index([core / "Tests", tree / "native/UITests", tree / "native/ContractTests", tree / "native/BoardLab"])
    mac_dirs = {str(tree / "native/UITests"), str(tree / "native/ContractTests"), str(tree / "native/BoardLab")}
    manifest = HERE / "cg.toml"
    checks = sw.xctest_checks(sw.refs(stories, "xctest", manifest), cases, idx, mac_dirs,
                              rc.get("linux") == 0 and bool(cases), sha)

    def stage_row(stage: str, log: str) -> dict:
        r = rc.get(stage)
        text = (out / log).read_text(errors="replace") if (out / log).exists() else ""
        if r is None:
            return {"outcome": "skip", "detail": f"{stage} stage not run"}
        if stage == "wasm" and "skip board wasm" in text:
            return {"outcome": "skip", "detail": "no wasm Swift SDK on this box"}
        last = [l for l in text.splitlines() if l.startswith(("ok ", "FAIL", "skip"))][-1:] or [f"exit {r}"]
        return {"outcome": "pass" if r == 0 else "fail", "detail": last[0][:300]}

    on_vm = {recipe: stage_row(stage, {"wasm": "wasm.log", "boardops": "board-ops.log", "linux": "linux-test.log"}[stage])
             for recipe, stage in VM_RECIPES.items()}
    # just test-linux is judged on its Linux swift test part, after the retry (a case that passed alone is flaky,
    # not red); its cross-builds and app compile prove nothing per story and are not run here.
    still = [k for k, v in cases.items() if v["outcome"] == "fail"]
    if cases:
        on_vm["test-linux"] = {"outcome": "fail" if still else "pass",
                               "detail": f"Linux swift test only: {len(cases)} cases, {len(still)} failing"
                                         + (f" ({still[0]})" if still else "")}
    checks.update(sw.just_checks(sw.refs(stories, "just", manifest), sw.just_recipes(tree / "justfile"), on_vm, sha))
    for ref in sw.refs(stories, "node", manifest):
        name = Path(ref.split(":", 1)[1]).name
        if name == "test-board-wasm.mjs":
            checks[ref] = on_vm["wasm-test"]
        elif not list(tree.glob(f"scripts/**/{name}")):
            checks[ref] = {"outcome": "missing", "detail": f"{name} is not in the tree at {sha}"}
        else:
            checks[ref] = {"outcome": "skip", "detail": f"{name}: no VM stage runs it"}
    for ref in sw.refs(stories, "script", manifest):
        name = ref.split(":", 1)[1]
        path = tree / "scripts/native" / name
        if not path.exists():
            checks[ref] = {"outcome": "missing", "detail": f"scripts/native/{name} is not in the tree at {sha}"}
        elif name not in PORTABLE_SCRIPTS:
            checks[ref] = {"outcome": "skip", "detail": f"needs Mac: {name} drives xcodebuild, the simulator or Mac tools"}
        elif "scripts" in stages or (out / f"script-{name}.log").exists():
            log = out / f"script-{name}.log"
            r = sw.sh(NICE + [path], tree, log, 300, env) if "scripts" in stages else 0
            text = log.read_text(errors="replace")
            bad = [l for l in text.splitlines() if l.startswith(("FAIL", "not ok"))]
            checks[ref] = {"outcome": "pass" if r == 0 else "fail", "detail": (bad[:1] or [f"exit {r}"])[0][:300]}
        else:
            checks[ref] = {"outcome": "skip", "detail": "scripts stage not run"}

    run = {"repo": "context-grabber-whiteboard", "sha": sha, "dirty": dirty, "started": started,
           "finished": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
           "kinds": ["xctest", "just", "node", "script"], "checks": checks,
           "stages": rc, "linux_cases": len(cases)}
    sw.write_checks(out, run)
    jrc = sw.judge(stories, out, manifest, a.previous)
    if rc.get("linux") not in (0, None) and not cases:
        print(f"WALK COULD NOT RUN: Linux swift test exit {rc.get('linux')} with no results")
        return 2
    return jrc


if __name__ == "__main__":
    sys.exit(main())
