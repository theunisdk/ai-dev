#!/usr/bin/env bash
# Generate a distributable Claude Code plugin from this kit.
#
# Why: `.claude/` is per-repo. A plugin installs once per machine and applies to
# every repo, which is the better answer when you work across many repositories.
#
# The split it produces:
#   plugin (generic machinery)  → commands, skill, runner, lens prompts, schema
#   repo (your standards)       → .review/rubric.md, learnings.md, config.sh
#
#   ./scripts/make-plugin.sh ../codex-review-plugin
#
# Then, from Claude Code:
#   /plugin marketplace add <that-repo-or-path>
#   /plugin install codex-review@internal-dev-tools
# Or to test without installing:
#   claude --plugin-dir ../codex-review-plugin
set -euo pipefail

DEST="${1:?usage: make-plugin.sh <output-dir>}"
SRC="$(git rev-parse --show-toplevel)"

mkdir -p "$DEST/.claude-plugin" "$DEST/commands" "$DEST/skills" "$DEST/scripts/lib" "$DEST/review"

cp "$SRC/.claude-plugin/plugin.json"      "$DEST/.claude-plugin/"
cp "$SRC/.claude-plugin/marketplace.json" "$DEST/.claude-plugin/"
cp "$SRC"/.claude/commands/*.md           "$DEST/commands/"
cp -r "$SRC"/.claude/skills/*             "$DEST/skills/"
cp "$SRC"/scripts/review.sh "$SRC"/scripts/review-install.sh "$DEST/scripts/"
cp "$SRC"/scripts/lib/*.sh                "$DEST/scripts/lib/"
cp -r "$SRC"/.review/prompts              "$DEST/review/"
cp "$SRC"/.review/schema.json "$SRC"/.review/adjudication.md "$DEST/review/"
cp "$SRC"/REVIEW.md                       "$DEST/README.md"

cat > "$DEST/PLUGIN-NOTES.md" <<'MD'
# Plugin notes

This plugin ships the generic machinery. Each repository still supplies its own:

- `.review/rubric.md`      — house rules and severity definitions
- `.review/learnings.md`   — accumulated suppressions and blind spots
- `.review/config.sh`      — per-repo posture

Those are repo-specific by nature; sharing them across repos dilutes all of them.

Inside plugin commands and skills, reference bundled files with
`${CLAUDE_PLUGIN_ROOT}` — never an absolute path, which breaks on other machines.

Before publishing: fill in `author.name` and `owner.name` in the two manifests,
and run `claude plugin validate <dir>`.
MD

echo "Plugin written to: $DEST"
echo "Test with:  claude --plugin-dir $DEST"
