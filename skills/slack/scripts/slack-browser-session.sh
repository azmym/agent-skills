#!/bin/bash
# Manage a persistent Slack browser session via local Playwright.
# Provides cross-platform Slack access without macOS-specific token extraction.
#
# Usage:
#   slack-browser-session.sh start              Open browser, navigate to Slack
#   slack-browser-session.sh login EMAIL PASS   Automate email+password login
#   slack-browser-session.sh login-manual       Open visible browser for SSO/2FA
#   slack-browser-session.sh status             Show current session status
#   slack-browser-session.sh stop               Close browser session
#   slack-browser-session.sh get                Print session ID
#
# Prerequisites:
#   - Node.js 18+ (Playwright auto-installs on first use)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE="$SCRIPT_DIR/playwright-bridge.js"
SLACK_CONFIG_DIR="${HOME}/.agents/config/slack"
SESSION_FILE="${SLACK_CONFIG_DIR}/browser-session"
SESSIONS_DIR="${SLACK_CONFIG_DIR}/sessions"

mkdir -p "$SLACK_CONFIG_DIR"

# ---------------------------------------------------------------------------
# Ensure Playwright is installed
# ---------------------------------------------------------------------------
ensure_playwright() {
  if ! command -v node &>/dev/null; then
    echo "ERROR: Node.js is required but not found." >&2
    echo "Install Node.js 18+ from https://nodejs.org" >&2
    exit 1
  fi

  # Check if playwright-chromium is installed
  if [ ! -d "$SCRIPT_DIR/node_modules/playwright-chromium" ]; then
    echo "Installing playwright-chromium (first-time setup)..." >&2
    (cd "$SCRIPT_DIR" && npm install --no-fund --no-audit 2>&1) >&2

    # Install Chromium browser binary
    echo "Downloading Chromium browser..." >&2
    (cd "$SCRIPT_DIR" && npx playwright install chromium 2>&1) >&2
    echo "Setup complete." >&2
  fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
run_bridge() {
  node "$BRIDGE" "$@"
}

cmd_start() {
  ensure_playwright
  if [ -f "$SESSION_FILE" ]; then
    local existing
    existing=$(cat "$SESSION_FILE")
    if [ -f "$SESSIONS_DIR/$existing/storageState.json" ]; then
      echo "Session already exists: $existing" >&2
      echo "Use 'stop' first or 'status' to check." >&2
      echo "$existing"
      return 0
    fi
  fi

  echo "Starting Slack browser session..." >&2
  local result
  result=$(run_bridge --function open --session new --input '{"url": "https://app.slack.com"}')
  local sid
  sid=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])")
  echo "$sid" > "$SESSION_FILE"
  echo "Session started: $sid" >&2
  echo "$sid"
}

cmd_login() {
  local EMAIL="${1:?Usage: slack-browser-session.sh login EMAIL PASSWORD}"
  local PASSWORD="${2:?Usage: slack-browser-session.sh login EMAIL PASSWORD}"

  ensure_playwright

  if [ ! -f "$SESSION_FILE" ]; then
    cmd_start >/dev/null
  fi
  local SID
  SID=$(cat "$SESSION_FILE")

  echo "Logging in with email/password..." >&2

  # Navigate to sign-in page
  run_bridge --function interact --session "$SID" \
    --input '{"action": "goto", "url": "https://slack.com/signin"}' >/dev/null

  # Wait for page to load
  run_bridge --function interact --session "$SID" \
    --input '{"action": "wait", "ms": 3000}' >/dev/null

  # Fill email (Slack login form uses predictable CSS selectors)
  run_bridge --function interact --session "$SID" \
    --input "{\"action\": \"fill\", \"selector\": \"input[type=\\\"email\\\"]\", \"value\": \"$EMAIL\"}" >/dev/null

  # Submit email
  run_bridge --function interact --session "$SID" \
    --input '{"action": "press", "selector": "input[type=\\"email\\"]", "key": "Enter"}' >/dev/null

  # Wait for password page
  run_bridge --function interact --session "$SID" \
    --input '{"action": "wait", "ms": 3000}' >/dev/null

  # Fill password
  run_bridge --function interact --session "$SID" \
    --input "{\"action\": \"fill\", \"selector\": \"input[type=\\\"password\\\"]\", \"value\": \"$PASSWORD\"}" >/dev/null

  # Submit password
  run_bridge --function interact --session "$SID" \
    --input '{"action": "press", "selector": "input[type=\\"password\\"]", "key": "Enter"}' >/dev/null

  # Wait for Slack to fully load
  run_bridge --function interact --session "$SID" \
    --input '{"action": "wait", "ms": 5000}' >/dev/null

  echo "Login attempted. Use 'status' to verify." >&2
}

cmd_login_manual() {
  ensure_playwright

  local SID
  if [ -f "$SESSION_FILE" ]; then
    SID=$(cat "$SESSION_FILE")
  fi

  if [ -z "${SID:-}" ]; then
    local result
    result=$(run_bridge --function open --session new --headed --input '{"url": "https://slack.com/signin", "headed": true}')
    SID=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])")
    echo "$SID" > "$SESSION_FILE"
  else
    run_bridge --function open --session "$SID" --headed --input '{"url": "https://slack.com/signin", "headed": true}'
  fi

  echo "" >&2
  echo "A browser window has opened." >&2
  echo "Please log in to Slack manually (SSO, 2FA, etc.)." >&2
  echo "Once you reach app.slack.com, close the browser window." >&2
  echo "" >&2
  echo "Session: $SID" >&2
  echo "After login, your session state is saved automatically." >&2
}

cmd_status() {
  if [ ! -f "$SESSION_FILE" ]; then
    echo "No active browser session." >&2
    exit 1
  fi
  local SID
  SID=$(cat "$SESSION_FILE")

  if [ -f "$SESSIONS_DIR/$SID/storageState.json" ]; then
    echo "Active session: $SID"
    echo "State file: $SESSIONS_DIR/$SID/storageState.json"
  else
    echo "Session ID recorded ($SID) but no state file found."
    echo "Run 'login' or 'login-manual' to authenticate."
  fi
}

cmd_stop() {
  if [ ! -f "$SESSION_FILE" ]; then
    echo "No active browser session." >&2
    exit 0
  fi
  local SID
  SID=$(cat "$SESSION_FILE")
  run_bridge --function close --session "$SID" --input '{}' 2>/dev/null || true
  rm -f "$SESSION_FILE"
  echo "Browser session closed." >&2
}

cmd_get() {
  if [ ! -f "$SESSION_FILE" ]; then
    echo "No active browser session." >&2
    exit 1
  fi
  cat "$SESSION_FILE"
}

case "${1:-help}" in
  start)         cmd_start ;;
  login)         shift; cmd_login "$@" ;;
  login-manual)  cmd_login_manual ;;
  status)        cmd_status ;;
  stop)          cmd_stop ;;
  get)           cmd_get ;;
  help|--help|-h)
    echo "Usage: slack-browser-session.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start          Start a new browser session"
    echo "  stop           Stop and clean up the active session"
    echo "  status         Show current session status"
    echo "  login          Automated login: login <email> <password>"
    echo "  login-manual   Open a visible browser for manual SSO/2FA login"
    echo "  get            Print the active session ID"
    echo "  help           Show this help message"
    ;;
  *)             echo "Usage: slack-browser-session.sh <start|login|login-manual|status|stop|get>" >&2; exit 1 ;;
esac
