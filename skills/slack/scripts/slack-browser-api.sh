#!/bin/bash
# Make Slack API calls through an agent-browser session.
# Cross-platform alternative to token-based slack-api.sh.
# Falls back to slack-api.sh if no browser session is active.
#
# Usage: slack-browser-api.sh <method> [key=value ...]
# Example: slack-browser-api.sh conversations.history channel=C041RSY6DN2 limit=20

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SESSION_FILE="${HOME}/.claude/slack-browser-session"

# Fall back to token-based API if no browser session or no infsh
if [ ! -f "$SESSION_FILE" ] || ! command -v infsh &>/dev/null; then
  exec "${SCRIPT_DIR}/slack-api.sh" "$@"
fi

SESSION_ID=$(cat "$SESSION_FILE")
METHOD="${1:?Usage: slack-browser-api.sh <method> [key=value ...]}"
shift

# Build JavaScript URLSearchParams append statements
PARAMS_JS=""
for arg in "$@"; do
  KEY="${arg%%=*}"
  VALUE="${arg#*=}"
  # Escape backslashes and double quotes for JSON embedding
  VALUE=$(printf '%s' "$VALUE" | sed 's/\\/\\\\/g; s/"/\\"/g')
  PARAMS_JS="${PARAMS_JS}    params.append(\"${KEY}\", \"${VALUE}\");\n"
done

# Build the JavaScript code to execute inside the browser
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
    const resp = await fetch("https://slack.com/api/${METHOD}", {
      method: "POST",
      body: params
    });
    return JSON.stringify(await resp.json());
  } catch (e) {
    return JSON.stringify({ok: false, error: e.message});
  }
})()
JSEOF
)

# Encode JS as a JSON string for the execute input
JS_JSON=$(printf '%s' "$JS_CODE" | jq -Rs '.')

RESULT=$(infsh app run agent-browser --function execute --session "$SESSION_ID" \
  --input "{\"code\": ${JS_JSON}}")

# Extract the result field (our Slack API JSON response)
PARSED=$(echo "$RESULT" | jq -r '.result // empty' 2>/dev/null)
if [ -n "$PARSED" ]; then
  echo "$PARSED"
else
  echo "$RESULT"
fi
