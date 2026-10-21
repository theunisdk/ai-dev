#!/usr/bin/env python3
"""Fetch / wait on CodeRabbit review findings for a PR.

The reliable "what's left to fix" signal is the set of *unresolved* review
threads authored by CodeRabbit, minus nitpicks. This cross-references every
commit (a finding raised three pushes ago that was never addressed stays
unresolved), which is exactly what "keep fixing till all sorted" needs — SHA
filtering alone would orphan earlier-round findings.

CodeRabbit tags each finding with a severity line, e.g.
  _🎯 Functional Correctness_ | _🟠 Major_ | _⚡ Quick win_
Severities: 🔴 Critical, 🟠 Major, 🟡 Minor, 🔵 Trivial. Nitpicks carry a
"🧹 Nitpick" tag and are skipped.

Findings CodeRabbit cannot post inline ("Outside diff range comments (N)",
"Duplicate comments (N)") live only in the body of its newest review on the
head. They have no thread to resolve and count until a later review on a new
head stops repeating them.

The head's review state comes from the `CodeRabbit` commit status on the head
SHA (newest entry), not only from review objects: a clean incremental pass
leaves no review object, and skipped, rate-limited and completed runs all post
state=success. Only the description tells them apart:
  reviewed      "Review completed"; with no CodeRabbit status on the head, a
                non-empty CodeRabbit review object on it, but only in a repo
                where CodeRabbit posts no statuses at all (review_status off).
                An empty-body review object acknowledges a thread reply.
  skipped       "Review skipped" (`@coderabbitai ignore`), or "Review skipped:
                <reason>" (the repo's CodeRabbit config, e.g. label opt-in)
  rate limited  "Review rate limited" — not reviewed
  pending       "Review in progress" / "Review approved", or no status yet
  unknown       any other description — not reviewed

Subcommands:
  threads  --pr N [--sha S]  list unresolved non-nitpick CodeRabbit findings and
                             the head's review state (S defaults to the PR head).
  wait     --pr N [--sha S] [--after-nudge]
                             poll until the head leaves pending, then do as threads.
                             --after-nudge: statuses older than the newest
                             `@coderabbitai review` comment count as pending.
  detect                     print `CodeRabbit: installed|not installed (…)` from
                             CodeRabbit's statuses, reviews and comments on the
                             repo's last 10 merged PRs; installed names any newer
                             PRs with none. No merged PRs: assumed installed.
                             Exit 0 installed, 9 not installed, 2 a gh call failed.

Exit codes (threads and wait):
  0  head reviewed, findings remain     5  head reviewed, clean (ACTIONABLE: 0)
  6  head skipped — not reviewed        7  head rate limited — not reviewed
  8  unknown status — not reviewed      2  a gh/git call failed
  3  threads only: head still pending   4  wait only: timed out while pending
Exit 5 is the only clean pass. 6, 7 and 8 still list older unresolved findings.

Repo defaults to `gh`'s current repo; override with --repo owner/name.
Note: REST review author is "coderabbitai[bot]", GraphQL author is "coderabbitai".
"""
import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone

NITPICK = "🧹 Nitpick"
REST_BOT = "coderabbitai[bot]"
GQL_BOT = "coderabbitai"
STATUS_CONTEXT = "CodeRabbit"
RATE_LIMIT_MARKER = "rate limited by coderabbit.ai"
NEXT_REVIEW = re.compile(r"Next included review available in ([^.*\n]+)")
MINUTES = re.compile(r"^(\d+) minutes?$")

REVIEWED, SKIPPED, RATE_LIMITED, PENDING, UNKNOWN = (
    "reviewed", "skipped", "rate limited", "pending", "unknown")
EXIT = {SKIPPED: 6, RATE_LIMITED: 7, UNKNOWN: 8, PENDING: 3}

BODY_SECTION = re.compile(r"^(?:\*\*|<summary>)\W*?(?:([A-Z][A-Za-z ]*?) comments(?: \((\d+)\)|: (\d+))"
                          r"|Prompt to fix review comments)", re.M)
BODY_KINDS = ("Outside diff range", "Duplicate")
BODY_ITEM = re.compile(r"<summary>(.*?)</summary><blockquote>(.*?)</blockquote></details>", re.S)
BODY_LOC = re.compile(r"`([^`\s]+:\d[\d-]*)`")

THREADS_QUERY = """
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){
        pageInfo{ hasNextPage }
        nodes{
          isResolved isOutdated
          comments(first:1){ nodes{ author{login} path line originalLine url body } }
        }
      }
    }
  }
}
"""


def run(cmd):
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write(out.stderr)
        sys.exit(2)
    return out.stdout


def current_repo():
    return run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]).strip()


def pr_head(pr, repo):
    return run(["gh", "pr", "view", str(pr), "-R", repo, "--json", "headRefOid",
                "-q", ".headRefOid"]).strip()


def api_list(path):
    """GET a list endpoint across all pages."""
    raw = run(["gh", "api", "--paginate", path])
    # --paginate may concatenate arrays; decode all documents.
    dec, idx, items = json.JSONDecoder(), 0, []
    text = raw.strip()
    while idx < len(text):
        while idx < len(text) and text[idx] in " \n\r\t":
            idx += 1
        if idx >= len(text):
            break
        obj, idx = dec.raw_decode(text, idx)
        items.extend(obj if isinstance(obj, list) else [obj])
    return items


def unresolved_findings(pr, repo):
    owner, name = repo.split("/", 1)
    raw = run(["gh", "api", "graphql", "-f", f"query={THREADS_QUERY}",
               "-F", f"owner={owner}", "-F", f"repo={name}", "-F", f"pr={pr}"])
    threads = json.loads(raw)["data"]["repository"]["pullRequest"]["reviewThreads"]
    if threads["pageInfo"]["hasNextPage"]:
        sys.stderr.write("WARNING: PR has over 100 review threads; only the first 100 were read.\n")
    nodes = threads["nodes"]
    findings = []
    for t in nodes:
        c = (t.get("comments") or {}).get("nodes") or []
        if not c:
            continue
        c = c[0]
        if (c.get("author") or {}).get("login") != GQL_BOT:
            continue
        if t.get("isResolved"):
            continue
        body = c.get("body") or ""
        if NITPICK in body:
            continue
        findings.append({
            "path": c.get("path"),
            "line": c.get("line") or c.get("originalLine"),
            "outdated": t.get("isOutdated"),
            "url": c.get("url"),
            "body": body,
        })
    return findings


def nudge_time(pr, repo):
    """created_at of the newest human `@coderabbitai review` comment on the PR."""
    times = [c.get("created_at") or "" for c in api_list(f"repos/{repo}/issues/{pr}/comments")
             if (c.get("user") or {}).get("type") != "Bot"
             and "@coderabbitai review" in (c.get("body") or "")]
    if not max(times, default=""):
        sys.stderr.write(f"--after-nudge: no '@coderabbitai review' comment on PR #{pr}.\n")
        sys.exit(2)
    return max(times)


def head_review(reviews, sha, since=None):
    """Newest non-empty CodeRabbit review object on commit SHA, or None."""
    on_head = [r for r in reviews
               if r.get("commit_id") == sha and (r.get("user") or {}).get("login") == REST_BOT
               and (r.get("body") or "").strip()
               and (not since or (r.get("submitted_at") or "") >= since)]
    return max(on_head, key=lambda r: r.get("submitted_at") or "", default=None)


def repo_posts_status(pr, repo):
    """True if CodeRabbit has posted a commit status on this PR or a recent one."""
    shas = [c["sha"] for c in api_list(f"repos/{repo}/pulls/{pr}/commits")]
    recent = json.loads(run(["gh", "api", f"repos/{repo}/pulls?state=all&per_page=10"]))
    shas += [p["head"]["sha"] for p in recent if p.get("number") != pr]
    return any(st.get("context") == STATUS_CONTEXT
               for sha in shas
               for st in json.loads(run(["gh", "api", f"repos/{repo}/commits/{sha}/statuses"])))


def bot_trace(repo, pr):
    """What CodeRabbit left on merged PR {number, headRefOid}, or None."""
    if any(st.get("context") == STATUS_CONTEXT
           for st in api_list(f"repos/{repo}/commits/{pr['headRefOid']}/statuses?per_page=100")):
        return "status"
    for kind, path in (("review", "pulls/{}/reviews"), ("comment", "issues/{}/comments")):
        if any((c.get("user") or {}).get("login") == REST_BOT
               for c in api_list(f"repos/{repo}/{path.format(pr['number'])}")):
            return kind
    return None


def detect(repo):
    """(installed, detail) from CodeRabbit's trace on the repo's last 10 merged PRs."""
    prs = json.loads(run(["gh", "pr", "list", "-R", repo, "--state", "merged", "--limit", "10",
                          "--json", "number,headRefOid"]))
    if not prs:
        return True, "assumed: no merged PRs to check"
    for i, p in enumerate(prs):
        trace = bot_trace(repo, p)
        if trace:
            newer = ", ".join(f"#{q['number']}" for q in prs[:i])
            return True, f"CodeRabbit {trace} on #{p['number']}" + (
                f"; none on the {i} newer merged PRs {newer}" if i else "")
    return False, (f"detected: no CodeRabbit status, review or comment on the last {len(prs)} merged PRs, "
                   f"#{prs[-1]['number']}–#{prs[0]['number']}")


def head_state(pr, repo, sha, since=None):
    """(state, detail) of CodeRabbit's run on commit SHA; see the module docstring."""
    statuses = [st for st in api_list(f"repos/{repo}/commits/{sha}/statuses?per_page=100")
                if st.get("context") == STATUS_CONTEXT
                and (not since or (st.get("created_at") or "") >= since)]
    newest = max(statuses, key=lambda st: st.get("created_at") or "", default=None)
    if newest is None:
        missing = "no CodeRabbit status on head" + (f" since {since}" if since else "")
        if head_review(api_list(f"repos/{repo}/pulls/{pr}/reviews"), sha, since):
            if not repo_posts_status(pr, repo):
                return REVIEWED, "review object on head; this repo gets no CodeRabbit statuses"
            missing += ", though a review object is on it"
        return PENDING, missing
    desc = newest.get("description") or ""
    detail = f'status "{desc}"'
    if desc.startswith("Review completed"):
        return REVIEWED, detail
    if desc.startswith("Review skipped"):
        return SKIPPED, detail
    if desc.startswith("Review rate limited"):
        return RATE_LIMITED, detail
    if desc.startswith(("Review in progress", "Review approved")):
        return PENDING, detail
    return UNKNOWN, f'status {newest.get("state")} "{desc}"'


def next_review_wait(pr, repo):
    """Time left until CodeRabbit's "Next included review available in N minutes", or None."""
    for c in reversed(api_list(f"repos/{repo}/issues/{pr}/comments")):
        if (c.get("user") or {}).get("login") != REST_BOT:
            continue
        body = c.get("body") or ""
        if RATE_LIMIT_MARKER not in body:
            continue
        m = NEXT_REVIEW.search(body)
        if not m:
            continue
        named, updated = m.group(1).strip(), c.get("updated_at") or ""
        mins = MINUTES.match(named)
        try:
            written = datetime.fromisoformat(updated.replace("Z", "+00:00"))
        except ValueError:
            written = None
        if not mins or not written:
            return f"{named} as of {updated or 'an unknown time'}"
        elapsed = (datetime.now(timezone.utc) - written).total_seconds() / 60
        left = int(mins.group(1)) - int(elapsed)
        if left <= 0:
            return f"0 minutes: quota should be free now ({named} as of {updated})"
        return f"~{left} minutes ({named} as of {updated})"
    return None


def body_findings(review):
    """Non-nitpick findings in a review body's outside-diff and duplicate sections."""
    if not review:
        return []
    text = re.sub(r"^> ?", "", review.get("body") or "", flags=re.M)
    marks = list(BODY_SECTION.finditer(text))
    findings, kinds_seen = [], False

    def add(path, kind, body):
        findings.append({"path": path, "line": None, "outdated": False,
                         "url": review.get("html_url"),
                         "tag": f"{kind}, in the review body: no thread", "body": body})

    for i, m in enumerate(marks):
        if not m.group(1) or not m.group(1).startswith(BODY_KINDS):
            continue
        kinds_seen = True
        kind = m.group(1).lower()
        section = text[m.end():marks[i + 1].start() if i + 1 < len(marks) else len(text)]
        items = BODY_ITEM.findall(section)
        for summ, body in items:
            if NITPICK in summ or NITPICK in body:
                continue
            loc = BODY_LOC.search(body) or BODY_LOC.search(re.sub(r"</?code>", "`", summ))
            add(loc.group(1) if loc else m.group(1), kind, body.strip())
        for _ in range(int(m.group(2) or m.group(3)) - len(items)):
            add(f"{m.group(1)} comments", f"{kind}, not parsed: read the review body", "")
    if not kinds_seen and any(f"{k} comments" in text for k in BODY_KINDS):
        add("review body", "not parsed: read the review body", "")
    return findings


def report(pr, repo, sha, state, detail):
    """Print the head's state and findings; return the exit code."""
    head = f"head {sha[:7]} {state.upper()} ({detail})"
    if state != REVIEWED:
        head += "; NOT reviewed, so this count is not a pass"
    if state == RATE_LIMITED:
        wait = next_review_wait(pr, repo)
        head += (f"; next included review available in {wait}" if wait else
                 "; no wait time in CodeRabbit's summary comment, '@coderabbitai rate limit' shows it")
    review = head_review(api_list(f"repos/{repo}/pulls/{pr}/reviews"), sha)
    n = print_findings(pr, repo, head, body_findings(review))
    if state == REVIEWED:
        return 0 if n > 0 else 5
    return EXIT[state]


def print_findings(pr, repo, head, extra):
    findings = unresolved_findings(pr, repo) + extra
    print(f"ACTIONABLE: {len(findings)} — {head}\n")
    for i, f in enumerate(findings, 1):
        loc = f"{f['path']}:{f['line']}" if f["line"] else f["path"]
        tag = " [outdated]" if f["outdated"] else ""
        tag += f" [{f['tag']}]" if f.get("tag") else ""
        print(f"[{i}] {loc}{tag}")
        print(f"    {f['url']}")
        for ln in f["body"].splitlines():
            print(f"    {ln}")
        print()
    return len(findings)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["threads", "wait", "detect"])
    p.add_argument("--pr", type=int)
    p.add_argument("--sha")
    p.add_argument("--after-nudge", action="store_true")
    p.add_argument("--repo")
    p.add_argument("--timeout", type=int, default=1200)
    p.add_argument("--interval", type=int, default=45)
    a = p.parse_args()

    repo = a.repo or current_repo()
    if a.cmd == "detect":
        installed, detail = detect(repo)
        print(f"CodeRabbit: {'installed' if installed else 'not installed'} ({detail})")
        sys.exit(0 if installed else 9)
    if a.pr is None:
        p.error(f"{a.cmd} needs --pr")
    sha = a.sha or pr_head(a.pr, repo)

    if a.cmd == "threads":
        sys.exit(report(a.pr, repo, sha, *head_state(a.pr, repo, sha)))

    if a.cmd == "wait":
        since = nudge_time(a.pr, repo) if a.after_nudge else None
        deadline = time.time() + a.timeout
        while True:
            state, detail = head_state(a.pr, repo, sha, since)
            if state != PENDING:
                sys.exit(report(a.pr, repo, sha, state, detail))
            if time.time() >= deadline:
                break
            time.sleep(a.interval)
        print(f"TIMEOUT after {a.timeout}s: CodeRabbit has not finished {sha[:7]} ({detail}). "
              f"It may still be reviewing; check the commit status before nudging.",
              file=sys.stderr)
        sys.exit(4)


if __name__ == "__main__":
    main()
