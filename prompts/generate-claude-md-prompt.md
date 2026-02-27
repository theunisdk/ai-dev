
Please analyze this codebase and create a `CLAUDE.md` file in the repository root. This file is automatically loaded into every Claude Code conversation, so it must be concise and high-value — think cheat sheet, not documentation.

## Philosophy

`CLAUDE.md` is context that Claude reads on every interaction. Every line costs context window space, so it should contain only what Claude needs to know to work effectively in this codebase. It should **reference** existing documentation, not duplicate it.

## What to Include

### 1. Project Overview (2-3 sentences max)
What this project is, what it does, and who it's for.

### 2. Essential Commands
The commands a developer (or Claude) needs regularly:
- How to install dependencies
- How to run the project locally
- How to run tests (all tests, single test, watch mode)
- How to build
- How to lint/format
- How to deploy (if applicable)

Keep these as exact commands, not descriptions.

### 3. Architecture Summary
A brief description of how the project is organized:
- What the main directories contain
- The key architectural pattern (monolith, microservices, serverless, etc.)
- The data flow at a high level (e.g., "API requests → controllers → services → Firestore")

### 4. Code Conventions
Patterns Claude should follow when writing code in this project:
- Naming conventions (files, variables, functions, classes)
- Import organization
- Error handling approach
- Testing patterns
- Any framework-specific patterns (e.g., "always use server actions, never API routes")

### 5. Important Context
Things that aren't obvious from reading the code:
- Non-standard configurations or gotchas
- Environment requirements
- Key business domain concepts that affect code decisions
- Security rules or constraints
- Common pitfalls specific to this codebase

### 6. Documentation Pointers
If a `docs/` folder exists, add a brief section pointing to key docs:
```
## Documentation
- Architecture: docs/architecture.md
- Database: docs/database/README.md
- Full index: docs/INDEX.md
```

Do NOT summarize the docs — just link to them.

## What NOT to Include

- Full documentation (that's what `docs/` is for)
- Code examples or snippets
- Dependency lists (that's what package.json is for)
- API endpoint lists
- Database schema details
- Anything that changes frequently (keep it stable)
- Verbose explanations of things Claude can figure out from the code

## Length Target

Aim for **50-150 lines**. If it's over 200 lines, it's too long. The entire file is loaded into every conversation, so brevity is critical.

## Analysis Approach

1. Read `package.json` (or equivalent) for project type, dependencies, and scripts
2. Scan the directory structure for organization patterns
3. Check for existing documentation in `docs/`, `README.md`, etc.
4. Read a few representative source files to identify conventions
5. Look at test files to understand testing patterns
6. Check for configuration files (linters, formatters, CI/CD) that define standards
7. Look for existing `.cursorrules`, `CLAUDE.md`, or similar files

## Deliverables

1. Create `CLAUDE.md` in the repository root
2. Create a git commit with a descriptive message
3. Push to a feature branch
4. Create a pull request

Please begin by analyzing the repository structure.
