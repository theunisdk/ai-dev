---
name: nldr-gen-docs-light
description: Use when the user asks to generate light/simple project docs, set up docs for a small or simple project, or wants just enough documentation for AI session-start context. Also use when a project has no docs/INDEX.md and the user wants a quick documentation baseline without per-table or per-system detail.
user-invocable: true
---

# NLDR Generate Docs (Light)

Generate minimal AI-optimized documentation: enough for an AI agent to know where to start without searching the whole codebase. Two files only.

## Philosophy

Documentation is for AI-assisted development. AI reads code, so docs capture what code can't say quickly:
- Business rules and the "why"
- Domain concepts
- Where things live
- Conventions that aren't obvious from any single file

Do NOT include code examples, implementation details, or API usage in `docs/` — reference file locations instead ("Auth logic: `src/services/auth.ts`"). This rule applies to `docs/`; the README's quick-start commands are normal readme content and stay.

## When NOT to use

Signals the project needs `nldr-gen-docs` (full) instead: 15+ tables/collections; multiple distinct domains (auth, billing, jobs, integrations…); an implicit database schema scattered across many files; or an existing per-system/per-table docs tree that is accurate and actively useful. On any of these, recommend full and say why — let the user decide.

## Output: exactly two files

### 1. `README.md` (create or update)

Normal project readme: overview, purpose, quick start with prerequisites, key features, link to `docs/INDEX.md`. If a README exists, preserve accurate content and add the docs link.

### 2. `docs/INDEX.md` — the entire doc set in one file

```markdown
---
docs-level: light
---

# <Project> Documentation

## What This Is
<One-paragraph purpose. Key domain concepts and terminology.>

## Architecture
<Conceptual shape: major components and how data flows between them.
Text diagram if helpful. No table names, no field lists.>

## Where Things Live
<Brief directory map so AI starts in the right place, e.g.
"API routes: `src/app/api/` · business logic: `src/services/` · DB access: `src/db/`">

## Tech Stack
<Runtime, frameworks, key dependencies, infra. One line each.>

## Business Rules
<The non-obvious rules and "why"s. State transitions, validation intent,
authorization model — conceptually.>

## Conventions & Testing
<Test tools and what they're used for ("Playwright for e2e, Vitest for unit"),
commands to run, style conventions worth knowing, gotchas.>
```

The `docs-level: light` frontmatter marker is REQUIRED — `nldr-update-docs` and `nldr-pr-docs` read it to maintain the right depth.

## The implicit-contract rule

Even in light mode: **if a data contract exists only implicitly in code, write it down.** Examples: JSONB/metadata blob shapes, Firestore/Mongo collection structures with no schema file, message formats between services. Add a short "Data Contracts" section to INDEX.md for these. If the schema is explicit (Prisma/Drizzle/SQL/Convex schema file), just point to that file — don't duplicate it. If the schema lives in a different repo, point there ("Schema source of truth: `~/dev/org/db-repo`").

## Pre-existing docs

If a `docs/` folder already exists with more than INDEX.md:

1. Fold still-accurate content into the new INDEX.md (it's a consolidation, not a from-scratch write).
2. List the superseded doc files and propose deleting them (or moving to `docs/archive/` if the user prefers). Get confirmation before deleting.
3. Do NOT silently leave two competing doc sets — a light INDEX plus a stale detailed tree is worse than either alone.

## Process

1. Scan the repo: structure, entry points, schema/model files, tests, CI config, existing docs.
2. Write both files. `docs/INDEX.md` should be readable in one pass — roughly 150–250 wrapped lines as a ceiling, not a quota. Shorter is better than padded.
3. Verify every file path referenced actually exists.
4. Handle pre-existing docs (section above).
5. Commit with a descriptive message.

## Common mistakes

- Writing per-table or per-system docs — that's `nldr-gen-docs`'s job.
- Duplicating an explicit schema file into prose.
- Padding sections to look complete. Empty-ish is fine; wrong or bloated is not — every extra line is future staleness.
