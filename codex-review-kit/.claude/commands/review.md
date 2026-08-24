---
description: Run the Codex review pipeline, then verify and act on every finding
argument-hint: "[base-ref | --uncommitted] [extra flags]"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

Run the pre-PR review for this repository and adjudicate the results.

Pass through to the runner: `$ARGUMENTS`

Follow `.review/adjudication.md` exactly — read it first. It is the canonical
procedure, shared with the `pre-pr-review` skill, so behaviour is identical
however the review was triggered.

The step people skip is verification: open every cited file and confirm the
evidence before deciding anything. Codex hallucinates line numbers.
