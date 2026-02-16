#!/bin/bash
# Unified Slack Web API wrapper with mode selection.
#
# Usage: slack-api.sh <method> [key=value ...]
#
# Mode selection (in order of priority):
#   1. SLACK_MODE environment variable
#   2. ~/.agents/config/slack/config.env file
#   3. Default: auto
#
# Modes:
#   token   - Direct curl calls using Chrome session tokens (macOS only)
#   browser - API calls through local Playwright browser (cross-platform)
#   auto    - Try browser if session exists, otherwise fall back to token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE="$SCRIPT_DIR/playwright-bridge.js"
SLACK_CONFIG_DIR="${HOME}/.agents/config/slack"
CONFIG_FILE="${SLACK_CONFIG_DIR}/config.env"
TOKENS_FILE="${SLACK_CONFIG_DIR}/tokens.env"
SESSION_FILE="${SLACK_CONFIG_DIR}/browser-session"
SESSIONS_DIR="${SLACK_CONFIG_DIR}/sessions"

# Ensure config directory exists
mkdir -p "$SLACK_CONFIG_DIR"

# Load config if SLACK_MODE not already set via environment
if [ -z "${SLACK_MODE:-}" ] && [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
fi
SLACK_MODE="${SLACK_MODE:-auto}"

# Resolve auto mode
if [ "$SLACK_MODE" = "auto" ]; then
  if [ -f "$SESSION_FILE" ]; then
    SID=$(cat "$SESSION_FILE")
    if [ -f "$SESSIONS_DIR/$SID/storageState.json" ]; then
      SLACK_MODE="browser"
    else
      SLACK_MODE="token"
    fi
  else
    SLACK_MODE="token"
  fi
fi

METHOD="${1:?Usage: slack-api.sh <method> [key=value ...]}"
shift

# --- Token Mode ---
run_token() {
  if [ ! -f "$TOKENS_FILE" ]; then
    "${SCRIPT_DIR}/slack-token-refresh.sh" >&2
  fi
  source "$TOKENS_FILE"

  PARAMS=()
  for arg in "$@"; do
    PARAMS+=(-d "$arg")
  done

  RESPONSE=$(curl -s "https://slack.com/api/${METHOD}" \
    -H "Authorization: Bearer ${SLACK_XOXC}" \
    -H "Cookie: d=${SLACK_XOXD}" \
    -H "User-Agent: ${SLACK_UA}" \
    ${PARAMS[@]+"${PARAMS[@]}"})

  # Auto-refresh on invalid_auth and retry once
  if echo "$RESPONSE" | python3 -c "import sys,json; sys.exit(0 if json.load(sys.stdin).get('error')=='invalid_auth' else 1)" 2>/dev/null; then
    "${SCRIPT_DIR}/slack-token-refresh.sh" >&2
    source "$TOKENS_FILE"
    RESPONSE=$(curl -s "https://slack.com/api/${METHOD}" \
      -H "Authorization: Bearer ${SLACK_XOXC}" \
      -H "Cookie: d=${SLACK_XOXD}" \
      -H "User-Agent: ${SLACK_UA}" \
      ${PARAMS[@]+"${PARAMS[@]}"})
  fi

  echo "$RESPONSE"
}

# --- Browser Mode ---
run_browser() {
  if [ ! -f "$SESSION_FILE" ]; then
    echo '{"ok":false,"error":"no_browser_session","hint":"Run slack-browser-session.sh start"}' >&2
    exit 1
  fi
  if ! command -v node &>/dev/null; then
    echo '{"ok":false,"error":"node_not_found","hint":"Install Node.js 18+ from https://nodejs.org"}' >&2
    exit 1
  fi

  SESSION_ID=$(cat "$SESSION_FILE")

  PARAMS_JS=""
  for arg in "$@"; do
    KEY="${arg%%=*}"
    VALUE="${arg#*=}"
    VALUE=$(printf '%s' "$VALUE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    PARAMS_JS="${PARAMS_JS}    params.append(\"${KEY}\", \"${VALUE}\");"$'\n'
  done

  # Uses relative /api/ path against app.slack.com origin.
  # This ensures the browser's session cookies (including the httpOnly d cookie)
  # are included automatically via same-origin request.
  JS_CODE=$(cat <<JSEOF
(async () => {
  try {
    const lc = JSON.parse(localStorage.localConfig_v2);
    const teamIds = Object.keys(lc.teams);
    if (teamIds.length === 0) return JSON.stringify({ok: false, error: "no_teams_found"});
    const token = lc.teams[teamIds[0]].token;
    const params = new URLSearchParams();
    params.append("token", token);
${PARAMS_JS}
    const resp = await fetch("/api/${METHOD}", {
      method: "POST",
      body: params,
      credentials: "same-origin"
    });
    return JSON.stringify(await resp.json());
  } catch (e) {
    return JSON.stringify({ok: false, error: e.message});
  }
})()
JSEOF
  )

  JS_JSON=$(printf '%s' "$JS_CODE" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))")

  RESULT=$(node "$BRIDGE" --function execute --session "$SESSION_ID" \
    --input "{\"code\": ${JS_JSON}}")

  PARSED=$(echo "$RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
r = data.get('result', '')
if isinstance(r, str):
    print(r)
else:
    print(json.dumps(r))
" 2>/dev/null)

  if [ -n "$PARSED" ]; then
    echo "$PARSED"
  else
    echo "$RESULT"
  fi
}

# --- Execute ---
case "$SLACK_MODE" in
  token)   run_token "$@" ;;
  browser) run_browser "$@" ;;
  *)       echo "Unknown SLACK_MODE: $SLACK_MODE (expected: auto, token, browser)" >&2; exit 1 ;;
esac
