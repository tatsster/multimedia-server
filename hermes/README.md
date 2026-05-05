# Hermes LXC Setup

This folder captures the current Hermes LXC setup and system-level configuration in a secret-safe form. It is the rebuild guide for CT `108` / `hermes` and should be used together with the canonical inventory in [`../inventory/lxc-map.md`](../inventory/lxc-map.md).

Fresh rebuild target:

- LXC: privileged container / `Unprivileged container=No`
- Feature: `nesting=1`
- Network: static `192.168.1.110/24` on `vmbr0`
- Model route: Hermes -> OmniRoute at `http://192.168.1.109:20128/v1`
- Memory route: Hermes -> Hindsight at `http://192.168.1.111:8888`
- Gateway: system-level `hermes-gateway.service` only

Do not commit real API keys, provider tokens, Discord tokens, Proxmox token secrets, or passwords.

## Current live target

Current live Hermes LXC verified from Proxmox:

```text
CTID: 108
Hostname: hermes
IP: 192.168.1.110/24
OS: Debian 13 trixie
Tag: agent
```

Current LXC resources/defaults:

```text
features: nesting=1
unprivileged: 0
privileged container
memory: 8192
swap: 512
cpulimit: 4
rootfs: 20G on vm_storage
onboot: 1
```

Keep these values unless intentionally resizing.

## Current live install layout

Verified live command paths:

```text
hermes: /usr/local/bin/hermes -> /usr/local/lib/hermes-agent/venv/bin/hermes
install dir: /usr/local/lib/hermes-agent
Hermes home: /root/.hermes
config: /root/.hermes/config.yaml
env: /root/.hermes/.env
logs: /root/.hermes/logs/gateway.log
hindsight client config: /root/.hermes/hindsight/config.json
```

Verified live Hermes version:

```text
Hermes Agent v0.12.0 (2026.4.30)
Project: /usr/local/lib/hermes-agent
Python: 3.11.15
OpenAI SDK: 2.32.0
```

Verified live upstream repo:

```text
https://github.com/NousResearch/hermes-agent.git
branch: main
```

The live root/FHS install matches the official installer behavior:

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup
```

For a controlled rebuild, clone first and run the installer/script locally instead of blindly piping if preferred.

## Current gateway service layout

The working live gateway is the **system-level** service:

```text
/etc/systemd/system/hermes-gateway.service
```

Current service shape:

```ini
[Unit]
Description=Hermes Agent Gateway - Messaging Platform Integration
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/lib/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace
WorkingDirectory=/usr/local/lib/hermes-agent
Environment="HOME=/root"
Environment="USER=root"
Environment="LOGNAME=root"
Environment="PATH=/usr/local/lib/hermes-agent/venv/bin:/usr/local/lib/hermes-agent/node_modules/.bin:/root/.hermes/node/bin:/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="VIRTUAL_ENV=/usr/local/lib/hermes-agent/venv"
Environment="HERMES_HOME=/root/.hermes"
Restart=always
RestartSec=60
KillMode=mixed
KillSignal=SIGTERM
ExecReload=/bin/kill -USR1 $MAINPID
TimeoutStopSec=210
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

After rebuild, prefer managing the gateway as the system service only:

```bash
systemctl enable --now hermes-gateway.service
systemctl status hermes-gateway.service --no-pager
```

## Current config snapshot

Sanitized system-level config example:

```text
config/config.system.example.yaml
```

Sanitized Hindsight client config example:

```text
config/hindsight.config.example.json
```

Secrets and private host values were replaced with placeholders.

Important current values preserved in the examples:

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

Current live private endpoints used by this homelab:

```text
OMNIROUTE_BASE_URL=http://192.168.1.109:20128/v1
HINDSIGHT_API_URL=http://192.168.1.111:8888
PROXMOX_HOST=https://192.168.1.101:8006
```

Do not commit real API keys/tokens/passwords.

## Rebuild steps

### 1. Create Hermes LXC

Use the repo PVE script or create manually with the same defaults:

```bash
cd /root/repos/multimedia-server
CTID=108 HOSTNAME=hermes IP_CIDR=192.168.1.110/24 ./scripts/pve/create-hermes-lxc.sh
```

If CTID/IP already exist, choose a temporary/test CTID/IP and delete it after testing.

### 2. Install Hermes

Inside the Hermes LXC:

```bash
apt-get update
apt-get install -y curl git ca-certificates build-essential
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup
```

Expected result for root install:

```text
/usr/local/lib/hermes-agent
/usr/local/bin/hermes
/root/.hermes
```

### 3. Restore sanitized config templates

Copy from the repo checkout into Hermes home. If the repo is not present inside the LXC, copy these files from the Proxmox host first.

```bash
mkdir -p /root/.hermes/hindsight
cp hermes/config/config.system.example.yaml /root/.hermes/config.yaml
cp hermes/config/hindsight.config.example.json /root/.hermes/hindsight/config.json
cp .env.example /root/.hermes/.env.example
cp /root/.hermes/.env.example /root/.hermes/.env
chmod 0600 /root/.hermes/.env
```

Then replace placeholders in:

```text
/root/.hermes/config.yaml
/root/.hermes/hindsight/config.json
/root/.hermes/.env
```

Keep `/root/.hermes/.env` private. It is intentionally ignored by Git.

### 4. Configure model/provider via `hermes config set`

Prefer `hermes config set` for model/provider changes so the command history documents what changed:

```bash
hermes config set model.default "codex/gpt-5.5-medium"
hermes config set model.provider "custom"
hermes config set model.base_url "http://192.168.1.109:20128/v1"
# Prefer env-backed config for secrets. If you must set a live key directly, never paste it into this repo.
hermes config set model.api_key '${OMNIROUTE_API_KEY}'
hermes config set memory.provider "hindsight"
```

If the config also uses `custom_providers`, keep its OmniRoute entry aligned with the model settings.

### 5. Configure Hindsight client

Edit:

```text
/root/.hermes/hindsight/config.json
```

Current external Hindsight mode:

```json
{
  "mode": "local_external",
  "api_url": "http://192.168.1.111:8888",
  "bank_id": "hermes",
  "recall_budget": "mid"
}
```

### 6. Configure gateway/platform secrets

Create and edit:

```bash
cp /root/.hermes/.env.example /root/.hermes/.env
nano /root/.hermes/.env
```

Only keep real secrets in `.env` / password manager, never in Git.

Required/optional secrets:

| Placeholder | Where to create/get it | Notes |
|---|---|---|
| `${OMNIROUTE_BASE_URL}` | OmniRoute LXC service URL | Current: `http://192.168.1.109:20128/v1` |
| `${OMNIROUTE_API_KEY}` | OmniRoute Dashboard -> Endpoints/API Keys | Create a key for Hermes only |
| `${HINDSIGHT_API_URL}` | Hindsight LXC/API | Current: `http://192.168.1.111:8888` |
| `${PROXMOX_HOST}` | Proxmox web UI URL | Current: `https://192.168.1.101:8006` |
| `<user@realm!tokenid>` | Proxmox -> Datacenter -> Permissions -> API Tokens | Use least privilege where possible |
| `${PROXMOX_TOKEN_SECRET}` | Proxmox API token secret shown at creation | Store in private password manager/env only |
| `<discord_user_id>` | Discord developer/user profile | Optional; only needed for Discord allowlist |
| `${DISCORD_BOT_TOKEN}` | Discord developer portal bot token | Needed for Discord gateway |
| `${DISCORD_HOME_CHANNEL}` | Discord channel ID | Needed for home channel replies |
| `${FIRECRAWL_API_KEY}` | Firecrawl dashboard | Current web backend uses Firecrawl |
| `${GOOGLE_API_KEY}` | Google AI Studio | Used by Gemini/auxiliary model paths if configured |

### 7. Enable exactly one gateway service

Current desired state is **system gateway active, user gateway removed/disabled**.

If the installer did not create `/etc/systemd/system/hermes-gateway.service`, create or restore the system unit using the service shape shown earlier in this guide, then run:

```bash
systemctl daemon-reload
systemctl enable --now hermes-gateway.service
```

Stop/disable the user-level gateway if present:

```bash
systemctl --user stop hermes-gateway.service 2>/dev/null || true
systemctl --user disable hermes-gateway.service 2>/dev/null || true
rm -f /root/.config/systemd/user/hermes-gateway.service
systemctl --user daemon-reload 2>/dev/null || true
```

Restart/check the system gateway explicitly:

```bash
# Hermes helper, explicit system target
hermes gateway restart --system
hermes gateway status --system

# Direct systemd equivalent
systemctl restart hermes-gateway.service
systemctl status hermes-gateway.service --no-pager
```

Avoid plain `hermes gateway restart` when both user and system units exist, because the helper can target the user service by default.

## Troubleshooting: duplicate Hermes gateway

Symptom from live Hermes:

```text
Both user and system gateway services are installed (user + system).
Default gateway commands target the user service unless you pass --system.
```

Cause:

- System service exists at `/etc/systemd/system/hermes-gateway.service` and is running.
- User service exists at `/root/.config/systemd/user/hermes-gateway.service` and is failed/disabled.
- `hermes gateway status` defaults to the user service, so it reports the failed user unit even though the system service is actually running.

Fix:

```bash
systemctl --user stop hermes-gateway.service 2>/dev/null || true
systemctl --user disable hermes-gateway.service 2>/dev/null || true
rm -f /root/.config/systemd/user/hermes-gateway.service
systemctl --user daemon-reload 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now hermes-gateway.service
hermes gateway status --system
systemctl status hermes-gateway.service --no-pager
```

Verify only one service remains:

```bash
systemctl status hermes-gateway.service --no-pager
systemctl --user status hermes-gateway.service --no-pager 2>&1 || true
ps -eo pid,ppid,stat,cmd | grep -E 'hermes_cli|gateway run' | grep -v grep
```

Expected active process:

```text
/usr/local/lib/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace
```

## Verification

```bash
hermes --version
hermes config check
hermes config get model
hermes config get memory
hermes gateway status --system
systemctl status hermes-gateway.service --no-pager
journalctl -u hermes-gateway -n 100 --no-pager
```

Optional endpoint checks from Hermes LXC:

```bash
curl -fsS http://192.168.1.109:20128/v1/models \
  -H 'Authorization: Bearer <omniroute-api-key>' >/dev/null
curl -fsS http://192.168.1.111:8888/health
```

Expected model route:

```text
model.default: codex/gpt-5.5-medium
model.provider: custom
model.base_url: http://192.168.1.109:20128/v1
memory.provider: hindsight
```

Expected Hindsight client config:

```text
mode: local_external
api_url: http://192.168.1.111:8888
bank_id: hermes
```

## Notes

- Prefer `hermes config set` for future model/provider changes.
- If image generation is enabled later, configure its provider separately; Hermes image generation does not automatically reuse the chat model provider.
- Current CLI platform toolsets include `image_gen` and `kanban`; Discord platform toolsets also include `image_gen` and `kanban`.
- Current live Hermes is behind upstream; `hermes update --check` / `hermes update` can be used intentionally after making a backup.
