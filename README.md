# Agent Skills

A collection of skills for AI coding agents.

## Available Skills

### Slack

Interact with Slack directly from your AI coding agent: read, summarize, search, post messages, react, pin, and manage channels using the Slack Web API.

Supports three modes:

| Mode | Config Value | Behavior |
|------|-------------|----------|
| **Auto-detect** | `auto` (recommended) | Uses browser mode if a session exists, otherwise falls back to token mode |
| **Token** | `token` | Direct curl calls using Chrome session tokens. Fast. macOS only |
| **Browser** | `browser` | API calls through local Playwright browser. Cross-platform. Also enables UI automation |

**Use when:**
- User shares a Slack URL
- User asks to read or summarize a channel
- User searches Slack messages
- User asks to send/post a message
- User asks to react to or pin a message
- User looks up a Slack user
- User mentions a Slack channel by name (e.g., `#channel-name`)
- User wants to interact with Slack Canvas, Huddles, or Workflow Builder (browser mode)

## Installation

The `skills` CLI installs skills into `~/.agents/skills/` and symlinks them to each agent's directory automatically.

### Claude Code only

```bash
npx skills add https://github.com/azmym/agent-skills --skill slack
```

### All supported agents (Claude Code, Cursor, Codex, etc.)

```bash
npx skills add https://github.com/azmym/agent-skills --skill slack --agent '*'
```

### Specific agents

```bash
npx skills add https://github.com/azmym/agent-skills --skill slack --agent 'Claude Code,Cursor'
```

## First Use

On the very first Slack operation, the agent will prompt you to choose a mode:

1. **Token** (macOS only): Fastest. Extracts tokens from Chrome automatically. Requires Chrome with Slack open, AppleScript enabled, and `uvx`.
2. **Browser** (cross-platform): Uses a local Playwright browser. Works on macOS, Linux, and Windows. Requires Node.js 18+. Supports SSO and 2FA login.
3. **Auto-detect** (recommended): Uses browser mode when a session exists, falls back to token mode otherwise.

Your choice is saved to `~/.agents/config/slack/config.env` and the agent will never ask again.

If you select **Browser** mode, the agent will also launch a visible browser window so you can log in to Slack (supports SSO, 2FA, and any login method your workspace uses).

### Changing mode later

You can change mode at any time by editing the config file:

```bash
# Switch to token mode
echo 'SLACK_MODE=token' > ~/.agents/config/slack/config.env

# Switch to browser mode
echo 'SLACK_MODE=browser' > ~/.agents/config/slack/config.env

# Switch to auto-detect
echo 'SLACK_MODE=auto' > ~/.agents/config/slack/config.env
```

Or override per-call with an environment variable:

```bash
SLACK_MODE=browser slack-api.sh conversations.history channel=C041RSY6DN2 limit=20
```

The environment variable takes priority over the config file.

### How auto-detect works

1. Check if a Playwright session exists with a valid `storageState.json` under `~/.agents/config/slack/sessions/`
2. If a valid session is found, use **browser** mode
3. If no valid session exists, fall back to **token** mode

This means you can set `SLACK_MODE=auto` and freely switch between modes: start a browser session to use browser mode, stop it to fall back to token mode, all without changing config.

## Prerequisites

### Token Mode (macOS)

#### 1. Google Chrome

Chrome must be running with Slack open in a tab.

- Open **Chrome** and navigate to [app.slack.com](https://app.slack.com)
- Sign in to your workspace

#### 2. Allow JavaScript from Apple Events

Required for the skill to extract your session token from Chrome.

1. Open Chrome
2. Go to **View > Developer > Allow JavaScript from Apple Events**
3. Confirm the prompt
4. This setting must stay enabled

#### 3. Python 3

Used for JSON parsing and cookie extraction.

```bash
python3 --version
```

If not installed:

```bash
brew install python3
```

#### 4. uvx (from uv)

Used to run `pycookiecheat` for extracting the session cookie from Chrome's cookie database.

```bash
# Install uv (which provides uvx)
brew install uv

# Verify
uvx --version
```

### Browser Mode (Cross-Platform)

#### 1. Node.js 18+

Install from [nodejs.org](https://nodejs.org) or via your package manager:

```bash
# macOS
brew install node

# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

Playwright and Chromium install automatically on first use. No additional setup required.

## How It Works

### Token Mode

1. On the first API call, the skill automatically extracts two session tokens from Chrome:
   - **xoxc**: from Slack's `localStorage` via AppleScript
   - **xoxd**: from Chrome's cookie database via `pycookiecheat`
2. Tokens are saved to `~/.agents/config/slack/tokens.env`
3. If a token expires (`invalid_auth`), the skill auto-refreshes and retries
4. API calls are made via `curl` directly to the Slack Web API

No manual token management needed.

### Browser Mode

1. A local Playwright Chromium instance is launched
2. You log in to Slack once (manually for SSO/2FA, or automated for email/password)
3. Session state (cookies + localStorage) is saved to `~/.agents/config/slack/sessions/<id>/storageState.json`
4. API calls launch a short-lived Chromium process, restore the session state, execute `fetch()`, and exit
5. If no browser session is active and mode is `auto`, the skill falls back to token mode

Browser mode also enables **UI automation** for Slack features that have no API:

- Canvas creation and editing
- Huddle interactions
- Workflow Builder configuration
- Slack Connect invitations
- Admin and settings pages
- Visual message verification via screenshots

## Usage Examples

Once installed, just ask your agent naturally:

| Prompt | What happens |
|---|---|
| "Summarize #engineering from today" | Reads channel history and summarizes |
| "What did John say in #standup this week?" | Searches messages by user and channel |
| "Post 'deploy complete' in #releases" | Sends a message to the channel |
| "React with thumbsup to that message" | Adds an emoji reaction |
| _Paste a Slack URL_ | Reads the message or thread at that URL |
| "Search Slack for deployment errors" | Searches across all channels |
| "Pin that message" | Pins the referenced message |
| "Who is U04ABC123?" | Looks up user info by ID |
| "Create a canvas in #project-alpha" | Uses browser mode to create a Slack Canvas |
| "Take a screenshot of the #design channel" | Captures a visual snapshot via browser mode |

## Troubleshooting

### Token Mode

| Problem | Fix |
|---|---|
| `ERROR: Could not find Chrome cookie database` | Make sure Chrome is running |
| `ERROR: Could not extract xoxc token` | Open [app.slack.com](https://app.slack.com) in a Chrome tab and enable **Allow JavaScript from Apple Events** |
| `ERROR: Could not extract xoxd cookie` | Run `uvx --from pycookiecheat python3 -c "print('ok')"` to verify pycookiecheat works |
| `invalid_auth` keeps failing | Close and reopen the Slack tab in Chrome, then retry |
| `uvx: command not found` | Install uv: `brew install uv` |
| Scripts not executing | Run `chmod +x` on scripts in `scripts/` |

### Browser Mode

| Problem | Fix |
|---|---|
| `Node.js is required but not found` | Install Node.js 18+ from https://nodejs.org |
| `no_browser_session` | Run `slack-browser-session.sh start` first |
| `browserType.launch: Executable doesn't exist` | Run `slack-browser-session.sh start` (auto-installs Chromium) |
| Login page keeps showing | Session may have expired; run `stop` then `login-manual` again |
| `no_teams_found` error | Slack hasn't loaded workspace data yet; wait a few seconds and retry |
| Slow API responses | Browser mode has overhead; for high-frequency calls on macOS, use `SLACK_MODE=token` |
| SSO login flow | Use `login-manual` to open a visible browser window and log in manually |

## License

MIT
