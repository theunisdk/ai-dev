# Review standards

Single source of truth for what "reviewed" means in this repository. Both agents
read this: `AGENTS.md` points Codex here, `CLAUDE.md` points Claude Code here.
Edit this file, not the individual prompts, when you want to change standards.

## Severity definitions

| Severity | Meaning | Action |
|---|---|---|
| `critical` | Data loss, security breach, or production outage if merged. | Must fix before PR. |
| `high` | Incorrect behaviour users will hit on a normal path. | Must fix before PR. |
| `medium` | Real defect on an uncommon path, or a trap that will cost future maintenance. | Fix, or record a written reason not to. |
| `low` | Worth knowing. Not worth blocking. | Judgement call. |

## Evidence bar

A finding is only valid if it cites a file and line the reviewer actually read,
and names the specific construct that proves the claim. No cited line, no finding.

## Out of scope for automated review

Formatting, naming, import order, documentation preferences, architectural taste,
speculative refactors, and anything a linter or formatter already enforces.

## House rules

<!-- Repo-specific standards go here. Examples to replace: -->
- Every HTTP handler must scope database reads to the caller's tenant.
- Outbound network calls require an explicit timeout.
- Database migrations must be safe to run against the previous release.
- Money is never represented as a float.

## Pipeline

1. `/review` — six parallel Codex lenses, then Claude Code adjudicates each finding.
2. Push and open the PR.
3. CodeRabbit runs as the final gate.
4. `/review-postmortem` — feed anything CodeRabbit caught that we missed back into
   `learnings.md`, so the local pass closes the gap over time.
