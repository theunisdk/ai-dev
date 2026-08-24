# Adjudication procedure

The canonical procedure for acting on Codex review findings. The `/review`
command and the `pre-pr-review` skill both delegate here so the behaviour is
identical however the review was triggered. Edit this file, not its callers.

## 1 — Run

```
./scripts/review.sh [base-ref | --uncommitted]
```

Several minutes; lenses run in parallel. If it exits non-zero for a setup reason,
fix that and stop — do not substitute a hand-rolled review.

Then read `.review/findings.json`.

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

## 3 — Classify

Exactly one disposition per finding:

- **FIX** — verified, worth changing now.
- **REJECT** — verified wrong, out of scope per `.review/rubric.md`, or a
  deliberate choice. **A one-line reason is mandatory.** "Not an issue" is not a
  reason; "callers already hold the lock, see `pool.rs:88`" is.
- **ESCALATE** — real, but the fix is a judgement call, a scope increase, or
  touches something you should not decide alone. Leave the code untouched.

`critical` and `high` are FIX or ESCALATE — never REJECT without an explicit
verified reason. `medium` is FIX unless there is a reason. `low` is judgement.

## 4 — Apply

Apply all FIXes with the minimal change that removes the defect; do not
opportunistically refactor. Group related fixes into coherent commits.

Run the project's tests and type checker. If a fix breaks a test, decide whether
the test encoded the bug — and say which, explicitly.

## 5 — Write the verdict

Write `.review/verdict.md`. Include the HEAD short SHA in the header so the
pre-push hook can tell whether the verdict is current.

```markdown
# Review verdict — <branch> — <short-sha> — <date>

<n> findings · <f> fixed · <r> rejected · <e> escalated
Lenses: <list> · Effort: <effort>

| ID | Sev | Agree | File:line | Finding | Disposition | Reason |
|----|-----|-------|-----------|---------|-------------|--------|

## Escalated — needs a human decision
<one short paragraph each, trade-off stated>

## Rejected
<ID — reason, one line each>

## Verification
<test / typecheck / lint results after fixes>
```

## 6 — Report back

In chat: the counts, every ESCALATE in full, and any REJECT you are less than
certain about. Do not re-narrate the fixes — the verdict file has them.

CodeRabbit still runs as the final gate on the PR. The goal is for it to find
nothing, not to substitute for it.
