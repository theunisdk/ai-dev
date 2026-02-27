
I would like you to do a full code review of this project and create comprehensive documentation focused on business rules, concepts, and system behavior.

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

## Requirements

### 1. Main README
Create/Update the README.md with:
- Project overview and purpose
- Quick start guide with prerequisites
- System architecture diagram (text-based)
- Key features list
- Development workflow
- Links to detailed documentation

### 2. Documentation Structure
Create a `docs/` folder with hierarchical documentation following this structure:

**Core Documentation:**
- `docs/INDEX.md` - Navigation guide for all documentation with quick links
- `docs/tech-stack.md` - Complete technology stack (runtime, frameworks, dependencies, tools)
- `docs/deployment.md` - Deployment guide with local setup and CI/CD
- `docs/architecture.md` - High-level system architecture and design patterns
- `docs/improvements.md` - Code quality issues, technical debt, and roadmap

**Database/Data Layer Documentation:**
- `docs/database/README.md` - Database overview and design principles
- One markdown file per major collection/table documenting:
  - Purpose and business context
  - Document/table structure with field descriptions
  - Business rules governing the data
  - Relationships to other collections/tables
  - Data lifecycle (creation, updates, deletion rules)
  - Triggers/hooks behavior and their business purpose
  - Validation rules and constraints

**System Documentation:**
Create separate documents for each major system/domain:
- Purpose and business context
- Key concepts and terminology
- Architecture and data flow diagrams
- Business rules and logic
- Integration points and dependencies
- Error scenarios and expected behavior
- Security considerations

**Development Documentation:**
- `docs/style-guide.md` - Code style standards and conventions
- `docs/testing-guide.md` - Testing approach and what to test
- Any system-specific guides (API concepts, webhook flows, etc.)

### 3. Documentation Methodology
Follow these principles:
- **Hierarchical Structure**: Main README links to docs/INDEX.md, which links to all other docs
- **AI-Optimized**: Split into sections for easy AI processing and reference
- **Concept-Focused**: Explain what and why, not how (AI can read the code for how)
- **TypeScript Interfaces**: Define data structures with proper types (these are contracts, not examples)
- **Cross-References**: Link related documents together
- **Workflows**: Describe business flows and expected behaviors step-by-step
- **Best Practices**: Include security, performance, and design best practices

### 4. Focus Areas

**Database Structure (CRITICAL):**
- Analyze all database triggers, schemas, and models to understand collections/tables
- Document the hierarchical structure and relationships
- Explain business rules for data integrity
- Map out data flows (how creating/updating in one place affects others)
- Identify denormalization patterns and their purposes
- Document aggregation and counter patterns and their business logic

**Business Rules:**
- Document validation rules and why they exist
- Explain state transitions and when they occur
- Describe authorization rules and access patterns
- Document integration behaviors and expected outcomes

**Code Quality:**
- Identify security issues (hardcoded secrets, vulnerabilities)
- Find deprecated dependencies
- Check for testing coverage
- Note TypeScript strict mode usage
- Find anti-patterns (async forEach, race conditions, etc.)

### 5. Each Document Should Include:
- Clear purpose statement
- Business context and why it exists
- Key concepts and terminology
- Data structure definitions (TypeScript interfaces as contracts)
- Business rules and validation logic
- Workflow descriptions with expected behaviors
- Security considerations
- Performance considerations
- Links to related documentation

### 6. What NOT to Include:
- Code snippets or examples (AI reads the actual code)
- Implementation tutorials
- Step-by-step coding guides
- API usage examples
- Copy-paste code blocks

Instead, reference file locations when helpful:
- "See `src/services/auth.ts` for authentication logic"
- "User validation is handled in `src/validators/user.ts`"

### 7. Deliverables
1. Complete all documentation files
2. Ensure all cross-references are valid
3. Create git commits with descriptive messages
4. Push to a feature branch
5. Create a pull request with a comprehensive summary

## Analysis Approach

1. **Start with a full repository scan** to understand the project structure
2. **Identify the database/data layer** by analyzing:
   - Schema files
   - Model definitions
   - Migration files
   - Database triggers/hooks
   - ORM configurations
3. **Map out major systems/domains** by analyzing:
   - Directory structure
   - Module boundaries
   - Service/controller organization
4. **Understand data flows** by analyzing:
   - How data moves through the system
   - Event-driven patterns
   - API endpoints
   - Background jobs/queues
5. **Extract business rules** by analyzing:
   - Validation logic
   - State machines
   - Authorization checks
   - Integration behaviors
6. **Document each system comprehensively** before moving to the next

## Important Notes

- **Focus on concepts over code** - AI can read the implementation, document the intent
- **Explain the "why"** - Business reasoning is harder to extract from code than the "how"
- **Focus specifically on the database structure** - use triggers, models, and schemas to understand what collections/tables exist and their purposes
- **Create ALL referenced documentation** - if you mention a file in docs/INDEX.md, create that file
- **Reference source files** - point to where logic lives, don't copy it
- **Follow the hierarchical methodology** - main README → INDEX → specific docs
- **Make it AI-friendly** - split into logical sections for easy reference
- **Include improvements documentation** - document what needs to be fixed or enhanced
- **Be comprehensive but concise** - detailed where needed, but avoid unnecessary verbosity

## Output Format

After analysis, provide:
1. A summary of what you found (project type, tech stack, architecture)
2. Create all documentation files in the proper structure
3. Commit and push the changes
4. Create a pull request with a detailed summary

Please begin by analyzing the repository structure and then systematically create all documentation following this methodology.
