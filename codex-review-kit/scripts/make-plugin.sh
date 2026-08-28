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

# The cleanup below runs `rm -rf` on caller-supplied subpaths, so the destination
# has to earn that. Rather than blacklisting dangerous paths one at a time, only
# two kinds of directory qualify: an empty one, or one this script previously
# generated. That covers `/`, `$HOME`, the kit itself and everything else in the
# same class, without needing to enumerate them.
mkdir -p "$DEST"
dest_abs="$(cd "$DEST" && pwd -P)"
src_abs="$(cd "$SRC" && pwd -P)"

[ "$dest_abs" = "/" ] && { echo "error: refusing to build into the filesystem root" >&2; exit 1; }

case "$dest_abs" in
  "$src_abs"|"$src_abs"/*)
    echo "error: destination is inside the kit ($dest_abs) — pick a directory outside $src_abs" >&2
    exit 1 ;;
esac
case "$src_abs" in
  "$dest_abs"/*)
    echo "error: destination contains the kit ($dest_abs) — pick a directory outside $src_abs" >&2
    exit 1 ;;
esac

if [ -n "$(ls -A "$dest_abs" 2>/dev/null)" ] && [ ! -f "$dest_abs/.claude-plugin/plugin.json" ]; then
  echo "error: $dest_abs is not empty and was not built by this script" >&2
  echo "       (expected .claude-plugin/plugin.json) — pick a new or previously generated directory" >&2
  exit 1
fi

# Generated content is replaced wholesale, not overlaid: a command or skill
# deleted from the kit would otherwise survive in a reused output directory and
# ship in the plugin forever.
for d in .claude-plugin commands skills scripts review; do
  rm -rf "${dest_abs:?}/$d"
done
DEST="$dest_abs"
mkdir -p "$DEST/.claude-plugin" "$DEST/commands" "$DEST/skills" "$DEST/scripts/lib" "$DEST/review"

# Explicit allowlist, not a glob: .claude/skills/ also holds repo-private skills
# that gitignore keeps out of git but would not keep out of a filesystem copy.
KIT_SKILLS="pre-pr-review"

cp "$SRC/.claude-plugin/plugin.json"      "$DEST/.claude-plugin/"
cp "$SRC/.claude-plugin/marketplace.json" "$DEST/.claude-plugin/"
cp "$SRC"/.claude/commands/*.md           "$DEST/commands/"
for s in $KIT_SKILLS; do
  [ -d "$SRC/.claude/skills/$s" ] || { echo "error: kit skill missing: $s" >&2; exit 1; }
  cp -r "$SRC/.claude/skills/$s" "$DEST/skills/"
done
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
