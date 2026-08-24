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

Subcommands:
  threads  --pr N           list unresolved non-nitpick CodeRabbit findings.
                            exit 0 if any remain, exit 5 if clean (none).
  wait     --pr N --sha S   poll until CodeRabbit posts a review for SHA S
                            (the latest push), then list findings. timeout -> exit 4.

Repo defaults to `gh`'s current repo; override with --repo owner/name.
Note: REST review author is "coderabbitai[bot]", GraphQL author is "coderabbitai".
"""
import argparse
import json
import subprocess
import sys
import time

NITPICK = "🧹 Nitpick"
REST_BOT = "coderabbitai[bot]"
GQL_BOT = "coderabbitai"

THREADS_QUERY = """
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){
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


def head_sha():
    return run(["git", "rev-parse", "HEAD"]).strip()


def unresolved_findings(pr, repo):
    owner, name = repo.split("/", 1)
    raw = run(["gh", "api", "graphql", "-f", f"query={THREADS_QUERY}",
               "-F", f"owner={owner}", "-F", f"repo={name}", "-F", f"pr={pr}"])
    nodes = json.loads(raw)["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]
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


def reviewed_head(pr, repo, sha):
    """True once CodeRabbit has posted a review for commit SHA."""
    raw = run(["gh", "api", "--paginate", f"repos/{repo}/pulls/{pr}/reviews"])
    # --paginate may concatenate arrays; decode all documents.
    dec, idx, reviews = json.JSONDecoder(), 0, []
    text = raw.strip()
    while idx < len(text):
        while idx < len(text) and text[idx] in " \n\r\t":
            idx += 1
        if idx >= len(text):
            break
        obj, idx = dec.raw_decode(text, idx)
        reviews.extend(obj if isinstance(obj, list) else [obj])
    return any(r.get("commit_id") == sha and (r.get("user") or {}).get("login") == REST_BOT
               for r in reviews)


def print_findings(pr, repo):
    findings = unresolved_findings(pr, repo)
    print(f"ACTIONABLE: {len(findings)}\n")
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
    p.add_argument("--repo")
    p.add_argument("--timeout", type=int, default=1200)
    p.add_argument("--interval", type=int, default=45)
    a = p.parse_args()

    repo = a.repo or current_repo()

    if a.cmd == "threads":
        n = print_findings(a.pr, repo)
        sys.exit(0 if n > 0 else 5)

    if a.cmd == "wait":
        sha = a.sha or head_sha()
        deadline = time.time() + a.timeout
        while time.time() < deadline:
            if reviewed_head(a.pr, repo, sha):
                print(f"CodeRabbit has reviewed {sha[:7]}.\n")
                n = print_findings(a.pr, repo)
                sys.exit(0 if n > 0 else 5)
            time.sleep(a.interval)
        print(f"TIMEOUT after {a.timeout}s: no CodeRabbit review for {sha[:7]} yet. "
              f"It may still be reviewing, or you may need to comment '@coderabbitai review'.",
              file=sys.stderr)
        sys.exit(4)


if __name__ == "__main__":
    main()
