# NLDR Docs Skills — Design

**Date:** 2026-08-04
**Status:** Approved

## Problem

The `prompts/` folder contains proven prompts for generating and updating AI-optimized project documentation (`generate_documents_prompt_v2.md`, `update_documents_prompt.md`, `pr_docs_review_prompt.md`). Two problems:

1. They're copy-paste prompts, not skills — high friction to run, so docs go stale.
2. One size doesn't fit all: small projects don't need per-table docs; the full treatment is overkill and creates maintenance surface that drifts (observed in real projects).

## Goal

A set of easy-to-run skills so docs can be (re)generated at session start, kept in sync on demand, and auto-updated on PR via CI.

## Design

### Documentation convention (shared by all skills)

- `README.md` → links to `docs/INDEX.md` → links to topic docs (hierarchical).
- `docs/INDEX.md` carries a frontmatter marker: `docs-level: light` or `docs-level: full`. Update skills read this marker and maintain that depth.
- Philosophy (unchanged from the prompts): document business rules, concepts, data relationships, behavioral expectations. No code examples — AI reads the code. Reference file locations instead.

### Light mode = two files

- `README.md` — normal project readme, points to `docs/INDEX.md`.
- `docs/INDEX.md` — **is** the whole doc: what this is, architecture (conceptual), where things live (directory map), tech stack, business rules, conventions & testing. One read at session start.
- Rule even in light mode: **if a data contract exists only implicitly in code (e.g. JSONB shapes, Firestore collections), write it down.**

### Full mode = adaptive depth ("document whatever is implicit")

Validated against two real projects (amiti-awareness → light; holodek → full):

- **Implicit schema** (Firestore/Mongo, JSONB blobs): per-collection docs ARE the schema → write them.
- **Explicit schema** (Prisma, Convex `schema.ts`, SQL migrations): skip per-table docs (they duplicate and rot) → write a **data-flow / write-ownership doc** instead (who writes which counter, which tables are derived, which snapshots don't self-heal).
- Always: per-system docs for each real domain, `docs/INDEX.md` as navigation, tech-stack, architecture, improvements.

### The five skills

| Skill | Purpose | Interactive? |
|---|---|---|
| `nldr-gen-docs-light` | Generate light docs (README + self-contained INDEX) | Yes |
| `nldr-gen-docs` | Generate full docs, adaptive data-layer depth | Yes |
| `nldr-update-docs` | Gap analysis → present → apply. Reads level marker; also removes over-documentation | Presents gap analysis, waits for go-ahead |
| `nldr-pr-docs` | PR-scoped delta doc update | Never asks — CI-safe; commits to PR branch |
| `nldr-setup-docs-ci` | Install GitHub Actions workflow that runs `nldr-pr-docs` on PRs | Yes (checklist) |

Six were considered; update/PR variants per level were collapsed because the level marker lets one update skill serve both.

### Distribution

Skills are authored in this repo under `skills/` (shared with others) and symlinked into `~/.claude/skills/`.

### CI integration

`nldr-setup-docs-ci` ships a starter workflow (`references/github-workflow.yml`) using `anthropics/claude-code-action` that invokes the `nldr-pr-docs` skill on PR events. First-time setup: no existing Claude CI in any repo. The skill checks/instructs on `ANTHROPIC_API_KEY` secret and PR write permissions.

## Out of scope

- Non-GitHub CI providers.
- Auto-detection of light vs full at generation time (user picks the skill; the skill may advise if the choice looks wrong).
