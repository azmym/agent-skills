# Browser Mode Reference

Browser mode provides cross-platform Slack access by running a local Playwright Chromium instance. Instead of extracting browser tokens and making curl calls, API requests execute inside the browser using `fetch()`, which automatically includes all authentication cookies.

## Prerequisites

- **Node.js 18+** installed and available on PATH
- Internet connection (for first-time Chromium download, ~150 MB)

Playwright and Chromium install automatically on first use. No manual setup needed.

## How It Works

1. **Session start**: Launches headless Chromium, navigates to Slack, saves session state
2. **API calls**: Each call launches a short-lived Chromium process, restores cookies via `storageState`, executes `fetch()` against the Slack Web API, and returns the JSON response
3. **Session persistence**: Cookies and localStorage are saved to `~/.agents/config/slack/sessions/<session_id>/storageState.json` between calls

There is no long-running browser daemon. Each API call is a standalone process that starts, executes, and exits.

### How storageState Works

Playwright's `storageState` captures:
- All cookies for the browser context (including Slack's `d` cookie for authentication)
- All localStorage entries (including Slack's `localConfig_v2` with workspace tokens)

On each call, the bridge script:
1. Creates a new browser context with the saved `storageState`
2. Navigates to `app.slack.com` (which activates the session)
3. Executes the requested operation
4. Saves the updated `storageState` back to disk

This means the session survives between calls without keeping a browser open.

## Config and State

All browser mode state lives under `~/.agents/config/slack/`:

| File | Purpose |
|------|----------|
| `config.env` | Mode selection (`SLACK_MODE=browser`) |
| `browser-session` | Active browser session ID |
| `sessions/<id>/storageState.json` | Playwright session cookies and localStorage |
| `sessions/<id>/refs.json` | Element refs from last snapshot |

## Session Lifecycle

### Start a session

    {SKILL_DIR}/scripts/slack-browser-session.sh start

Launches headless Chromium and navigates to `app.slack.com`. If you have not previously logged in, you will see the Slack login page.

### Log in manually (SSO / 2FA)

    {SKILL_DIR}/scripts/slack-browser-session.sh login-manual

Opens a **visible** (headed) Chromium window at `slack.com/signin`. Log in manually through your SSO provider, 2FA, or any other auth flow. Once you reach `app.slack.com`, close the browser window. Session state is saved automatically.

### Log in with email + password

    {SKILL_DIR}/scripts/slack-browser-session.sh login user@example.com mypassword

Automates the email/password flow using CSS selectors on Slack's login page. Only works for workspaces with direct email/password authentication (not SSO).

### Check session status

    {SKILL_DIR}/scripts/slack-browser-session.sh status

Shows the current session ID and whether a valid state file exists.

### Close session

    {SKILL_DIR}/scripts/slack-browser-session.sh stop

Deletes the session directory and clears the active session.

## Making API Calls

Use `slack-api.sh` with `SLACK_MODE=browser` (or set it in config):

    {SKILL_DIR}/scripts/slack-api.sh conversations.history channel=C041RSY6DN2 limit=20
    {SKILL_DIR}/scripts/slack-api.sh chat.postMessage channel=C041RSY6DN2 text="Hello"
    {SKILL_DIR}/scripts/slack-api.sh search.messages query="project update" count=10

All methods from the [API reference](api-methods.md) are supported.

### How API Calls Work

1. The script reads the browser session ID from `~/.agents/config/slack/browser-session`
2. It builds a JavaScript snippet that calls `fetch()` against the Slack Web API
3. The token is extracted from `localStorage.localConfig_v2` inside the browser
4. The browser automatically attaches session cookies (including the httpOnly `d` cookie)
5. The JSON response is returned to stdout

### Automatic Fallback

When `SLACK_MODE=auto` (the default), `slack-api.sh` automatically falls back to token mode when:

- No browser session is active (`~/.agents/config/slack/browser-session` does not exist)
- No valid `storageState.json` exists for the recorded session

## UI Automation

Browser mode enables direct interaction with Slack's web interface for features not available through the API.

### Common Patterns

Navigate to a channel:

    node {SKILL_DIR}/scripts/playwright-bridge.js --function interact --session $SESSION_ID \
      --input '{"action": "goto", "url": "https://app.slack.com/client/TEAM_ID/CHANNEL_ID"}'

Snapshot interactive elements:

    node {SKILL_DIR}/scripts/playwright-bridge.js --function snapshot --session $SESSION_ID --input '{}'
    # Returns: @e1: button "New Message", @e2: a "general", ...

Click, fill, press:

    node {SKILL_DIR}/scripts/playwright-bridge.js --function interact --session $SESSION_ID \
      --input '{"action": "click", "ref": "@e1"}'

    node {SKILL_DIR}/scripts/playwright-bridge.js --function interact --session $SESSION_ID \
      --input '{"action": "fill", "selector": "[data-qa=\"message_input\"]", "value": "Hello from browser mode"}'

Take a screenshot:

    node {SKILL_DIR}/scripts/playwright-bridge.js --function screenshot --session $SESSION_ID --input '{}'

Run custom JavaScript:

    node {SKILL_DIR}/scripts/playwright-bridge.js --function execute --session $SESSION_ID \
      --input '{"code": "document.title"}'

### Use Cases

| Feature | API Support | Browser Mode |
|---------|-------------|---------------|
| Send/read messages | Yes (API preferred) | Yes (fallback) |
| Search messages | Yes (API preferred) | Yes (fallback) |
| Canvas creation/editing | No | Yes |
| Huddle interactions | No | Yes |
| Workflow Builder config | No | Yes |
| Slack Connect invites | Limited | Yes |
| Admin/settings pages | Limited | Yes |
| Visual message verification | No | Yes (screenshot) |

## Token Mode vs Browser Mode

| | Token Mode | Browser Mode |
|---|-----------|---------------|
| Platform | macOS only | Cross-platform |
| Speed | Fast (direct curl) | Slower (browser overhead) |
| Dependencies | Chrome, AppleScript, pycookiecheat | Node.js 18+, Playwright (auto-installed) |
| Auth | Automatic from running Chrome | One-time login via Playwright |
| SSO / 2FA | Requires Chrome login first | Built-in manual login support |
| API coverage | Web API methods only | Web API + UI automation |
| Persistence | Tokens cached in file | storageState file |
| Best for | Frequent, fast API calls on macOS | Cross-platform use, UI automation |

## Troubleshooting

**"Node.js is required but not found"**: Install Node.js 18+ from https://nodejs.org.

**"No active browser session"**: Run `slack-browser-session.sh start` first.

**"browserType.launch: Executable doesn't exist"**: Chromium not downloaded. Run `slack-browser-session.sh start` (auto-installs).

**Login page keeps showing**: The session may have expired. Stop and start a new session, then log in again.

**"no_teams_found" error**: You are logged in but Slack has not loaded the workspace data yet. Wait a few seconds and retry, or use `snapshot` to check the page state.

**Slow API responses**: Browser-proxied calls have overhead from launching Chromium. For high-frequency calls on macOS, switch to token mode by setting `SLACK_MODE=token`.

**SSO login flow**: Use `login-manual` to open a visible browser window. Navigate through your SSO provider manually, then close the window when done.
