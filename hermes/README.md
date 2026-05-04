# Hermes LXC Setup

This folder captures the current Hermes system-level configuration in a secret-safe form.

## Current config snapshot

- Sanitized system-level config example: [`config/config.system.example.yaml`](config/config.system.example.yaml)
- Source captured from current Hermes system/user config path: `/root/.hermes/config.yaml`
- Secrets and private host values were replaced with placeholders.

Important current values preserved in the example:

```yaml
model:
  default: codex/gpt-5.5-medium
  provider: custom
  base_url: ${OMNIROUTE_BASE_URL}
  api_key: ${OMNIROUTE_API_KEY}
  max_tokens: 65536
memory:
  provider: hindsight
custom_providers:
- name: Selfhosted Omniroute
  base_url: ${OMNIROUTE_BASE_URL}
  api_key: ${OMNIROUTE_API_KEY}
  model: codex/gpt-5.5-medium
```

Current live OmniRoute endpoint used by this homelab is private LAN-only and should be set during rebuild:

```text
OMNIROUTE_BASE_URL=http://<omniroute-lxc-ip>:20128/v1
```

## Rebuild steps

1. Create Hermes LXC using the standard LXC settings in the main homelab guide:
   - nesting enabled
   - privileged container / `Unprivileged container=No`
   - CPU advanced settings same as current setup
   - persistent storage for `/root/.hermes`
2. Install Hermes using the same installation method used on the live host.
3. Copy the sanitized example to the live config path:

```bash
mkdir -p /root/.hermes
cp hermes/config/config.system.example.yaml /root/.hermes/config.yaml
```

4. Replace placeholders manually or through `hermes config set`:

```bash
hermes config set model.base_url "http://<omniroute-lxc-ip>:20128/v1"
hermes config set model.api_key "<omniroute-api-key>"
hermes config set model.default "codex/gpt-5.5-medium"
hermes config set memory.provider "hindsight"
```

5. Restart Hermes/gateway after config changes:

```bash
hermes gateway restart
```

## Required secrets and where to get them

Do not commit these real values.

| Placeholder | Where to create/get it | Notes |
|---|---|---|
| `${OMNIROUTE_BASE_URL}` | OmniRoute LXC service URL | Usually `http://<omniroute-lxc-ip>:20128/v1` |
| `${OMNIROUTE_API_KEY}` | OmniRoute Dashboard → Endpoints/API Keys | Create a key for Hermes only |
| `${PROXMOX_HOST}` | Proxmox web UI URL | Example: `https://<proxmox-ip>:8006` |
| `<user@realm!tokenid>` | Proxmox → Datacenter → Permissions → API Tokens | Use least privilege where possible |
| `${PROXMOX_TOKEN_SECRET}` | Proxmox API token secret shown at creation | Store in private password manager/env only |
| `<discord_user_id>` | Discord developer/user profile | Optional; only needed for Discord allowlist |

## Troubleshooting: duplicate Hermes gateway

Symptom: Hermes behaves inconsistently or routes through the wrong gateway/provider after rebuild.

Likely cause: both a system-level gateway and a user-level gateway are enabled.

Fix checklist:

1. Inspect active Hermes config locations:

```bash
hermes config get
# also inspect /root/.hermes/config.yaml and any service-level config if present
```

2. Keep only one active gateway/provider definition.
3. Remove or disable the duplicate user-level/system-level gateway entry.
4. Restart:

```bash
hermes gateway restart
```

5. Verify model routing uses OmniRoute:

```bash
hermes config get model
```

Expected base URL:

```text
http://<omniroute-lxc-ip>:20128/v1
```

## Notes

- Prefer `hermes config set` for future model/provider changes so the command history documents what changed.
- If image generation is enabled later, configure its provider separately; Hermes image generation does not automatically reuse the chat model provider.
