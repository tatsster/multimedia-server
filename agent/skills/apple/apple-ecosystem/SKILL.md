---
name: apple-ecosystem
description: "Class-level macOS/Apple workflows: Notes, Reminders, Find My, iMessage/SMS, and GUI computer-use automation."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [Apple, macOS, Notes, Reminders, iMessage, FindMy, Computer-Use]
---

# Apple Ecosystem Workflows

Use this umbrella when the user asks to interact with Apple-native data or apps from a Mac: Apple Notes, Reminders, Find My devices/AirTags, iMessage/SMS, or macOS GUI automation. These workflows generally require macOS, Homebrew-installed CLIs, and user-granted privacy/automation permissions.

## General macOS permission pattern

Many Apple workflows fail until the terminal/agent process has permission under System Settings → Privacy & Security. After installing a CLI, run a harmless command once, watch for the prompt, then grant the requested permission (Automation, Full Disk Access, Reminders, Contacts, Messages, or Accessibility as appropriate).

## Apple Notes

Use `memo` when the user asks to create, search, edit, move, delete, or export Apple Notes that sync through iCloud.

Install: `brew tap antoniorodr/memo && brew install antoniorodr/memo/memo`.

Common commands:

```bash
memo notes
memo notes -f "Folder Name"
memo notes -s "query"
memo notes -a "Note Title"
memo notes -e
memo notes -d
memo notes -m
memo notes -ex
```

Do not use Apple Notes for agent-only durable facts; use the `memory` tool instead. Use Obsidian-specific workflows for an Obsidian vault.

## Apple Reminders

Use `remindctl` for reminders or to-dos that should appear on the user's Apple devices.

Install: `brew install steipete/tap/remindctl`; check `remindctl status`; authorize with `remindctl authorize` if needed.

Common commands:

```bash
remindctl today
remindctl tomorrow
remindctl week
remindctl overdue
remindctl all
remindctl list
remindctl list Work --create
```

If the user says "remind me" and means an agent alert/notification rather than an iOS Reminders item, use `cronjob` instead or clarify if ambiguous.

## Find My

Use the Find My workflow only on macOS when the user wants locations of Apple devices or AirTags. Expect privacy constraints and avoid exposing sensitive location data unnecessarily. Verify tooling and permissions before promising a result.

## iMessage / SMS

Use the iMessage workflow on macOS for sending or reading iMessages/SMS via an installed CLI such as `imsg`. Confirm recipient identity before sending messages. Treat message content as sensitive and avoid bulk sends unless explicitly requested.

## macOS computer use

Use macOS GUI automation when a task must interact with an app that has no reliable CLI/API. Prefer CLI/API automation first; GUI automation is brittle. Before controlling the GUI, verify the active app/window, make reversible changes where possible, and ask for clarification before destructive actions.
