---
description: Adversarially review a design spec against the real codebase before building it
argument-hint: "<path to spec .md or directory> [extra flags]"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

Review the spec BEFORE implementation, so its holes cost a paragraph instead
of a rework. Target: $ARGUMENTS

1. Run the spec lens set:
   ```bash
   ./scripts/review.sh --spec <path> [extra flags]
   ```
   Four lenses (assumptions, holes, conflicts, ambiguity) read the spec AND
   the repository — verifying the spec's claims against real code and the
   rubric's house rules.

2. Adjudicate per `.review/adjudication.md`, with the spec-mode deltas:
   - **FIX** edits the SPEC document, not code. Minimal edits that close the
     hole; don't rewrite the author's voice.
   - **ESCALATE** is the star here, not the fallback: ambiguity findings are
     usually genuine product decisions. Collect them into one numbered list
     of questions for the user — that list is the main deliverable.
   - **LOG** applies when a lens uncovers a pre-existing codebase problem the
     spec merely walks past — file the issue, link it, keep the spec review
     on the spec.
   - REJECT with a written reason, as always. The rubric's evidence bar
     applies: a finding about the codebase must cite code the lens read.

3. Write `.review/verdict.md` as usual, then report: the escalated decision
   list in full, what was edited in the spec, and anything logged.

**One pass, no loop.** Review once, adjudicate, resolve the escalated
decisions with the user, and start building. Do not re-run on the amended
spec unless the answers changed its architecture — the implementation review
(pre-pr-review) is the next gate, and it will see the code this spec becomes.
