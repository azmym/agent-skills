#!/bin/bash
# Slack Web API wrapper using browser session tokens.
# Usage: slack-api.sh <method> [key=value ...]
# Example: slack-api.sh conversations.replies channel=C041RSY6DN2 ts=1770725748.342899

set -euo pipefail

TOKENS_FILE="${HOME}/.claude/slack-tokens.env"

# Auto-refresh if tokens file missing
if [ ! -f "$TOKENS_FILE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  "${SCRIPT_DIR}/slack-token-refresh.sh" >&2
fi

source "$TOKENS_FILE"

METHOD="${1:?Usage: slack-api.sh <method> [key=value ...]}"
shift

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
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  "${SCRIPT_DIR}/slack-token-refresh.sh" >&2
  source "$TOKENS_FILE"
  RESPONSE=$(curl -s "https://slack.com/api/${METHOD}" \
    -H "Authorization: Bearer ${SLACK_XOXC}" \
    -H "Cookie: d=${SLACK_XOXD}" \
    -H "User-Agent: ${SLACK_UA}" \
    ${PARAMS[@]+"${PARAMS[@]}"})
fi

echo "$RESPONSE"
