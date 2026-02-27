
I would like you to review the code changes in this pull request and determine if any project documentation needs to be updated. If updates are needed, make them.

## Context

This project maintains AI-optimized documentation focused on business rules, concepts, and system behavior — not code examples or implementation details. Documentation lives in `docs/` and the main `README.md`. See the existing docs to understand the format and conventions used.

## Process

### Step 1: Understand the PR Changes

1. **Review the PR diff** - Read all changed, added, and deleted files in this pull request
2. **Categorize the changes** - Determine what kind of changes were made:
   - New feature or system
   - Modified business rules or validation logic
   - Database/data layer changes (new collections, schema changes, new triggers)
   - Changed data flows or workflows
   - Removed or deprecated features
   - Refactored code (renamed files, moved modules, restructured)
   - Dependency changes
   - Configuration or deployment changes
   - Bug fixes
   - Tests only
   - Cosmetic / formatting only

### Step 2: Assess Documentation Impact

For each change, determine if it affects documentation:

**Always requires doc updates:**
- New database collections/tables or significant schema changes
- New systems, services, or major features
- Changed business rules, validation logic, or state transitions
- Changed data flows or integration behaviors
- Removed or deprecated features/systems
- Changed authorization rules or security model
- Renamed or moved files that are referenced in docs
- Dependency additions/removals that affect the tech stack

**Usually requires doc updates:**
- New API endpoints or changed endpoint behavior
- Modified workflows or processes
- Changed error handling that affects expected behavior
- Configuration changes that affect deployment

**Rarely requires doc updates:**
- Bug fixes (unless they reveal a previously undocumented business rule)
- Code refactoring that doesn't change behavior
- Test additions/changes
- Cosmetic or formatting changes
- Internal implementation changes with no behavioral impact

### Step 3: If No Updates Needed

If the changes don't impact documentation, state this clearly with a brief explanation of why (e.g., "This PR contains only bug fixes and test additions with no changes to business rules, data structures, or system behavior. No documentation updates needed.").

**Stop here — do not make any changes.**

### Step 4: If Updates Are Needed

List the specific documentation files that need updating and what needs to change in each. Then apply the updates:

**Updating existing docs:**
- Preserve the document's existing structure and organization
- Update only the sections affected by the PR changes
- Keep all content that is still accurate
- Update any file path references that changed
- Fix any cross-references broken by the PR

**Adding new docs (for new systems/collections):**
- `docs/database/<collection>.md` for new collections/tables
- `docs/<system>.md` for new systems/domains
- Each new doc should include: purpose, business context, key concepts, data structures, business rules, workflows, security/performance considerations, and links to related docs

**Removing docs (for removed features):**
- Delete documentation for removed systems/features
- Remove entries from `docs/INDEX.md`

**Always check these files when making updates:**
- `docs/INDEX.md` - Add/remove entries if docs were added/removed
- `docs/tech-stack.md` - Update if dependencies changed
- `docs/architecture.md` - Update if system architecture changed
- `docs/improvements.md` - Update if technical debt items were resolved or new ones introduced
- `README.md` - Update if project overview, features, or architecture changed

### Step 5: Validation

After making changes, verify:
1. All cross-references between docs are valid
2. `docs/INDEX.md` reflects any added/removed docs
3. File path references in updated docs point to files that exist
4. Updated docs follow the same format and philosophy as the rest

## Documentation Philosophy

Documentation should focus on:
- **Business rules and logic** - What the system does and why
- **Concepts and domain knowledge** - Understanding the problem domain
- **Data relationships and flows** - How information moves through the system
- **Behavioral expectations** - What should happen in various scenarios

Documentation should NOT include:
- Code examples (AI can reference the actual codebase)
- Implementation details (AI can analyze the code directly)
- Syntax or API usage patterns (these are in the code)

Reference file locations when helpful:
- "See `src/services/auth.ts` for authentication logic"
- "User validation is handled in `src/validators/user.ts`"

## Deliverables

1. Assessment of whether documentation updates are needed (with reasoning)
2. If updates are needed: updated documentation files committed to the same PR
3. A summary comment listing what was updated and why

Please begin by reviewing the PR diff.
