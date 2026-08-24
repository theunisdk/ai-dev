---
name: tdk-2-push-review
description: Push the current branch, open a PR, and drive it through CodeRabbit's review — at most two fix rounds, after which every remaining finding is dispositioned (fixed, issue-logged, or rejected with a written reason) rather than looped on — then pause for confirmation before merging to main. Explicit-invocation only: use when the user says "tdk-2-push-review" (or invokes it directly). Do NOT auto-trigger on a bare "push this" or "open a PR".
---

# tdk-2-push-review

Take a feature branch with finished work all the way to merged: **push → open PR → drive CodeRabbit's review → confirm → squash-merge to main.** The heart of it is the CodeRabbit round: verify each finding, fix what's real in one batch, answer the rest in writing. **At most two fix rounds** — the terminal state is not "zero comments", it is "every finding dispositioned": fixed, logged as an issue, or rejected on the thread with a reason. Unbounded looping is how one PR eats seven rounds — each hasty fix-push is fresh review surface that generates the next round's findings.

This is a live-repo workflow (real pushes, a real PR, a real merge), so move deliberately and never merge without the user's go-ahead.

## The one rule that's non-negotiable

**Never merge on your own.** The user wants to eyeball the final state. Do everything up to the merge, then stop and ask. Everything else below is in service of arriving at that pause with a clean PR.

## Step 1 — Preflight

- `git status` and `git branch --show-current`. If you're on `main`, stop — there's nothing to open a PR for. Ask the user what branch they meant.
- If there are uncommitted changes, commit them following the repo's Conventional Commits style (`feat(scope): …`, `fix(scope): …`, `chore(scope): …`). If `settings.json` is among the changes, commit it too — the project requires it.
- Push: `git push -u origin HEAD`.

## Step 2 — Open (or reuse) the PR

- If a PR already exists for this branch (`gh pr view --json number,url`), reuse it — don't open a duplicate.
- Otherwise: `gh pr create --base main`. Title = the Conventional Commit summary of the work. Body = a short summary plus issue-closing keywords. Use a **per-issue** closing keyword (`Closes #12, closes #15`) — a comma list like `Closes #12, #15` only closes the first.
- Capture the PR number; you'll pass it to the helper script throughout.

## Step 3 — The CodeRabbit rounds (two, maximum)

This is the core. A **round** = one review from CodeRabbit, fully dispositioned,
answered with at most one push. You get **two fix rounds**; after that, no more
fix commits — everything still open is dispositioned in place (rule 4b/4c) or
brought to the user. The cap is what makes the loop converge: every push is
fresh review surface, so round N's hasty fixes become round N+1's findings.

1. **Record the pushed commit:** `git rev-parse HEAD`.
2. **Wait for CodeRabbit to review it and list what's actionable:**
   ```bash
   python3 ~/.claude/skills/tdk-2-push-review/scripts/coderabbit.py wait --pr <PR> --sha <SHA>
   ```
   CodeRabbit usually takes a few minutes. The script polls (self-times-out at 20 min) and, once the review lands, prints `ACTIONABLE: N` followed by each unresolved, **non-nitpick** finding — its location, severity tag (🔴 Critical / 🟠 Major / 🟡 Minor / 🔵 Trivial), URL, and body. The body often includes a "Prompt for AI Agents" block with CodeRabbit's own fix guidance — read it.
   - Because CodeRabbit can be slow, prefer running this **in the background** and picking up the output when it finishes.
   - If it times out (exit 4), CodeRabbit may not have auto-triggered. Nudge it with `gh pr comment <PR> --body "@coderabbitai review"` and wait again.
3. **If `ACTIONABLE: 0` → done.** Go to Step 4.
4. **Otherwise, triage every finding in the round before fixing anything.**
   Severity tags are CodeRabbit's opinion, not ground truth — read the actual
   code first, then route each finding to exactly one disposition:
   - **(a) Real, and introduced by this PR** → fix it properly, in this
     round's batch. Don't paper over it just to silence the bot.
   - **(b) Real, but pre-existing or unrelated to this change** → **log it,
     don't fix it.** Create a GitHub issue (`gh issue create`) quoting the
     finding and location, then reply on the thread with the issue link and
     resolve it. Fixing unrelated bugs inside this PR is unreviewable scope
     creep; an issue with a link is the responsible disposition, not an
     ignored finding.
   - **(c) Wrong or not applicable** → reply to the thread with your
     reasoning and resolve it, so it leaves the actionable set. Never
     silently ignore it — and never commit the rebuttal as a code comment;
     the justification lives in the PR reply (see CLAUDE.md).
   - **Nitpicks (🧹) and trivial style points are out of scope** — the script
     already filters them out. Don't chase them.
5. **One batch, one push.** Apply all of the round's (a) fixes together. If
   the batch is substantial (new logic, changed transaction/authz boundaries —
   not mechanical one-liners), run a scoped local review over it first
   (`/review --uncommitted`, or the relevant lenses) so the *fixes* have been
   reviewed before CodeRabbit sees them — unreviewed fix commits are where
   the next round's "major" findings come from. Then check the build locally
   (`pnpm lint`, and `pnpm test` if the changes touch logic — CI runs exactly
   these), commit once (e.g. `fix(scope): address CodeRabbit round 1`), push
   once. Loop back to step 1 with the new HEAD — this consumed one of the two
   rounds.
6. **After round two**, do not push further fix commits. Disposition whatever
   remains via (b)/(c), and if anything is left that genuinely needs code
   changes, stop and bring it to the user with your read on it — a finding
   that survives two verified fix rounds needs a human decision, and grinding
   further manufactures churn.

**Don't thrash within a round either.** If one finding survives two fix
attempts, escalate it to the user rather than iterating on it.

## Step 4 — Verify CI is green

The Lint & Test check is **not** a required status check in this repo, so it won't block a merge — you have to check it yourself. Run `gh pr checks <PR>` and confirm Lint & Test passed. Never merge while it's red or still pending.

## Step 5 — Confirm, then merge

Present a short summary: PR link, what CodeRabbit findings you fixed, what you logged as issues (with links), what you rejected and why, CI status, and `ACTIONABLE: 0`. Then **ask the user to confirm the merge** — this is the pause they asked for.

On their go-ahead, squash-merge and delete the branch (the repo's convention — squash commits carry the `(#PR)` suffix):
```bash
gh pr merge <PR> --squash --delete-branch
```
**Always pass `--delete-branch`** — branches get cleaned up on every merge, so don't ask. The repo doesn't auto-delete, so omitting it strands the branch on the remote.

## Quick reference

| Need | Command |
|------|---------|
| Wait for review + list findings | `coderabbit.py wait --pr <PR> --sha <SHA>` |
| Re-list current findings (no wait) | `coderabbit.py threads --pr <PR>` |
| Nudge CodeRabbit to re-review | `gh pr comment <PR> --body "@coderabbitai review"` |
| Check CI | `gh pr checks <PR>` |

The script keys on **unresolved review threads**, so it correctly tracks findings across every push (a finding raised three rounds ago that was never addressed still shows up). It prints `ACTIONABLE: N` as the top line — that number is your loop condition. `--repo owner/name` overrides the auto-detected repo.
