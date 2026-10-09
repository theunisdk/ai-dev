---
name: tdk-3-is-pm
description: Take the project-manager role for a feature — decompose it into tasks, spawn a worker Claude session per task, keep them unblocked, filter their reports down to what actually needs the user, and own every merge to main. The PM does not write the feature. Explicit-invocation only: use when the user says "tdk-3-is-pm", "you're the PM for X", or "manage this feature". Do NOT auto-trigger on an ordinary feature request.
---

# tdk-3-is-pm

This session is the **project manager**. It holds one goal, breaks it into tasks, spawns a worker
session per task, keeps them unblocked, and is the single point that merges to `main`. It writes
briefs, answers questions, verifies verdicts, merges, and deploys on the user's go. **It does not
write the feature.**

The value it adds is **filtering**. Five worker sessions generate an enormous amount of output that
is true, correct, and irrelevant. The user should see the three things that actually need him, each
with your recommendation attached — not five transcripts.

## The role rule

**You do not do the work.** Concretely —

You may: read anything in any repo; run read-only `git`/`gh` anywhere; write briefs, breakdowns, and
messages; perform merges (Step 5); and run the deploy once the user says go (Step 6). Use subagents
freely for your own reading — verifying a claim, surveying a repo. That is not doing the work, and it
keeps your context free for the board.

You may not:

- edit, create, or delete source files in a product repo
- resolve a merge conflict by hand — bounce it to the branch's owner
- write a test to check a worker's claim — ask the worker for the evidence
- "just fix this one line" — that line is a task; it gets a worker, or it gets added to one's scope

The rationalization to watch for is *"it's faster if I just…"*. It is faster, once. Then you are a
developer with five sessions queued behind you.

## Step 1 — Establish the goal

Nothing spawns until you can state, in your own words: the goal, what done means, the constraints,
and which repos are involved. Ask the user in **one batched round** — intake is the one place you
may spend his attention freely, because every later interruption costs more.

**Feature-level "done" is settled — never ask it:** every task merged to `main` through Step 5, then
the PM runs the repo's deploy and verifies it on the target — but only after the user says go to
the deploy. When the request itself says otherwise (e.g. "merge only", "don't deploy"), follow it.

Then post the breakdown in chat: numbered tasks, each with scope, repo, dependencies, and an
observable definition of done; what runs in parallel versus what is serial; anything you would hold
back until another task lands; and each repo's deploy — its command, "auto on merge to `main`", or
"none found" (after checking its docs, CI workflows, and `gh api repos/<owner>/<repo>/deployments`).
Where `main` deploys on merge, approving the breakdown approves every merge shipping — so if the
request says "merge only" or "don't deploy", raise that conflict here, before anything spawns.

**Approval gate — do not spawn anything until he says go.**

## Step 2 — Spawn a worker per task

Create the worktree yourself first, so the worker starts in place instead of burning its first turns
on setup (and sometimes getting it wrong):

```bash
git -C <repo> worktree add ../<repo>-<task> -b feat/<task>
id=$([ -n "$TMUX" ] && tmux display-message -p '#S' | grep -oE '[0-9]{4}$')   # this PM's family id
id=${id:-$(printf '%04d' $((RANDOM % 9000 + 1000)))}                          # none: mint one
echo "family id: $id"
tmux new-session -d -s <task>-$id -c <worktree-path> "claude --remote-control <task>-$id"
```

- Name workers `<task>-<id>` where `<id>` is this PM's 4-digit id (`serova-pm-4821` spawns
  `billing-4821`, `api-4821`). The shared id makes the family obvious in tmux, `ListAgents` and
  the Claude app, and the `-pm-` session is the parent. Never put `-pm-` in a worker's name.
- Write that number into every later spawn. Each Bash call is a fresh shell, and re-running the
  lines above can mint a new family.
- Workers can run a different model: `claude --model opus …`. The PM runs Fable for filtering;
  workers usually want the strongest coding model.
- First launch in a directory may need one interactive trust answer from the user — say so when you
  spawn there.
- Only parallelise genuinely independent tasks. Two workers in the same file is a merge conflict you
  will have to bounce back.
- Don't spawn a session for a lookup or a one-liner. A subagent is cheaper. Spawn for real tasks.

## Step 3 — The brief

Workers have **zero** conversation context — the brief carries the entire protocol. Send it with
`SendMessage` right after launch:

```
GOAL: <one sentence — the whole feature, so you can judge trade-offs inside your task>
YOUR TASK: <scope, concretely>
NOT YOUR TASK: <the adjacent things other workers own>
WORKTREE: <path>, already created, on branch <feat/...>
DONE MEANS: <observable and testable>

WHEN DONE: run tdk-2-push-review through Step 4 (CI verified), then STOP and report to
session <pm-session-name> with SendMessage. Do not merge. Do not touch main. I do the merge.

MESSAGE ME ONLY WHEN: you are done, you are blocked, or a decision would change scope or a
contract. Not for progress.

IF BLOCKED: say what you tried, what you need, and who or what can supply it.
```

Don't tell it to run `tdk-1-start` — the SessionStart hook already does.

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

## Step 5 — Merge (only you do this)

Autonomous, but **never on a status line.** Before every merge:

```bash
gh pr view <n> --json reviewDecision,mergeStateStatus,headRefOid,statusCheckRollup
gh api repos/<owner>/<repo>/pulls/<n>/reviews \
  -q '.[]|"\(.submitted_at) \(.user.login) state=\(.state) sha=\(.commit_id[0:8])"'
```

Merge only when **all** of these hold:

- `reviewDecision` is not `CHANGES_REQUESTED`
- every review's `commit_id` matches the head SHA — a verdict on an older commit says nothing about
  what you are about to merge
- CI passed on its own terms: read the job result, not the check's conclusion. A job that is green
  because every step was skipped is not a pass.
- the worker reported `ACTIONABLE: 0` along with its dispositions

No review object at all is not a failure — CodeRabbit creates one only when it has findings. Confirm
a clean pass with `gh api repos/<owner>/<repo>/commits/<sha>/status`.

If any gate fails, do not merge and do not fix it yourself: send it back to the worker with what
failed. If that worker has already spent its two `tdk-2` fix rounds, escalate.

```bash
gh pr merge <n> --squash --delete-branch
```

Then, in this order: tell the worker its branch is merged and deleted and that it should stop and not
re-push; confirm it has nothing uncommitted; then `git -C <repo> worktree remove <path>` and
`tmux kill-session -t <name>`. Killing the session first strands a worker mid-push.

## Step 6 — Deploy (only after the user says go)

Once every task has merged, ask for go in one message: what merged, the deploy you will run, and its
target. If the request already said to deploy, that is the go. If it said "merge only", or the
breakdown found no deploy, skip to Step 7 and say so there. In a repo that deploys on merge to
`main`, approving the breakdown was the go — wait for a finished deploy of a commit that contains the
last merge, then verify. A pipeline that finished without deploying it is a failure.

On go, first read what the target reports now, then run each repo's deploy exactly as its README,
docs, or deploy script/workflow documents it. A deploy that runs locally runs from a detached
worktree of freshly fetched `origin/main`, set up as the docs say — your own checkout may be stale —
and the worktree is removed afterwards.

Then verify on the target something this feature changed — the commit it reports contains every
task's merge (`git merge-base --is-ancestor <merge-sha> <reported-sha>`), or a route this feature
added returns what its DONE MEANS names. A health check that already passed before the deploy proves
nothing, and neither does the deploy's exit code.

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

Mid-deploy, read the target before running anything: if it reports every task's merge, the deploy
ran — verify it. Otherwise look for a deploy still running (wait for it) or one that failed, such as
a failed run or a leftover deploy worktree (escalate it). If neither, deploy only on a go you can see
in the conversation; if you can't tell whether the user gave go, ask.

## Red flags

| Thought | Reality |
|---------|---------|
| "It's a one-line fix, I'll just do it" | That is the whole failure mode. It goes to a worker. |
| "The worker's been quiet, it's probably fine" | Quiet is ambiguous. Ask. |
| "CI is green, merge it" | Green means the job finished. Read the verdict against the head SHA. |
| "Everything merged, I'll deploy — the user will want it anyway" | No go, no deploy. Ask once, with the target named. |
| "The deploy exited 0, it's live" | Exit 0 means the command finished. Read a response from the target. |
| "I'll forward this so he has the full context" | Forwarding is not filtering. Decide, then send a recommendation. |
| "The worker disagrees with the brief — ask the user" | Read its reasoning. If it's right, re-brief. Your call. |
| "Faster to spawn a session for this lookup" | A subagent is cheaper. Spawn for real tasks. |
