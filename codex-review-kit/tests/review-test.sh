#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# review-test.sh — regression tests for scripts/review.sh.
#
# Drives the real script end-to-end inside a throwaway git repo, with a
# stubbed `codex` on PATH — no network, no Codex login, no real lenses.
# Each test builds a fresh fixture repo with the kit installed, points the
# stub at per-lens fixtures, and asserts on the report the run leaves behind.
#
#   ./tests/review-test.sh
#
# Exit codes: 0 all passed · 1 at least one assertion failed
# ---------------------------------------------------------------------------
set -uo pipefail

KIT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
pass() { printf 'ok   - %s\n' "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf 'FAIL - %s\n' "$*"; }
assert()     { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi; }
assert_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi; }

# --- codex stub ------------------------------------------------------------
# Writes $CODEX_STUB_DIR/<lens>.json to the -o path and exits with the code
# in $CODEX_STUB_DIR/<lens>.rc (default 0). `codex login status` succeeds.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/codex" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "login" ] && exit 0
out=""
while [ $# -gt 0 ]; do
  [ "$1" = "-o" ] && { out="$2"; shift; }
  shift
done
lens="$(basename "$out" .json)"; lens="${lens#out-}"
[ -n "$out" ] && [ -f "$CODEX_STUB_DIR/$lens.json" ] && cp "$CODEX_STUB_DIR/$lens.json" "$out"
rc=0
[ -f "$CODEX_STUB_DIR/$lens.rc" ] && rc="$(cat "$CODEX_STUB_DIR/$lens.rc")"
exit "$rc"
EOF
chmod +x "$WORK/bin/codex"

# --- fixture helpers -------------------------------------------------------
make_repo() { # make_repo <dir> — kit installed, one commit on main, branch `change` checked out
  local dir="$1"
  git init -q -b main "$dir"
  (
    cd "$dir" || exit 1
    git config user.email review-test@example.invalid
    git config user.name review-test
    mkdir -p scripts/lib .review/prompts .review/raw
    cp "$KIT/scripts/review.sh" scripts/
    cp "$KIT/scripts/lib/common.sh" scripts/lib/
    cp "$KIT/.review/schema.json" .review/
    cp "$KIT/.review/prompts/_common.md" "$KIT/.review/prompts/correctness.md" \
       "$KIT/.review/prompts/security.md" .review/prompts/
    printf 'house rules\n' > .review/rubric.md
    printf 'seed\n' > .review/findings.md
    printf 'seed\n' > .review/raw/seed.txt
    printf 'seed\n' > src.txt
    git add -A && git commit -qm base && git checkout -qb change
  )
}

finding() { # finding <title> — one schema-shaped, above-threshold finding
  printf '{"findings":[{"file":"src.txt","line_start":1,"line_end":1,"severity":"high","category":"correctness","title":"%s","why_it_matters":"stub","evidence":"stub","suggested_fix":"stub","confidence":0.9}]}' "$1"
}

LOG=""
run_review() { # run_review <dir> <stubdir> <review.sh args...>; output in $LOG
  local dir="$1" stub="$2"; shift 2
  LOG="$dir.log"
  (
    cd "$dir" && PATH="$WORK/bin:$PATH" CODEX_STUB_DIR="$stub" \
      REVIEW_SKIP_AUTH_CHECK=1 bash scripts/review.sh --no-analyzers "$@" main
  ) > "$LOG" 2>&1
}

# --- tests -----------------------------------------------------------------
assert "review.sh parses (bash -n)" bash -n "$KIT/scripts/review.sh"

# A branch changing only tracked .review/ sources must still be reviewed:
# those files are review INPUTS (rubric, prompts, config). Only the kit's
# generated artifacts stay excluded. Regression for the filter that dropped
# ^.review/ wholesale and made rubric-only branches take the zero-change
# exit with complete:true.
test_tracked_review_sources_survive_filter() {
  local repo="$WORK/t1" stub="$WORK/t1-stub"
  make_repo "$repo"; mkdir -p "$stub"
  printf '{"findings":[]}' > "$stub/correctness.json"
  (
    cd "$repo" || exit 1
    printf 'updated rule\n' >> .review/rubric.md
    printf 'stale\n' >> .review/findings.md
    printf 'junk\n' >> .review/raw/seed.txt
    git add -A && git commit -qm 'change review sources and artifacts'
  )
  run_review "$repo" "$stub" --lenses correctness; local rc=$?

  assert    "t1: run exits 0" test "$rc" -eq 0
  assert_not "t1: zero-change early exit not taken" grep -q 'no changes to review' "$LOG"
  assert    "t1: rubric survives the filter" grep -qxF '.review/rubric.md' "$repo/.review/raw/changed-files.txt"
  assert_not "t1: generated findings.md still filtered" grep -qxF '.review/findings.md' "$repo/.review/raw/changed-files.txt"
  assert_not "t1: generated raw/ still filtered" grep -qE '^\.review/raw/' "$repo/.review/raw/changed-files.txt"
  assert    "t1: lens launched" test -f "$repo/.review/raw/log-correctness.txt"
  assert    "t1: clean run reports complete:true" jq -e '.complete == true' "$repo/.review/findings.json"
}

# A lens that leaves valid JSON but exits nonzero (timeout kill, salvaged
# truncated output) did not finish its review. Its findings are kept, but it
# must land in lenses_failed and force complete:false — this is the case
# where the report otherwise asserts something false.
test_nonzero_rc_lens_marked_failed() {
  local repo="$WORK/t2" stub="$WORK/t2-stub"
  make_repo "$repo"; mkdir -p "$stub"
  finding 'clean lens finding'  > "$stub/correctness.json"
  finding 'failed lens finding' > "$stub/security.json"
  printf '42\n' > "$stub/security.rc"
  (
    cd "$repo" || exit 1
    printf 'change\n' >> src.txt
    git add -A && git commit -qm 'source change'
  )
  run_review "$repo" "$stub" --lenses correctness,security; local rc=$?

  assert "t2: run exits 0" test "$rc" -eq 0
  assert "t2: nonzero-rc lens in lenses_failed" jq -e '.lenses_failed == ["security"]' "$repo/.review/findings.json"
  assert "t2: complete is false" jq -e '.complete == false' "$repo/.review/findings.json"
  assert "t2: failed lens findings retained" \
    jq -e '[.findings[] | select(.title == "failed lens finding")] | length == 1' "$repo/.review/findings.json"
  assert "t2: clean lens findings retained" \
    jq -e '[.findings[] | select(.title == "clean lens finding")] | length == 1' "$repo/.review/findings.json"
}

# Every lens crashing WITH parseable output must still reach the merge and
# report its findings — failed-but-salvaged gates completeness, not the
# every-lens-failed abort.
test_all_lenses_failed_with_output_still_merges() {
  local repo="$WORK/t3" stub="$WORK/t3-stub"
  make_repo "$repo"; mkdir -p "$stub"
  finding 'salvaged finding' > "$stub/security.json"
  printf '42\n' > "$stub/security.rc"
  (
    cd "$repo" || exit 1
    printf 'change\n' >> src.txt
    git add -A && git commit -qm 'source change'
  )
  run_review "$repo" "$stub" --lenses security; local rc=$?

  assert     "t3: run exits 0" test "$rc" -eq 0
  assert_not "t3: every-lens-failed abort not taken" grep -q 'every lens failed' "$LOG"
  assert     "t3: findings retained" \
    jq -e '[.findings[] | select(.title == "salvaged finding")] | length == 1' "$repo/.review/findings.json"
  assert     "t3: complete is false" jq -e '.complete == false' "$repo/.review/findings.json"
  assert     "t3: lens in lenses_failed" jq -e '.lenses_failed == ["security"]' "$repo/.review/findings.json"
}

test_tracked_review_sources_survive_filter
test_nonzero_rc_lens_marked_failed
test_all_lenses_failed_with_output_still_merges

echo
if [ "$FAILURES" -gt 0 ]; then
  printf '%d assertion(s) FAILED\n' "$FAILURES"; exit 1
fi
echo "all tests passed"
