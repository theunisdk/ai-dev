
I would like you to review and update the existing documentation for this project. Documentation was previously generated and may be outdated. Your goal is to bring it in sync with the current codebase while preserving any manual refinements.

## Philosophy

This documentation is designed for AI-assisted development. AI can read and analyze the actual code, so documentation should focus on:
- **Business rules and logic** - What the system does and why
- **Concepts and domain knowledge** - Understanding the problem domain
- **Data relationships and flows** - How information moves through the system
- **Behavioral expectations** - What should happen in various scenarios

Documentation should NOT include:
- Code examples (AI can reference the actual codebase)
- Implementation details (AI can analyze the code directly)
- Syntax or API usage patterns (these are in the code)

## Update Process

### Phase 1: Audit Existing Documentation

Before making any changes, build a complete picture of what's already documented:

1. **Read all existing documentation** - Read every file in `docs/`, the main `README.md`, `CLAUDE.md`, and any `.cursorrules` files
2. **Build an inventory** - List every documented system, collection, feature, and concept
3. **Note file references** - Track all source file paths referenced in the docs (e.g., "See `src/services/auth.ts`")

### Phase 2: Analyze the Current Codebase

Scan the repository to understand its current state:

1. **Repository structure** - Map out the current directory structure, modules, and boundaries
2. **Database/data layer** - Analyze schemas, models, triggers, and migrations for current collections/tables
3. **Major systems** - Identify all systems/domains by analyzing services, controllers, and module organization
4. **Business rules** - Extract current validation logic, state machines, authorization rules, and integration behaviors
5. **Dependencies** - Check for new, removed, or updated dependencies

### Phase 3: Gap Analysis

Compare the existing documentation against the current codebase and produce a summary of findings before making changes. Categorize issues as:

- **Stale content** - Documented features/rules that have changed in the codebase (renamed files, modified logic, updated business rules, changed data structures)
- **Missing documentation** - New systems, collections, features, or business rules that have no documentation
- **Orphaned documentation** - Docs describing things that no longer exist in the codebase
- **Broken references** - File paths or cross-references pointing to moved, renamed, or deleted code/docs
- **Structural issues** - Missing INDEX.md entries, broken navigation, inconsistent formatting

**Present this gap analysis summary to the user before proceeding with updates.**

### Phase 4: Update Documentation

Apply updates following these rules:

**Updating existing docs:**
- Preserve the document's existing structure and organization
- Update only the sections that are stale or inaccurate
- Keep any manually added context, notes, or refinements that are still accurate
- Update file path references that have changed
- Fix broken cross-references

**Adding new documentation:**
Follow the same structure as existing docs (consistent with the generation prompt):
- `docs/database/<collection>.md` for new collections/tables
- `docs/<system>.md` for new systems/domains
- Each new doc should include: purpose, business context, key concepts, data structures, business rules, workflows, security/performance considerations, and links to related docs

**Removing orphaned docs:**
- Delete documentation for systems/features that no longer exist
- Remove entries from `docs/INDEX.md` for deleted docs

**Always update these files:**
- `docs/INDEX.md` - Ensure navigation reflects all current docs
- `docs/improvements.md` - Refresh with current code quality issues, technical debt, and roadmap items
- `docs/tech-stack.md` - Update if dependencies have changed
- `README.md` - Update if the project overview, features, or architecture has changed

### Phase 5: Validation

Before committing, verify:
1. All cross-references between docs are valid
2. `docs/INDEX.md` links to every doc file that exists
3. No orphaned docs remain
4. All file path references in docs point to files that exist
5. New docs follow the same format and philosophy as existing ones

## Each Document Should Include:
- Clear purpose statement
- Business context and why it exists
- Key concepts and terminology
- Data structure definitions (TypeScript interfaces as contracts)
- Business rules and validation logic
- Workflow descriptions with expected behaviors
- Security considerations
- Performance considerations
- Links to related documentation

## What NOT to Include:
- Code snippets or examples (AI reads the actual code)
- Implementation tutorials
- Step-by-step coding guides
- API usage examples
- Copy-paste code blocks

Instead, reference file locations when helpful:
- "See `src/services/auth.ts` for authentication logic"
- "User validation is handled in `src/validators/user.ts`"

## Deliverables

1. Gap analysis summary (presented before making changes)
2. Updated documentation files
3. Ensure all cross-references are valid
4. Create git commits with descriptive messages explaining what was updated
5. Push to a feature branch
6. Create a pull request with a summary that highlights:
   - What was updated and why
   - What new docs were added
   - What orphaned docs were removed
   - Any significant business rule or architecture changes discovered

## Important Notes

- **Preserve manual refinements** - Do not overwrite content that is still accurate just to regenerate it
- **Focus on the delta** - Only update what has actually changed; don't rewrite docs that are still correct
- **Explain the "why"** - Business reasoning is harder to extract from code than the "how"
- **Focus on database changes** - Database structure changes often have the widest documentation impact
- **Update improvements.md thoroughly** - This is the most likely doc to go stale; refresh it completely
- **Reference source files** - Point to where logic lives, don't copy it
- **Be transparent** - The gap analysis summary should clearly show what you plan to change and why

Please begin by reading the existing documentation, then analyzing the codebase, then presenting your gap analysis before making any changes.
