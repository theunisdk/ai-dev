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
#   ./scripts/review.sh --spec docs/specs/foo.md   # review a spec, not code
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
MODE="branch"            # branch | uncommitted | spec
SPEC_PATHS=""
LENSES_FLAG=0

[ -f "$REPO_ROOT/.review/config.sh" ] && . "$REPO_ROOT/.review/config.sh"

# --- args ------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --uncommitted)  MODE="uncommitted" ;;
    --spec)         MODE="spec"; SPEC_PATHS="$SPEC_PATHS $2"; shift ;;
    --lenses)       LENSES="$2"; LENSES_FLAG=1; shift ;;
    --effort)       EFFORT="$2"; shift ;;
    --model)        MODEL="$2"; shift ;;
    --profile)      PROFILE="$2"; shift ;;
    --confidence)   CONFIDENCE_MIN="$2"; shift ;;
    --timeout)      LENS_TIMEOUT="$2"; shift ;;
    --fail-on)      FAIL_ON="$2"; shift ;;
    --no-analyzers) RUN_ANALYZERS="0" ;;
    --parallel)     MAX_PARALLEL="$2"; shift ;;
    -h|--help)      sed -n '2,18p' "$0"; exit 0 ;;
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

# Fail closed. Every lens would fail identically on an expired login, and six
# empty lens outputs render as a clean review — the exact shape of "nothing"
# and "failed" being indistinguishable that this pipeline exists to catch.
if [ "${REVIEW_SKIP_AUTH_CHECK:-0}" != "1" ] && ! codex login status >/dev/null 2>&1; then
  die "not authenticated to Codex — run 'codex login' (REVIEW_SKIP_AUTH_CHECK=1 overrides, for when 'codex login status' is broken but exec works)"
fi

# A lens runs `codex exec`, which loads AGENTS.md — and AGENTS.md tells agents to
# run this script. Without this guard a lens can re-enter the pipeline instead of
# returning its findings.
[ -z "${REVIEW_LENS_SESSION:-}" ] || die "refusing to run inside a review lens session (REVIEW_LENS_SESSION is set)"

# --- spec mode: its own lens set, no diff, no analyzers --------------------
if [ "$MODE" = "spec" ]; then
  [ "$LENSES_FLAG" = 1 ] || LENSES="spec-assumptions,spec-holes,spec-conflicts,spec-ambiguity"
  RUN_ANALYZERS="0"
fi

# --- resolve the change set ------------------------------------------------
if [ "$MODE" = "spec" ]; then
  : > "$OUT/changed-files.txt"
  for p in $SPEC_PATHS; do
    if [ -d "$p" ]; then
      find "$p" -name '*.md' -type f >> "$OUT/changed-files.txt"
    elif [ -f "$p" ]; then
      printf '%s\n' "$p" >> "$OUT/changed-files.txt"
    else
      die "spec path not found: $p"
    fi
  done
  RANGE_LABEL="spec documents: $(tr '\n' ' ' < "$OUT/changed-files.txt")"
elif [ "$MODE" = "uncommitted" ]; then
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

# Never review our own generated artifacts — except in spec mode, where every path
# was named explicitly on the command line and dropping one silently reviews nothing.
# Only the generated ones: tracked .review/ sources (rubric, prompts, config) are
# review inputs like any other file, and excluding them makes a branch that changes
# only the review rules hit the zero-change early exit below and report a clean pass.
if [ "$MODE" = "spec" ]; then
  sort -u "$OUT/changed-files.txt" > "$OUT/changed-files.tmp"
else
  grep -v -E '^\.review/(raw|runs)/|^\.review/(findings\.json|findings\.md|verdict\.md)$' \
    "$OUT/changed-files.txt" | sort -u > "$OUT/changed-files.tmp"
fi
mv "$OUT/changed-files.tmp" "$OUT/changed-files.txt"
CHANGED_COUNT="$(grep -c . < "$OUT/changed-files.txt" || true)"
DIFF_LINES=0
[ -f "$OUT/diff.patch" ] && DIFF_LINES="$(wc -l < "$OUT/diff.patch" | tr -d ' ')"

if [ "${CHANGED_COUNT:-0}" -eq 0 ]; then
  info "no changes to review against $RANGE_LABEL"
  # Carries complete/lenses_failed like every other exit path. Adjudication is told to check
  # `complete` before anything else, so a payload without it forces the reader to guess — and
  # the guess that a clean run and a broken one look alike is exactly what those fields exist
  # to prevent.
  printf '{"findings":[],"lenses_failed":[],"complete":true}\n' > .review/findings.json
  printf '# Codex pre-PR review\n\nNo changes to review against %s.\n' "$RANGE_LABEL" > .review/findings.md
  exit 0
fi

if [ "$MODE" = "spec" ]; then
  info "reviewing $CHANGED_COUNT spec file(s) — $RANGE_LABEL"
else
  info "reviewing $CHANGED_COUNT file(s), $DIFF_LINES diff lines — $RANGE_LABEL"
fi

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
  if [ "$MODE" = "spec" ]; then
    echo "- Documents under review (cite findings against these files' line numbers):"
    sed 's/^/  - `/;s/$/`/' "$OUT/changed-files.txt"
    echo "- House rules: \`.review/rubric.md\` — a spec that would violate them is a finding."
  else
    echo "- Files changed: $CHANGED_COUNT"
    echo "- Unified diff: \`.review/raw/diff.patch\`"
    echo "- Changed file list: \`.review/raw/changed-files.txt\`"
  fi
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
    # Counted as failed, not merely skipped: its area went unreviewed either way, and a run
    # that silently drops a lens while reporting complete:true is the failure this whole
    # field exists to make visible. A local overlay alone does not create a lens — the shared
    # base prompt has to exist too.
    warn "no prompt for lens '$lens' at $lens_file — skipping"
    missing_lenses="${missing_lenses:-} $lens"
    IFS=','; continue
  fi

  pf="$OUT/prompt-$lens.md"
  common=".review/prompts/_common.md"
  [ "$MODE" = "spec" ] && common=".review/prompts/_common-spec.md"
  {
    cat "$common"
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
    # no --ask-for-approval: removed in codex 0.149; exec is non-interactive
    # and the deep-review profile pins approval_policy = "never" anyway.
    args="exec --profile $PROFILE --sandbox read-only"
    args="$args -c model_reasoning_effort=$EFFORT"
    [ -n "$MODEL" ] && args="$args --model $MODEL"
    # shellcheck disable=SC2086
    REVIEW_LENS_SESSION=1 run_with_timeout "$LENS_TIMEOUT" \
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
failed_lenses=""
for lens in $launched; do
  rc="$(cat "$OUT/rc-$lens" 2>/dev/null)"
  case "$rc" in ''|*[!0-9]*) rc=1 ;; esac
  f="$OUT/out-$lens.json"
  if [ ! -s "$f" ]; then
    warn "lens '$lens' produced no output (rc=$rc) — see $OUT/log-$lens.txt"
    failed_lenses="$failed_lenses $lens"
    printf '{"findings":[]}' > "$f"; continue
  fi
  salvage_json "$f" || {
    warn "lens '$lens' returned unparseable output — see $OUT/log-$lens.txt"
    failed_lenses="$failed_lenses $lens"
    printf '{"findings":[]}' > "$f"; continue
  }
  jq --arg l "$lens" '.findings = ((.findings // []) | map(. + {lens: $l}))' "$f" \
    > "$f.tmp" && mv "$f.tmp" "$f"
  n="$(jq '.findings | length' "$f")"
  if [ "$rc" -ne 0 ]; then
    # Parseable output is not a finished review: a lens killed by the timeout, or one
    # whose truncated output salvage_json scavenged, still leaves a valid JSON object.
    # Its findings are kept — its area is still unreviewed.
    warn "lens '$lens' exited rc=$rc — keeping its $n finding(s), but its area is unreviewed"
    failed_lenses="$failed_lenses $lens"
  else
    info "  ← lens '$lens': $n finding(s) (rc=$rc)"
  fi
  # Counts usable output, and only gates the every-lens-failed abort below — a salvaged
  # lens must still reach the merge even though it is also recorded as failed.
  ok_lenses=$((ok_lenses + 1))
done

if [ "$ok_lenses" -eq 0 ]; then
  # Write the failure out before dying. Otherwise .review/findings.json still holds the
  # PREVIOUS run's report — with its own complete:true — and the next reader adjudicates a
  # stale pass against the current branch without anything saying so.
  failed_lenses="$failed_lenses${missing_lenses:-}"
  jq -n --arg failed "$(printf '%s' "${failed_lenses# }")" \
    '{findings: [], lenses_failed: ($failed | if . == "" then [] else split(" ") end), complete: false}' \
    > .review/findings.json
  printf '# Codex pre-PR review\n\n> **INCOMPLETE — every lens failed.** No area of this diff was reviewed.\n> Check `%s/log-*.txt`.\n' \
    "$OUT" > .review/findings.md
  die "every lens failed — check $OUT/log-*.txt"
fi

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

# A lens that died contributes an empty findings array, which is indistinguishable
# from a lens that ran and found nothing. Record which ones failed so adjudication
# cannot read a partial run as a complete review.
failed_lenses="$failed_lenses${missing_lenses:-}"
FAILED_LIST="$(printf '%s' "${failed_lenses# }")"
jq --arg failed "$FAILED_LIST" '
  . + { lenses_failed: ($failed | if . == "" then [] else split(" ") end) }
  | . + { complete: ((.lenses_failed | length) == 0) }
' .review/findings.json > .review/findings.json.tmp \
  && mv .review/findings.json.tmp .review/findings.json

TOTAL="$(jq '.findings | length' .review/findings.json)"

# --- human-readable render -------------------------------------------------
{
  echo "# Codex pre-PR review"
  echo
  echo "\`$RANGE_LABEL\` · $CHANGED_COUNT files · lenses:$launched · effort \`$EFFORT\` · min confidence \`$CONFIDENCE_MIN\`"
  echo
  if [ -n "$FAILED_LIST" ]; then
    echo "> **INCOMPLETE REVIEW — do not treat this as a clean pass.**"
    echo "> These lenses did not finish their review: \`$FAILED_LIST\`."
    echo "> Their areas are unreviewed; any findings they emitted before failing are"
    echo "> listed below. See \`$OUT/log-<lens>.txt\`, fix the cause and re-run before"
    echo "> relying on this report."
    echo
  fi
  if [ "$(jq '.findings | length' .review/findings.json)" -eq 0 ]; then
    if [ -n "$FAILED_LIST" ]; then
      echo "_No findings — but the run was incomplete, so this is not a clean result._"
    else
      echo "_No findings above the confidence threshold._"
    fi
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
[ -z "$FAILED_LIST" ] || warn "INCOMPLETE: lens(es) failed; their areas are unreviewed —$failed_lenses"
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
