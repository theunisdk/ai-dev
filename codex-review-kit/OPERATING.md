# Operating the review kit: proving it, and what to watch

REVIEW.md explains what the pipeline is. This file is the operator's guide:
how to know it is actually working, and the failure modes that experience has
already demonstrated. Synced into every spoke alongside REVIEW.md.

## Proving it as you go

Two mechanisms, one you already own and one you run deliberately.

### The postmortem scorecard (the designed proof)

After CodeRabbit reviews each PR, run `/review-postmortem <PR>`. It yields
`caught N / missed M / rejected-wrongly R / noise X`. That is the metric:

- **`missed` trending toward zero** over a run of PRs → the local pass is
  doing CodeRabbit's job and CodeRabbit is insurance.
- **`missed` plateauing** → that residue is the part of CodeRabbit's value
  this pipeline cannot reproduce (repo-wide indexing, cross-PR memory, its
  analyzer fleet). Knowing precisely what you're paying for is the point.

Run the postmortem on **every** PR at first, including clean ones — "nothing
missed" is a data point, and skipping it silently stops the learning loop.

### Fire drills (the stronger, faster proof)

Don't wait for real bugs — plant them. On a scratch branch, commit a
deliberate violation of one of your repo's house rules and run
`./scripts/review.sh` against it. Choose violations that are invisible to
lint and tests, i.e. exactly what the rubric exists for. If a lens misses a
planted violation of a rule written in its own prompt overlay, you've found a
prompt problem for the cost of one throwaway branch.

This is mutation testing for the review system itself. Do two or three drills
per repo when you first wire it up, and again after any significant prompt or
model change.

### Plumbing spot-checks

For the first few runs, look under the hood:

- `.review/raw/log-<lens>.txt` — did all lenses actually produce output?
- `.review/raw/analyzers.txt` — does it contain real sections for your stack?
- `.review/raw/prompt-<lens>.md` — is your `prompts.local/` overlay and both
  learnings files present in the assembled prompt?

## What to be aware of

### This system fails quiet, not loud

The record so far, all found before the first paid review ran:

- The stock `_files_matching` helper never matched a multi-extension pattern
  (`case` treats an expanded `|` literally), so every per-language analyzer
  stanza was silently dead. The runs "succeeded" with an empty report.
- eslint 9 removed the `--format unix` flag the kit passed; with stderr
  discarded, lint "ran" and reported nothing.
- Codex 0.149 removed `--ask-for-approval`; every lens would have failed
  with a usage error, each one non-fatally.

The pattern: broken looks identical to clean. Treat an empty findings list on
a substantial diff as suspicious, not reassuring, and check the raw logs. A
single lens dying is a warning line, not an abort.

### Adjudication bias

Claude Code verifying findings about code Claude Code just wrote leans toward
REJECT. The mandatory written rejection reason helps; the scorecard's
`rejected-wrongly` column exists to catch it. For the first weeks, read a
sample of rejections yourself.

### Never apply an unverified finding

Codex hallucinates line numbers and occasionally invents behaviour. The
adjudication step — open the cited file, confirm the evidence — is the whole
point of the design. Findings applied unverified are worse than no review.

### Suppression discipline

- `/review-tune` requires the same rejection **twice** before suppressing —
  one occurrence is a one-off.
- Never suppress a class that ever produced a genuine FIX.
- Keep `learnings.md` under ~60 lines; past that it dilutes every prompt.
- Watch the "LOG, but pulled into scope" pattern: occasionally a logged
  pre-existing bug genuinely blocks the change and must ride along — but it
  needs the user's explicit sign-off and a written reason, or log-don't-fix
  quietly becomes fix-everything-here.

### Hub/spoke discipline

- Never edit synced files (`.review/prompts/`, `scripts/`,
  `.review/adjudication.md`, `learnings-shared.md`) inside a repo — the next
  `review-update.sh` silently overwrites them. Repo changes go in `prompts.local/` and
  `analyzers.local.sh` only.
- When a lesson generalises, confirm it actually landed as a **hub commit**,
  not just a note in the repo — routing only works if the hub receives it.
- The hub is public: nothing routed there may carry client, repo, schema, or
  incident specifics.
- Updates are pull-based. Nothing notifies a spoke that the hub improved;
  run `review-update.sh` when you've pushed a lesson from another repo.

### Cost and depth dials

Six lenses at `high` effort is the deliberate "start hard" posture. If it
feels slow before it feels shallow, dial back in this order: confidence floor
to 0.7 → drop `scope`/`tests` on small diffs → effort to `medium`, and A/B
that last one — more thinking is not reliably better.

### Model pinning

The profile pins `gpt-5.6-sol` — the current standard for code reviews. Two
things follow:

- Effort vocabulary is model-specific: sol accepts
  `none | low | medium | high | xhigh | max` (no `minimal`). An unsupported
  value fails the lens with a 400 — nothing surfaces on the console, but the
  response is in `.review/raw/log-<lens>.txt`.
- When the pin stops resolving or reviews suddenly feel shallow, check
  `/model` in the Codex TUI and re-pin in
  `~/.codex/deep-review.config.toml` before blaming the prompts.

## Reviewing specs before building

The same pipeline points at design documents: `/review-spec <path>` (or
`./scripts/review.sh --spec <path>`) runs four spec lenses — assumptions,
holes, conflicts, ambiguity — that read the spec AND the repository,
verifying every claim the spec makes about existing code and checking it
against the rubric's house rules.

Why it earns its cost: a hole found in a spec costs a paragraph; the same
hole found in code review costs a fix round. And the ambiguity lens directly
counters the implementer-assumption problem — every two-readings statement is
a decision the builder would otherwise make silently; the lens turns them
into an explicit question list you answer before the build starts.

Discipline mirrors the code side: one pass per spec, adjudicate (FIXes edit
the spec; ambiguities usually ESCALATE — that question list is the main
deliverable), resolve, build. No loops.

## The one habit

When CodeRabbit or production catches something this pipeline missed, the
postmortem is not paperwork — it is the only path by which the system gets
smarter, and the routing step is the only path by which one repo's lesson
reaches the others. Skip it and you own a static tool; run it and you own the
loop this was built for.
