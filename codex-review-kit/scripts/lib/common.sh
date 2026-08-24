#!/usr/bin/env bash
# Shared helpers. Deliberately POSIX-ish: works on macOS bash 3.2 and Linux.

_c_red=""; _c_yel=""; _c_dim=""; _c_off=""
if [ -t 2 ]; then
  _c_red=$'\033[31m'; _c_yel=$'\033[33m'; _c_dim=$'\033[2m'; _c_off=$'\033[0m'
fi

info() { printf '%s[review]%s %s\n' "$_c_dim" "$_c_off" "$*" >&2; }
warn() { printf '%s[review] warn:%s %s\n' "$_c_yel" "$_c_off" "$*" >&2; }
die()  { printf '%s[review] error:%s %s\n' "$_c_red" "$_c_off" "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not on PATH"
}

# Detect the default base branch: origin/HEAD, else common names, else main.
detect_base_branch() {
  local ref
  ref="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"
  if [ -n "$ref" ]; then
    echo "${ref#refs/remotes/}"; return 0
  fi
  local b
  for b in origin/main origin/master origin/develop main master develop; do
    if git rev-parse --verify "$b" >/dev/null 2>&1; then echo "$b"; return 0; fi
  done
  echo "main"
}

# Portable timeout: run_with_timeout SECS cmd args...
# (macOS has no coreutils `timeout` by default.)
run_with_timeout() {
  local secs="$1"; shift
  "$@" &
  local pid=$!
  (
    local waited=0
    while [ "$waited" -lt "$secs" ]; do
      kill -0 "$pid" 2>/dev/null || exit 0
      sleep 2; waited=$((waited + 2))
    done
    kill -TERM "$pid" 2>/dev/null
    sleep 5
    kill -KILL "$pid" 2>/dev/null
  ) & local watcher=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill -TERM "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null
  return "$rc"
}

# Make a model's final message parse as JSON, in place.
# Strips markdown fences and any prose before the first '{'. Returns 1 if hopeless.
salvage_json() {
  local f="$1"
  if jq -e . "$f" >/dev/null 2>&1; then return 0; fi
  sed -e 's/^[[:space:]]*```[a-zA-Z]*[[:space:]]*$//' -e 's/^[[:space:]]*```[[:space:]]*$//' \
    "$f" > "$f.strip" 2>/dev/null
  if jq -e . "$f.strip" >/dev/null 2>&1; then mv "$f.strip" "$f"; return 0; fi
  # last resort: take from the first '{' to the last '}'
  awk 'BEGIN{s=0} /\{/ && s==0 {s=1} s==1 {print}' "$f.strip" 2>/dev/null > "$f.brace"
  if jq -e . "$f.brace" >/dev/null 2>&1; then mv "$f.brace" "$f"; rm -f "$f.strip"; return 0; fi
  rm -f "$f.strip" "$f.brace"
  return 1
}
