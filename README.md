# Agent Skills

A curated collection of skills that extend AI coding agents (Claude Code, Cursor, Codex, and others) with real, day-to-day capabilities: talking to Slack, auditing your own setup, and more to come.

If you've ever wanted your agent to "just read that Slack thread" or "tell me what's broken in my config," this repository is for you. Each skill is a self-contained bundle of prompts, scripts, and docs that your agent loads on demand.

## Table of Contents

- [What is a "skill"?](#what-is-a-skill)
- [Installation](#installation)
  - [Claude Code only](#claude-code-only)
  - [All supported agents](#all-supported-agents)
  - [Specific agents](#specific-agents)
- [Available Skills](#available-skills)
  - [Slack](#slack)
  - [Setup Check](#setup-check)
- [License](#license)

## What is a "skill"?

A skill is a focused capability you drop into your agent's skills directory. Once installed, your agent can recognize when a user intent matches the skill (for example, "summarize this Slack channel") and invoke it automatically, no extra plumbing required.

Think of skills as plug-in expertise. You install the ones you need, your agent becomes better at those tasks, and nothing else changes.

## Installation

The `skills` CLI installs each skill into `~/.agents/skills/` and symlinks it into every agent's skills directory for you. In the commands below, replace `<skill>` with the name of the skill you want, for example `slack` or `setup-check`.

### Claude Code only

Use this if Claude Code is the only agent you run, or the only one you want this skill wired into.

```bash
npx skills add https://github.com/azmym/agent-skills --skill <skill>
```

### All supported agents

If you hop between agents (Claude Code, Cursor, Codex, and others), install once and cover them all:

```bash
npx skills add https://github.com/azmym/agent-skills --skill <skill> --agent '*'
```

### Specific agents

Pick a subset by passing a comma-separated list:

```bash
npx skills add https://github.com/azmym/agent-skills --skill <skill> --agent 'Claude Code,Cursor'
```

## Available Skills

### Slack

Bring Slack into your agent's workflow. Read channels, summarize threads, search messages, post updates, react, pin, and (in browser mode) even drive features that have no public API like Canvas and Huddles.

This skill is designed around one idea: you shouldn't have to context-switch into Slack just to ask "what did the team decide?" Just ask your agent.

#### Three operating modes

You pick the mode that matches your environment. Most people start with `auto` and never touch it again.

| Mode | Config value | When it's the right fit |
|------|--------------|-------------------------|
| Auto-detect (recommended) | `auto` | You want browser mode's full feature set when a session exists, and token mode's speed the rest of the time. Zero babysitting. |
| Token | `token` | macOS only. You want the fastest possible response times and are happy to keep Chrome open to Slack. |
| Browser | `browser` | You're on Linux or Windows, or you need UI automation features like Canvas, Huddles, or Workflow Builder. |

#### When your agent will use this skill

Your agent reaches for the Slack skill when you do things like:

- Paste a Slack URL and ask "what's this about?"
- Say "summarize #engineering from today" or "what did Alex say in #standup this week?"
- Ask it to "post 'deploy complete' in #releases" or "react with :tada: to that message"
- Mention a channel by name, for example `#design-reviews`
- Ask for Slack Canvas creation, Huddle interaction, or Workflow Builder changes (browser mode only)

#### Install

```bash
npx skills add https://github.com/azmym/agent-skills --skill slack
```

#### First run

The first time you trigger anything Slack-related, the agent will ask you to pick a mode:

1. **Token** (macOS only): Fastest option. Pulls session tokens out of Chrome automatically. Requires Chrome running with Slack open, AppleScript permission, and `uvx`.
2. **Browser** (cross-platform): Uses a local Playwright browser. Works on macOS, Linux, and Windows. Supports SSO, 2FA, and any login flow your workspace uses.
3. **Auto-detect** (recommended): Uses browser mode when a Playwright session is live, falls back to token mode otherwise.

Your choice is saved to `~/.agents/config/slack/config.env` and you'll never be asked again.

If you pick Browser mode, the agent opens a real browser window so you can complete your normal Slack login (SSO, 2FA, whatever you usually use). After that first login, sessions are reused.

#### Changing mode later

You can change your mind at any time by editing one file:

```bash
# Switch to token mode
echo 'SLACK_MODE=token' > ~/.agents/config/slack/config.env

# Switch to browser mode
echo 'SLACK_MODE=browser' > ~/.agents/config/slack/config.env

# Switch back to auto-detect
echo 'SLACK_MODE=auto' > ~/.agents/config/slack/config.env
```

You can also override per invocation using an environment variable (handy for one-off calls):

```bash
SLACK_MODE=browser slack-api.sh conversations.history channel=C041RSY6DN2 limit=20
```

The environment variable wins over the config file.

#### How auto-detect decides

1. It looks for a valid Playwright session at `~/.agents/config/slack/sessions/*/storageState.json`.
2. If a valid session is found, it uses browser mode.
3. Otherwise, it falls back to token mode.

In practice: start a browser session when you want the full feature set, stop it when you want maximum speed. No config edits required.

#### Prerequisites

##### Token mode (macOS)

1. **Google Chrome running with Slack open.** Open Chrome, visit [app.slack.com](https://app.slack.com), and sign in to your workspace.

2. **Allow JavaScript from Apple Events.** This permission lets the skill read your Slack session token out of the page.

   In Chrome, go to **View > Developer > Allow JavaScript from Apple Events** and confirm the prompt. Leave it on.

3. **Python 3**, used for JSON parsing and cookie extraction:

   ```bash
   python3 --version
   # If missing:
   brew install python3
   ```

4. **uvx (from uv)**, used to run `pycookiecheat` against Chrome's cookie database:

   ```bash
   brew install uv
   uvx --version   # sanity check
   ```

##### Browser mode (any OS)

1. **Node.js 18 or newer.** Install from [nodejs.org](https://nodejs.org) or your package manager:

   ```bash
   # macOS
   brew install node

   # Ubuntu / Debian
   curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

Playwright and Chromium install themselves the first time they run. Nothing else to set up.

#### How it works under the hood

If you're curious (or debugging), here's what each mode actually does.

##### Token mode

1. On the first API call, the skill pulls two session tokens out of Chrome:
   - `xoxc` from Slack's `localStorage` via AppleScript
   - `xoxd` from Chrome's cookie database via `pycookiecheat`
2. Tokens are cached in `~/.agents/config/slack/tokens.env`.
3. If Slack rejects a token with `invalid_auth`, the skill re-extracts and retries automatically.
4. Every call is a plain `curl` request to the Slack Web API.

You never manage tokens by hand.

##### Browser mode

1. A local Playwright Chromium instance launches.
2. You log in once (manually for SSO/2FA, or automated for email/password).
3. Session state (cookies plus `localStorage`) is saved to `~/.agents/config/slack/sessions/<id>/storageState.json`.
4. Each API call spawns a short-lived Chromium process, restores your session, runs `fetch()` inside the page context, and exits.
5. If no active session is found and mode is `auto`, the skill quietly falls back to token mode.

Browser mode also unlocks UI automation for Slack surfaces that have no public API:

- Canvas creation and editing
- Huddle interactions
- Workflow Builder configuration
- Slack Connect invitations
- Admin and settings pages
- Visual verification via screenshots

#### Usage examples

Once installed, you don't call anything by name. Just talk to your agent:

| You say | What the skill does |
|---------|---------------------|
| "Summarize #engineering from today" | Pulls recent channel history and summarizes it |
| "What did John say in #standup this week?" | Searches messages filtered by user and channel |
| "Post 'deploy complete' in #releases" | Sends a message on your behalf |
| "React with thumbsup to that message" | Adds an emoji reaction |
| (You paste a Slack message URL) | Reads the specific message or thread |
| "Search Slack for deployment errors" | Runs a cross-channel search |
| "Pin that message" | Pins the referenced message |
| "Who is U04ABC123?" | Looks up user info by Slack ID |
| "Create a canvas in #project-alpha" | Opens browser mode and creates a Canvas |
| "Take a screenshot of the #design channel" | Captures a visual snapshot via browser mode |

#### Troubleshooting

Most issues fall into one of two buckets. Find the symptom, apply the fix.

##### Token mode

| Symptom | Try this |
|---------|----------|
| `ERROR: Could not find Chrome cookie database` | Make sure Chrome is actually running. |
| `ERROR: Could not extract xoxc token` | Open [app.slack.com](https://app.slack.com) in Chrome and enable **View > Developer > Allow JavaScript from Apple Events**. |
| `ERROR: Could not extract xoxd cookie` | Sanity-check pycookiecheat: `uvx --from pycookiecheat python3 -c "print('ok')"`. |
| `invalid_auth` keeps failing | Close and reopen the Slack tab in Chrome, then try again. |
| `uvx: command not found` | Install uv: `brew install uv`. |
| Scripts won't execute | Run `chmod +x` on the files inside `scripts/`. |

##### Browser mode

| Symptom | Try this |
|---------|----------|
| `Node.js is required but not found` | Install Node.js 18+ from [nodejs.org](https://nodejs.org). |
| `no_browser_session` | Start one: `slack-browser-session.sh start`. |
| `browserType.launch: Executable doesn't exist` | Run `slack-browser-session.sh start`; it auto-installs Chromium. |
| Login page keeps reappearing | Your session likely expired. `stop` it, then `login-manual` to sign in again. |
| `no_teams_found` | Slack hasn't finished loading workspace data. Wait a few seconds and retry. |
| API responses feel slow | Browser mode carries launch overhead. On macOS, switch high-frequency calls to `SLACK_MODE=token`. |
| SSO login | Use `login-manual`; it opens a visible browser so you can complete SSO normally. |

---

### Setup Check

Audit your Claude Code configuration and get a clear, grouped report of what's healthy, what's conflicting, and what's drifted out of date. This is the skill you run when something "feels off" and you want a second opinion before you start ripping things out.

#### What it checks

- Skills: duplicates, broken symlinks, unused entries, placeholders
- Hooks: conflicts, missing paths, event collisions
- Plugins: disabled, stale cache, version drift
- Rules: internal contradictions, overlap with plugin behavior
- Settings: duplicate or conflicting keys (health only, no rewrites)
- Security: overly broad permissions, skipped prompts, orphaned MCP permissions
- MCP servers: empty configs, duplicates
- Memory: empty directories, stale entries, index mismatches
- Cross-category overlaps: for example, a rule duplicating what a plugin already enforces
- Updates: Claude Code CLI and plugin versions

#### When your agent will use this skill

- You ask "check my setup" or "audit my config"
- You say "what's broken?" or "find duplicates"
- You want a cleanup report before adding more plugins
- You ask about Claude Code or plugin update status
- You want to review MCP servers or memory state
- You invoke `/setup-check` directly, optionally with a scope

#### Install

```bash
npx skills add https://github.com/azmym/agent-skills --skill setup-check
```

#### Scope arguments

Run as `/setup-check [scope] [optional goal message]`. The default scope is `all`.

| Scope | What it audits |
|-------|----------------|
| `all` | Everything below, plus update checks |
| `updates` | Claude Code CLI and plugin versions |
| `skills` | Duplicates, broken symlinks, unused, placeholders |
| `hooks` | Conflicts, broken paths, event collisions |
| `plugins` | Disabled, stale cache, version tracking |
| `rules` | Contradictions, overlap with plugin behavior |
| `settings` | Duplicates, conflicting keys (health only) |
| `security` | Broad permissions, skipped prompts, orphaned MCP perms |
| `mcp` | Empty configs, duplicate servers |
| `memory` | Empty dirs, stale entries, index mismatches |
| `overlaps` | Cross-category overlap detection only |

You can combine scopes. For example, `/setup-check skills plugins` runs both.

#### Usage examples

| You say | What happens |
|---------|--------------|
| "Check my setup" | Full audit, grouped by category |
| "What's broken in my Claude Code config?" | Runs `all` and highlights errors, conflicts, misconfigurations |
| "Find overlaps between my skills and plugins" | Runs the `overlaps` cross-category detector |
| `/setup-check updates` | CLI and plugin update status only |
| `/setup-check skills hooks` | Audits just those two categories |

## License

MIT
