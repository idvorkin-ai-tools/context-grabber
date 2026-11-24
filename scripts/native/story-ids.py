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

       story-ids.py reserve <journey> [n] [--dir stories-dir]   (story 791, bead context-grabber-jg3w)
Hands out the next n free IDs (one by default) in a journey's ranges, one per line on stdout and nothing else.
<journey> is one of its story files or a word from its row ("building", "whiteboard"). An ID is
free when it is in none of: the stories on the shared remote's main (fetched first), the stories in stories-dir, the story
headings an open PR adds (gh pr diff; for a PR whose diff gh refuses as too large, each story file's patch from its
file list, or the whole file on its head; a PR none of that can read is named in a warning and skipped, bead
context-grabber-1338), and the reservations in the shared ledger that are under 24 hours old and not yet on main.

The shared ledger (bead context-grabber-py4h) is ledger.json in the commit refs/story-ids/ledger points at on the remote whose
URL is github.com/idvorkin/context-grabber (picked by URL, since on the Linux lane origin is a fork), so every
machine sees every reservation. On one machine reservations take a lock one after the other; across machines the
ledger is written by a plain push of a commit on top of the one read, which the remote refuses if another machine
pushed in between; then it reads the ledger again and picks again, up to five times. Never a forced push, and
nothing else on the remote is touched. Main is read from that same remote.
Fails, handing out nothing, when main can't be fetched, the open PRs can't be listed, or the shared ledger can't be
read or written.
Overrides, for the tests: STORY_IDS_REMOTE (the remote, a name or a path, instead of the one found by URL),
STORY_IDS_REPO (the repository git runs in, default the stories dir's), STORY_IDS_LOCK (default
~/tmp/agent/locks/story-ids.lock), STORY_IDS_GH (the gh command), STORY_IDS_MAIN (a stories dir read as main instead
of the remote's main), STORY_IDS_NOW (epoch seconds), STORY_IDS_BRANCH (the branch the ledger records),
STORY_IDS_HOLD (seconds to wait between reading the ledger and writing it, so the race tests overlap).
"""
import fcntl
import json
import os
import re
import shlex
import subprocess
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

HEADING = re.compile(r"^### User Story (\d+):")
LINK = re.compile(r"\]\(([^)#]+\.md)\)")
SPAN = re.compile(r"^(\d+)(?:\s*[–-]\s*(\d+))?$")
UPSTREAM = re.compile(r"github\.com[:/]+idvorkin/context-grabber(\.git)?/?$")
LEDGER_REF = "refs/story-ids/ledger"
TRIES = 5


def fmt(spans):
    return ", ".join(str(a) if a == b else f"{a}–{b}" for a, b in spans)


def table(root, problems, text=None):
    """The journey table: (journey -> spans, file -> journey, journey -> its row but the IDs column, journey -> its name)."""
    ranges = {}  # journey (its first file) -> spans
    journey = {}  # file -> its journey
    titles = {}  # journey -> its row but the IDs column, for reserve's journey words
    labels = {}  # journey -> its name as its row gives it ("The whiteboard"), for reserve's messages
    if text is None:
        with open(os.path.join(root, "README.md"), encoding="utf-8") as fh:
            text = fh.read()
    for n, line in enumerate(text.splitlines(), 1):
        line = line.rstrip("\n").strip()
        if not (line.startswith("|") and line.endswith("|")):
            continue
        cells = [c.strip() for c in line[1:-1].split("|")]
        files = LINK.findall(cells[0]) if len(cells) >= 2 else []
        if not files:
            continue
        name, column = files[0], cells[-1]
        titles[name] = " ".join(cells[:-1])
        labels[name] = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", cells[0]).split(":")[0].strip()
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
    return ranges, journey, titles, labels


def main(root):
    problems = []
    readme = os.path.join(root, "README.md")
    if not os.path.isfile(readme):
        print(f"FAIL no {readme}")
        return 1
    ranges, journey, _, _ = table(root, problems)

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


def repo_of(root):
    return os.environ.get("STORY_IDS_REPO") or run(["git", "rev-parse", "--show-toplevel"], cwd=root).strip()


def shared_remote(repo):
    """The remote holding main and the shared ledger: STORY_IDS_REMOTE, else the one whose URL is
    github.com/idvorkin/context-grabber (on the Linux lane origin is a fork; Larry, 2026-11-24)."""
    if os.environ.get("STORY_IDS_REMOTE"):
        return os.environ["STORY_IDS_REMOTE"]
    for line in run(["git", "remote", "-v"], cwd=repo).splitlines():
        parts = line.split()
        if len(parts) >= 2 and UPSTREAM.search(parts[1]):
            return parts[0]
    raise RuntimeError("no git remote points at github.com/idvorkin/context-grabber, which holds main and the shared "
                       "story ID ledger; add one: git remote add upstream https://github.com/idvorkin/context-grabber.git")


def main_ids(root):
    """The story IDs and the journey table on main: the shared remote's main fetched now, or STORY_IDS_MAIN's dir for
    the tests."""
    fake = os.environ.get("STORY_IDS_MAIN")
    if fake:
        with open(os.path.join(fake, "README.md"), encoding="utf-8") as fh:
            return tree_ids(fake), fh.read()
    top = run(["git", "rev-parse", "--show-toplevel"], cwd=root).strip()
    rel = os.path.relpath(os.path.realpath(root), os.path.realpath(top))
    remote = shared_remote(repo_of(root))
    head = run(["git", "ls-remote", remote, "refs/heads/main"], cwd=top).split()[0]
    run(["git", "fetch", "-q", remote, "main"], cwd=top)
    names = run(["git", "ls-tree", "--name-only", head, rel + "/"], cwd=top).split()
    texts = [run(["git", "show", f"{head}:{n}"], cwd=top) for n in names if n.endswith(".md") and not n.endswith("README.md")]
    return ids_in(texts), run(["git", "show", f"{head}:{rel}/README.md"], cwd=top)


def read_ledger(repo, remote):
    """(the commit refs/story-ids points at on the remote or None, its reservations)."""
    try:
        listed = run(["git", "ls-remote", remote, LEDGER_REF], cwd=repo).split()
        if not listed:
            return None, []
        head = listed[0]
        run(["git", "fetch", "-q", remote, LEDGER_REF], cwd=repo)
        return head, json.loads(run(["git", "show", f"{head}:ledger.json"], cwd=repo)).get("reservations", [])
    except (RuntimeError, ValueError) as e:
        raise RuntimeError(f"can't read the shared ledger {LEDGER_REF} on {remote}: {e}") from e


def write_ledger(repo, remote, parent, reservations, message):
    """Pushes the ledger as a commit on top of parent; False when the remote refuses it because another machine wrote
    the ledger in between (never forced). Fails on anything else."""
    text = json.dumps({"reservations": reservations}, indent=1) + "\n"
    try:
        blob = subprocess.run(["git", "hash-object", "-w", "--stdin"], cwd=repo, input=text, capture_output=True,
                              text=True, check=True).stdout.strip()
        tree = subprocess.run(["git", "mktree"], cwd=repo, input=f"100644 blob {blob}\tledger.json\n", capture_output=True,
                              text=True, check=True).stdout.strip()
        ident = ["-c", "user.name=story-ids", "-c", "user.email=story-ids@invalid"]
        # A random token makes each attempt's commit its own: two machines writing the same ledger on the same parent in
        # the same second would otherwise make one commit, and the second push would pass as already up to date.
        message += f"\n\ntoken {uuid.uuid4().hex}"
        commit = run(["git"] + ident + ["commit-tree", tree] + (["-p", parent] if parent else []) + ["-m", message], cwd=repo).strip()
    except (RuntimeError, subprocess.CalledProcessError) as e:
        raise RuntimeError(f"can't write the shared ledger: {e}") from e
    r = subprocess.run(["git", "push", "-q", remote, f"{commit}:{LEDGER_REF}"], cwd=repo, capture_output=True, text=True)
    if r.returncode == 0:
        return True
    err = (r.stderr or r.stdout).strip()
    # Lost the race (non-fast-forward, or the remote's ref lock taken by the other push) when the ledger moved since it
    # was read; anything else (no access, no network) is a failure, not a retry.
    now_at = subprocess.run(["git", "ls-remote", remote, LEDGER_REF], cwd=repo, capture_output=True, text=True)
    if now_at.returncode == 0 and (now_at.stdout.split() or [None])[0] != parent:
        return False
    raise RuntimeError(f"can't write the shared ledger {LEDGER_REF} on {remote}: {err[:300]}")


def is_story(path):
    return path.endswith(".md") and "stories/" in path and not path.endswith("README.md")


def pr_files_ids(gh, number):
    """A PR's story IDs when gh refuses its whole diff (too large; bead context-grabber-1338): each story file's own
    patch from the PR's file list, and for a story file whose patch GitHub leaves out (itself too large), every heading
    in that file as it is on the PR's head, which can only take more IDs than the PR adds, never fewer."""
    listed = run(gh + ["api", "--paginate", f"repos/{{owner}}/{{repo}}/pulls/{number}/files?per_page=100",
                       "--jq", ".[] | {f: .filename, p: .patch}"])
    lines = [line for line in listed.splitlines() if line.strip()]
    pr = json.loads(run(gh + ["pr", "view", str(number), "--json", "changedFiles,headRefOid"]))
    if len(lines) != pr["changedFiles"]:
        raise RuntimeError(f"its file list gives {len(lines)} of its {pr['changedFiles']} changed files")
    ids, whole = set(), []
    for line in lines:
        entry = json.loads(line)
        if not is_story(entry.get("f") or ""):
            continue
        if entry.get("p"):
            ids |= {int(i) for i in ADDED.findall(entry["p"])}
        else:
            whole.append(entry["f"])
    for f in whole:
        ids |= ids_in([run(gh + ["api", "-H", "Accept: application/vnd.github.raw",
                                 f"repos/{{owner}}/{{repo}}/contents/{f}?ref={pr['headRefOid']}"])])
    return ids


def one_pr_ids(gh, number):
    """(IDs, None) for one open PR, or (set(), why) when neither its diff nor its files can be read."""
    try:
        return {int(i) for i in ADDED.findall(run(gh + ["pr", "diff", str(number)]))}, None
    except RuntimeError as diff_error:
        try:
            return pr_files_ids(gh, number), None
        except (RuntimeError, ValueError, KeyError) as files_error:
            return set(), f"diff: {diff_error}; files: {files_error}"


def gh_cmd():
    return shlex.split(os.environ.get("STORY_IDS_GH", "gh"))


def pr_id_map(who="reserve"):
    """{PR number: the story IDs it adds} for every open PR (from any machine). One PR that can't be read at all is
    named in a warning and skipped, so it can't block every reservation (bead context-grabber-1338); the listing itself
    failing still fails."""
    gh = gh_cmd()
    prs = json.loads(run(gh + ["pr", "list", "--state", "open", "--limit", "500", "--json", "number"]))
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(lambda p: one_pr_ids(gh, p["number"]), prs))
    got_by = {}
    for p, (got, why) in zip(prs, results):
        got_by[p["number"]] = got
        if why:
            print(f"WARN {who}: open PR #{p['number']} could not be read, so the IDs it adds are not known and "
                  f"may be handed out again; check it by hand ({why})", file=sys.stderr)
    return got_by


def pr_ids():
    """The story IDs every open PR adds, and how many open PRs there are."""
    got_by = pr_id_map()
    return set().union(*got_by.values()) if got_by else set(), len(got_by)


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


def full(root, name, n, have, ranges, labels, busy, main_ranges):
    """Why a journey can't give n IDs, and how to extend it (bead context-grabber-0e04)."""
    top = max([b for rs in (ranges, main_ranges) for spans in rs.values() for _, b in spans] + list(busy))
    start = (top // 100 + 1) * 100 if top % 100 else top + 1
    free = ", ".join(f"{labels[j]} {sum(1 for a, b in ranges[j] for i in range(a, b + 1) if i not in busy)}"
                     for j in sorted(ranges, key=lambda j: min(a for a, _ in ranges[j])))
    return (f"the journey {labels[name]!r} ({name}) has {have} free ID(s) of the {n} asked for in its IDs "
            f"({fmt(ranges[name])}). To extend it, add the next unused block, {start}–{start + 99} (above every journey's "
            f"IDs; a quiet journey can take twenty), to the end of its row's IDs column in {os.path.join(root, 'README.md')}, "
            f"then reserve again. Free IDs per journey: {free}")


def reserve(root, query, n):
    problems = []
    ranges, journey, titles, labels = table(root, problems)
    name = find_journey(query, ranges, journey, titles)
    on_main, main_readme = main_ids(root)
    main_ranges = table(root, [], main_readme)[0]
    in_prs, n_prs = pr_ids()
    taken = on_main | in_prs | tree_ids(root)
    repo = repo_of(root)
    remote = shared_remote(repo)
    now = float(os.environ.get("STORY_IDS_NOW") or time.time())
    branch = os.environ.get("STORY_IDS_BRANCH")
    if branch is None:
        r = subprocess.run(["git", "branch", "--show-current"], cwd=root, capture_output=True, text=True)
        branch = r.stdout.strip() or "?"
    lock_path = os.path.expanduser(os.environ.get("STORY_IDS_LOCK", "~/tmp/agent/locks/story-ids.lock"))
    os.makedirs(os.path.dirname(lock_path), exist_ok=True)
    # On this machine, one reservation at a time; across machines, the push refuses a ledger another machine changed.
    with open(lock_path, "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for _ in range(TRIES):
            parent, held = read_ledger(repo, remote)
            time.sleep(float(os.environ.get("STORY_IDS_HOLD", "0")))  # the race tests widen the window the push guards
            live = [r for r in held if now - r["at"] < DAY and r["id"] not in on_main]
            busy = taken | {r["id"] for r in live}
            got = []
            for a, b in ranges[name]:
                for i in range(a, b + 1):
                    if len(got) < n and i not in busy:
                        got.append(i)
            if len(got) < n:
                raise RuntimeError(full(root, name, n, len(got), ranges, labels, busy, main_ranges))
            live += [{"id": i, "journey": name, "branch": branch, "at": now,
                      "until": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now + DAY))} for i in got]
            if write_ledger(repo, remote, parent, live, f"reserve {', '.join(map(str, got))} in {name} for {branch}"):
                break
        else:
            raise RuntimeError(f"the shared ledger {LEDGER_REF} on {remote} changed under each of {TRIES} tries; reserve again")
    for i in got:
        print(i)
    print(f"reserved {', '.join(map(str, got))} in {name} for {branch} for 24 h (main, {n_prs} open PR(s) and the shared "
          f"ledger {LEDGER_REF} on {remote} checked)", file=sys.stderr)
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


def main_head(root):
    """The commit main is at on the shared remote, fetched (or STORY_IDS_BASE, a ref in the repository, for the tests)."""
    base = os.environ.get("STORY_IDS_BASE")
    repo = repo_of(root)
    if base:
        return run(["git", "rev-parse", base], cwd=repo).strip()
    remote = shared_remote(repo)
    head = run(["git", "ls-remote", remote, "refs/heads/main"], cwd=repo).split()[0]
    run(["git", "fetch", "-q", remote, "main"], cwd=repo)
    return head


def claimed(root):
    """Story 1515, bead context-grabber-6p52: every story ID this tree adds over main that another open PR adds too.
    The branch's own PR is the open PR sharing a commit subject with the branch's commits over main (the pipeline's
    worktree is on no branch, and its rebase changes the commits but not their subjects)."""
    on_main = main_ids(root)[0]
    new = sorted(tree_ids(root) - on_main)
    got_by = pr_id_map("claimed")
    clashes = {n: [pr for pr, ids in got_by.items() if n in ids] for n in new}
    if any(clashes.values()):
        repo = repo_of(root)
        mine = set(run(["git", "log", "--no-merges", "--format=%s", f"{main_head(root)}..HEAD"], cwd=repo).splitlines())
        gh = gh_cmd()
        info = {}
        for pr in sorted({pr for prs in clashes.values() for pr in prs}):
            view = json.loads(run(gh + ["pr", "view", str(pr), "--json", "headRefName,commits"]))
            subjects = {c.get("messageHeadline", "") for c in view.get("commits") or []
                        if not c.get("messageHeadline", "").startswith("Merge ")}
            info[pr] = (view.get("headRefName") or "?", bool(subjects & mine))
        failed = False
        for n, prs in clashes.items():
            for pr in prs:
                branch, ours = info[pr]
                if not ours:
                    failed = True
                    print(f"FAIL claimed: story {n} is also added by open PR #{pr} (branch {branch}); take a new ID with "
                          f"scripts/native/story-ids.py reserve <journey> and renumber this branch's story")
        if failed:
            return 1
    word = "ID" if len(new) == 1 else "IDs"
    listed = f" ({', '.join(map(str, new))})" if new else ""
    print(f"ok   claimed: {len(new)} new story {word}{listed}, none added by another open PR ({len(got_by)} open)")
    return 0


def claimed_cli(args):
    root = "docs/stories"
    if "--dir" in args:
        k = args.index("--dir")
        root = args[k + 1]
        args = args[:k] + args[k + 2:]
    if args:
        print("usage: story-ids.py claimed [--dir stories-dir]", file=sys.stderr)
        return 2
    try:
        return claimed(root)
    except (RuntimeError, OSError, ValueError, KeyError, IndexError) as e:
        print(f"FAIL claimed: {e}")
        return 1


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "reserve":
        sys.exit(reserve_cli(sys.argv[2:]))
    if len(sys.argv) > 1 and sys.argv[1] == "claimed":
        sys.exit(claimed_cli(sys.argv[2:]))
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/stories"))
