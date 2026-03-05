#!/bin/bash
# Refresh Slack browser session tokens.
# Extracts xoxc from Chrome localStorage via AppleScript.
# Extracts xoxd from Chrome cookie database via lsof + pycookiecheat.
set -euo pipefail

SLACK_CONFIG_DIR="${HOME}/.agents/config/slack"
TOKENS_FILE="${SLACK_CONFIG_DIR}/tokens.env"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

mkdir -p "$SLACK_CONFIG_DIR"

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
# Copy Chrome's Cookies DB to /tmp to avoid SQLite lock conflicts
TMP_COOKIES="/tmp/slack-chrome-cookies-$$"
cp "$COOKIE_FILE" "$TMP_COOKIES"
[ -f "${COOKIE_FILE}-wal" ] && cp "${COOKIE_FILE}-wal" "${TMP_COOKIES}-wal"
[ -f "${COOKIE_FILE}-shm" ] && cp "${COOKIE_FILE}-shm" "${TMP_COOKIES}-shm"
trap 'rm -f "$TMP_COOKIES" "${TMP_COOKIES}-wal" "${TMP_COOKIES}-shm"' EXIT

# Try direct decryption first (no Chrome lock issues with the copy)
XOXD=$(python3 -c "
import sqlite3, subprocess, hashlib, urllib.parse
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

# Get Chrome Safe Storage password from Keychain
pwd = subprocess.check_output(
    ['security', 'find-generic-password', '-s', 'Chrome Safe Storage', '-w']
).strip()

# Derive key: PBKDF2-SHA1, salt='saltysalt', 1003 iterations, 16 bytes
kdf = PBKDF2HMAC(algorithm=hashes.SHA1(), length=16, salt=b'saltysalt', iterations=1003)
key = kdf.derive(pwd)

db = sqlite3.connect('${TMP_COOKIES}')
row = db.execute(
    \"SELECT encrypted_value FROM cookies WHERE host_key LIKE '%slack.com' AND name='d'\"
).fetchone()
db.close()

if not row or not row[0]:
    print('NOT_FOUND')
else:
    blob = row[0]
    # v10 prefix = 3 bytes, then AES-128-CBC with 16-byte space IV
    if blob[:3] == b'v10':
        blob = blob[3:]
    iv = b' ' * 16
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
    dec = cipher.decryptor()
    plaintext = dec.update(blob) + dec.finalize()
    # Remove PKCS7 padding
    pad_len = plaintext[-1]
    if isinstance(pad_len, int) and 1 <= pad_len <= 16:
        plaintext = plaintext[:-pad_len]
    d = plaintext.decode('utf-8', errors='replace')
    if '%2' in d:
        print(d)
    else:
        print(urllib.parse.quote(d, safe=''))
" 2>/dev/null || echo "NOT_FOUND")

# Fall back to pycookiecheat if direct decryption failed
if [ "$XOXD" = "NOT_FOUND" ]; then
  echo "Direct decryption failed, trying pycookiecheat..." >&2
  XOXD=$(uvx --from pycookiecheat python3 -c "
from pycookiecheat import chrome_cookies
import urllib.parse
cookies = chrome_cookies('https://slack.com', cookie_file='${TMP_COOKIES}')
d = cookies.get('d', '')
if not d: print('NOT_FOUND')
elif '%2' in d: print(d)
else: print(urllib.parse.quote(d, safe=''))
" 2>/dev/null || echo "NOT_FOUND")
fi

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
