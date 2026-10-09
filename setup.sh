#!/usr/bin/env bash
# Machine setup for this toolkit: symlink every skill in skills/ into ~/.claude/skills
# so Claude Code discovers them, and install every mod in mods/ from this checkout's
# marketplace (.claude-plugin/marketplace.json). Claude Code reads those mods in place
# from the checkout, so a pull updates them. Idempotent — run it after every pull
# that adds a skill or mod; existing correct links are just refreshed.
#
#   git clone git@github.com:theunisdk/ai-dev.git && cd ai-dev && ./setup.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_ROOT="$HOME/.claude/skills"
mkdir -p "$DEST_ROOT"

linked=0; kept=0; conflicts=0

link() {
  local src="$1" name dest
  name="$(basename "$src")"
  dest="$DEST_ROOT/$name"

  if [ -L "$dest" ]; then
    ln -sfn "${src%/}" "$dest"
    kept=$((kept + 1))
  elif [ -e "$dest" ]; then
    # A real directory here means a local copy that may have diverged from the
    # repo — exactly the drift this script exists to prevent. Never clobber it.
    echo "  ! $name: real directory at $dest — compare with 'diff -r', then"
    echo "      rm -rf '$dest' and re-run to adopt the repo copy"
    conflicts=$((conflicts + 1))
  else
    ln -sn "${src%/}" "$dest"
    echo "  + linked $name"
    linked=$((linked + 1))
  fi
}

for src in "$REPO_DIR"/skills/*/; do
  [ -f "$src/SKILL.md" ] && link "$src"
done

echo "skills: $linked linked, $kept refreshed, $conflicts conflict(s)"

if command -v claude >/dev/null 2>&1; then
  for src in "$REPO_DIR"/mods/*/; do
    [ -f "$src/.claude-plugin/plugin.json" ] || continue
    name="$(basename "$src")"
    # A link left by an older setup.sh would load the mod a second time beside the install.
    if [ "$(readlink "$DEST_ROOT/$name" 2>/dev/null)" = "${src%/}" ]; then
      rm "$DEST_ROOT/$name" && echo "  - removed old link $name"
    fi
    if claude plugin install "$name" --marketplace "$REPO_DIR" >/dev/null 2>&1; then
      echo "  ✓ mod $name"
    else
      echo "  ! mod $name: install failed — run: claude plugin install $name --marketplace '$REPO_DIR'"
    fi
  done
else
  echo "note: claude CLI not on PATH — mods not installed (install Claude Code, then re-run ./setup.sh)"
fi

command -v codex >/dev/null 2>&1 || echo "note: codex CLI not on PATH — the review kit needs it (then: codex login)"
command -v jq >/dev/null 2>&1 || echo "note: jq not installed — the review kit needs it"
exit 0
