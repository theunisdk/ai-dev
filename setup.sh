#!/usr/bin/env bash
# Machine setup for this toolkit: symlink every skill in skills/ into
# ~/.claude/skills so Claude Code discovers them. Idempotent — run it after
# every pull that adds a skill; existing correct links are just refreshed.
#
#   git clone git@github.com:theunisdk/ai-dev.git && cd ai-dev && ./setup.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_ROOT="$HOME/.claude/skills"
mkdir -p "$DEST_ROOT"

linked=0; kept=0; conflicts=0
for src in "$REPO_DIR"/skills/*/; do
  name="$(basename "$src")"
  [ -f "$src/SKILL.md" ] || continue
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
done

echo "skills: $linked linked, $kept refreshed, $conflicts conflict(s)"

command -v codex >/dev/null 2>&1 || echo "note: codex CLI not on PATH — the review kit needs it (then: codex login)"
command -v jq >/dev/null 2>&1 || echo "note: jq not installed — the review kit needs it"
exit 0
