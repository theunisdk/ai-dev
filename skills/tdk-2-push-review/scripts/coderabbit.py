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

The head's review state comes from the `CodeRabbit` commit status on the head
SHA (newest entry), not only from review objects: a clean incremental pass
leaves no review object, and skipped, rate-limited and completed runs all post
state=success. Only the description tells them apart:
  reviewed      "Review completed"; with no CodeRabbit status on the head
                (repos with review_status off), a non-empty CodeRabbit review
                object on it (an empty-body one acknowledges a thread reply)
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

Exit codes (both subcommands):
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


def head_state(pr, repo, sha, since=None):
    """(state, detail) of CodeRabbit's run on commit SHA; see the module docstring."""
    statuses = [st for st in api_list(f"repos/{repo}/commits/{sha}/statuses?per_page=100")
                if st.get("context") == STATUS_CONTEXT
                and (not since or (st.get("created_at") or "") >= since)]
    newest = max(statuses, key=lambda st: st.get("created_at") or "", default=None)
    if newest is None:
        reviews = api_list(f"repos/{repo}/pulls/{pr}/reviews")
        if any(r.get("commit_id") == sha and (r.get("user") or {}).get("login") == REST_BOT
               and (r.get("body") or "").strip()
               and (not since or (r.get("submitted_at") or "") >= since) for r in reviews):
            return REVIEWED, "review object on head, no CodeRabbit status"
        return PENDING, "no CodeRabbit status on head" + (f" since {since}" if since else "")
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


def report(pr, repo, sha, state, detail):
    """Print the head's state and findings; return the exit code."""
    head = f"head {sha[:7]} {state.upper()} ({detail})"
    if state != REVIEWED:
        head += "; NOT reviewed, so this count is not a pass"
    if state == RATE_LIMITED:
        wait = next_review_wait(pr, repo)
        head += (f"; next included review available in {wait}" if wait else
                 "; no wait time in CodeRabbit's summary comment, '@coderabbitai rate limit' shows it")
    n = print_findings(pr, repo, head)
    if state == REVIEWED:
        return 0 if n > 0 else 5
    return EXIT[state]


def print_findings(pr, repo, head):
    findings = unresolved_findings(pr, repo)
    print(f"ACTIONABLE: {len(findings)} — {head}\n")
    for i, f in enumerate(findings, 1):
        loc = f"{f['path']}:{f['line']}" if f["line"] else f["path"]
        tag = " [outdated]" if f["outdated"] else ""
        print(f"[{i}] {loc}{tag}")
        print(f"    {f['url']}")
        for ln in f["body"].splitlines():
            print(f"    {ln}")
        print()
    return len(findings)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["threads", "wait"])
    p.add_argument("--pr", required=True, type=int)
    p.add_argument("--sha")
    p.add_argument("--after-nudge", action="store_true")
    p.add_argument("--repo")
    p.add_argument("--timeout", type=int, default=1200)
    p.add_argument("--interval", type=int, default=45)
    a = p.parse_args()

    repo = a.repo or current_repo()
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
