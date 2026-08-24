#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# review.sh — multi-lens pre-PR code review via OpenAI Codex CLI.
#
# Runs N narrow, parallel review passes over the current branch's diff, each
# with its own focus, then merges the structured findings into a single
# JSON + Markdown report for Claude Code to adjudicate.
#
# Usage:
#   ./scripts/review.sh                     # diff vs auto-detected base branch
#   ./scripts/review.sh origin/develop      # diff vs explicit base
#   ./scripts/review.sh --uncommitted       # staged + unstaged + untracked
#   ./scripts/review.sh --lenses security,contracts
#   ./scripts/review.sh --effort medium --confidence 0.7
#
# Exit codes: 0 ok · 1 setup/runtime error · 2 findings at/above --fail-on
# ---------------------------------------------------------------------------
set -uo pipefail

# --- locate repo root ------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "error: not inside a git repository" >&2; exit 1; }
cd "$REPO_ROOT" || exit 1

# shellcheck source=lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"

# --- defaults (override in .review/config.sh or via flags) -----------------
LENSES="correctness,security,contracts,resources,tests,scope"
EFFORT="high"
MODEL=""                 # empty = whatever the deep-review profile pins
PROFILE="deep-review"
CONFIDENCE_MIN="0.5"
MAX_PARALLEL="6"
LENS_TIMEOUT="900"       # seconds per lens
FAIL_ON="none"           # none | critical | high | medium | low
RUN_ANALYZERS="1"
BASE=""
MODE="branch"            # branch | uncommitted

[ -f "$REPO_ROOT/.review/config.sh" ] && . "$REPO_ROOT/.review/config.sh"

# --- args ------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --uncommitted)  MODE="uncommitted" ;;
    --lenses)       LENSES="$2"; shift ;;
    --effort)       EFFORT="$2"; shift ;;
    --model)        MODEL="$2"; shift ;;
    --profile)      PROFILE="$2"; shift ;;
    --confidence)   CONFIDENCE_MIN="$2"; shift ;;
    --timeout)      LENS_TIMEOUT="$2"; shift ;;
    --fail-on)      FAIL_ON="$2"; shift ;;
    --no-analyzers) RUN_ANALYZERS="0" ;;
    --parallel)     MAX_PARALLEL="$2"; shift ;;
    -h|--help)      sed -n '2,20p' "$0"; exit 0 ;;
    -*)             die "unknown flag: $1" ;;
    *)              BASE="$1" ;;
  esac
  shift
done

OUT=".review/raw"
rm -rf "$OUT"; mkdir -p "$OUT"

# --- preflight -------------------------------------------------------------
need_cmd git
need_cmd jq
need_cmd codex
[ -f .review/schema.json ] || die "missing .review/schema.json — run scripts/review-install.sh"

if ! codex login status >/dev/null 2>&1; then
  warn "could not confirm Codex auth via 'codex login status'; continuing anyway"
fi

# --- resolve the change set ------------------------------------------------
if [ "$MODE" = "uncommitted" ]; then
  git diff HEAD > "$OUT/diff.patch"
  git ls-files --others --exclude-standard | while IFS= read -r f; do
    [ -f "$f" ] && git diff --no-index /dev/null "$f" >> "$OUT/diff.patch" 2>/dev/null
  done
  git diff HEAD --name-only > "$OUT/changed-files.txt"
  git ls-files --others --exclude-standard >> "$OUT/changed-files.txt"
  RANGE_LABEL="uncommitted changes in working tree"
else
  [ -n "$BASE" ] || BASE="$(detect_base_branch)"
  git rev-parse --verify "$BASE" >/dev/null 2>&1 || die "base ref not found: $BASE"
  MERGE_BASE="$(git merge-base "$BASE" HEAD)" || die "no merge base with $BASE"
  git diff "$MERGE_BASE"...HEAD > "$OUT/diff.patch"
  git diff "$MERGE_BASE"...HEAD --name-only > "$OUT/changed-files.txt"
  git log --format='%h %s' "$MERGE_BASE"..HEAD > "$OUT/commits.txt"
  RANGE_LABEL="$BASE...$(git rev-parse --abbrev-ref HEAD) (merge-base ${MERGE_BASE:0:10})"
fi

# never review our own artifacts
grep -v -E '^\.review/' "$OUT/changed-files.txt" | sort -u > "$OUT/changed-files.tmp" \
  && mv "$OUT/changed-files.tmp" "$OUT/changed-files.txt"
CHANGED_COUNT="$(grep -c . < "$OUT/changed-files.txt" || true)"
DIFF_LINES="$(wc -l < "$OUT/diff.patch" | tr -d ' ')"

if [ "${CHANGED_COUNT:-0}" -eq 0 ]; then
  info "no changes to review against $RANGE_LABEL"
  printf '{"findings":[]}' > .review/findings.json
  exit 0
fi

info "reviewing $CHANGED_COUNT file(s), $DIFF_LINES diff lines — $RANGE_LABEL"

# --- cheap static signal (fed to Codex as priors, so it aims higher) -------
if [ "$RUN_ANALYZERS" = "1" ]; then
  . "$REPO_ROOT/scripts/lib/analyzers.sh"
  collect_analyzer_output "$OUT" || warn "analyzer collection had errors (non-fatal)"
fi

# --- build the shared context block ----------------------------------------
{
  echo "## Review context"
  echo
  echo "- Repository root: \`$REPO_ROOT\`"
  echo "- Change set: $RANGE_LABEL"
  echo "- Files changed: $CHANGED_COUNT"
  echo "- Unified diff: \`.review/raw/diff.patch\`"
  echo "- Changed file list: \`.review/raw/changed-files.txt\`"
  [ -f "$OUT/commits.txt" ] && echo "- Commits in range: \`.review/raw/commits.txt\`"
  [ -s "$OUT/analyzers.txt" ] && echo "- Static analyzer output already collected: \`.review/raw/analyzers.txt\` (do NOT re-report anything a linter already flagged there)"
  echo
} > "$OUT/context.md"

# --- launch lenses ---------------------------------------------------------
pids=""; running=0; launched=""
OLD_IFS="$IFS"; IFS=','
for lens in $LENSES; do
  IFS="$OLD_IFS"
  lens="$(echo "$lens" | tr -d '[:space:]')"
  [ -n "$lens" ] || { IFS=','; continue; }
  lens_file=".review/prompts/${lens}.md"
  if [ ! -f "$lens_file" ]; then
    warn "no prompt for lens '$lens' at $lens_file — skipping"; IFS=','; continue
  fi

  pf="$OUT/prompt-$lens.md"
  {
    cat .review/prompts/_common.md
    echo; echo "---"; echo
    cat "$OUT/context.md"
    echo "---"; echo
    if [ -s .review/learnings-shared.md ]; then
      echo "## Kit-wide learnings (shared across repositories — obey these)"
      echo
      cat .review/learnings-shared.md
      echo; echo "---"; echo
    fi
    if [ -s .review/learnings.md ]; then
      echo "## Repository learnings (accumulated from past reviews — obey these)"
      echo
      cat .review/learnings.md
      echo; echo "---"; echo
    fi
    cat "$lens_file"
    # repo-owned overlay: extra hunt lists layered onto the shared lens prompt
    if [ -s ".review/prompts.local/${lens}.md" ]; then
      echo
      cat ".review/prompts.local/${lens}.md"
    fi
  } > "$pf"

  (
    args="exec --profile $PROFILE --sandbox read-only --ask-for-approval never"
    args="$args -c model_reasoning_effort=$EFFORT"
    [ -n "$MODEL" ] && args="$args --model $MODEL"
    # shellcheck disable=SC2086
    run_with_timeout "$LENS_TIMEOUT" \
      codex $args \
        --output-schema .review/schema.json \
        -o "$OUT/out-$lens.json" \
        "$(cat "$pf")" \
      > "$OUT/log-$lens.txt" 2>&1
    echo "$?" > "$OUT/rc-$lens"
  ) &
  pids="$pids $!"
  launched="$launched $lens"
  info "  → lens '$lens' started (effort=$EFFORT)"

  running=$((running + 1))
  if [ "$running" -ge "$MAX_PARALLEL" ]; then wait; running=0; fi
  IFS=','
done
IFS="$OLD_IFS"

wait

# --- normalise each lens output -------------------------------------------
ok_lenses=0
for lens in $launched; do
  rc="$(cat "$OUT/rc-$lens" 2>/dev/null || echo 1)"
  f="$OUT/out-$lens.json"
  if [ ! -s "$f" ]; then
    warn "lens '$lens' produced no output (rc=$rc) — see $OUT/log-$lens.txt"
    printf '{"findings":[]}' > "$f"; continue
  fi
  salvage_json "$f" || {
    warn "lens '$lens' returned unparseable output — see $OUT/log-$lens.txt"
    printf '{"findings":[]}' > "$f"; continue
  }
  jq --arg l "$lens" '.findings = ((.findings // []) | map(. + {lens: $l}))' "$f" \
    > "$f.tmp" && mv "$f.tmp" "$f"
  n="$(jq '.findings | length' "$f")"
  info "  ← lens '$lens': $n finding(s) (rc=$rc)"
  ok_lenses=$((ok_lenses + 1))
done

[ "$ok_lenses" -gt 0 ] || die "every lens failed — check $OUT/log-*.txt"

# --- merge, filter, dedupe, sort ------------------------------------------
jq -s --argjson th "$CONFIDENCE_MIN" '
  { findings: (map(.findings // []) | add // []) }
  | .findings |= (
      map(select((.confidence // 0) >= $th))
      # collapse duplicates, but keep the highest severity/confidence seen and
      # remember every lens that independently reported it (agreement = signal)
      | group_by(((.file // "?") + ":" + ((.line_start // 0)|tostring) + ":" + (.title // "?")) | ascii_downcase)
      | map(
          ( sort_by(({critical:0,high:1,medium:2,low:3}[.severity] // 4), -(.confidence // 0)) | .[0] )
          + { lens: (map(.lens) | unique | join(",")),
              agreement: length,
              confidence: (map(.confidence // 0) | max) }
        )
      | sort_by(({critical:0, high:1, medium:2, low:3}[.severity] // 4), -(.agreement), .file, (.line_start // 0))
      | to_entries | map(.value + {id: ("F" + ((.key + 1)|tostring))})
    )
' "$OUT"/out-*.json > .review/findings.json || die "merge failed"

TOTAL="$(jq '.findings | length' .review/findings.json)"

# --- human-readable render -------------------------------------------------
{
  echo "# Codex pre-PR review"
  echo
  echo "\`$RANGE_LABEL\` · $CHANGED_COUNT files · lenses:$launched · effort \`$EFFORT\` · min confidence \`$CONFIDENCE_MIN\`"
  echo
  if [ "$(jq '.findings | length' .review/findings.json)" -eq 0 ]; then
    echo "_No findings above the confidence threshold._"
  else
    jq -r '
      .findings[]
      | "## " + (.id) + " · " + (.severity | ascii_upcase) + " · " + (.title)
      + "\n\n`" + (.file // "?") + ":" + ((.line_start // 0) | tostring)
      + (if (.line_end // 0) > (.line_start // 0) then "-" + ((.line_end)|tostring) else "" end)
      + "`  ·  lens `" + (.lens // "?") + "`  ·  " + (.category // "-")
      + "  ·  confidence " + ((.confidence // 0) | tostring)
      + (if (.agreement // 1) > 1 then "  ·  **" + ((.agreement)|tostring) + " lenses agree**" else "" end)
      + "\n\n**Why it matters.** " + (.why_it_matters // "-")
      + "\n\n**Evidence.** " + (.evidence // "-")
      + (if (.suggested_fix // "") != "" then "\n\n**Suggested fix.** " + .suggested_fix else "" end)
      + "\n"
    ' .review/findings.json
  fi
} > .review/findings.md

# --- summary ---------------------------------------------------------------
echo
info "$TOTAL finding(s) → .review/findings.json  ·  .review/findings.md"
jq -r '
  (.findings | group_by(.severity) | map({(.[0].severity): length}) | add // {}) as $c
  | ["critical","high","medium","low"] | map(. + ": " + (($c[.] // 0)|tostring)) | join("   ")
' .review/findings.json

# --- gate ------------------------------------------------------------------
case "$FAIL_ON" in
  none) exit 0 ;;
  critical|high|medium|low)
    hit="$(jq --arg lvl "$FAIL_ON" '
      {critical:0,high:1,medium:2,low:3} as $r
      | [.findings[] | select(($r[.severity] // 9) <= ($r[$lvl] // 9))] | length' .review/findings.json)"
    if [ "$hit" -gt 0 ]; then
      warn "$hit finding(s) at or above '$FAIL_ON'"; exit 2
    fi
    ;;
esac
exit 0
