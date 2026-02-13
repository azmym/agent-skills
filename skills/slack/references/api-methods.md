# Slack Web API Methods Reference

Full reference for all supported Slack Web API methods via the skill's API wrapper.
All methods use: `~/.claude/skills/slack/scripts/slack-api.sh <method> [key=value ...]`

## Table of Contents

- [Messages (chat.*)](#messages)
- [Conversations (conversations.*)](#conversations)
- [Reactions (reactions.*)](#reactions)
- [Pins (pins.*)](#pins)
- [Bookmarks (bookmarks.*)](#bookmarks)
- [Users (users.*)](#users)
- [User Groups (usergroups.*)](#user-groups)
- [Search (search.*)](#search)
- [Files (files.*)](#files)
- [Emoji (emoji.*)](#emoji)
- [Reminders (reminders.*)](#reminders)

---

## Messages

### chat.postMessage — Send a message

    slack-api.sh chat.postMessage channel=CHANNEL_ID text="Hello world"

Key parameters:
- `channel` (required) — channel, DM, or group ID
- `text` (required) — message body (max 4000 chars). Also used as fallback when blocks are provided
- `thread_ts` — reply to a thread (provide parent message ts)
- `reply_broadcast=true` — also post threaded reply to channel
- `unfurl_links=false` — suppress link previews
- `blocks` — JSON array of Block Kit blocks for rich formatting

### chat.update — Edit a message

    slack-api.sh chat.update channel=CHANNEL_ID ts=MESSAGE_TS text="Updated text"

Parameters: same as postMessage plus `ts` (required) — timestamp of message to edit.
Can only edit messages posted by the authenticated user.

### chat.delete — Delete a message

    slack-api.sh chat.delete channel=CHANNEL_ID ts=MESSAGE_TS

Can only delete messages posted by the authenticated user.

### chat.getPermalink — Get message permalink

    slack-api.sh chat.getPermalink channel=CHANNEL_ID message_ts=MESSAGE_TS

Returns `.permalink` — a shareable URL for the message.

### chat.meMessage — Send /me message

    slack-api.sh chat.meMessage channel=CHANNEL_ID text="is thinking..."

---

## Conversations

### conversations.history — Read channel messages

    slack-api.sh conversations.history channel=CHANNEL_ID limit=20

Optional:
- `oldest` / `latest` — Unix timestamps to bound the range
- `inclusive=true` — include messages at the boundary timestamps
- `cursor` — pagination cursor from previous response

### conversations.replies — Read thread replies

    slack-api.sh conversations.replies channel=CHANNEL_ID ts=THREAD_TS limit=100

### conversations.list — List channels

    slack-api.sh conversations.list types=public_channel limit=200

Types: `public_channel`, `private_channel`, `mpim`, `im` (comma-separated for multiple).

### conversations.info — Get channel details

    slack-api.sh conversations.info channel=CHANNEL_ID

Returns name, topic, purpose, member count, creation date.

### conversations.members — List channel members

    slack-api.sh conversations.members channel=CHANNEL_ID limit=100

Returns array of user IDs. Use with users.info to resolve names.

### conversations.join — Join a public channel

    slack-api.sh conversations.join channel=CHANNEL_ID

### conversations.open — Open/create a DM

    slack-api.sh conversations.open users=USER_ID

For multi-party DM, comma-separate user IDs.

### conversations.mark — Mark channel as read

    slack-api.sh conversations.mark channel=CHANNEL_ID ts=LATEST_TS

---

## Reactions

### reactions.add — Add emoji reaction

    slack-api.sh reactions.add channel=CHANNEL_ID timestamp=MESSAGE_TS name=thumbsup

`name` is the emoji name without colons (e.g., `thumbsup`, `eyes`, `white_check_mark`).
Supports skin tones: `thumbsup::skin-tone-3`.

### reactions.remove — Remove emoji reaction

    slack-api.sh reactions.remove channel=CHANNEL_ID timestamp=MESSAGE_TS name=thumbsup

### reactions.get — Get reactions for a message

    slack-api.sh reactions.get channel=CHANNEL_ID timestamp=MESSAGE_TS

### reactions.list — List reactions by user

    slack-api.sh reactions.list user=USER_ID limit=20

---

## Pins

### pins.add — Pin a message

    slack-api.sh pins.add channel=CHANNEL_ID timestamp=MESSAGE_TS

### pins.remove — Unpin a message

    slack-api.sh pins.remove channel=CHANNEL_ID timestamp=MESSAGE_TS

### pins.list — List pinned items

    slack-api.sh pins.list channel=CHANNEL_ID

---

## Bookmarks

### bookmarks.list — List channel bookmarks

    slack-api.sh bookmarks.list channel_id=CHANNEL_ID

### bookmarks.add — Add a bookmark

    slack-api.sh bookmarks.add channel_id=CHANNEL_ID title="Bookmark Title" type=link link="https://example.com"

### bookmarks.remove — Remove a bookmark

    slack-api.sh bookmarks.remove channel_id=CHANNEL_ID bookmark_id=BOOKMARK_ID

---

## Users

### users.info — Get user info

    slack-api.sh users.info user=USER_ID

Key response fields: `.user.real_name`, `.user.profile.display_name`, `.user.profile.email`, `.user.profile.title`, `.user.tz`.

### users.profile.get — Get detailed user profile

    slack-api.sh users.profile.get user=USER_ID

Returns extended profile fields including custom status, phone, etc.

### users.lookupByEmail — Find user by email

    slack-api.sh users.lookupByEmail email=user@example.com

### users.getPresence — Check if user is online

    slack-api.sh users.getPresence user=USER_ID

Returns `.presence` — "active" or "away".

---

## User Groups

### usergroups.list — List user groups (handles)

    slack-api.sh usergroups.list include_users=true

Returns all @handle groups. With `include_users=true`, includes member IDs.

### usergroups.users.list — List members of a user group

    slack-api.sh usergroups.users.list usergroup=USERGROUP_ID

---

## Search

### search.messages — Search messages

    slack-api.sh search.messages query="search terms" count=10 sort=timestamp sort_dir=desc

Modifiers: `in:#channel`, `from:@user`, `before:YYYY-MM-DD`, `after:YYYY-MM-DD`, `has:link`, `has:reaction`, `has:pin`, `has:star`.

### search.files — Search files

    slack-api.sh search.files query="filename or keyword" count=10

---

## Files

### files.list — List files

    slack-api.sh files.list channel=CHANNEL_ID count=20

Optional: `types` (images, snippets, pdfs, etc.), `user`, `ts_from`, `ts_to`.

### files.info — Get file details

    slack-api.sh files.info file=FILE_ID

---

## Emoji

### emoji.list — List custom workspace emoji

    slack-api.sh emoji.list

Returns map of emoji name -> URL.

---

## Reminders

### reminders.add — Create a reminder

    slack-api.sh reminders.add text="Review PR" time=1770800000

`time` can be a Unix timestamp or natural language like "in 15 minutes", "tomorrow at 9am".

### reminders.list — List active reminders

    slack-api.sh reminders.list

### reminders.complete — Mark reminder as complete

    slack-api.sh reminders.complete reminder=REMINDER_ID

### reminders.delete — Delete a reminder

    slack-api.sh reminders.delete reminder=REMINDER_ID
