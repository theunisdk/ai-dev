---
name: review-kit-install
description: Use when the user asks to implement, install, add, or set up "the review kit", "the codex review pipeline", or "pre-PR review" in a repository that doesn't have it yet. Bootstraps the kit from the theunisdk/ai-dev hub and then adapts it to the repo properly. Not for repos that already have .review/ — there, use the repo's own /review-onboard or scripts/review-update.sh.
user-invocable: true
---

# review-kit-install

Install the codex review kit (multi-lens pre-PR review: parallel Codex lenses
→ Claude adjudication → CodeRabbit gate) into the current repository, as a
spoke of the shared hub.

**The hub:** `github.com/theunisdk/ai-dev`, directory `codex-review-kit/`.
Prefer a local clone if one exists (commonly `~/dev/private/ai-dev`); the
public GitHub repo is the fallback and always works.

## Steps

1. **Preconditions**: inside a git repo; `git`, `jq`, and `codex`
   (authenticated) on PATH. If `.review/rubric.md` already exists, stop —
   this repo has the kit; run `scripts/review-update.sh` to update it
   instead.

2. **Bootstrap** the machinery and templates:
   ```bash
   # local hub clone:
   REVIEW_KIT_DIR=~/dev/private/ai-dev/codex-review-kit \
     bash ~/dev/private/ai-dev/codex-review-kit/scripts/review-update.sh --init
   # or, no local clone:
   curl -fsSL https://raw.githubusercontent.com/theunisdk/ai-dev/main/codex-review-kit/scripts/review-update.sh -o /tmp/ru.sh
   bash /tmp/ru.sh --init
   ```
   Then `./scripts/review-install.sh` (per-machine: codex profile pinned to
   the fleet-standard model, git hooks, AGENTS.md/CLAUDE.md pointers).

3. **Adapt — this is where the value is.** The bootstrap put
   `.claude/commands/review-onboard.md` in the repo. Follow it exactly: it
   covers the stack survey, verified analyzer wiring, the grounded rubric
   (its law: every house rule cites code you actually read — an invented
   rule is worse than none), per-lens hazard overlays, misfire facts, the
   fire drill, and the commit. Read the repo's new `REVIEW.md` and
   `OPERATING.md` for the system you are wiring up.

4. **Report** to the user what the onboard command's final step specifies:
   the grounded house rules with evidence, anything you could not ground,
   and the fire-drill outcome.
