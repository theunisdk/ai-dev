# Repo-owned stack wiring for the analyzer pass. Sourced by the kit's
# scripts/lib/analyzers.sh INSTEAD of its generic per-language stanzas, with
# these in scope:
#   $report            — append findings here (plain text, fed to the lenses)
#   $list              — file listing the changed paths, one per line
#   _have <cmd>        — true if the tool is installed
#   _section <title>   — write a section header into $report
#   _files_matching '<glob>|<glob>' — changed files that exist, by extension
#
# Keep every command best-effort (`|| true`, `head -N`) — this pass informs
# the review, it never gates it. Verify each command works before adding it.
#
# Example (TypeScript monorepo):
#
# local ts; ts="$(_files_matching '*.ts|*.tsx')"
# if [ -n "$ts" ]; then
#   _section "eslint"
#   printf '%s\n' "$ts" | xargs npx --no-install eslint 2>&1 | head -200 >> "$report" || true
#   _section "tsc"
#   npx --no-install tsc --build 2>&1 | head -100 >> "$report" || true
# fi
