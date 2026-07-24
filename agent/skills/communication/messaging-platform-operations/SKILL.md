---
name: messaging-platform-operations
description: "Operate messaging platforms from Hermes: email CLIs, gateway chat behavior, group mentions, member lookup, and direct messages."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [messaging, email, imap, smtp, gateway, chat, yuanbao, mentions, dm, communication]
    related_skills: []
---

# Messaging Platform Operations

## Umbrella scope

Use this class-level skill for operating messaging systems from Hermes: terminal email clients, gateway-delivered chat replies, group member lookup, @mentions, direct messages, and platform-specific quirks. It absorbs the former narrow `himalaya` and `yuanbao` skills.

Keep platform-specific details in `references/` so the main trigger stays discoverable across email and chat workflows.

## General gateway rule

On gateway-backed chats, your final text reply is usually the message delivered to the user or group. Do not claim you cannot send a message or mention someone when the platform integration explicitly supports it. Use the platform's member lookup/DM tools only when the workflow requires an API action beyond the normal reply.

## Email from terminal: Himalaya

Use Himalaya when the task is to operate a mailbox from terminal tools with IMAP/SMTP/Notmuch/Sendmail. It is separate from Hermes' Email gateway adapter.

Prerequisites:
- `himalaya` CLI installed.
- `~/.config/himalaya/config.toml` configured.
- Credentials stored securely via `pass`, keyring, or another command.

Common commands:

```bash
himalaya folder list
himalaya envelope list
himalaya envelope list --folder "Sent"
himalaya message read 42
himalaya message export 42 --full
himalaya template reply 42 | himalaya template send
himalaya message move 42 "Archive"
himalaya message delete 42
himalaya attachment download 42 --dir ~/Downloads
```

Prefer `--output json` where supported. For non-interactive composition, pipe a complete message to `himalaya template send`; avoid editor workflows unless using PTY intentionally.

Important Himalaya folder alias warning: v1.2.0 expects `folder.aliases.X` (plural) under `[accounts.NAME]`. The old singular `[accounts.NAME.folder.alias]` form is silently ignored and can cause Gmail save-to-Sent failures after SMTP succeeds; retrying can duplicate sent mail.

See:
- `references/himalaya-configuration.md`
- `references/himalaya-message-composition.md`

## Yuanbao group interaction

Use Yuanbao-specific workflows for group member lookup, @mentions, group info, and DMs.

Rules:
- In group replies, the reply text itself is sent to the group.
- To @mention someone, first query members to get the exact nickname; then include `@nickname` in the reply.
- Keep mention replies short and natural. Do not explain mechanics unless asked.
- Extract `group_code` from chat IDs like `group:535168412`.
- For Yuanbao DMs, use the Yuanbao DM tool, not generic `send_message`.
- If multiple member matches are returned, ask the user to clarify.

See `references/yuanbao-group-interaction.md` for exact tool shapes and examples.
