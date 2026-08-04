---
name: nldr-gen-docs
description: Use when the user asks to generate full/comprehensive project documentation, document a complex codebase (many tables, multiple domains, cross-cutting business logic), or create a docs/ folder with per-system detail. Also use when nldr-gen-docs-light was considered but the project is too complex for a single-doc treatment.
user-invocable: true
---

# NLDR Generate Docs (Full)

Do a full code review of the project and generate comprehensive AI-optimized documentation focused on business rules, concepts, and system behavior.

## Philosophy

Documentation is for AI-assisted development. AI reads code, so document what code can't say quickly:
- **Business rules and logic** — what the system does and why
- **Concepts and domain knowledge** — the problem domain
- **Data relationships and flows** — how information moves
- **Behavioral expectations** — what should happen in various scenarios

Do NOT include code examples, implementation tutorials, or API usage patterns. Reference file locations instead ("Auth logic: `src/services/auth.ts`").

## When NOT to use

Small/simple project (one domain, few tables, fits in one context pass)? Recommend `nldr-gen-docs-light` instead and say why. Let the user decide.

## Core rule: document whatever is implicit

The data layer treatment depends on where the schema lives:

| Schema situation | What to write |
|---|---|
| **Implicit** — Firestore/Mongo/DynamoDB, shapes scattered across writes, triggers, denormalization code | Per-collection docs. These docs ARE the schema — the only explicit representation of it. |
| **Explicit** — Prisma/Drizzle/SQL migrations/Convex schema file | NO per-table docs (they duplicate the schema file and rot). Write a **data-flow & write-ownership doc** instead: who writes which counter, which tables are derived/denormalized, which snapshots don't self-heal, naming mismatches between UI and code. |
| **Mixed** — explicit schema with implicit JSONB/metadata blobs | Point to the schema file; document only the implicit blob shapes and the write-ownership layer. |

The semantics are often implicit even when the schema is explicit. Write-ownership is the highest-value doc a schema file can't provide.

## Output structure

```
README.md                      # overview, quick start, architecture diagram (text), features, link to docs/INDEX.md
docs/
  INDEX.md                     # navigation for all docs + docs-level marker
  architecture.md              # high-level system architecture and design patterns
  tech-stack.md                # runtime, frameworks, dependencies, tools
  deployment.md                # local setup and CI/CD
  improvements.md              # code quality issues, tech debt, roadmap
  data-flows.md                # write-ownership doc (explicit-schema projects)
  database/                    # per-collection docs (implicit-schema projects only)
    README.md                  #   overview + design principles
    <collection>.md            #   one per major collection
  systems/
    <system>.md                # one per major domain
  style-guide.md               # code style standards (if conventions are non-obvious)
  testing-guide.md             # testing approach and what to test
```

`docs/INDEX.md` frontmatter marker is REQUIRED:

```markdown
---
docs-level: full
---
```

`nldr-update-docs` and `nldr-pr-docs` read it to maintain the right depth.

## Each document includes

- Purpose statement and business context (why it exists)
- Key concepts and terminology
- Data structure definitions where contracts matter (TypeScript interfaces as contracts, not examples)
- Business rules and validation logic
- Workflows with expected behaviors
- Error scenarios, security and performance considerations
- Links to related docs and source file references

Per-collection docs additionally: field descriptions with business meaning, relationships, lifecycle (creation/update/deletion rules), trigger/hook behavior and purpose, validation rules.

## Analysis approach

1. **Full repository scan** — structure, module boundaries, entry points.
2. **Data layer** — schemas, models, migrations, triggers/hooks, ORM config. Decide implicit vs explicit (see core rule).
3. **Map domains** — directory structure, service/controller organization. One systems doc per real domain.
4. **Data flows** — how creating/updating in one place affects others; event-driven patterns; background jobs; counters/aggregations and their business logic.
5. **Business rules** — validation, state machines, authorization, integration behaviors.
6. **Code quality** (for improvements.md) — security issues, deprecated deps, test coverage, anti-patterns (async forEach, race conditions).

Document each system completely before moving to the next.

## Delivery

1. Create ALL files referenced from INDEX.md — no dead links.
2. Verify cross-references and file paths are valid.
3. Commit with descriptive messages; if the user wants review, push a feature branch and open a PR with a summary.

## Common mistakes

- Per-table docs for a project with an explicit schema file — duplication that rots.
- Documenting "how" (code does that) instead of "why".
- Skipping the write-ownership doc — it's the one thing no schema file can tell you.
- Mentioning a doc in INDEX.md without creating it.
