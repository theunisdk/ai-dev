# Codex pre-PR review kit

Six narrow, parallel Codex review passes over your branch diff, merged into
structured findings, adjudicated by Claude Code, gated by CodeRabbit on the PR.
Once it's wired up, read **OPERATING.md** — how to prove the pipeline works
(scorecard, fire drills) and the quiet failure modes to watch.

The design premise: a single "review this diff" pass gets you roughly what Claude
Code already gives you. The quality comes from **decomposition** — several
reviewers each with a tight brief and enough budget to trace outward from the
diff into callers, tests, and config.

## Pipeline

```
  branch with changes
        │
        ├─ scripts/review.sh ──┬─ correctness ─┐
        │                      ├─ security     │
        │  (+ linters/semgrep  ├─ contracts    ├─→ .review/findings.json
        │     first, as priors)├─ resources    │   .review/findings.md
        │                      ├─ tests        │
        │                      └─ scope      ──┘
        │
        ├─ /review in Claude Code
        │     verifies each finding against real code
        │     → FIX / LOG(issue) / REJECT(reason) / ESCALATE
        │     → .review/verdict.md
        │
        ├─ push → PR → CodeRabbit (final gate)
        │
        └─ /review-postmortem <PR>
              what CodeRabbit caught that we missed → .review/learnings.md
              → next run is better
```

## Install

**Requires:** `git`, `jq`, `codex` (authenticated). Optional but recommended:
`semgrep`, `gitleaks`, plus your language's linter.

**Hub and spokes.** The kit's source of truth is one public hub
(`github.com/theunisdk/codex-review-kit`). Each repo is a spoke: it
vendors the shared machinery via `scripts/review-update.sh` and commits it,
alongside the files that are its own and never synced:

| | lives | moves |
|---|---|---|
| runner, lens prompts, schema, adjudication, commands, skill, hooks | hub → synced into every spoke | `scripts/review-update.sh` |
| `learnings-shared.md` (generic + stack lessons) | hub → synced read-only | same |
| `rubric.md`, `config.sh`, `learnings.md`, `prompts.local/`, `analyzers.local.sh` | spoke only | never |

**New repo:** say `/review-onboard` in Claude Code — it bootstraps the files
and, more importantly, does the adaptation properly: a rubric grounded in code
it actually read, analyzer commands verified before wiring, concrete lens
hazards, and a fire drill to prove the result. By hand, the bootstrap is:

```bash
# From a local hub clone — no download, and the default path:
REVIEW_KIT_DIR=~/dev/private/codex-review-kit \
  bash ~/dev/private/codex-review-kit/scripts/review-update.sh --init
# Without one, pin the fetch to a reviewed commit rather than the mutable `main`,
# and read it before running it — the next line executes whatever it downloaded.
./scripts/review-install.sh          # per-machine setup
# then adapt the repo-owned files — all of them live under .review/:
#   .review/rubric.md  .review/learnings.md  .review/config.sh
#   .review/analyzers.local.sh  .review/prompts.local/
git add .review scripts .claude .codex .githooks .claude-plugin REVIEW.md OPERATING.md AGENTS.md CLAUDE.md
git commit -m "chore: add codex pre-PR review pipeline"
```

**Every other machine:** clone the repo, run `./scripts/review-install.sh`.
Everything repo-specific is committed; the only per-machine artifact is
`~/.codex/deep-review.config.toml`, which the installer creates if absent and
never overwrites. `--check` verifies without changing anything.

**Picking up kit improvements:** `./scripts/review-update.sh` in any spoke —
it overwrites the synced half, records the hub commit in `.review/kit-version`,
and leaves the repo-owned half alone. Fix a machinery bug or add a generic
lesson once, in the hub; every repo inherits it on its next sync.

`make-plugin.sh` still exists for a Claude Code plugin build, but the runner
reads prompts from the repo, not `${CLAUDE_PLUGIN_ROOT}` — the vendored spoke
layout is the supported path; the plugin is untested sugar.

## Use

```bash
./scripts/review.sh                    # vs auto-detected base branch
./scripts/review.sh origin/develop     # explicit base
./scripts/review.sh --uncommitted      # working tree, before you commit
./scripts/review.sh --spec docs/specs/foo.md   # review a DESIGN DOC pre-build
./scripts/review.sh --lenses security,contracts --effort xhigh
./scripts/review.sh --fail-on high     # exit 2 if anything high+ (for CI)
```

In Claude Code:

| Trigger | Does |
|---|---|
| **skill** `pre-pr-review` | Fires on its own when you're wrapping up — "ready to push", "does this look right", "anything I missed" |
| `/review` | Same thing, explicitly, with arguments |
| `/review-onboard` | Wires the kit into a new repo: grounded rubric, verified analyzers, fire drill |
| `/review-spec <path>` | Reviews a design doc pre-build: assumptions verified against the repo, holes, conflicts, ambiguity |
| `/review-tune` | Folds recurring rejections into `learnings.md` to cut noise |
| `/review-postmortem <PR>` | Records what CodeRabbit caught that we missed |

Both the skill and the command delegate to `.review/adjudication.md`, so the
behaviour is identical however the review started. Edit that file to change what
adjudication means; don't edit the callers.

The verification step is the point. Codex hallucinates line numbers and
occasionally invents behaviour; findings applied unverified are worse than no
review at all.

## Skills: which tool needs one, and why

**Claude Code: yes — for discovery.** Slash commands only fire when typed. Without
the skill, saying "ok, that's done, let's push" gets you an ad-hoc read of the
diff — the weaker review this pipeline exists to replace. The skill's description
is tuned to trigger on that class of phrasing, and its body tells Claude Code not
to improvise a review instead.

**Codex: no, not in the hot path.** Skills exist for progressive disclosure — the
agent sees descriptions, then loads the full `SKILL.md` when it judges a match.
But `scripts/review.sh` calls `codex exec "<the entire prompt>"`. We already know
what we want and pass it in full, so a skill would be pure indirection: same
tokens, plus a new failure mode where it fails to trigger. The layer Codex
actually reads automatically is `AGENTS.md`, which the installer writes.

`.codex/skills/repo-review-standards/` ships anyway, for when you drive Codex
interactively (`/review` in the TUI, ad-hoc critique) and want the same rubric
applied. It is genuinely optional — delete it and the pipeline is unaffected.

## Tuning

You said start hard and tone down. Defaults reflect that: all six lenses, `high`
effort, `0.5` confidence floor. Dial back in `.review/config.sh` (committed, so
every machine agrees) in roughly this order:

1. **Confidence floor → 0.7.** Cheapest noise reduction, costs nothing in time.
2. **Drop lenses.** `scope` and `tests` are the usual first cuts on small diffs.
3. **Effort → medium.** Do this last, and A/B it — more thinking is not reliably
   better here. One published benchmark found a Codex model scoring *worse* at
   high effort than medium, because the extra tokens forced context compaction.
   Your mileage will vary by model; measure on a PR where you know the answer.

Going the other way: `--effort xhigh` (model-dependent), lower the confidence
floor to `0.3`, or add a seventh lens — copy any `prompts/*.md`, write a "hunt
specifically for" list, add the name to `LENSES`.

## The two feedback loops

These are what make it improve rather than plateau:

**Noise down** (`/review-tune`): recurring REJECT reasons become SUPPRESS entries
in `learnings.md`, injected into every future prompt. Requires two occurrences —
one rejection is a one-off.

**Coverage up** (`/review-postmortem`): every CodeRabbit finding you missed gets
diagnosed — wrong lens, insufficient tracing, filtered by threshold, or
structurally out of reach — and turned into a prompt edit or a WATCH entry.

Both commands **route** each lesson before writing it: repo-specific lessons
land in the repo's `learnings.md` or `prompts.local/`; anything that would hold
in another repo goes to the hub (`learnings-shared.md` or a base prompt),
scrubbed of repo and client specifics since the hub is public. That routing is
what makes a bug found in one repo teach every other repo on its next
`review-update.sh`.

Track the postmortem scorecard. If `missed` trends toward zero, the local pass is
working and CodeRabbit is insurance. If it plateaus, the honest read is that part
of CodeRabbit's value (repo-wide indexing, cross-PR memory, its analyzer fleet)
isn't reproducible this way — which is fine, since it's still your final gate.

## Layout

```
.review/
  rubric.md            REPO-OWNED  standards — single source of truth
  learnings.md         REPO-OWNED  this repo's memory, never leaves it
  config.sh            REPO-OWNED  posture (all values commented out = defaults)
  analyzers.local.sh   REPO-OWNED  stack wiring, replaces the generic stanzas
  prompts.local/       REPO-OWNED  per-lens hazard overlays, appended at run time
  adjudication.md      synced      verify → FIX/LOG/REJECT/ESCALATE → verdict
  learnings-shared.md  synced      kit-wide memory, edited only in the hub
  kit-version          synced      which hub commit this repo last pulled
  schema.json          synced      enforced output shape via codex --output-schema
  prompts/             synced      the shared lens prompts — never edit in a repo
    _common.md         role, method, hard exclusions, calibration
    correctness.md     logic, nulls, async ordering, contract drift
    security.md        authz, injection, SSRF, secrets, crypto, limits
    contracts.md       API breaks, migrations, rolling-deploy safety
    resources.md       races, locks, leaks, N+1, timeouts, transactions
    tests.md           would these tests have caught it? the revert test
    scope.md           intent fidelity, debug residue, operability
    _common-spec.md    spec-mode role and method (claims verified in-repo)
    spec-*.md          spec lenses: assumptions, holes, conflicts, ambiguity
scripts/               all synced
  review.sh            the runner
  review-update.sh     pull the shared half from the hub
  review-install.sh    idempotent per-machine setup
  lib/common.sh        portable helpers (macOS bash 3.2 safe)
  lib/analyzers.sh     generic analyzer collection; defers to analyzers.local.sh
.claude/               synced: /review, /review-tune, /review-postmortem + skill
.codex/                synced: optional interactive-Codex skill
.claude-plugin/        synced: plugin manifests
.githooks/pre-push     synced: warns on a stale verdict; never blocks
templates/             hub only: seeds for the repo-owned files (--init)
```

## Notes and gotchas

- **Codex profiles moved.** Since 0.134.0, `--profile` no longer reads
  `[profiles.name]` tables from `config.toml`. Each profile is its own file with
  top-level keys: `~/.codex/deep-review.config.toml`. If you copy a profile from
  an older blog post it will silently do nothing.
- **Model names churn.** The profile pins `gpt-5.6-sol` — the current standard
  for code reviews. When it stops resolving, check `/model` in the Codex TUI for
  what your plan exposes and re-pin; note the effort vocabulary is
  model-specific (sol: `none|low|medium|high|xhigh|max`, no `minimal`).
- **Reviewers are read-only.** Every lens runs `--sandbox read-only`; the
  deep-review profile supplies `approval_policy = "never"`, since codex 0.149
  removed `--ask-for-approval`. They can grep your repo for context but cannot
  touch your working tree — only Claude Code writes, and only after verification.
- **A lens failing is non-fatal.** Others still run; check `.review/raw/log-*.txt`.
  Only a total failure aborts.
- **Adjudication has a bias problem.** Claude Code reviewing findings about code
  Claude Code just wrote will tend to reject. The mandatory written reason helps.
  Spot-check a sample manually for the first couple of weeks anyway.
- **Add your stack's linters** to `.review/analyzers.local.sh` (never to
  `scripts/lib/analyzers.sh`, which the next sync overwrites). Their output is
  fed to Codex as "already covered, don't re-report" — which is what pushes the
  lenses toward semantic bugs instead of lint-level noise.
