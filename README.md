# Agent Skills

A collection of skills for AI coding agents.

## Available Skills

### Slack

Interact with Slack directly from your AI coding agent: read, summarize, search, post messages, react, pin, and manage channels using the Slack Web API.

Supports three modes:

| Mode | Config Value | Behavior |
|------|-------------|----------|
| **Auto-detect** | `auto` (default) | Uses browser mode if a session exists, otherwise falls back to token mode |
| **Token** | `token` | Direct curl calls using Chrome session tokens. Fast. macOS only |
| **Browser** | `browser` | API calls through agent-browser session. Cross-platform. Also enables UI automation |

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
npx skills add azmym/agent-skills
```

### All supported agents (Claude Code, Cursor, Codex, etc.)

```bash
npx skills add azmym/agent-skills --agent '*'
```

### Specific agents

```bash
npx skills add azmym/agent-skills --agent 'Claude Code,Cursor'
```

### Install agent-browser (for browser mode)

```bash
npx skills add inference-sh-0/skills --skill agent-browser
```

## Mode Selection

Choose your mode by creating a config file or setting an environment variable.

All config and state lives under `~/.agents/config/slack/`.

### Config file (persistent)

```bash
# Auto-detect (default, no config needed)
echo 'SLACK_MODE=auto' > ~/.agents/config/slack/config.env

# Token mode (macOS, fast)
echo 'SLACK_MODE=token' > ~/.agents/config/slack/config.env

# Browser mode (cross-platform)
echo 'SLACK_MODE=browser' > ~/.agents/config/slack/config.env
```

### Environment variable (per-call override)

```bash
SLACK_MODE=browser slack-api.sh conversations.history channel=C041RSY6DN2 limit=20
```

The environment variable takes priority over the config file.

### How auto-detect works

1. Check if a browser session exists (`~/.agents/config/slack/browser-session`) and `infsh` is installed
2. If yes, use browser mode
3. If no, use token mode

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

#### 1. inference.sh CLI

```bash
curl -fsSL https://cli.inference.sh | sh
infsh login
```

#### 2. agent-browser skill

```bash
npx skills add inference-sh-0/skills --skill agent-browser
```

No Chrome, AppleScript, or pycookiecheat required.

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

1. A persistent headless browser session is launched via the [agent-browser](https://skills.sh/inference-sh-0/skills/agent-browser) skill
2. You log in to Slack once through the browser session (email/password or SSO)
3. API calls execute inside the browser using `fetch()`, which automatically includes all authentication cookies
4. The session persists across calls until you explicitly close it
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
| `infsh: command not found` | Install: `curl -fsSL https://cli.inference.sh \| sh && infsh login` |
| `no_browser_session` | Run `slack-browser-session.sh start` first |
| Login page keeps showing | Session may have expired; run `stop` then `start` again |
| `no_teams_found` error | Slack hasn't loaded workspace data yet; wait a few seconds and retry |
| Slow API responses | Browser mode has overhead; for high-frequency calls on macOS, use `SLACK_MODE=token` |
| SSO login flow | Use `snapshot` and `interact` via agent-browser to navigate the SSO provider's form step by step |

## License

MIT
