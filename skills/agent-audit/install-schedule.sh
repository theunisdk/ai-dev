#!/usr/bin/env bash
# Run claude_session_audit.py every hour: a LaunchAgent on macOS, a crontab line elsewhere.
# macOS uses launchd, not cron, because the Claude login lives in the login Keychain,
# which only jobs inside the user's session can read. Idempotent; --remove uninstalls.
#
#   ./install-schedule.sh            # install or refresh
#   ./install-schedule.sh --remove   # uninstall (reports in ~/.claude-audit stay)
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SKILL_DIR/claude_session_audit.py"
AUDIT_DIR="${CLAUDE_AUDIT_DIR:-$HOME/.claude-audit}"
LABEL="com.theunisdk.claude-audit"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CRON_TAG="# claude-session-audit"

remove=false
[ "${1:-}" = "--remove" ] && remove=true

if [ "$(uname)" = "Darwin" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  if $remove; then
    rm -f "$PLIST"
    echo "  - audit schedule removed"
    exit 0
  fi
else
  current="$(crontab -l 2>/dev/null | grep -vF "$CRON_TAG" || true)"
  if $remove; then
    printf '%s\n' "$current" | sed '/^$/d' | crontab -
    echo "  - audit schedule removed"
    exit 0
  fi
fi

PY="$(command -v python3 || true)"
CLAUDE="$(command -v claude || true)"
if [ -z "$PY" ] || [ -z "$CLAUDE" ]; then
  echo "  ! audit schedule: python3 and the claude CLI must be on PATH — not installed"
  exit 1
fi
mkdir -p "$AUDIT_DIR"

if [ "$(uname)" = "Darwin" ]; then
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PY</string>
    <string>$SCRIPT</string>
    <string>--claude-bin</string><string>$CLAUDE</string>
    <string>--on-flag</string>
    <string>osascript -e 'display notification "An agent session was flagged. Ask Claude what the hourly audit found." with title "Claude audit"'</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$(dirname "$CLAUDE"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    <key>CLAUDE_AUDIT_DIR</key><string>$AUDIT_DIR</string>
  </dict>
  <key>StartInterval</key><integer>3600</integer>
  <key>StandardOutPath</key><string>$AUDIT_DIR/schedule.log</string>
  <key>StandardErrorPath</key><string>$AUDIT_DIR/schedule.log</string>
</dict>
</plist>
EOF
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "  ✓ audit schedule: launchd $LABEL, hourly"
else
  line="0 * * * * PATH=$(dirname "$CLAUDE"):/usr/local/bin:/usr/bin:/bin CLAUDE_AUDIT_DIR='$AUDIT_DIR' '$PY' '$SCRIPT' --claude-bin '$CLAUDE' >> '$AUDIT_DIR/schedule.log' 2>&1 $CRON_TAG"
  printf '%s\n%s\n' "$current" "$line" | sed '/^$/d' | crontab -
  echo "  ✓ audit schedule: crontab, hourly"
  if grep -qi microsoft /proc/version 2>/dev/null && ! pgrep -x cron >/dev/null; then
    echo "    note: cron isn't running in this WSL distro — enable systemd in /etc/wsl.conf, or: sudo service cron start"
  fi
fi
