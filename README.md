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
| `setup-session-orchestration-prompt.md` | Wire cross-repo session spawning (tmux + `--remote-control`) and the `tdk-1-start` SessionStart hook into a machine's global Claude Code config |

### [skills/](skills/)

Claude Code skills, authored here and symlinked into `~/.claude/skills/`. Highlights:

| Skill | Purpose |
|-------|---------|
| `nldr-gen-docs-light` | Generate minimal AI-optimized docs (README + self-contained `docs/INDEX.md`) for simple projects |
| `nldr-gen-docs` | Generate comprehensive docs for complex projects, with adaptive data-layer depth |
| `nldr-update-docs` | Sync existing docs with the codebase (gap analysis first; works for light and full doc sets) |
| `nldr-pr-docs` | PR-scoped doc updates — runs interactively or headless in CI |
| `nldr-setup-docs-ci` | Wire `nldr-pr-docs` into a repo's GitHub Actions |
| `review-kit-install` | Bootstrap + adapt the codex review kit into a repo that doesn't have it ("implement the review kit here") |
| `tdk-1-start` | Session kickoff: load project context, confirm the starting branch |
| `tdk-2-push-review` | Push → PR → CodeRabbit, capped at two fix rounds; every finding fixed, issue-logged, or rejected with a reason; pauses before merge |
| `tdk-3-is-pm` | Take the PM role for a feature: decompose it, spawn a worker session per task, filter their reports, own every merge to `main`, and deploy on your go |

Install all skills and mods on a machine: `./setup.sh` (idempotent — re-run after any
pull; it symlinks every skill into `~/.claude/skills`, never clobbering a local copy
that diverged, and installs every mod — see [mods/](#mods)). One skill by hand:
`ln -sfn "$(pwd)/skills/<name>" ~/.claude/skills/<name>`

### [mods/](mods/)

Claude Code mods: plugins whose function hooks draw UI inside Claude Code (the
terminal and the desktop Code tab). This repo is a plugin marketplace,
`theunisdk-ai-dev`, listing them.

Anyone can install a mod from GitHub:

```bash
claude plugin marketplace add theunisdk/ai-dev
claude plugin install session-board@theunisdk-ai-dev
```

Update later with `claude plugin marketplace update theunisdk-ai-dev`, or turn on
auto-update for the marketplace under `/plugin` → Marketplaces.

On a machine with this repo cloned, `./setup.sh` installs every mod from the
checkout instead; Claude Code then reads them in place, so a `git pull` updates
them. Either way, run `/reload-plugins` in a session that is already open.

Mods need a recent Claude Code, and they don't load in WSL sessions of the
desktop app — use a native Windows session there.

| Mod | Purpose |
|-----|---------|
| `session-board` | `/board` opens a pane listing running sessions grouped under their PM (`<project>-pm-<number>-…`, workers carry the same number), with the ones waiting on you on top. The session showing it needs Remote Control on to see other machines |

### [wsl-cli-tools/](wsl-cli-tools/)

Command-line utilities for development workflows in WSL, including file conversion (Markdown/PDF), project scaffolding, audio transcription, and more. See the [wsl-cli-tools README](wsl-cli-tools/README.md) for details.

### [codex-review-kit/](codex-review-kit/) — moved

The multi-lens pre-PR review pipeline now lives in its own repo:
**[theunisdk/codex-review-kit](https://github.com/theunisdk/codex-review-kit)**.
The copy here is frozen at the split point so existing spokes can transition:
their next `scripts/review-update.sh` run against this repo delivers the
redirecting script, and every sync after that pulls from the new hub. This
directory will be removed once all consuming repos have re-synced.

## Usage

**Prompts** — Copy the contents of any prompt file and paste it into your AI assistant (Claude, Cursor, ChatGPT, etc.) while working in a project.

**CLI Tools** — See [wsl-cli-tools/README.md](wsl-cli-tools/README.md) for installation and usage instructions.

## License

MIT
