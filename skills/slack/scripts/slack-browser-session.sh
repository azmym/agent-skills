#!/bin/bash
# Manage a persistent Slack browser session via agent-browser skill.
# Provides cross-platform Slack access without macOS-specific token extraction.
#
# Usage:
#   slack-browser-session.sh start              Open browser, navigate to Slack
#   slack-browser-session.sh login EMAIL PASS   Automate email+password login
#   slack-browser-session.sh status             Screenshot current state
#   slack-browser-session.sh stop               Close browser session
#   slack-browser-session.sh get                Print session ID
#
# Prerequisites:
#   - infsh CLI installed (curl -fsSL https://cli.inference.sh | sh && infsh login)
#   - agent-browser skill (npx skills add inference-sh-0/skills --skill agent-browser)

set -euo pipefail

SESSION_FILE="${HOME}/.claude/slack-browser-session"

ensure_infsh() {
  if ! command -v infsh &>/dev/null; then
    echo "ERROR: infsh CLI not found. Install: curl -fsSL https://cli.inference.sh | sh && infsh login" >&2
    exit 1
  fi
}

cmd_start() {
  ensure_infsh
  if [ -f "$SESSION_FILE" ]; then
    echo "Session already exists. Use 'stop' first or 'status' to check." >&2
    cat "$SESSION_FILE"
    return 0
  fi
  echo "Starting Slack browser session..." >&2
  RESULT=$(infsh app run agent-browser --function open --session new \
    --input '{"url": "https://app.slack.com"}')
  SESSION_ID=$(echo "$RESULT" | jq -r '.session_id')
  mkdir -p "$(dirname "$SESSION_FILE")"
  echo "$SESSION_ID" > "$SESSION_FILE"
  echo "Session started: $SESSION_ID" >&2
  echo "Use 'status' to screenshot the current state." >&2
  echo "$SESSION_ID"
}

cmd_login() {
  ensure_infsh
  local EMAIL="${1:?Usage: slack-browser-session.sh login EMAIL PASSWORD}"
  local PASSWORD="${2:?Usage: slack-browser-session.sh login EMAIL PASSWORD}"

  if [ ! -f "$SESSION_FILE" ]; then
    cmd_start >/dev/null
  fi
  local SID
  SID=$(cat "$SESSION_FILE")

  # Wait for page to load
  infsh app run agent-browser --function interact --session "$SID" \
    --input '{"action": "wait", "wait_ms": 3000}' >/dev/null

  # Snapshot to find login form elements
  infsh app run agent-browser --function snapshot --session "$SID" --input '{}' >/dev/null

  # Fill email field and submit
  infsh app run agent-browser --function interact --session "$SID" \
    --input "{\"action\": \"fill\", \"ref\": \"@e1\", \"text\": \"${EMAIL}\"}" >/dev/null 2>&1 || true
  infsh app run agent-browser --function interact --session "$SID" \
    --input '{"action": "press", "text": "Enter"}' >/dev/null

  # Wait for password page
  infsh app run agent-browser --function interact --session "$SID" \
    --input '{"action": "wait", "wait_ms": 3000}' >/dev/null
  infsh app run agent-browser --function snapshot --session "$SID" --input '{}' >/dev/null

  # Fill password field and submit
  infsh app run agent-browser --function interact --session "$SID" \
    --input "{\"action\": \"fill\", \"ref\": \"@e1\", \"text\": \"${PASSWORD}\"}" >/dev/null 2>&1 || true
  infsh app run agent-browser --function interact --session "$SID" \
    --input '{"action": "press", "text": "Enter"}' >/dev/null

  # Wait for Slack to fully load
  infsh app run agent-browser --function interact --session "$SID" \
    --input '{"action": "wait", "wait_ms": 5000}' >/dev/null

  echo "Login attempted. Use 'status' to verify." >&2
}

cmd_status() {
  ensure_infsh
  if [ ! -f "$SESSION_FILE" ]; then
    echo "No active browser session." >&2
    exit 1
  fi
  local SID
  SID=$(cat "$SESSION_FILE")
  infsh app run agent-browser --function screenshot --session "$SID" --input '{}'
}

cmd_stop() {
  if [ ! -f "$SESSION_FILE" ]; then
    echo "No active browser session." >&2
    exit 0
  fi
  ensure_infsh
  local SID
  SID=$(cat "$SESSION_FILE")
  infsh app run agent-browser --function close --session "$SID" --input '{}' 2>/dev/null || true
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

case "${1:-status}" in
  start)  cmd_start ;;
  login)  shift; cmd_login "$@" ;;
  status) cmd_status ;;
  stop)   cmd_stop ;;
  get)    cmd_get ;;
  *)      echo "Usage: slack-browser-session.sh <start|login|status|stop|get>" >&2; exit 1 ;;
esac
