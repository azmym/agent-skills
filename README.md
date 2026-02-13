# Agent Skills

A collection of skills for AI coding agents.

## Available Skills

### Slack

Interact with Slack directly from your AI coding agent — read, summarize, search, post messages, react, pin, and manage channels using the Slack Web API.

Tokens are extracted automatically from your running Chrome browser. No Slack app creation or OAuth setup required.

**Use when:**
- User shares a Slack URL
- User asks to read or summarize a channel
- User searches Slack messages
- User asks to send/post a message
- User asks to react to or pin a message
- User looks up a Slack user
- User mentions a Slack channel by name (e.g., `#channel-name`)

## Prerequisites

### 1. macOS

This skill relies on AppleScript and `lsof` for token extraction. It does not currently support Linux or Windows.

### 2. Google Chrome

Chrome must be running with Slack open in a tab.

- Open **Chrome** and navigate to [app.slack.com](https://app.slack.com)
- Sign in to your workspace

### 3. Allow JavaScript from Apple Events

Required for the skill to extract your session token from Chrome.

1. Open Chrome
2. Go to **View → Developer → Allow JavaScript from Apple Events**
3. Confirm the prompt
4. This setting must stay enabled

### 4. Python 3

Used for JSON parsing and cookie extraction.

```bash
python3 --version
```

If not installed:

```bash
brew install python3
```

### 5. uvx (from uv)

Used to run `pycookiecheat` for extracting the session cookie from Chrome's cookie database.

```bash
# Install uv (which provides uvx)
brew install uv

# Verify
uvx --version
```

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

## How It Works

1. On the first API call, the skill automatically extracts two session tokens from Chrome:
   - **xoxc** — from Slack's `localStorage` via AppleScript
   - **xoxd** — from Chrome's cookie database via `pycookiecheat`
2. Tokens are saved to `~/.claude/slack-tokens.env`
3. If a token expires (`invalid_auth`), the skill auto-refreshes and retries

No manual token management needed.

## Usage Examples

Once installed, just ask your agent naturally:

| Prompt | What happens |
|---|---|
| "Summarize #engineering from today" | Reads channel history and summarizes |
| "What did John say in #standup this week?" | Searches messages by user and channel |
| "Post 'deploy complete' in #releases" | Sends a message to the channel |
| "React with 👍 to that message" | Adds an emoji reaction |
| _Paste a Slack URL_ | Reads the message or thread at that URL |
| "Search Slack for deployment errors" | Searches across all channels |
| "Pin that message" | Pins the referenced message |
| "Who is U04ABC123?" | Looks up user info by ID |

## Troubleshooting

| Problem | Fix |
|---|---|
| `ERROR: Could not find Chrome cookie database` | Make sure Chrome is running |
| `ERROR: Could not extract xoxc token` | Open [app.slack.com](https://app.slack.com) in a Chrome tab and enable **Allow JavaScript from Apple Events** |
| `ERROR: Could not extract xoxd cookie` | Run `uvx --from pycookiecheat python3 -c "print('ok')"` to verify pycookiecheat works |
| `invalid_auth` keeps failing | Close and reopen the Slack tab in Chrome, then retry |
| `uvx: command not found` | Install uv: `brew install uv` |
| Scripts not executing | Run `chmod +x` on both scripts in `scripts/` |

## License

MIT
