---
name: slack
description: Interact with Slack via the Web API. Read, summarize, search, post messages, react, pin, and manage channels. Use when the user (1) shares a Slack URL, (2) asks to read or summarize a channel, (3) searches Slack messages, (4) asks to send/post a message, (5) asks to react to or pin a message, (6) looks up a user, or (7) mentions a Slack channel by name (e.g., "#channel-name"). Also triggers for Slack threads, daily standups, conversation digests, or any Slack interaction.
---

# Slack Web API Skill

Interact with Slack: read, write, search, react, pin, and manage conversations via the Web API.

## API Wrapper

All calls go through the script at `scripts/slack-api.sh` relative to this skill's base directory:

    {SKILL_DIR}/scripts/slack-api.sh <method> [key=value ...]

Where `{SKILL_DIR}` is the base directory provided when this skill is loaded (e.g., `~/.agents/skills/slack`).

For the full method reference, see [references/api-methods.md](references/api-methods.md).

## Parsing Slack URLs

Extract channel and timestamp from Slack URLs:

    https://{WORKSPACE}.slack.com/archives/{CHANNEL_ID}/p{TIMESTAMP_WITHOUT_DOT}

Insert a dot before the last 6 digits of the timestamp:
- URL: p1770725748342899 -> ts: 1770725748.342899

For threaded messages, the URL may include ?thread_ts= parameter.

## Read Operations

### Read a thread

    slack-api.sh conversations.replies channel=CHANNEL_ID ts=THREAD_TS limit=100

### Read channel history

    slack-api.sh conversations.history channel=CHANNEL_ID limit=20

Optional: `oldest` / `latest` (Unix timestamps) to bound the time range.

### Search messages

    slack-api.sh search.messages query="search terms" count=10

Modifiers: `in:#channel`, `from:@user`, `before:YYYY-MM-DD`, `after:YYYY-MM-DD`, `has:link`, `has:reaction`, `has:pin`.

### Find a channel by name

    slack-api.sh conversations.list types=public_channel limit=200 | python3 -c "import sys,json; channels=json.load(sys.stdin).get('channels',[]); matches=[c for c in channels if 'TARGET' in c['name']]; [print(f\"{c['id']} #{c['name']}\") for c in matches]"

### Look up a user

    slack-api.sh users.info user=USER_ID

Name: `.user.real_name` or `.user.profile.display_name`.

### List pinned items

    slack-api.sh pins.list channel=CHANNEL_ID

### List channel members

    slack-api.sh conversations.members channel=CHANNEL_ID limit=100

## Write Operations

### Send a message

    slack-api.sh chat.postMessage channel=CHANNEL_ID text="Hello world"

Thread reply: add `thread_ts=PARENT_TS`. Broadcast to channel: add `reply_broadcast=true`.

### Edit a message

    slack-api.sh chat.update channel=CHANNEL_ID ts=MESSAGE_TS text="Updated text"

### Delete a message

    slack-api.sh chat.delete channel=CHANNEL_ID ts=MESSAGE_TS

### Add a reaction

    slack-api.sh reactions.add channel=CHANNEL_ID timestamp=MESSAGE_TS name=thumbsup

Emoji name without colons. Supports skin tones: `thumbsup::skin-tone-3`.

### Remove a reaction

    slack-api.sh reactions.remove channel=CHANNEL_ID timestamp=MESSAGE_TS name=thumbsup

### Pin a message

    slack-api.sh pins.add channel=CHANNEL_ID timestamp=MESSAGE_TS

### Unpin a message

    slack-api.sh pins.remove channel=CHANNEL_ID timestamp=MESSAGE_TS

## Image and File Handling

Messages may contain files. For images in the JSON response:

    source ~/.claude/slack-tokens.env
    curl -s "FILE_URL_PRIVATE" \
      -H "Authorization: Bearer ${SLACK_XOXC}" \
      -H "Cookie: d=${SLACK_XOXD}" \
      -o /tmp/slack-image-N.png

Then use the Read tool to view the downloaded image.

## Output Formatting

1. Parse JSON with python3 -c "import sys,json; ..."
2. Resolve user IDs (U...) to real names via users.info (cache lookups)
3. Present messages with timestamps and names
4. Replace <@U...> mentions with resolved real names
5. Decode Slack markup (entities, link syntax, channel references) to plain text

## Rate Limiting

- Add sleep 1 between consecutive API calls
- Never bulk-paginate large datasets (users.list), it kills the session
- Prefer targeted queries over bulk fetches

## Token Refresh (Automatic)

Token refresh is fully automatic. The API wrapper (`slack-api.sh`):
1. Auto-refreshes if `~/.claude/slack-tokens.env` is missing
2. Auto-refreshes on `invalid_auth` errors and retries the call

Tokens are extracted from the running Chrome browser:
- xoxc: from Slack's localStorage via AppleScript
- xoxd: from Chrome's cookie database via `lsof` + `pycookiecheat`

Prerequisites (one-time):
- Chrome > View > Developer > Allow JavaScript from Apple Events (must stay enabled)
- Slack open in a Chrome tab at app.slack.com
- `uvx` installed

## Setup

No manual setup needed. On first API call, tokens are extracted automatically from Chrome.
If extraction fails, ensure the prerequisites above are met.

## Full API Reference

For additional methods (bookmarks, user groups, reminders, emoji, files, user profiles, etc.), see [references/api-methods.md](references/api-methods.md).

## Error Handling

- not_in_channel: User does not have access to this channel
- channel_not_found: Invalid channel ID
- invalid_auth: Token expired, auto-refresh attempted (see Token Refresh)
- ratelimited: Wait and retry with sleep 5
- cant_update_message / cant_delete_message: Can only modify own messages
