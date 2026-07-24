# Himalaya Configuration Reference

Configuration file location: `~/.config/himalaya/config.toml`

## Minimal IMAP + SMTP Setup

```toml
[accounts.default]
email = "user@example.com"
display-name = "Your Name"
default = true

backend.type = "imap"
backend.host = "imap.example.com"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "user@example.com"
backend.auth.type = "password"
backend.auth.cmd = "pass show email/imap"

message.send.backend.type = "smtp"
message.send.backend.host = "smtp.example.com"
message.send.backend.port = 587
message.send.backend.encryption.type = "start-tls"
message.send.backend.login = "user@example.com"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "pass show email/smtp"

folder.aliases.inbox = "INBOX"
folder.aliases.sent = "Sent"
folder.aliases.drafts = "Drafts"
folder.aliases.trash = "Trash"
```

## Password options

Testing only:

```toml
backend.auth.raw = "your-password"
```

Recommended:

```toml
backend.auth.cmd = "pass show email/imap"
# macOS example:
# backend.auth.cmd = "security find-generic-password -a user@example.com -s imap -w"
```

System keyring, when Himalaya has keyring support:

```toml
backend.auth.keyring = "imap-example"
```

Then run `himalaya account configure <account>` to store the password.

## Gmail

```toml
[accounts.gmail]
email = "you@gmail.com"
display-name = "Your Name"
default = true

backend.type = "imap"
backend.host = "imap.gmail.com"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "you@gmail.com"
backend.auth.type = "password"
backend.auth.cmd = "pass show google/app-password"

message.send.backend.type = "smtp"
message.send.backend.host = "smtp.gmail.com"
message.send.backend.port = 587
message.send.backend.encryption.type = "start-tls"
message.send.backend.login = "you@gmail.com"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "pass show google/app-password"

folder.aliases.inbox = "INBOX"
folder.aliases.sent = "[Gmail]/Sent Mail"
folder.aliases.drafts = "[Gmail]/Drafts"
folder.aliases.trash = "[Gmail]/Trash"
```

Gmail requires an app password if 2FA is enabled.

## iCloud

```toml
[accounts.icloud]
email = "you@icloud.com"
display-name = "Your Name"

backend.type = "imap"
backend.host = "imap.mail.me.com"
backend.port = 993
backend.encryption.type = "tls"
backend.login = "you@icloud.com"
backend.auth.type = "password"
backend.auth.cmd = "pass show icloud/app-password"

message.send.backend.type = "smtp"
message.send.backend.host = "smtp.mail.me.com"
message.send.backend.port = 587
message.send.backend.encryption.type = "start-tls"
message.send.backend.login = "you@icloud.com"
message.send.backend.auth.type = "password"
message.send.backend.auth.cmd = "pass show icloud/app-password"
```

Generate an app-specific password at appleid.apple.com.

## Folder aliases

Use v1.2.0 `folder.aliases.X` syntax, plural, directly under `[accounts.NAME]`:

```toml
folder.aliases.inbox = "INBOX"
folder.aliases.sent = "Sent"
folder.aliases.drafts = "Drafts"
folder.aliases.trash = "Trash"
```

The equivalent sub-section also works:

```toml
[accounts.default.folder.aliases]
inbox = "INBOX"
sent = "Sent"
drafts = "Drafts"
trash = "Trash"
```

Do not use singular `[accounts.NAME.folder.alias]`. v1.2.0 silently ignores it. On Gmail this can make save-to-Sent fail after SMTP delivery succeeds; retrying sends duplicate emails.

## Multiple accounts

```toml
[accounts.personal]
email = "personal@example.com"
default = true

[accounts.work]
email = "work@company.com"
```

Switch accounts:

```bash
himalaya --account work envelope list
```

## Notmuch backend

```toml
[accounts.local]
email = "user@example.com"
backend.type = "notmuch"
backend.db-path = "~/.mail/.notmuch"
```

## Extras

```toml
signature = "Best regards,\nYour Name"
signature-delim = "-- \n"
downloads-dir = "~/Downloads/himalaya"
```

Set editor via environment variable: `export EDITOR="vim"`.
