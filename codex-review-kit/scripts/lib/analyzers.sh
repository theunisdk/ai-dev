#!/usr/bin/env bash
# Collect cheap static-analysis signal on the changed files and write it to
# .review/raw/analyzers.txt. Every tool is OPTIONAL — missing tools are skipped
# silently. The point is not to gate on this output; it is to hand Codex the
# lint-level noise up front so it spends its reasoning budget on semantic bugs
# a linter structurally cannot find.
#
# This file is synced from the kit — do not edit it in a repo. Wire your own
# stack in .review/analyzers.local.sh instead (repo-owned, never overwritten).

collect_analyzer_output() {
  local out="$1"
  local list="$out/changed-files.txt"
  local report="$out/analyzers.txt"
  : > "$report"

  _have() { command -v "$1" >/dev/null 2>&1; }
  _section() { printf '\n### %s\n' "$1" >> "$report"; }

  # --- files by extension, existing only ---
  _files_matching() {
    local pat="$1"
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      case "$f" in $pat) printf '%s\n' "$f" ;; esac
    done < "$list"
  }

  # --- secrets ------------------------------------------------------------
  if _have gitleaks; then
    _section "gitleaks (secrets)"
    gitleaks protect --staged --no-banner --redact 2>&1 | head -100 >> "$report" || true
  fi

  # --- semgrep (multi-language, high signal) ------------------------------
  if _have semgrep; then
    _section "semgrep --config=auto"
    # shellcheck disable=SC2046
    semgrep --config=auto --quiet --error --json $(tr '\n' ' ' < "$list") 2>/dev/null \
      | jq -r '.results[]? | "- " + .path + ":" + (.start.line|tostring) + " [" + .check_id + "] " + .extra.message' \
      2>/dev/null | head -200 >> "$report" || true
  fi

  # --- Shell --------------------------------------------------------------
  local sh; sh="$(_files_matching '*.sh|*.bash')"
  if [ -n "$sh" ] && _have shellcheck; then
    _section "shellcheck"
    printf '%s\n' "$sh" | xargs shellcheck -f gcc 2>/dev/null | head -100 >> "$report" || true
  fi

  # --- repo-specific stack wiring ------------------------------------------
  # A repo that knows its stack writes .review/analyzers.local.sh (start from
  # templates/analyzers.local.sh in the kit). It runs INSTEAD of the generic
  # per-language stanzas below, with $report, $list and the
  # _have/_section/_files_matching helpers in scope.
  if [ -f .review/analyzers.local.sh ]; then
    # shellcheck disable=SC1091
    . .review/analyzers.local.sh
    if [ ! -s "$report" ]; then rm -f "$report"; fi
    return 0
  fi

  # --- JS / TS ------------------------------------------------------------
  local js; js="$(_files_matching '*.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs')"
  if [ -n "$js" ] && _have npx && [ -f package.json ]; then
    _section "eslint"
    # no --format flag: eslint 9 removed every non-core formatter, unix included
    printf '%s\n' "$js" | xargs npx --no-install eslint 2>/dev/null \
      | head -200 >> "$report" || true
    if [ -f tsconfig.json ]; then
      _section "tsc --noEmit"
      npx --no-install tsc --noEmit 2>&1 | head -100 >> "$report" || true
    fi
  fi

  # --- Python -------------------------------------------------------------
  local py; py="$(_files_matching '*.py')"
  if [ -n "$py" ]; then
    if _have ruff; then
      _section "ruff"
      printf '%s\n' "$py" | xargs ruff check --output-format concise 2>/dev/null | head -200 >> "$report" || true
    fi
    if _have mypy; then
      _section "mypy"
      printf '%s\n' "$py" | xargs mypy --no-error-summary 2>/dev/null | head -100 >> "$report" || true
    fi
    if _have bandit; then
      _section "bandit"
      printf '%s\n' "$py" | xargs bandit -q -f custom 2>/dev/null | head -100 >> "$report" || true
    fi
  fi

  # --- Go -----------------------------------------------------------------
  if [ -n "$(_files_matching '*.go')" ] && _have go; then
    _section "go vet"
    go vet ./... 2>&1 | head -100 >> "$report" || true
    _have staticcheck && { _section "staticcheck"; staticcheck ./... 2>&1 | head -100 >> "$report" || true; }
  fi

  # --- Rust ---------------------------------------------------------------
  if [ -n "$(_files_matching '*.rs')" ] && _have cargo; then
    _section "cargo clippy"
    cargo clippy --quiet --message-format short 2>&1 | head -100 >> "$report" || true
  fi

  # --- Terraform / IaC ----------------------------------------------------
  if [ -n "$(_files_matching '*.tf')" ] && _have tflint; then
    _section "tflint"; tflint --format compact 2>&1 | head -80 >> "$report" || true
  fi

  if [ ! -s "$report" ]; then rm -f "$report"; fi
  return 0
}
