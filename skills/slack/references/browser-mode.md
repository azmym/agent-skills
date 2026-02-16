# Browser Mode Reference

Browser mode provides cross-platform Slack access by running a persistent browser session via the [agent-browser](https://skills.sh/inference-sh-0/skills/agent-browser) skill. Instead of extracting browser tokens and making curl calls, API requests execute inside the browser using `fetch()`, which automatically includes all authentication cookies.

## Prerequisites

- [inference.sh CLI](https://inference.sh) installed and authenticated
- agent-browser skill: `npx skills add inference-sh-0/skills --skill agent-browser`

## Config and State

All browser mode state lives under `~/.agents/config/slack/`:

| File | Purpose |
|------|---------|
| `config.env` | Mode selection (`SLACK_MODE=browser`) |
| `browser-session` | Active browser session ID |

## Session Lifecycle

### Start a session

    {SKILL_DIR}/scripts/slack-browser-session.sh start

Opens a headless browser and navigates to `app.slack.com`. If you have not previously logged in through this browser session, you will see the Slack login page.

### Log in (if needed)

For email + password authentication:

    {SKILL_DIR}/scripts/slack-browser-session.sh login user@example.com mypassword

For SSO or other login methods, use agent-browser directly:

    SESSION_ID=$({SKILL_DIR}/scripts/slack-browser-session.sh get)

    # Take snapshot to see the login form
    infsh app run agent-browser --function snapshot --session $SESSION_ID --input '{}'

    # Interact with elements using @e refs from the snapshot
    infsh app run agent-browser --function interact --session $SESSION_ID \
      --input '{"action": "click", "ref": "@e3"}'

    # Continue following the SSO flow with snapshot + interact

### Check session status

    {SKILL_DIR}/scripts/slack-browser-session.sh status

Returns a screenshot of the current browser state. Useful to verify login succeeded.

### Close session

    {SKILL_DIR}/scripts/slack-browser-session.sh stop

## Making API Calls

Use `slack-api.sh` with `SLACK_MODE=browser` (or set it in config):

    {SKILL_DIR}/scripts/slack-api.sh conversations.history channel=C041RSY6DN2 limit=20
    {SKILL_DIR}/scripts/slack-api.sh chat.postMessage channel=C041RSY6DN2 text="Hello"
    {SKILL_DIR}/scripts/slack-api.sh search.messages query="project update" count=10

All methods from the [API reference](api-methods.md) are supported.

### How It Works

1. The script reads the browser session ID from `~/.agents/config/slack/browser-session`
2. It builds a JavaScript snippet that calls `fetch()` against the Slack Web API
3. The token is extracted from `localStorage.localConfig_v2` inside the browser
4. The browser automatically attaches session cookies (including the httpOnly `d` cookie)
5. The JSON response is returned to stdout

### Automatic Fallback

When `SLACK_MODE=auto` (the default), `slack-api.sh` automatically falls back to token mode when:

- No browser session is active (`~/.agents/config/slack/browser-session` does not exist)
- `infsh` CLI is not installed

## UI Automation

Browser mode enables direct interaction with Slack's web interface for features not available through the API.

### Common Patterns

Navigate to a channel:

    infsh app run agent-browser --function interact --session $SESSION_ID \
      --input '{"action": "goto", "url": "https://app.slack.com/client/TEAM_ID/CHANNEL_ID"}'

Snapshot interactive elements:

    infsh app run agent-browser --function snapshot --session $SESSION_ID --input '{}'
    # Returns: @e1 [button] "New Message", @e2 [div] "general", ...

Click, fill, type:

    infsh app run agent-browser --function interact --session $SESSION_ID \
      --input '{"action": "click", "ref": "@e1"}'

    infsh app run agent-browser --function interact --session $SESSION_ID \
      --input '{"action": "fill", "ref": "@e5", "text": "Hello from browser mode"}'

Take a screenshot:

    infsh app run agent-browser --function screenshot --session $SESSION_ID --input '{}'

Run custom JavaScript:

    infsh app run agent-browser --function execute --session $SESSION_ID \
      --input '{"code": "document.title"}'

### Use Cases

| Feature | API Support | Browser Mode |
|---------|-------------|--------------|
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
|---|-----------|-------------|
| Platform | macOS only | Cross-platform |
| Speed | Fast (direct curl) | Slower (browser overhead) |
| Dependencies | Chrome, AppleScript, pycookiecheat | infsh CLI, agent-browser |
| Auth | Automatic from running Chrome | One-time login in browser session |
| API coverage | Web API methods only | Web API + UI automation |
| Persistence | Tokens cached in file | Browser session-based |
| Best for | Frequent, fast API calls on macOS | Cross-platform use, UI automation |

## Troubleshooting

**"No active browser session"**: Run `slack-browser-session.sh start` first.

**Login page keeps showing**: The session may have expired. Stop and start a new session, then log in again.

**"no_teams_found" error**: You are logged in but Slack has not loaded the workspace data yet. Wait a few seconds and retry, or use `snapshot` to check the page state.

**Slow API responses**: Browser-proxied calls have overhead from the Playwright session. For high-frequency calls on macOS, switch to token mode by setting `SLACK_MODE=token`.

**SSO login flow**: Use `snapshot` and `interact` to navigate the SSO provider's login form step by step. Each SSO provider (Google, Okta, Azure AD) has a different flow.
