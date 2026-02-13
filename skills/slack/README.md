# Slack Skill

Interact with Slack directly from your AI coding agent — read, summarize, search, post messages, react, pin, and manage channels using the Slack Web API.

Tokens are extracted automatically from your running Chrome browser. No Slack app creation or OAuth setup required.

## Prerequisites

### 1. Google Chrome

Chrome must be running with Slack open in a tab.

- Open **Chrome** and navigate to [app.slack.com](https://app.slack.com)
- Sign in to your workspace

### 2. Allow JavaScript from Apple Events

This is required for the skill to extract your session token from Chrome.

1. Open Chrome
2. Go to **View → Developer → Allow JavaScript from Apple Events**
3. Confirm the prompt
4. This setting must stay enabled

### 3. Python 3

Python 3 is used for JSON parsing and cookie extraction. Verify it's installed:

```bash
python3 --version
```

If not installed:

```bash
brew install python3
```

### 4. uvx (from uv)

The skill uses `uvx` to run `pycookiecheat` for extracting the session cookie from Chrome's cookie database.

```bash
# Install uv (which provides uvx)
brew install uv

# Verify
uvx --version
```

### 5. macOS Only

This skill relies on:

- **AppleScript** to read Chrome's localStorage (for the `xoxc` token)
- **lsof** to locate Chrome's cookie database file (for the `xoxd` cookie)

These are macOS-specific. The skill does not currently support Linux or Windows.

## Installation

### Claude Code

```bash
npx skills add azmym/agent-skills
```

This installs the skill into `~/.claude/skills/slack/`. Claude Code automatically detects and loads it.

### Cursor

1. Clone or download this repository:

   ```bash
   git clone https://github.com/azmym/agent-skills.git
   ```

2. Copy the skill files into your Cursor rules directory:

   ```bash
   mkdir -p ~/.cursor/skills/slack
   cp -r agent-skills/skills/slack/* ~/.cursor/skills/slack/
   ```

3. Add the skill to your Cursor rules. Create or edit `.cursorrules` in your project root:

   ```
   @file ~/.cursor/skills/slack/SKILL.md
   ```

   Alternatively, add the content of `SKILL.md` directly into your `.cursorrules` or `.cursor/rules/` directory.

4. Make the scripts executable:

   ```bash
   chmod +x ~/.cursor/skills/slack/scripts/slack-api.sh
   chmod +x ~/.cursor/skills/slack/scripts/slack-token-refresh.sh
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
