#!/usr/bin/env bash
# Read-only check for the trojanized Anthropic.claude-code 2.1.313 IDE extension
# (Cursor extension marketplace, 2026-10-29). It changes nothing on the machine.
# Indicators come from Cursor's notice:
#   https://cursor.com/blog/claude-code-extension-security-notice
#
#   bash check.sh
#
# Exit: 0 no indicator found, 1 indicator found, 2 none found but a check could not run.
set -u

IP='134.209.82.225'
KEY_COMMENT='svc-telemetry'
KEY_FP='SHA256:0Z6R+DF64Do2nwQic8a7kkfDLNNk4IiK+2U2Rci4htk'
BAD_VERSION='2.1.313'
BAD_VERSION_RE='anthropic\.claude-code[-@ ]v?2\.1\.313'

found=0; skipped=0
hit()  { echo "FOUND  $*"; found=$((found + 1)); }
ok()   { echo "clean  $*"; }
skip() { echo "SKIP   $*"; skipped=$((skipped + 1)); }
note() { echo "info   $*"; }

os="$(uname -s)"
wsl=0
grep -qi microsoft /proc/version 2>/dev/null && wsl=1

# In WSL the Windows profiles are scanned too, for extensions and IDE logs.
homes=("$HOME")
if [ "$wsl" = 1 ]; then
  for d in /mnt/c/Users/*/; do
    [ -d "$d/AppData" ] && homes+=("${d%/}")
  done
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
      name="${ext#"$h"/}"
      case "$ext" in
        *"-$BAD_VERSION"*) hit "malicious version installed: $ext" ;;
      esac
      if [ ! -r "$ext" ]; then
        skip "cannot read $ext"
      elif grep -rqlF -e "$IP" -e "$KEY_COMMENT" "$ext" 2>/dev/null; then
        hit "backdoor strings in $ext"
      else
        ok "$name"
      fi
    done
    for meta in "$dir/extensions.json" "$dir/.obsolete"; do
      [ -f "$meta" ] || continue
      if grep -qE "$BAD_VERSION_RE" "$meta" 2>/dev/null; then
        hit "$BAD_VERSION recorded in $meta"
      fi
    done
  done
done
[ "$ext_seen" = 1 ] || ok "no Claude Code IDE extension installed"

echo "== IDE logs (was $BAD_VERSION ever loaded?)"
log_seen=0
for h in "${homes[@]}"; do
  for app in Cursor Code "Code - Insiders" Windsurf VSCodium; do
    for logs in "$h/Library/Application Support/$app/logs" "$h/.config/$app/logs" \
                "$h/AppData/Roaming/$app/logs"; do
      [ -d "$logs" ] || continue
      log_seen=1
      if grep -rqE "$BAD_VERSION_RE" "$logs" 2>/dev/null; then
        hit "$BAD_VERSION appears in $logs"
      else
        ok "$logs"
      fi
    done
  done
done
[ "$log_seen" = 1 ] || note "no IDE log folders found"

echo "== SSH authorized_keys"
for f in "$HOME/.ssh/authorized_keys" "$HOME/.ssh/authorized_keys2"; do
  [ -e "$f" ] || { ok "$f absent"; continue; }
  [ -r "$f" ] || { skip "cannot read $f"; continue; }
  before=$found
  grep -nF "$KEY_COMMENT" "$f" >/dev/null 2>&1 && hit "key '$KEY_COMMENT' in $f"
  # The comment can be edited away; the fingerprint cannot.
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -lf "$f" 2>/dev/null | grep -qF "$KEY_FP" && hit "attacker key fingerprint in $f"
  else
    skip "ssh-keygen missing, fingerprint not checked in $f"
  fi
  [ "$found" = "$before" ] && ok "$f"
done

echo "== Dropped files"
for f in "$HOME/.config/.smt" "$HOME/.config/.smtk" "$HOME/.config/smt.cmd" "$HOME/.config/smtk" \
         "$HOME/Library/LaunchAgents/com.apple.sysmond.plist"; do
  if [ -e "$f" ]; then hit "$f"; else ok "$f absent"; fi
done
stk_seen=0
for t in "${TMPDIR:-/tmp}" /tmp; do
  for f in "${t%/}"/.stk_*; do
    [ -e "$f" ] && { hit "$f"; stk_seen=1; }
  done
done
[ "$stk_seen" = 1 ] || ok "no .stk_* files in temp"

echo "== Persistence"
if [ "$os" = Darwin ]; then
  agents="$HOME/Library/LaunchAgents"
  if [ -d "$agents" ]; then
    renamed="$(grep -lF -e ".config/.smt" -e "$IP" "$agents"/*.plist 2>/dev/null)"
    if [ -n "$renamed" ]; then hit "LaunchAgent runs the backdoor: $renamed"; else ok "LaunchAgents"; fi
  fi
  # Apple's real sysmond is a system daemon; only a per-user agent of that name is the backdoor.
  if launchctl print "gui/$(id -u)/com.apple.sysmond" >/dev/null 2>&1; then
    hit "user LaunchAgent com.apple.sysmond is loaded"
  else
    ok "no user LaunchAgent com.apple.sysmond loaded"
  fi
fi
if command -v crontab >/dev/null 2>&1; then
  if crontab -l 2>/dev/null | grep -qF -e ".config/.smt" -e "$IP"; then
    hit "crontab entry runs the backdoor"
  else
    ok "crontab"
  fi
else
  note "crontab command missing"
fi

echo "== Live processes and connections"
procs="$(ps ax -o pid= -o args= 2>/dev/null)"
if [ -z "$procs" ]; then
  skip "could not list processes"
else
  bad="$(printf '%s\n' "$procs" | grep -F -e "$IP" -e ".config/.smt" -e ".stk_")"
  if [ -n "$bad" ]; then hit "backdoor process: $bad"; else ok "no backdoor process"; fi
fi
if command -v lsof >/dev/null 2>&1; then
  conns="$(lsof -nP -i "@$IP" 2>/dev/null)"
  if [ -n "$conns" ]; then hit "open connection to $IP: $conns"; else ok "no connection to $IP"; fi
elif command -v ss >/dev/null 2>&1; then
  conns="$(ss -tn 2>/dev/null | grep -F "$IP")"
  if [ -n "$conns" ]; then hit "open connection to $IP: $conns"; else ok "no connection to $IP"; fi
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
