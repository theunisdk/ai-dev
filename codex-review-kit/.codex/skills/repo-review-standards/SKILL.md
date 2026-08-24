---
name: repo-review-standards
description: Apply this repository's code review standards when reviewing changes, running /review, or being asked to critique a diff inside an interactive Codex session. Loads the shared rubric, severity definitions, evidence bar, and accumulated suppressions. Not needed for the automated pre-PR pipeline, which passes its full prompt directly.
---

# Repository review standards

Read these before reviewing anything here:

- `.review/rubric.md` — severity definitions, evidence bar, house rules, what is
  explicitly out of scope for automated review.
- `.review/learnings.md` — accumulated suppressions (classes of finding this repo
  has rejected repeatedly) and known blind spots.

## Method

Do not review from the diff alone. Read the changed files in full, then trace
outward: grep for callers of every changed function, read the tests that cover the
changed code, read the schemas and config the change touches. Most real defects
live at the boundary between changed and unchanged code.

## Evidence bar

Cite a file and line you actually read, and name the construct that proves the
claim. No cited line, no finding. An empty result is a good answer for a clean
diff and a much better one than padding.

## Scope

Never report formatting, naming, import order, documentation preferences,
architectural taste, or anything a linter already enforces.

---

**Note on the automated pipeline.** `./scripts/review.sh` runs six parallel
`codex exec` passes with complete, self-contained prompts built from
`.review/prompts/`. It does not rely on this skill — the prompts are passed in
full, so no discovery step is involved. This skill exists for when you are driving
Codex interactively and want the same standards applied to `/review` or an ad-hoc
critique.
