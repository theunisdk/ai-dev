# AI Dev Toolkit

A collection of reusable prompts and CLI tools for AI-assisted software development.

## What's Inside

### [prompts/](prompts/)

Ready-to-use prompts for common AI-assisted development tasks:

| Prompt | Purpose |
|--------|---------|
| `generate-claude-md-prompt.md` | Generate a `CLAUDE.md` configuration file for Claude Code projects |
| `generate-cursorrules-prompt.md` | Generate a `.cursorrules` file for Cursor AI projects |
| `generate_documents_prompt_v2.md` | Generate comprehensive project documentation from code |
| `update_documents_prompt.md` | Update existing project documentation to match current code |
| `pr_docs_review_prompt.md` | Review PR changes and update affected documentation |

### [skills/](skills/)

Claude Code skills, authored here and symlinked into `~/.claude/skills/`. Highlights:

| Skill | Purpose |
|-------|---------|
| `nldr-gen-docs-light` | Generate minimal AI-optimized docs (README + self-contained `docs/INDEX.md`) for simple projects |
| `nldr-gen-docs` | Generate comprehensive docs for complex projects, with adaptive data-layer depth |
| `nldr-update-docs` | Sync existing docs with the codebase (gap analysis first; works for light and full doc sets) |
| `nldr-pr-docs` | PR-scoped doc updates — runs interactively or headless in CI |
| `nldr-setup-docs-ci` | Wire `nldr-pr-docs` into a repo's GitHub Actions |

Install a skill: `ln -sfn "$(pwd)/skills/<name>" ~/.claude/skills/<name>`

### [wsl-cli-tools/](wsl-cli-tools/)

Command-line utilities for development workflows in WSL, including file conversion (Markdown/PDF), project scaffolding, audio transcription, and more. See the [wsl-cli-tools README](wsl-cli-tools/README.md) for details.

## Usage

**Prompts** — Copy the contents of any prompt file and paste it into your AI assistant (Claude, Cursor, ChatGPT, etc.) while working in a project.

**CLI Tools** — See [wsl-cli-tools/README.md](wsl-cli-tools/README.md) for installation and usage instructions.

## License

MIT
