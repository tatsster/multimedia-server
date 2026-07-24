# Yuanbao Group Interaction

## Critical behavior

Your normal text reply is the message delivered to the group or user by the gateway. You do not need a separate send-message tool for group replies.

When your reply includes `@nickname`, the gateway converts it into a real @mention. Never tell the user you cannot @mention if the Yuanbao integration is active.

## Tools

| Tool | Use |
| --- | --- |
| `yb_query_group_info` | Query group name, owner, member count. |
| `yb_query_group_members` | Find a user, list bots, list all members, or get nickname for @mention. |
| `yb_send_dm` | Send a private/direct message with optional media. |

## @mention workflow

1. Call `yb_query_group_members` with `action="find"`, `name="<target name>"`, `mention=true`.
2. Get the exact nickname.
3. Include `@nickname` in your reply text.

Example request: `帮我艾特元宝`

Tool call:

```json
{ "group_code": "328306697", "action": "find", "name": "元宝", "mention": true }
```

Reply:

```text
@元宝 你好，有人找你！
```

Rules:
- Do not guess nicknames.
- Use `@nickname` with a space before the mention when embedded in text.
- Be concise; do not explain the mechanism.

## DM workflow

For private messages / 私信 / DM:

1. Extract `group_code` from current chat ID, e.g. `group:535168412` -> `535168412`.
2. Call `yb_send_dm` with `group_code`, target `name` or `user_id`, `message`, and optional media files.
3. Report the result.

Examples:

```json
yb_send_dm({ "group_code": "535168412", "name": "用户aea3", "message": "hello" })
```

```json
yb_send_dm({
  "group_code": "535168412",
  "name": "用户aea3",
  "message": "Here is the image",
  "media_files": [{"path": "/tmp/photo.jpg"}]
})
```

Rules:
- Use `user_id` directly if known.
- If multiple users match, ask for clarification.
- Do not use generic `send_message` for Yuanbao DMs.
- Images are sent as image messages; other files as documents.

## Group info and member listing

```json
yb_query_group_info({ "group_code": "328306697" })
```

Member actions:
- `find`: partial, case-insensitive name search.
- `list_bots`: bots and Yuanbao AI assistants.
- `list_all`: all members.

Notes:
- Yuanbao groups are called 派 (Pai).
- Member roles: `user`, `yuanbao_ai`, `bot`.
