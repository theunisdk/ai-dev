#!/usr/bin/env bash
# Run claude_session_audit.py every hour: a LaunchAgent on macOS, a crontab line elsewhere.
# macOS uses launchd, not cron, because the Claude login lives in the login Keychain,
# which only jobs inside the user's session can read. Idempotent; --remove uninstalls.
#
#   ./install-schedule.sh            # install or refresh
#   ./install-schedule.sh --remove   # uninstall (reports in ~/.claude-audit stay)
set -euo pipefail

# The job runs the script through setup.sh's skill link, so it survives the checkout moving.
SCRIPT="$HOME/.claude/skills/agent-audit/claude_session_audit.py"
AUDIT_DIR="${CLAUDE_AUDIT_DIR:-$HOME/.claude-audit}"
LABEL="com.theunisdk.claude-audit"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CRON_TAG="# claude-session-audit"

case "${1:-}" in
  "") remove=false ;;
  --remove) remove=true ;;
  *) echo "usage: $0 [--remove]" >&2; exit 64 ;;
esac

read_crontab() {
  local out
  if out="$(crontab -l 2>&1)"; then
    printf '%s\n' "$out" | grep -vF "$CRON_TAG" || true
  elif printf '%s' "$out" | grep -qi "no crontab"; then
    :
  else
    echo "  ! audit schedule: crontab -l failed, crontab left alone: $out" >&2
    return 1
  fi
}

launchd_loaded() { launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; }

if $remove; then
  if [ "$(uname)" = "Darwin" ]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    if launchd_loaded; then
      echo "  ! audit schedule: $LABEL is still loaded; log out and back in to stop it" >&2
      exit 1
    fi
    rm -f "$PLIST"
  else
    current="$(read_crontab)"
    printf '%s\n' "$current" | crontab -
  fi
  echo "  - audit schedule removed"
  exit 0
fi

if [ ! -e "$SCRIPT" ]; then
  echo "  ! audit schedule: $SCRIPT missing — run ./setup.sh first; not installed" >&2
  exit 1
fi
PY="$(command -v python3 || true)"
CLAUDE="$(command -v claude || true)"
if [ -z "$PY" ] || [ -z "$CLAUDE" ]; then
  echo "  ! audit schedule: python3 and the claude CLI must be on PATH — not installed" >&2
  exit 1
fi
# Resolve shims (pyenv, asdf) to the real interpreter; launchd and cron won't load them.
PY="$("$PY" -c 'import sys; print(sys.executable)')"
mkdir -p "$AUDIT_DIR"

if [ "$(uname)" = "Darwin" ]; then
  xml() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
  new="$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(xml "$PY")</string>
    <string>$(xml "$SCRIPT")</string>
    <string>--claude-bin</string><string>$(xml "$CLAUDE")</string>
    <string>--on-flag</string>
    <string>osascript -e "display notification \"Hourly agent audit: {verdict}. Ask Claude what the audit found.\" with title \"Claude audit\""</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$(xml "$(dirname "$CLAUDE")"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    <key>CLAUDE_AUDIT_DIR</key><string>$(xml "$AUDIT_DIR")</string>
  </dict>
  <key>StartInterval</key><integer>3600</integer>
  <key>StandardOutPath</key><string>$(xml "$AUDIT_DIR")/schedule.log</string>
  <key>StandardErrorPath</key><string>$(xml "$AUDIT_DIR")/schedule.log</string>
</dict>
</plist>
EOF
)"
  # Reload only on a change: a bootout kills an audit that is mid-run.
  if [ -f "$PLIST" ] && [ "$(cat "$PLIST")" = "$new" ] && launchd_loaded; then
    echo "  ✓ audit schedule: launchd $LABEL, hourly (unchanged)"
    exit 0
  fi
  mkdir -p "$(dirname "$PLIST")"
  printf '%s\n' "$new" > "$PLIST"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  for _ in 1 2 3; do
    launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null && break
    sleep 2
  done
  if ! launchd_loaded; then
    echo "  ! audit schedule: launchctl bootstrap failed for $PLIST — not running" >&2
    exit 1
  fi
  echo "  ✓ audit schedule: launchd $LABEL, hourly"
else
  for p in "$PY" "$SCRIPT" "$CLAUDE" "$AUDIT_DIR"; do
    case "$p" in *[\'%]*)
      echo "  ! audit schedule: cron can't take a path with ' or %: $p — not installed" >&2
      exit 1 ;;
    esac
  done
  current="$(read_crontab)"
  line="0 * * * * PATH='$(dirname "$CLAUDE")':/usr/local/bin:/usr/bin:/bin CLAUDE_AUDIT_DIR='$AUDIT_DIR' '$PY' '$SCRIPT' --claude-bin '$CLAUDE' >> '$AUDIT_DIR/schedule.log' 2>&1 $CRON_TAG"
  if [ -n "$current" ]; then
    printf '%s\n%s\n' "$current" "$line" | crontab -
  else
    printf '%s\n' "$line" | crontab -
  fi
  echo "  ✓ audit schedule: crontab, hourly"
  if grep -qi microsoft /proc/version 2>/dev/null && ! pgrep -x cron >/dev/null; then
    echo "    note: cron isn't running in this WSL distro — enable systemd in /etc/wsl.conf, or: sudo service cron start"
  fi
fi
