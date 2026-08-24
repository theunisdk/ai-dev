---
name: pre-pr-review
description: Run the repository's multi-lens Codex review pipeline and adjudicate its findings. Use whenever the user is finishing a change and about to commit, push, open a pull request, or asks to review, check, sanity-check, or look over their changes or diff before shipping — including phrasings like "I'm done", "ready to push", "does this look right", or "anything I missed". Do NOT use for reviewing a single snippet pasted into chat, or for reviewing someone else's PR on GitHub.
---

# Pre-PR review

This repository has a review pipeline. **Use it instead of reviewing the diff
yourself** — an ad-hoc read of the diff is exactly the weaker review this pipeline
exists to replace, and skipping it silently gives the user false confidence.

Six narrow Codex lenses (correctness, security, contracts, resources, tests,
scope) run in parallel against the branch diff, each tracing outward into callers,
tests, and config rather than reading hunks in isolation. Your job is the
adjudication half: verify what Codex claims, fix what is real, reject what is not,
and escalate what needs a human.

**Follow `.review/adjudication.md` exactly.** Read it now — it is the canonical
procedure and it is short.

Two things that go wrong if you improvise:

- **Skipping verification.** Codex hallucinates line numbers. Applying findings
  unverified is worse than no review, because the diff grows and nothing was
  actually checked.
- **Rejecting your own work.** If you wrote the code under review, you have a
  structural bias toward rejecting findings about it. That is why every REJECT
  needs a written reason — an unstated rejection is not a judgement, it is a skip.

Standards live in `.review/rubric.md`; accumulated suppressions and known blind
spots live in `.review/learnings.md`. Read the rubric before classifying anything
as out of scope.

If the pipeline is not set up in this repository (`scripts/review.sh` missing),
say so and offer to run `./scripts/review-install.sh` — do not silently fall back
to reviewing the diff yourself.
