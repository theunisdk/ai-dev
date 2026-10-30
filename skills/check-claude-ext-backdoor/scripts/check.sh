#!/usr/bin/env bash
# Read-only check for the trojanized Anthropic.claude-code 2.1.313 IDE extension
# (Cursor extension marketplace, 2026-10-29). It changes nothing on the machine.
# Indicators come from Cursor's notice and, for Linux, from OpenSourceMalware:
#   https://cursor.com/blog/claude-code-extension-security-notice
#   https://opensourcemalware.com/blog/trojanized-claude-code-extension-plants-persistent-ssh-backdoor
#
#   bash check.sh        (as the user who runs the IDE, never with sudo)
#
# Exit: 0 no indicator found, 1 indicator found, 2 none found but a check could not run.
set -u

IP='134.209.82.225'
IP_RE='134\.209\.82\.225'
KEY_COMMENT='svc-telemetry'
KEY_FP='SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk'
BAD_VERSION='2.1.313'
BAD_VERSION_RE='anthropic\.claude-code[-@ ]v?2\.1\.313'
SMT_RE='\.config/\.smtk?([^[:alnum:]_.]|$)'
STK_RE='\.stk_[0-9a-f]{10}'

found=0; skipped=0
hit()  { echo "FOUND  $*"; found=$((found + 1)); }
ok()   { echo "clean  $*"; }
skip() { echo "SKIP   $*"; skipped=$((skipped + 1)); }
note() { echo "info   $*"; }

# grep exits 0 on a match, 1 on none, and 2 when it could not read something.
grep_result() {
  local rc=$1 what=$2 clean_msg=$3 target=${4:-$3}
  case $rc in
    0) hit "$what" ;;
    1) [ -n "$clean_msg" ] && ok "$clean_msg" ;;
    *) skip "could not read all of $target" ;;
  esac
  return 0
}

if [ -z "${HOME:-}" ]; then
  echo "SKIP   HOME is not set"; echo "RESULT: could not run."; exit 2
fi
if [ "$(id -u)" = 0 ] && [ -n "${SUDO_USER:-}" ]; then
  echo "SKIP   running under sudo checks root's home, not $SUDO_USER's. Run without sudo."
  echo "RESULT: could not run."; exit 2
fi

os="$(uname -s)"
wsl=0
grep -qi microsoft /proc/version 2>/dev/null && wsl=1

homes=("$HOME")
if [ "$wsl" = 1 ]; then
  win_profiles=0
  for d in /mnt/c/Users/*/; do
    [ -d "$d/AppData" ] && { homes+=("${d%/}"); win_profiles=1; }
  done
  [ "$win_profiles" = 1 ] || note "WSL: no Windows profile under /mnt/c/Users; run check.ps1 on the Windows host"
fi

echo "== IDE extensions"
ext_seen=0
for h in "${homes[@]}"; do
  for root in .cursor .cursor-server .vscode .vscode-server .vscode-insiders \
              .vscode-server-insiders .vscode-oss .vscodium .windsurf .windsurf-server; do
    dir="$h/$root/extensions"
    [ -d "$dir" ] || continue
    for ext in "$dir"/anthropic.claude-code-*; do
      [ -d "$ext" ] || continue
      ext_seen=1
      case "$ext" in
        *"-$BAD_VERSION"*) hit "malicious version installed: $ext"; continue ;;
      esac
      if [ ! -f "$ext/extension.js" ]; then
        skip "no extension.js in $ext"
        continue
      fi
      grep -qF -e "$IP" -e "$KEY_COMMENT" "$ext/extension.js" 2>/dev/null
      grep_result $? "backdoor strings in $ext/extension.js" "$ext"
    done
    for meta in "$dir/extensions.json" "$dir/.obsolete"; do
      [ -f "$meta" ] || continue
      grep -qE "$BAD_VERSION_RE" "$meta" 2>/dev/null
      grep_result $? "$BAD_VERSION recorded in $meta" "$meta"
    done
  done
done
[ "$ext_seen" = 1 ] || ok "no Claude Code IDE extension installed"

echo "== IDE logs (was $BAD_VERSION ever loaded?)"
log_seen=0
for h in "${homes[@]}"; do
  log_dirs=()
  for app in Cursor Code "Code - Insiders" Windsurf VSCodium; do
    log_dirs+=("$h/Library/Application Support/$app/logs" "$h/.config/$app/logs" "$h/AppData/Roaming/$app/logs")
  done
  for server in .cursor-server .vscode-server .vscode-server-insiders .windsurf-server; do
    log_dirs+=("$h/$server/data/logs")
  done
  for logs in "${log_dirs[@]}"; do
    [ -d "$logs" ] || continue
    log_seen=1
    grep -rqE "$BAD_VERSION_RE" "$logs" 2>/dev/null
    grep_result $? "$BAD_VERSION appears in $logs" "$logs"
  done
done
[ "$log_seen" = 1 ] || note "no IDE log folders found"

echo "== SSH authorized_keys"
for f in "$HOME/.ssh/authorized_keys" "$HOME/.ssh/authorized_keys2"; do
  [ -e "$f" ] || { ok "$f absent"; continue; }
  [ -r "$f" ] || { skip "cannot read $f"; continue; }
  before=$found; before_skip=$skipped
  grep -qF "$KEY_COMMENT" "$f" 2>/dev/null
  grep_result $? "key '$KEY_COMMENT' in $f" "" "$f"
  # The comment can be edited away; the fingerprint cannot.
  if command -v ssh-keygen >/dev/null 2>&1; then
    fps="$(ssh-keygen -lf "$f" 2>/dev/null)"; rc=$?
    if printf '%s\n' "$fps" | grep -qF "$KEY_FP"; then
      hit "attacker key fingerprint in $f"
    elif [ "$rc" != 0 ] && grep -qvE '^[[:space:]]*(#|$)' "$f" 2>/dev/null; then
      skip "ssh-keygen could not read the keys in $f"
    fi
  else
    skip "ssh-keygen missing, fingerprint not checked in $f"
  fi
  [ "$found" = "$before" ] && [ "$skipped" = "$before_skip" ] && ok "$f"
done

echo "== Dropped files"
for f in "$HOME/.config/.smt" "$HOME/.config/.smtk" "$HOME/.config/smt.cmd" "$HOME/.config/smtk" \
         "$HOME/Library/LaunchAgents/com.apple.sysmond.plist"; do
  if [ -e "$f" ]; then hit "$f"; else ok "$f absent"; fi
done
tmp_dirs=("${TMPDIR:-/tmp}" /tmp)
[ "$os" = Darwin ] && tmp_dirs+=("$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)")
stk_seen=0; scanned=" "
for t in "${tmp_dirs[@]}"; do
  [ -n "$t" ] || continue
  t="${t%/}"
  case "$scanned" in *" $t "*) continue ;; esac
  scanned="$scanned$t "
  for f in "$t"/.stk_*; do
    [ -e "$f" ] && { hit "$f"; stk_seen=1; }
  done
done
[ "$stk_seen" = 1 ] || ok "no .stk_* files in$scanned"

echo "== Persistence"
if [ "$os" = Darwin ]; then
  plists=("$HOME/Library/LaunchAgents"/*.plist)
  if [ -e "${plists[0]}" ]; then
    grep -qE -e "$SMT_RE" -e "$IP_RE" "${plists[@]}" 2>/dev/null
    grep_result $? "a LaunchAgent runs the backdoor: $(grep -lE -e "$SMT_RE" -e "$IP_RE" "${plists[@]}" 2>/dev/null | tr '\n' ' ')" "LaunchAgents"
  else
    ok "no LaunchAgents"
  fi
  # Apple's real sysmond is a system daemon; only a per-user agent of that name is the backdoor.
  launchctl print "gui/$(id -u)/com.apple.sysmond" >/dev/null 2>&1
  case $? in
    0) hit "user LaunchAgent com.apple.sysmond is loaded" ;;
    113) ok "no user LaunchAgent com.apple.sysmond loaded" ;;
    *) skip "launchctl could not query the gui/$(id -u) domain (no GUI session?)" ;;
  esac
fi
if command -v crontab >/dev/null 2>&1; then
  cron="$(crontab -l 2>&1)"; rc=$?
  if [ "$rc" = 0 ]; then
    printf '%s\n' "$cron" | grep -qE -e "$SMT_RE" -e "$IP_RE"
    grep_result $? "crontab entry runs the backdoor" "crontab"
  elif printf '%s\n' "$cron" | grep -qi "no crontab"; then
    ok "no crontab"
  else
    skip "crontab -l failed: $(printf '%s\n' "$cron" | head -1)"
  fi
else
  note "crontab command missing"
fi

echo "== Live processes and connections"
procs="$(ps ax -o pid= -o args= 2>/dev/null)"
if [ -z "$procs" ]; then
  skip "could not list processes"
else
  bad="$(printf '%s\n' "$procs" | awk -v me=$$ -v parent="$PPID" '$1 != me && $1 != parent' |
    grep -E -e "$SMT_RE" -e "$STK_RE" -e "ssh.*$IP_RE")"
  if [ -n "$bad" ]; then hit "backdoor process: $bad"; else ok "no backdoor process"; fi
fi
if command -v lsof >/dev/null 2>&1; then
  conns="$(lsof -nP -i "@$IP" 2>&1)"; rc=$?
  if [ "$rc" = 0 ] && [ -n "$conns" ]; then hit "open connection to $IP: $conns"
  elif [ "$rc" = 1 ] && [ -z "$conns" ]; then ok "no connection to $IP"
  else skip "lsof failed: $(printf '%s\n' "$conns" | head -1)"; fi
elif command -v ss >/dev/null 2>&1; then
  conns="$(ss -tn 2>&1)"; rc=$?
  if [ "$rc" != 0 ]; then
    skip "ss failed: $(printf '%s\n' "$conns" | head -1)"
  else
    printf '%s\n' "$conns" | grep -qF "$IP"
    grep_result $? "open connection to $IP" "no connection to $IP"
  fi
else
  skip "neither lsof nor ss available, connections not checked"
fi

echo "== SSH server state (context, not an indicator)"
if [ "$os" = Darwin ]; then
  note "Remote Login state needs admin to read: sudo systemsetup -getremotelogin"
elif command -v systemctl >/dev/null 2>&1; then
  for svc in ssh sshd; do
    state="$(systemctl is-active "$svc" 2>/dev/null)"
    [ -n "$state" ] && [ "$state" != inactive ] && note "$svc service: $state"
  done
fi
[ "$wsl" = 1 ] && note "WSL: also run check.ps1 in PowerShell on the Windows host"

echo
if [ "$found" -gt 0 ]; then
  echo "RESULT: $found indicator(s) found. Treat this machine as exposed; see the skill's next steps."
  exit 1
elif [ "$skipped" -gt 0 ]; then
  echo "RESULT: no indicator found, but $skipped check(s) could not run (SKIP lines above)."
  exit 2
fi
echo "RESULT: no indicator found."
exit 0
