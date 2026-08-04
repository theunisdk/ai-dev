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

Do NOT include code examples, implementation details, or API usage — reference file locations instead ("Auth logic: `src/services/auth.ts`").

## When NOT to use

If the project has 15+ tables/collections, multiple distinct domains (auth, billing, jobs, integrations…), or an implicit database schema scattered across many files — recommend `nldr-gen-docs` (full) instead, and say why. Let the user decide.

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

Even in light mode: **if a data contract exists only implicitly in code, write it down.** Examples: JSONB/metadata blob shapes, Firestore/Mongo collection structures with no schema file, message formats between services. Add a short "Data Contracts" section to INDEX.md for these. If the schema is explicit (Prisma/Drizzle/SQL/Convex schema file), just point to that file — don't duplicate it.

## Process

1. Scan the repo: structure, entry points, schema/model files, tests, CI config.
2. Write both files. Target: `docs/INDEX.md` readable in one pass (~150–250 lines).
3. Verify every file path referenced actually exists.
4. Commit with a descriptive message.

## Common mistakes

- Writing per-table or per-system docs — that's `nldr-gen-docs`'s job.
- Duplicating an explicit schema file into prose.
- Padding sections to look complete. Empty-ish is fine; wrong or bloated is not — every extra line is future staleness.
