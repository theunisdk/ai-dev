#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# review-update.sh — pull the shared review-kit machinery into this repo.
#
# The kit lives in one hub (github.com/theunisdk/ai-dev, codex-review-kit/).
# This script copies the SHARED half into the current repo, overwriting what is
# there; the REPO-OWNED half is never touched:
#
#   synced (overwritten):  scripts/review*.sh, scripts/make-plugin.sh,
#                          scripts/lib/*.sh, .review/prompts/, schema.json,
#                          adjudication.md, learnings-shared.md, .gitignore,
#                          .claude/commands+skill, .codex/skills, .githooks,
#                          .claude-plugin/, REVIEW.md
#   repo-owned (never):    .review/rubric.md, config.sh, learnings.md,
#                          prompts.local/, analyzers.local.sh
#
#   ./scripts/review-update.sh           # sync machinery from the hub
#   ./scripts/review-update.sh --init    # also seed repo-owned files that are
#                                        # missing, from the kit's templates/
#
# Hub resolution order: $REVIEW_KIT_DIR, then the local clone at
# ~/dev/private/ai-dev, then a fresh shallow clone of the public repo.
# ---------------------------------------------------------------------------
set -euo pipefail

KIT_GIT_URL="${REVIEW_KIT_URL:-https://github.com/theunisdk/ai-dev}"
KIT_SUBDIR="codex-review-kit"

INIT=0
[ "${1:-}" = "--init" ] && INIT=1

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: run from inside the repo you want to update" >&2; exit 1; }
cd "$REPO_ROOT"

# --- locate the hub --------------------------------------------------------
TMP_CLONE=""
cleanup() { [ -n "$TMP_CLONE" ] && rm -rf "$TMP_CLONE"; }
trap cleanup EXIT

if [ -n "${REVIEW_KIT_DIR:-}" ] && [ -d "$REVIEW_KIT_DIR" ]; then
  KIT="$REVIEW_KIT_DIR"
elif [ -d "$HOME/dev/private/ai-dev/$KIT_SUBDIR" ]; then
  KIT="$HOME/dev/private/ai-dev/$KIT_SUBDIR"
else
  TMP_CLONE="$(mktemp -d)"
  echo "no local hub found — cloning $KIT_GIT_URL" >&2
  git clone --depth 1 --quiet "$KIT_GIT_URL" "$TMP_CLONE"
  KIT="$TMP_CLONE/$KIT_SUBDIR"
fi
[ -f "$KIT/scripts/review.sh" ] || {
  echo "error: '$KIT' does not look like the kit (no scripts/review.sh)" >&2; exit 1; }

# --- sync the shared half --------------------------------------------------
mkdir -p scripts/lib .review/prompts .claude/commands .claude/skills \
         .codex/skills .githooks .claude-plugin

cp "$KIT"/scripts/review.sh "$KIT"/scripts/review-install.sh \
   "$KIT"/scripts/review-update.sh "$KIT"/scripts/make-plugin.sh scripts/
cp "$KIT"/scripts/lib/*.sh scripts/lib/
cp "$KIT"/.review/prompts/*.md .review/prompts/
cp "$KIT"/.review/schema.json "$KIT"/.review/adjudication.md \
   "$KIT"/.review/.gitignore .review/
cp "$KIT"/.review/learnings-shared.md .review/
cp "$KIT"/.claude/commands/*.md .claude/commands/
cp -R "$KIT"/.claude/skills/pre-pr-review .claude/skills/
cp -R "$KIT"/.codex/skills/. .codex/skills/
cp "$KIT"/.githooks/pre-push .githooks/
cp "$KIT"/.claude-plugin/*.json .claude-plugin/
cp "$KIT"/REVIEW.md "$KIT"/OPERATING.md .
chmod +x scripts/review.sh scripts/review-install.sh scripts/review-update.sh \
         scripts/make-plugin.sh .githooks/pre-push

# --- seed repo-owned files on --init ---------------------------------------
if [ "$INIT" = 1 ]; then
  mkdir -p .review/prompts.local
  for f in rubric.md config.sh learnings.md; do
    [ -f ".review/$f" ] || cp "$KIT/templates/$f" ".review/$f"
  done
  [ -f .review/analyzers.local.sh ] || cp "$KIT/templates/analyzers.local.sh" .review/
  [ -f .review/prompts.local/README.md ] || cp "$KIT/templates/prompts.local/README.md" .review/prompts.local/
fi

# --- record what we synced to ----------------------------------------------
KIT_COMMIT="$(git -C "$KIT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
printf 'kit: %s %s\nsynced: %s\n' "$KIT_GIT_URL" "$KIT_COMMIT" "$(date +%Y-%m-%d)" \
  > .review/kit-version

echo "synced from kit @ $KIT_COMMIT → run scripts/review-install.sh if this is a new machine"
