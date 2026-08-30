---
description: Record what CodeRabbit caught that our local Codex pass missed
argument-hint: "<PR number or URL>"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

Close the loop between the local review and the CodeRabbit gate. Run this after
CodeRabbit has reviewed the PR: $ARGUMENTS

1. Pull CodeRabbit's findings on the PR. Try `gh pr view $ARGUMENTS --comments`
   and `gh api` for review comments. If `gh` is unavailable or unauthenticated,
   ask me to paste CodeRabbit's comments instead of guessing.

2. Diff the two reviews. Read `.review/verdict.md` for what the local pass produced,
   then classify each CodeRabbit finding:
   - **Caught locally** — we found it too. Good, no action.
   - **Missed** — CodeRabbit found a real defect our lenses did not surface.
   - **Rejected locally** — we saw it and rejected it. Re-examine the rejection
     reason: were we wrong?
   - **Noise** — CodeRabbit is wrong or it is out of scope per the rubric.

3. For every **Missed** finding, work out *why* the local pass missed it:
   - Wrong lens coverage → propose a specific "hunt specifically for"
     addition. Route it: a hazard specific to this repo goes in
     `.review/prompts.local/<lens>.md` (repo-owned overlay); one that would
     hold in any repo, or any repo on this stack, goes in the kit hub's
     `.review/prompts/<lens>.md`. The hub checkout is `$REVIEW_KIT_DIR`, or
     `~/dev/private/codex-review-kit`; `.review/kit-version` names the
     hub commit this repo last synced, so use it to check the checkout is not
     behind, not to find it. The hub is PUBLIC — strip anything identifying.
     Commit there so every repo inherits it on its next
     `scripts/review-update.sh`. Never edit `.review/prompts/` in this repo —
     the next sync overwrites it.
   - Right lens, insufficient tracing → propose a `## WATCH` line, dated,
     naming the defect class concretely — in `.review/learnings.md` if
     repo-specific, in the hub's `learnings-shared.md` if it generalises.
   - Filtered out → check whether it was below `CONFIDENCE_MIN` in
     `.review/raw/out-*.json`; if so, tell me the threshold is too aggressive.
   - Structurally out of reach (needs repo-wide index, cross-PR history, or a tool
     we do not run) → say so plainly. That is CodeRabbit earning its cost, and the
     right answer is to keep paying for it, not to bolt on more prompt.

4. Show me the proposed edits and wait for approval. Then report a one-line
   scorecard: `caught N / missed M / rejected-wrongly R / noise X`.

Track that scorecard over time. If `missed` trends toward zero on ordinary PRs,
the local pass is doing its job and CodeRabbit is pure insurance. If it does not,
the honest conclusion may be that some of CodeRabbit's value is not reproducible
this way.
