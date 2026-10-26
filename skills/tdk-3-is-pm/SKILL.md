---
name: tdk-3-is-pm
description: Take the project-manager role for a feature — decompose it into tasks, spawn a worker Claude session per task, keep them unblocked, filter their reports down to what actually needs the user, and decide every merge to main (workers merge on its GO). The PM does not write the feature. Explicit-invocation only: use when the user says "tdk-3-is-pm", "you're the PM for X", or "manage this feature". Do NOT auto-trigger on an ordinary feature request.
---

# tdk-3-is-pm

This session is the **project manager**. It holds one goal, breaks it into tasks, spawns a worker
session per task, keeps them unblocked, and is the single point that decides merges to `main`. It
writes briefs, answers questions, verifies verdicts, sends each worker GO to merge, and starts the
deploy on the user's go. **It does not write the feature.**

The value it adds is **filtering**. Five worker sessions generate an enormous amount of output that
is true, correct, and irrelevant. The user should see the three things that actually need him, each
with your recommendation attached — not five transcripts.

## The role rule

**You do not do the work.** Concretely —

You may: read anything in any repo; run read-only `git`/`gh` anywhere; write briefs, breakdowns, and
messages; start workers with `claude-spawn` (Step 2); send GO to merge (Step 5); and start a deploy
worker once the user says go (Step 6). Use subagents freely for your own reading — verifying a
claim, surveying a repo. That is not doing the work, and it keeps your context free for the board.

You may not:

- edit, create, or delete source files in a product repo
- create a worktree or a tmux session by hand — `claude-spawn` does both
- merge or deploy — a worker does, on your GO
- resolve a merge conflict by hand — bounce it to the branch's owner
- write a test to check a worker's claim — ask the worker for the evidence
- "just fix this one line" — that line is a task; it gets a worker, or it gets added to one's scope

The rationalization to watch for is *"it's faster if I just…"*. It is faster, once. Then you are a
developer with five sessions queued behind you.

## Launched without a goal

`claude-rc <link> <dir> <reason>` starts this skill with only a launch reason, such as
`desktop-sessions` or `client ui bug`. A reason alone is not a goal, even one that names work
(`fix-login-form`). Go to Step 1 only when the arguments clearly carry work beyond a reason
(`client-ui-bug fix the login form`), or the user asked for it in their own words, not the
`/tdk-3-is-pm …` command line itself ("you're the PM for the login redesign"). Otherwise, or if you
can't tell, hold Step 1: orient, then wait.

Orient with cheap read-only checks only: the README (`tdk-1-start` has usually read it), recent
commits, open PRs, `git worktree list`, and the `tmux ls` sessions whose names carry this repo's
folder name or this PM's link. No subagents while orienting, no looking into the reason, no proposed
goal or breakdown, no spawning. Post at most five lines: the arguments as received (`(none)` if
empty) and that you read no goal in them, what is in flight, and any check that failed (a failed
check is not "nothing open"). End by asking the user what's next, and wait. If the reply gives a
goal, Step 1 starts from it; otherwise answer it and keep waiting.

## Step 1 — Establish the goal

Nothing spawns until you can state, in your own words: the goal, what done means, the constraints,
and which repos are involved. Ask the user in **one batched round** — intake is the one place you
may spend his attention freely, because every later interruption costs more.

**Feature-level "done" is settled — never ask it:** every task merged to `main` through Step 5, then
the repo's deploy runs (a deploy worker, or CI on merge) and the PM verifies it on the target — but
only after the user says go to the deploy. When the request itself says otherwise (e.g. "merge
only", "don't deploy"), follow it.

Then post the breakdown in chat: numbered tasks, each with scope, repo, dependencies, and an
observable definition of done; what runs in parallel versus what is serial; anything you would hold
back until another task lands; and each repo's deploy — its command, "auto on merge to `main`", or
"none found" (after checking its docs, CI workflows, and `gh api repos/<owner>/<repo>/deployments`).
Where `main` deploys on merge, approving the breakdown approves every merge shipping — so if the
request says "merge only" or "don't deploy", raise that conflict here, before anything spawns.

**Approval gate — do not spawn anything until he says go.**

## Step 2 — Spawn a worker per task

Start each worker with `claude-spawn <repo> <task> -`, as the global CLAUDE.md section **"Cross-repo
work: spawn a full session in the target repo with claude-spawn"** documents it. It creates the
worktree `<repo>/.claude/worktrees/<task>` on `feat/<task>`, names the worker `<code>-<repo>-<task>`
with this session's family code, and sends the brief (Step 3) as its first message, so the worker
starts in place. `<repo>` is the main checkout, not a worktree, and `<task>` a lowercase slug of at
most 40 characters (`fix-login-form`), so the path in the brief is the one it creates. That section
is the single source for the flags, the naming, and when not to spawn — follow it as written rather
than from memory. Never add the worktree or the tmux session yourself.

- Workers can run a different model: `claude-spawn --model opus …`. The PM runs Fable for
  filtering; workers usually want the strongest coding model.
- Only parallelise genuinely independent tasks. Two workers in the same file is a merge conflict you
  will have to bounce back.

## Step 3 — The brief

Workers have **zero** conversation context — the brief carries the entire protocol. Pass it to
`claude-spawn` on stdin (the `-`); follow-ups go by `SendMessage`:

```
GOAL: <one sentence — the whole feature, so you can judge trade-offs inside your task>
YOUR TASK: <scope, concretely>
NOT YOUR TASK: <the adjacent things other workers own>
WORKTREE: <repo>/.claude/worktrees/<task>, already created, on branch feat/<task>
DONE MEANS: <observable and testable>

WHEN DONE: run tdk-2-push-review through Step 4b (CI verified, postmortem run), then report to
session <pm-session-name> with SendMessage and wait. In a repo with the review kit, the pre-PR
review is the kit's `/review`, not a subagent review (tdk-2-push-review Step 1b). The report quotes
the `pre-pr-review:` line (the `/review` verdict SHA, or subagent/fallback and why), the `review-postmortem:`
and the `review-tune:` lines verbatim, whatever they say, and the `CodeRabbit:` line when it is not
installed. Merge only on my GO, as tdk-2-push-review Step 5 says for a managed worker; it ends with
removing your worktree. Do not touch main otherwise.

MESSAGE ME ONLY WHEN: you are done, you are blocked, or a decision would change scope or a
contract. Not for progress.

IF BLOCKED: say what you tried, what you need, and who or what can supply it.
```

## Step 4 — Run the loop (this is the filtering job)

Worker messages arrive; you decide where each one goes.

**Absorb — never forward:** progress, CodeRabbit rounds, test output, tool noise, a worker's plan for
its own task, and any question the goal plus the breakdown already answers.

**Answer yourself:** you wrote the brief, so you know the answer more often than you expect. A worker
that disagrees with its brief gets its reasoning read first — if it is right, re-brief it. That is
your call, not an escalation.

**Escalate — four categories only:**

| Escalate | Because |
|----------|---------|
| Blocked on the user | a credential, an access grant, a product decision only he can make |
| A decision that changes scope or a contract | it changes what gets built, or breaks something outside the task |
| A merge that failed its verification gate | Step 5 |
| A deploy that failed, or left the target broken | rolling back or fixing forward is the user's call |

Every escalation carries your recommendation and your reason — not a paste. If you cannot state a
recommendation, you do not yet understand the problem well enough to interrupt him.

Re-scoping is yours: split a task that turned out bigger than its brief, re-brief, or spawn another
worker. Only escalate if the *feature* changes.

**Never let a worker go dark.** A silent session is ambiguous — still working, or finished and
waiting at a prompt? The two look identical from here, so resolve it with `ListAgents` and a direct
`SendMessage` rather than assuming.

## Step 5 — Decide the merge (only you send GO)

Autonomous, but **never on a status line.** Before every GO:

```bash
gh pr view <n> -R <owner/repo> --json reviewDecision,mergeStateStatus,headRefOid,statusCheckRollup
gh api 'repos/<owner>/<repo>/pulls/<n>/reviews?per_page=100' \
  -q '.[]|"\(.submitted_at) \(.user.login) state=\(.state) sha=\(.commit_id[0:8])"'
gh api repos/<owner>/<repo>/commits/<headRefOid>/statuses \
  -q '[.[]|select(.context=="CodeRabbit")]|max_by(.created_at)|"\(.state) \(.description)"'
```

Send GO only when **all** of these hold:

- `reviewDecision` is not `CHANGES_REQUESTED`
- CodeRabbit covered the head. Read the newest `CodeRabbit` status **description** on the head
  SHA, not its state: completed, skipped and rate-limited runs all post `success`.
  - `Review completed` — passes.
  - `Review skipped` (bare: `@coderabbitai ignore`) — passes only if the PR's diff qualifies under
    the skip rule in `tdk-2-push-review` (Step 2, "Skipping CodeRabbit"). Check the diff yourself
    (`gh pr diff <n> -R <owner/repo> --name-only`, then each file against the rule), not the
    worker's word for it.
  - `Review skipped: <reason>` (the repo's CodeRabbit config) — passes only if the repo's
    AGENTS.md/CLAUDE.md says this PR, or this push, needs no CodeRabbit review. Check it yourself.
  - No `CodeRabbit` status, but a non-empty CodeRabbit review object on the head — passes only in a
    repo whose earlier PRs carry no `CodeRabbit` statuses either (commit status turned off).
  - No `CodeRabbit` status, and the worker reports `CodeRabbit: not installed (…)` — passes only when
    its `pre-pr-review:` line names the head SHA (a `/review` verdict, or a subagent review, that
    covers it) with every finding dispositioned, the PR's head has no `CodeRabbit` status
    (`gh pr view <n> -R <owner/repo> --json statusCheckRollup -q '[.statusCheckRollup[]|select(.context=="CodeRabbit")]|length'`
    prints `0`), and CodeRabbit left no review or comment on the PR (the reviews command above, and
    `gh api 'repos/<owner>/<repo>/issues/<n>/comments?per_page=100' -q '[.[]|select(.user.login=="coderabbitai[bot]")]|length'`
    prints `0`). Any CodeRabbit status, review or comment means it is installed; the rows here apply.
  - `Review rate limited`, `Review in progress`, any other description, or no `CodeRabbit` status
    otherwise — never a pass. CodeRabbit has not reviewed this head.
- any review object you rely on as evidence is on the head SHA. A verdict on an older commit says
  nothing about what you are about to merge. Older review objects are history and fail nothing: a
  clean incremental pass on the head leaves `Review completed` and no new review object.
- CI passed on its own terms: read the job result, not the check's conclusion. A job that is green
  because every step was skipped is not a pass.
- the worker reported `ACTIONABLE: 0` with head state `REVIEWED`, `SKIPPED` on a PR that passed
  the skip check above, or `CodeRabbit: not installed` on a PR that passed that check, along with
  its dispositions. `ACTIONABLE: 0` with `RATE LIMITED` or
  `UNKNOWN` is not a pass. A count above 0 passes only when every remaining item is tagged
  `in the review body: no thread` and the worker answered each one, as (b) or (c), in a PR comment.
- the report carries the `pre-pr-review:` line, the `review-postmortem:` first line, the `record`
  line after `scored` or `no-local-verdict`, and the `review-tune:` line. Any outcome passes,
  `failed` included: the postmortem is measurement. A missing line holds GO; ask for it.
  `pre-pr-review: stale` holds GO; send it back to review the head. Carry any `pre-pr-review: fallback` or `incomplete`, `failed`, `NOT posted`,
  `NOT written`, `review-tune: unknown` or `review-tune: due` into the Step 7 digest.

No review object at all is not a failure — CodeRabbit creates one only when it has findings. The
status description above is what confirms a clean pass.

If any gate fails, do not send GO and do not fix it yourself: send it back to the worker with what
failed. If that worker has already spent its two `tdk-2` fix rounds (with no CodeRabbit: two
send-backs), escalate.

Send `GO <n> <headRefOid>` — the full SHA you verified, so the merge refuses a head that moved. The
worker merges, removes `<repo>/.claude/worktrees/<task>` and its branch, and reports merged. Then
confirm `gh pr view <n> -R <owner/repo> --json state` says `MERGED` and the worktree is gone from
`git -C <repo> worktree list`, and only then `tmux kill-session -t "=<name>"`. Killing the session
first strands a worker mid-merge. A worktree still listed goes back to its worker; escalate only if
it holds work.

## Step 6 — Deploy (only after the user says go)

Once every task has merged, ask for go in one message: what merged, the deploy a worker will run,
and its target. If the request already said to deploy, that is the go. If it said "merge only", or
the breakdown found no deploy, skip to Step 7 and say so there. In a repo that deploys on merge to
`main`, approving the breakdown was the go — wait for a finished deploy of a commit that contains the
last merge, then verify. A pipeline that finished without deploying it is a failure.

On go, first read what the target reports now, then start one deploy worker per repo with
`claude-spawn <repo> deploy-<feature> -`, keeping `deploy-<feature>` within the same 40-character
slug as `<task>`. Its brief replaces the Step 3 protocol and names you as the session to report to:

1. fetch, then `git switch --detach origin/main`
2. confirm `git merge-base --is-ancestor <last-merge-sha> HEAD`, taking the SHA from
   `gh pr view <n> -R <owner/repo> --json mergeCommit -q .mergeCommit.oid` — if it fails, report
   and don't deploy
3. run the deploy exactly as the repo's README, docs, or deploy script/workflow documents it
4. only if the deploy succeeded, as its last shell command: `git -C <repo> worktree remove
   <worktree> && git -C <repo> branch -D feat/deploy-<feature>` — no `--force`
5. report what ran and anything left behind

Then verify on the target something this feature changed — the commit it reports contains every
task's merge (`git merge-base --is-ancestor <merge-sha> <reported-sha>`), or a route this feature
added returns what its DONE MEANS names. A health check that already passed before the deploy proves
nothing, and neither does the deploy's exit code. Once verified, confirm the deploy worktree is gone
and `tmux kill-session -t "=<name>"`; one still listed goes back to its worker first.

If the deploy or the check fails, escalate at once: what the target shows, the likely cause, and your
recommendation — roll back, fix forward with a new worker, or what the user must supply. Don't fix
it yourself, and don't redeploy without a fresh go.

## Step 7 — Report

At the end of the feature, one digest: what shipped and its PR links, what was deployed and the
evidence it is live (or why it wasn't deployed), the decisions taken and who took them, and anything
deferred or logged as an issue. Same filter as Step 4 — the digest is what happened, not a
transcript of how.

## Recovery after compaction

The board lives in this conversation, so a compaction can thin it. Rebuild it rather than guess:

```bash
tmux ls                                   # live worker sessions
gh pr list --repo <repo> --state open     # in-flight work
git -C <repo> worktree list               # what is checked out where
git -C <repo> branch -r --merged main     # what already landed
```

Plus `ListAgents`. Where anything is still ambiguous, ask the worker directly what state it is in —
far cheaper than guessing wrong.

Mid-deploy, read the target before starting anything: if it reports every task's merge, the deploy
ran — verify it. Otherwise look for a deploy still running, such as a live `…-deploy-<feature>`
session (ask it; wait only if it is still deploying), or one that failed, such as a failed run or a
deploy worktree whose session is gone (escalate it). If neither, start the deploy only on a go you
can see in the conversation; if you can't tell whether the user gave go, ask.

## Red flags

| Thought | Reality |
|---------|---------|
| "It's a one-line fix, I'll just do it" | That is the whole failure mode. It goes to a worker. |
| "The launch reason says what to do, I'll look into it" | A reason is not a goal. Orient, post five lines, ask. |
| "The worker's been quiet, it's probably fine" | Quiet is ambiguous. Ask. |
| "CI is green, send GO" | Green means the job finished. Read the verdict against the head SHA. |
| "Everything merged, I'll start the deploy — the user will want it anyway" | No go, no deploy. Ask once, with the target named. |
| "The deploy exited 0, it's live" | Exit 0 means the command finished. Read a response from the target. |
| "I'll forward this so he has the full context" | Forwarding is not filtering. Decide, then send a recommendation. |
| "The worker disagrees with the brief — ask the user" | Read its reasoning. If it's right, re-brief. Your call. |
| "Faster to spawn a session for this lookup" | A subagent is cheaper. Spawn for real tasks. |
