#!/bin/bash
# Refresh Slack browser session tokens.
# Extracts xoxc from Chrome localStorage via AppleScript.
# Extracts xoxd from Chrome cookie database via lsof + pycookiecheat.
set -euo pipefail

TOKENS_FILE="${HOME}/.claude/slack-tokens.env"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

echo "Refreshing Slack tokens..." >&2

# --- Step 1: Find Chrome's Cookies file via lsof ---
COOKIE_FILE=$(lsof -c "Google Chrome" -F n 2>/dev/null | grep -i "/Cookies$" | sed 's/^n//' | head -1)
if [ -z "$COOKIE_FILE" ]; then
  COOKIE_FILE=$(lsof -c "Chrome" -F n 2>/dev/null | grep -i "/Cookies$" | sed 's/^n//' | head -1)
fi
if [ -z "$COOKIE_FILE" ]; then
  echo "ERROR: Could not find Chrome cookie database. Is Chrome running?" >&2
  exit 1
fi

# --- Step 2: Extract xoxd cookie ---
XOXD=$(uvx --from pycookiecheat python3 -c "
from pycookiecheat import chrome_cookies
import urllib.parse
cookies = chrome_cookies('https://slack.com', cookie_file='${COOKIE_FILE}')
d = cookies.get('d', '')
if not d: print('NOT_FOUND')
elif '%2' in d: print(d)
else: print(urllib.parse.quote(d, safe=''))
" 2>/dev/null || echo "NOT_FOUND")

if [ "$XOXD" = "NOT_FOUND" ]; then
  echo "ERROR: Could not extract xoxd cookie." >&2
  exit 1
fi

# --- Step 3: Extract xoxc token via AppleScript ---
XOXC=$(osascript -e '
tell application "Google Chrome"
    repeat with w in every window
        repeat with t in every tab of w
            if URL of t contains "app.slack.com" then
                set result to execute t javascript "
                    try {
                        var lc = JSON.parse(localStorage.localConfig_v2);
                        var teamIds = Object.keys(lc.teams);
                        teamIds.length > 0 ? lc.teams[teamIds[0]].token : \"NOT_FOUND\";
                    } catch(e) { \"NOT_FOUND\"; }
                "
                return result
            end if
        end repeat
    end repeat
    return "NOT_FOUND"
end tell
' 2>/dev/null || echo "NOT_FOUND")

if [ "$XOXC" = "NOT_FOUND" ]; then
  echo "ERROR: Could not extract xoxc token." >&2
  echo "Ensure Slack is open in Chrome at app.slack.com" >&2
  exit 1
fi

# --- Step 4: Write tokens ---
cat > "$TOKENS_FILE" << EOF
SLACK_XOXC="${XOXC}"
SLACK_XOXD="${XOXD}"
SLACK_UA="${UA}"
EOF

echo "Tokens refreshed." >&2
