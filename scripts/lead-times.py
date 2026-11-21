#!/usr/bin/env python3
"""How long does a change take? Lead times for idvorkin/context-grabber's merged PRs (story 828).

Writes data.json and index.html to LEAD_TIMES_OUT (default ~/tmp/agent/notes/lead-times). Stdlib only;
needs `gh` (authed) and this checkout (only `git fetch` and `merge-base` run in it). Reads the deploys
ledger at LEAD_TIMES_DEPLOYS (default ~/tmp/agent/notes/lead-times/deploys.jsonl) and test-ladder logs,
`*ladder*.log`, in LEAD_TIMES_LADDER_LOGS (default ~/tmp/agent/notes).

    just lead-times                  # last ~120 merged PRs
    scripts/lead-times.py --count 60
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

REPO_OWNER, REPO_NAME = "idvorkin", "context-grabber"
CLONE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # this checkout
OUT = os.path.expanduser(os.environ.get("LEAD_TIMES_OUT", "~/tmp/agent/notes/lead-times"))
NOTES = os.path.expanduser(os.environ.get("LEAD_TIMES_LADDER_LOGS", "~/tmp/agent/notes"))
DEPLOYS = os.path.expanduser(os.environ.get("LEAD_TIMES_DEPLOYS", "~/tmp/agent/notes/lead-times/deploys.jsonl"))
SCREEN_DIRS = ("native/App/", "native/UITests/", "native/Widgets/", "native/Share/")
PAGE = 30
SLEPT_S = 3000  # a single rung over this was a slept or hung Mac, not a real run
DEPLOY_LOG_START = "2026-11-14"
ON_DEVICE = {"cable", "testflight_available"}  # the deploys ledger's kinds that put a build on a device (#1038)


def gql(query, **variables):
    args = ["gh", "api", "graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        if v is not None:
            args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    p = subprocess.run(args, capture_output=True, text=True)
    try:
        out = json.loads(p.stdout)
    except json.JSONDecodeError:
        sys.exit(f"gh api graphql failed: {p.stderr.strip()}")
    if "data" not in out or out["data"] is None:
        sys.exit(f"gh api graphql returned no data: {p.stderr.strip()} {out.get('errors')}")
    return out["data"]  # partial errors (e.g. a missing issue number) are tolerated


PRS_Q = """
query($n:Int!,$after:String){repository(owner:"%s",name:"%s"){
 pullRequests(states:MERGED,first:$n,after:$after,orderBy:{field:CREATED_AT,direction:DESC}){
  pageInfo{hasNextPage endCursor}
  nodes{number title body createdAt mergedAt author{login} mergeCommit{oid}
   commits(first:100){totalCount nodes{commit{authoredDate committedDate}}}}}}}
""" % (REPO_OWNER, REPO_NAME)

# Files are a separate query: commits AND files for 30 PRs in one call trips GitHub's node limit.
FILES_Q = """
query($n:Int!,$after:String){repository(owner:"%s",name:"%s"){
 pullRequests(states:MERGED,first:$n,after:$after,orderBy:{field:CREATED_AT,direction:DESC}){
  nodes{number files(first:100){totalCount nodes{path}}}}}}
""" % (REPO_OWNER, REPO_NAME)


def fetch_prs(count):
    prs, after = [], None
    while len(prs) < count:
        n = min(PAGE, count - len(prs))
        page = gql(PRS_Q, n=n, after=after)["repository"]["pullRequests"]
        files = gql(FILES_Q, n=n, after=after)["repository"]["pullRequests"]["nodes"]
        by_num = {f["number"]: f["files"] for f in files}
        for node in page["nodes"]:
            node["files"] = by_num.get(node["number"]) or {"totalCount": 0, "nodes": []}
            prs.append(node)
        print(f"  fetched {len(prs)} PRs", file=sys.stderr)
        if not page["pageInfo"]["hasNextPage"]:
            break
        after = page["pageInfo"]["endCursor"]
    return prs


REF_RE = re.compile(r"(?<![\w/&])#(\d{1,5})\b")


def lookup_issues(numbers, cache):
    """number -> createdAt for issues; None for PRs or missing numbers. Batched by alias."""
    todo = sorted(n for n in numbers if n not in cache)
    for i in range(0, len(todo), 50):
        chunk = todo[i : i + 50]
        fields = " ".join(
            f"i{n}:issueOrPullRequest(number:{n}){{__typename ... on Issue{{createdAt}}}}" for n in chunk
        )
        data = gql('query{repository(owner:"%s",name:"%s"){%s}}' % (REPO_OWNER, REPO_NAME, fields))
        repo = data["repository"] or {}
        for n in chunk:
            node = repo.get(f"i{n}")
            cache[n] = node["createdAt"] if node and node.get("__typename") == "Issue" else None
    return cache


def parse_t(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def iso(dt):
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def minutes(a, b):
    a, b = parse_t(a), parse_t(b)
    return round((b - a).total_seconds() / 60, 1) if a and b else None


def load_deploys():
    if not os.path.exists(DEPLOYS):
        return []
    out = []
    with open(DEPLOYS) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return sorted(out, key=lambda d: d.get("at", ""))


def is_ancestor(anc, desc, cache):
    key = (anc, desc)
    if key not in cache:
        r = subprocess.run(["git", "-C", CLONE, "merge-base", "--is-ancestor", anc, desc], capture_output=True)
        cache[key] = r.returncode == 0
    return cache[key]


def on_device(merge_oid, merged_at, deploys, anc_cache):
    if not merge_oid:
        return None, None
    for d in deploys:
        # #1038: an upload to TestFlight is not on a device until TestFlight offers it (testflight_available).
        if d.get("at", "") < merged_at or d.get("kind", "cable") not in ON_DEVICE:
            continue
        if is_ancestor(merge_oid, d["sha"], anc_cache):
            return d["at"], d.get("device")
    return None, None


def uploaded(merge_oid, merged_at, deploys, anc_cache):
    """When a TestFlight upload first carried the merge, apart from when a device had it (#1038)."""
    for d in deploys:
        if d.get("kind") == "testflight_upload" and d.get("at", "") >= merged_at and merge_oid and is_ancestor(merge_oid, d["sha"], anc_cache):
            return d["at"]
    return None


LADDER_RE = re.compile(r"^  rung ([0-9.]+) ([^:]+): (?:(ok|FAILED), )?(\d+) s(?:, after (\d+) s waiting)?")


def ladder_runs():
    runs = []
    for path in sorted(glob.glob(os.path.join(NOTES, "*ladder*.log"))):
        with open(path, errors="replace") as f:
            for line in f:
                m = LADDER_RE.match(line.rstrip("\n"))
                if not m:
                    continue
                rung, label, status, secs, waited = m.groups()
                runs.append(
                    {
                        "file": os.path.basename(path),
                        "rung": rung,
                        "label": label.strip(),
                        "seconds": int(secs),
                        "ok": None if status is None else status == "ok",
                        "waited_s": int(waited) if waited else None,
                        "outlier": int(secs) > SLEPT_S,
                    }
                )
    return runs


def build(count):
    subprocess.run(["git", "-C", CLONE, "fetch", "-q", "origin"], check=False)
    raw = fetch_prs(count)
    refs = {}
    for pr in raw:
        nums = {int(n) for n in REF_RE.findall(f"{pr['title']}\n{pr['body'] or ''}")}
        nums.discard(pr["number"])
        refs[pr["number"]] = nums
    issue_cache = lookup_issues(set().union(*refs.values()) if refs else set(), {})
    deploys, anc_cache = load_deploys(), {}

    rows = []
    for pr in raw:
        commits = [c["commit"] for c in pr["commits"]["nodes"]]
        first = min((c["authoredDate"] for c in commits), default=None)
        last = max((c["committedDate"] for c in commits), default=None)
        paths = [f["path"] for f in pr["files"]["nodes"]]
        # ponytail: only the first 100 files are read; a PR that big almost surely touches native/App anyway.
        kind = "screen" if any(p.startswith(SCREEN_DIRS) for p in paths) else "logic"
        issues = sorted((n, issue_cache[n]) for n in refs[pr["number"]] if issue_cache.get(n))
        asked_issue, asked = min(issues, key=lambda t: t[1]) if issues else (None, None)
        merged = pr["mergedAt"]
        merge_oid = (pr.get("mergeCommit") or {}).get("oid")
        # A PR merged before the deploy log began may have reached a device in an unlogged install,
        # so its first *logged* deploy would overstate merged->on device: leave it unknown.
        if merged and merged >= DEPLOY_LOG_START:
            dev_at, dev = on_device(merge_oid, merged, deploys, anc_cache)
            up_at = uploaded(merge_oid, merged, deploys, anc_cache)
        else:
            dev_at, dev, up_at = None, None, None
        rows.append(
            {
                "number": pr["number"],
                "title": pr["title"],
                "author": (pr.get("author") or {}).get("login"),
                "mergedAt": merged,
                "asked": asked,
                "asked_issue": asked_issue,
                "first_commit": first,
                "last_commit": last,
                "opened": pr["createdAt"],
                "merged": merged,
                "on_device": dev_at,
                "on_device_device": dev,
                "uploaded": up_at,
                "merge_commit": merge_oid,
                "commit_count": pr["commits"]["totalCount"],
                "file_count": pr["files"]["totalCount"],
                "kind": kind,
                "whiteboard": any("Whiteboard" in p for p in paths),
                "min_first_to_merged": minutes(first, merged),
                "min_asked_to_merged": minutes(asked, merged),
                "min_asked_to_first": minutes(asked, first),
                "min_first_to_opened": minutes(first, pr["createdAt"]),
                "min_opened_to_merged": minutes(pr["createdAt"], merged),
                "min_merged_to_device": minutes(merged, dev_at),
                "min_merged_to_upload": minutes(merged, up_at),
            }
        )
    rows.sort(key=lambda r: r["merged"])
    return {
        "repo": f"{REPO_OWNER}/{REPO_NAME}",
        "generated": iso(datetime.now(timezone.utc)),
        "deploy_log_start": DEPLOY_LOG_START,
        "slept_threshold_s": SLEPT_S,
        "deploys": deploys,
        "prs": rows,
        "ladder_runs": ladder_runs(),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=120)
    ap.add_argument("--html-only", action="store_true", help="re-render index.html from data.json")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    data_path = os.path.join(OUT, "data.json")
    if a.html_only:
        with open(data_path) as f:
            data = json.load(f)
    else:
        data = build(a.count)
        with open(data_path, "w") as f:
            json.dump(data, f, indent=1)
    blob = json.dumps(data).replace("</", "<\\/")
    html_path = os.path.join(OUT, "index.html")
    with open(html_path, "w") as f:
        f.write(TEMPLATE.replace("/*__DATA__*/null", blob))
    print(f"wrote {data_path} and {html_path} ({len(data['prs'])} PRs, {len(data['ladder_runs'])} ladder lines)")


TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Change Lead Times</title>
<style>
:root{
 --bg:#f7f6f2;--surface:#ffffff;--ink:#1d1d1b;--muted:#6b6a64;--line:#e2e0d8;
 --logic:#2f6db5;--screen:#c2571a;--accent:#2f6db5;--warn:#a33a2a;--chip:#efede6;
}
@media (prefers-color-scheme: dark){
 :root:not([data-theme="light"]){
  --bg:#141413;--surface:#1f1f1d;--ink:#ecebe6;--muted:#a09f98;--line:#34332f;
  --logic:#6fa3e8;--screen:#f08a4b;--accent:#6fa3e8;--warn:#f07a6a;--chip:#2a2a27;
 }
}
:root[data-theme="dark"]{
 --bg:#141413;--surface:#1f1f1d;--ink:#ecebe6;--muted:#a09f98;--line:#34332f;
 --logic:#6fa3e8;--screen:#f08a4b;--accent:#6fa3e8;--warn:#f07a6a;--chip:#2a2a27;
}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{background:var(--bg);color:var(--ink);font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;overflow-x:hidden}
main{max-width:980px;margin:0 auto;padding:24px 16px 48px}
h1{font-size:1.6rem;margin:0 0 4px}
h2{font-size:1.15rem;margin:36px 0 8px}
p{margin:6px 0}
.sub{color:var(--muted);font-size:.9rem}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:12px;margin-top:16px}
.tile{background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.tile .v{font-size:1.5rem;font-weight:650;font-variant-numeric:tabular-nums}
.tile .l{color:var(--muted);font-size:.82rem}
.tile .k{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:5px}
.card{background:var(--surface);border:1px solid var(--line);border-radius:10px;padding:12px}
.scroll{overflow-x:auto;-webkit-overflow-scrolling:touch}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;font-size:.9rem}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--muted);font-weight:600;white-space:nowrap}
td.n{text-align:right;white-space:nowrap}
th.n{text-align:right}
.na{color:var(--muted);font-style:italic}
.out{color:var(--warn)}
.legend{display:flex;gap:16px;flex-wrap:wrap;font-size:.85rem;color:var(--muted);margin:6px 0}
.dot{display:inline-block;width:10px;height:10px;border-radius:50%;vertical-align:middle;margin-right:4px}
svg text{fill:var(--muted);font-size:11px}
svg .grid{stroke:var(--line)}
#tip{position:fixed;pointer-events:none;background:var(--surface);border:1px solid var(--line);border-radius:8px;padding:6px 9px;font-size:.82rem;max-width:280px;display:none;box-shadow:0 2px 10px rgba(0,0,0,.15)}
a{color:var(--accent)}
ul{padding-left:20px}
</style>
</head>
<body>
<main>
<h1>Change lead times</h1>
<p class="sub" id="scope"></p>

<div class="tiles" id="tiles"></div>

<h2>First commit to merged, per PR</h2>
<p class="sub">Minutes, log scale. Each dot is one PR at the time it merged.</p>
<div class="legend"><span><span class="dot" style="background:var(--logic)"></span>logic (host tests only)</span><span><span class="dot" style="background:var(--screen)"></span>screen (touches the app UI, goes through the simulator)</span></div>
<div class="card"><svg id="chart" width="100%" height="320" role="img" aria-label="Scatter of first commit to merged minutes per PR"></svg></div>

<h2>Where the time goes, stage by stage</h2>
<p class="sub">Median / 75th percentile / max for each stage. "Asked" is the creation time of the earliest issue the PR mentions.</p>
<div class="card scroll"><table id="stages"></table></div>
<p class="sub" id="stagenote"></p>
<h3 style="font-size:1rem;margin:20px 0 6px">Split by who opened the PR</h3>
<p class="sub">The author matters more than the kind: the pipeline opens a PR only at its end, so for those "opened \u2192 merged" is seconds, while PRs Larry opens wait open until an agent picks them up.</p>
<div class="card scroll"><table id="authors"></table></div>

<h2>Where a clean run's minutes go</h2>
<p class="sub" id="laddersub"></p>
<div class="card scroll"><table id="ladder"></table></div>
<details style="margin-top:10px"><summary class="sub">Every timing sample</summary>
<div class="card scroll" style="margin-top:8px"><table id="samples"></table></div></details>

<h2>The 10 slowest PRs</h2>
<p class="sub">By first commit to merged.</p>
<div class="card scroll"><table id="slow"></table></div>

<h2>What this can't see</h2>
<ul id="cant"></ul>
<p class="sub" id="gen"></p>
</main>
<div id="tip"></div>
<script>
const DATA = /*__DATA__*/null;
const prs = DATA.prs;
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
function q(xs, p){ xs = xs.filter(x => x != null).sort((a,b)=>a-b); if(!xs.length) return null;
  const i = (xs.length-1)*p, lo = Math.floor(i), hi = Math.ceil(i); return xs[lo] + (xs[hi]-xs[lo])*(i-lo); }
function dur(m){ if(m == null) return "—"; const neg = m < 0; m = Math.abs(m); let s;
  if(m < 90) s = Math.round(m) + " min"; else if(m < 48*60) s = (m/60).toFixed(1) + " h"; else s = (m/1440).toFixed(1) + " d";
  return (neg ? "−" : "") + s; }
function secs(s){ if(s == null) return "—"; return s < 90 ? s + " s" : (s/60).toFixed(1) + " min"; }
const fmtDate = s => new Date(s).toLocaleDateString(undefined,{month:"short",day:"numeric"});
const link = n => `<a href="https://github.com/${DATA.repo}/pull/${n}">#${n}</a>`;
const kinds = ["logic","screen"];
const byKind = k => prs.filter(p => p.kind === k);

// scope
const first = prs[0], last = prs[prs.length-1];
$("scope").textContent = `${prs.length} merged PRs in ${DATA.repo}, merged ${fmtDate(first.merged)} – ${fmtDate(last.merged)} ${new Date(last.merged).getFullYear()}. ` +
  `${byKind("logic").length} logic, ${byKind("screen").length} screen (${prs.filter(p=>p.whiteboard).length} touch the whiteboard).`;

// tiles
const tiles = [];
for(const k of kinds){ const xs = byKind(k).map(p=>p.min_first_to_merged);
  tiles.push([`<span class="k" style="background:var(--${k})"></span>${k}: first commit → merged`, `${dur(q(xs,.5))}`, `median; p75 ${dur(q(xs,.75))} (n=${xs.length})`]); }
const asked = prs.map(p=>p.min_asked_to_merged).filter(x=>x!=null);
tiles.push(["asked → merged", dur(q(asked,.5)), `median where an issue is referenced; p75 ${dur(q(asked,.75))} (n=${asked.length})`]);
tiles.push(["PRs", String(prs.length), `${fmtDate(first.merged)} – ${fmtDate(last.merged)}`]);
$("tiles").innerHTML = tiles.map(([l,v,s]) => `<div class="tile"><div class="l">${l}</div><div class="v">${v}</div><div class="l">${s}</div></div>`).join("");

// chart (hand-drawn SVG: no dependencies)
function drawChart(){
  const svg = $("chart"), W = svg.clientWidth || 600, H = 320, L = 52, R = 12, T = 12, B = 30;
  const pts = prs.filter(p => p.min_first_to_merged != null && p.min_first_to_merged > 0);
  const t0 = Date.parse(first.merged), t1 = Date.parse(last.merged) || t0 + 1;
  const ys = pts.map(p=>p.min_first_to_merged), ymin = Math.max(1, Math.min(...ys)), ymax = Math.max(...ys);
  const lo = Math.floor(Math.log10(ymin)), hi = Math.ceil(Math.log10(ymax));
  const x = t => L + (W-L-R) * (t - t0) / Math.max(1, t1 - t0);
  const y = v => T + (H-T-B) * (1 - (Math.log10(Math.max(v,1)) - lo) / Math.max(1, hi - lo));
  let g = "";
  const ticks = [1,5,15,30,60,120,240,480,1440,2880,5760,11520,20160].filter(v => v >= 10**lo && v <= 10**hi);
  for(const v of ticks){ g += `<line class="grid" x1="${L}" x2="${W-R}" y1="${y(v)}" y2="${y(v)}"/><text x="${L-6}" y="${y(v)+4}" text-anchor="end">${dur(v)}</text>`; }
  const days = Math.max(1, (t1-t0)/864e5), step = Math.ceil(days/6)*864e5;
  for(let t = t0; t <= t1; t += step){ g += `<text x="${x(t)}" y="${H-8}" text-anchor="middle">${fmtDate(t)}</text>`; }
  for(const p of pts){ g += `<circle cx="${x(Date.parse(p.merged)).toFixed(1)}" cy="${y(p.min_first_to_merged).toFixed(1)}" r="4.5" fill="var(--${p.kind})" fill-opacity=".8" data-n="${p.number}"/>`; }
  svg.innerHTML = g;
  const tip = $("tip");
  svg.onmousemove = e => { const n = e.target.dataset && e.target.dataset.n; if(!n){ tip.style.display="none"; return; }
    const p = prs.find(r => r.number == n);
    tip.innerHTML = `<b>#${p.number}</b> ${esc(p.title)}<br>${p.kind}${p.whiteboard?", whiteboard":""} · ${dur(p.min_first_to_merged)}`;
    tip.style.display = "block"; tip.style.left = Math.min(e.clientX+12, innerWidth-290) + "px"; tip.style.top = (e.clientY+12) + "px"; };
  svg.onmouseleave = () => tip.style.display = "none";
  svg.onclick = e => { const n = e.target.dataset && e.target.dataset.n; if(n) open(`https://github.com/${DATA.repo}/pull/${n}`, "_blank"); };
}
drawChart(); addEventListener("resize", drawChart);

// stages
const stages = [
  ["asked → first commit", "min_asked_to_first", "waiting for work to start"],
  ["first commit → PR opened", "min_first_to_opened", "build, local checks, simulator"],
  ["PR opened → merged", "min_opened_to_merged", "pipeline tail"],
  ["merged → on device", "min_merged_to_device", "deploy"],
];
let negAsk = 0;
let st = `<tr><th>stage</th>${kinds.map(k=>`<th class="n">${k} median</th><th class="n">p75</th><th class="n">max</th><th class="n">n</th>`).join("")}</tr>`;
for(const [name, key, what] of stages){
  st += `<tr><td>${name}<br><span class="sub">${what}</span></td>`;
  for(const k of kinds){
    let xs = byKind(k).map(p=>p[key]).filter(x=>x!=null);
    if(key === "min_asked_to_first"){ negAsk += xs.filter(x=>x<0).length; xs = xs.filter(x=>x>=0); }
    if(!xs.length){ st += `<td class="n na" colspan="4">${key==="min_merged_to_device" ? "not recorded before "+DATA.deploy_log_start : "no data"}</td>`; continue; }
    st += `<td class="n">${dur(q(xs,.5))}</td><td class="n">${dur(q(xs,.75))}</td><td class="n">${dur(Math.max(...xs))}</td><td class="n">${xs.length}</td>`;
  }
  st += "</tr>";
}
$("stages").innerHTML = st;
$("stagenote").textContent = negAsk ? `${negAsk} PR(s) had commits older than the issue they mention (the issue was filed after work began, or the PR cites an older related issue); those are left out of "asked → first commit".` : "";

// by author
const authors = [...new Set(prs.map(p=>p.author))];
let at = `<tr><th>author</th><th>kind</th><th class="n">PRs</th><th class="n">first commit \u2192 merged (median / p75)</th><th class="n">first commit \u2192 opened (median)</th><th class="n">opened \u2192 merged (median / p75)</th></tr>`;
for(const a of authors) for(const k of kinds){ const sub = prs.filter(p=>p.author===a && p.kind===k); if(!sub.length) continue;
  const c = key => sub.map(p=>p[key]);
  at += `<tr><td>${esc(a)}</td><td>${k}</td><td class="n">${sub.length}</td><td class="n">${dur(q(c("min_first_to_merged"),.5))} / ${dur(q(c("min_first_to_merged"),.75))}</td><td class="n">${dur(q(c("min_first_to_opened"),.5))}</td><td class="n">${dur(q(c("min_opened_to_merged"),.5))} / ${dur(q(c("min_opened_to_merged"),.75))}</td></tr>`; }
$("authors").innerHTML = at;

// ladder
const runs = DATA.ladder_runs;
const groups = [
  ["Host tests (rung 1)", r => r.rung === "1" && r.label === "Host"],
  ["Mac build (rung 1.5)", r => r.rung === "1.5"],
  ["Simulator compile", r => r.rung === "2" && r.label === "compile"],
  ["Simulator: chat classes", r => r.label === "chat classes"],
  ["Simulator: whiteboard classes", r => r.label === "whiteboard classes"],
  ["Simulator: places classes", r => r.label === "places classes"],
  ["Simulator: other classes", r => r.label === "other classes"],
  ["Simulator rung total (ok runs)", r => r.label === "Simulator" && r.ok === true],
];
let lt = `<tr><th>step</th><th class="n">typical (median)</th><th class="n">range</th><th class="n">samples</th><th>outliers excluded</th></tr>`;
for(const [name, f] of groups){
  const all = runs.filter(f), clean = all.filter(r => !r.outlier), xs = clean.map(r=>r.seconds);
  if(!all.length) continue;
  const outs = all.filter(r=>r.outlier).map(r=>`<span class="out">${secs(r.seconds)} (${esc(r.file)})</span>`).join(", ") || "none";
  lt += `<tr><td>${name}</td><td class="n">${secs(q(xs,.5))}</td><td class="n">${xs.length ? secs(Math.min(...xs))+" – "+secs(Math.max(...xs)) : "—"}</td><td class="n">${clean.length}</td><td>${outs}</td></tr>`;
}
$("ladder").innerHTML = lt;
$("laddersub").textContent = `From ${new Set(runs.map(r=>r.file)).size} ladder logs. These are samples of test-ladder runs, not tied to particular PRs. A single step over ${DATA.slept_threshold_s.toLocaleString()} s is treated as a slept or hung Mac and left out of the typical figure. Waits for the build lock are not counted in a step's seconds.`;
$("samples").innerHTML = `<tr><th>log</th><th>step</th><th class="n">seconds</th><th>result</th></tr>` +
  runs.filter(r => r.label !== "project").map(r => `<tr><td>${esc(r.file)}</td><td>rung ${r.rung} ${esc(r.label)}</td><td class="n ${r.outlier?"out":""}">${r.seconds}${r.waited_s?` <span class="sub">(+${r.waited_s} s waiting)</span>`:""}</td><td>${r.ok===null?"":r.ok?"ok":'<span class="out">FAILED</span>'}${r.outlier?' <span class="out">outlier</span>':""}</td></tr>`).join("");

// slowest
const slow = prs.filter(p=>p.min_first_to_merged!=null).sort((a,b)=>b.min_first_to_merged-a.min_first_to_merged).slice(0,10);
$("slow").innerHTML = `<tr><th>PR</th><th>title</th><th>kind</th><th class="n">first commit → merged</th><th class="n">opened → merged</th><th class="n">commits</th></tr>` +
  slow.map(p => `<tr><td>${link(p.number)}</td><td>${esc(p.title)}</td><td>${p.kind}${p.whiteboard?" (whiteboard)":""}</td><td class="n">${dur(p.min_first_to_merged)}</td><td class="n">${dur(p.min_opened_to_merged)}</td><td class="n">${p.commit_count}</td></tr>`).join("");

// can't see
const noIssue = prs.filter(p=>p.asked==null).length;
const onDev = prs.filter(p=>p.on_device!=null).length;
$("cant").innerHTML = [
  `<b>Time before the first commit when no issue is referenced</b>: ${noIssue} of ${prs.length} PRs mention no issue, so for them the clock starts at the first commit, not when the change was asked for. A chat request, a bead or a spoken ask leaves no timestamp here.`,
  `<b>"Asked" is a heuristic</b>: it is the earliest issue number in the PR's title or body. A PR that cites an old related issue looks like it waited longer than it did.`,
  `<b>Waiting on Igor</b>: approvals, questions and his reviews are inside these stages and can't be separated out; nor can nights and weekends (all times are wall-clock).`,
  `<b>"PR opened" is late for pipeline PRs</b>: the no-mistakes pipeline opens the PR after its review and test steps, so for those PRs the pipeline's own minutes sit in "first commit \u2192 PR opened", not in the tail.`,
  `<b>Commit times can predate the work</b>: rebased or cherry-picked commits keep their original author date, which stretches "first commit → merged" (often the cause of the multi-day outliers).`,
  `<b>Deploys before ${DATA.deploy_log_start}</b>: the deploy log starts then, so "merged → on device" is known for ${onDev} PR(s) only.`,
  `<b>Ladder timings</b> are a handful of sampled runs, not every PR's build.`,
].map(s=>`<li>${s}</li>`).join("");
$("gen").textContent = `Generated ${DATA.generated} by scripts/lead-times.py. Rerun it (just lead-times) to refresh.`;
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
