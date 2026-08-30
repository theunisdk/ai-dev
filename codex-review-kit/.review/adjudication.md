# Adjudication procedure

The canonical procedure for acting on Codex review findings. The `/review`
command and the `pre-pr-review` skill both delegate here so the behaviour is
identical however the review was triggered. Edit this file, not its callers.

## 1 — Run

```
./scripts/review.sh [base-ref | --uncommitted | --spec <path>]
```

(`--spec` reviews a design document instead of code — see the `/review-spec`
command for the mode's adjudication deltas; the rest of this procedure
applies unchanged.)

Several minutes; lenses run in parallel. If it exits non-zero for a setup reason,
fix that and stop — do not substitute a hand-rolled review.

Then read `.review/findings.json`, and **check `complete` before anything else.**
A lens that died usually contributes an empty findings array, which is
indistinguishable from a lens that ran and found nothing — so a partial run
reads as a clean pass unless you look. If `complete` is false, `lenses_failed`
names the lenses whose areas went unreviewed. A failed lens may still have
contributed findings (partial output salvaged before it died): treat those as
real, but never as evidence its area was covered. Fix the cause and re-run,
or, if you genuinely must proceed, say plainly in the verdict and to the user
which lenses did not finish.
Never report a run with `complete: false` as a clean review.

## 2 — Verify before you trust

**Codex hallucinates line numbers and occasionally invents behaviour.** For every
finding, before deciding anything:

- Open the cited file and read the cited region yourself.
- Confirm the construct in `evidence` actually exists there.
- Confirm the failure in `why_it_matters` is reachable — trace callers if the
  finding depends on how the code is called.

Evidence that does not survive this is `REJECT (unverifiable)` regardless of the
confidence Codex claimed.

Findings carry an `agreement` count — how many independent lenses reported the
same defect. Agreement above 1 is the strongest signal in the report; verify those
first. It is not a substitute for verifying.

The merge collapses duplicates only when titles match, so lenses often report
one defect under several wordings — especially in spec mode. Before verifying,
group findings that cite the same or adjacent lines, check whether they are one
issue, and dispose of the group together; treat the group's size as its real
agreement count. (Same-line findings are not automatically one issue — read
them.)

## 3 — Classify

Exactly one disposition per finding:

- **FIX** — verified, worth changing now.
- **LOG** — verified real, but pre-existing or unrelated to this change. File
  it in the repo's tracker (`gh issue create`, quoting the finding and
  location) and record the issue link in the verdict. **Do not fix it here**
  — an unrelated fix inside this diff is unreviewable scope creep; the issue
  link is the responsible disposition, not an ignored finding.
- **REJECT** — verified wrong, out of scope per `.review/rubric.md`, or a
  deliberate choice. **A one-line reason is mandatory.** "Not an issue" is not a
  reason; "callers already hold the lock, see `pool.rs:88`" is.
- **ESCALATE** — real, but the fix is a judgement call, a scope increase, or
  touches something you should not decide alone. Leave the code untouched.

`critical` and `high` are FIX or ESCALATE — never REJECT without an explicit
verified reason, and LOG only if the defect genuinely predates this change (a
critical the diff made newly reachable is this PR's problem). `medium` is FIX
unless there is a reason. `low` is judgement.

## 4 — Apply

Apply all FIXes with the minimal change that removes the defect; do not
opportunistically refactor. Group related fixes into coherent commits.

Run the project's tests and type checker, plus the lint/analyzer gate wired in
`.review/analyzers.local.sh` — that pass ran before the lenses, so nothing has
ever linted the code you just wrote. If a fix breaks a test, decide whether the
test encoded the bug — and say which, explicitly.

If the fixes amount to substantial new code — new logic or a changed
transaction, authz, or rollout boundary, not mechanical corrections — run ONE
scoped re-review over them (`--uncommitted`, relevant lenses only) before
writing the verdict: fixes applied during adjudication are otherwise the only
unreviewed code in the change, and it is exactly where downstream reviews land
their hits. Adjudicate that re-review's findings without a further re-pass —
one bounded loop, not a cycle.

## 5 — Write the verdict

Write `.review/verdict.md`. Include the HEAD short SHA in the header so the
pre-push hook can tell whether the verdict is current.

```markdown
# Review verdict — <branch> — <short-sha> — <date>

<n> findings · <f> fixed · <l> logged · <r> rejected · <e> escalated
Lenses: <list> · Effort: <effort>

| ID | Sev | Agree | File:line | Finding | Disposition | Reason |
|----|-----|-------|-----------|---------|-------------|--------|

## Escalated — needs a human decision
<one short paragraph each, trade-off stated>

## Rejected
<ID — reason, one line each>

## Verification
<test / typecheck / lint + analyzer results after fixes>
```

## 6 — Report back

In chat: the counts, every ESCALATE in full, and any REJECT you are less than
certain about. Do not re-narrate the fixes — the verdict file has them.

CodeRabbit still runs as the final gate on the PR. The goal is for it to find
nothing, not to substitute for it.
