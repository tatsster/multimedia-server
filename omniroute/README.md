# OmniRoute LXC Setup

OmniRoute is the OpenAI-compatible AI gateway/router used by Hermes and Hindsight.

Current live target:

```text
CTID: 107
Hostname: omniroute
IP: 192.168.1.109/24
Port: 20128
Dashboard: http://192.168.1.109:20128
OpenAI-compatible API: http://192.168.1.109:20128/v1
```

## Live LXC profile

Captured from the current Proxmox host:

```text
OS: Debian 13 trixie
arch: amd64
cores: 2
memory: 4096
swap: 512
rootfs: vm_storage:subvol-107-disk-0,size=4G
onboot: 1
features: nesting=1
unprivileged: 0
privileged container: yes
network: vmbr0, 192.168.1.109/24, gw 192.168.1.1
tag: agent
```

Preserve `features: nesting=1` and `unprivileged: 0` for rebuild consistency.

## Live install layout

```text
Package: omniroute@3.7.8 from npm
Upstream: https://github.com/diegosouzapw/OmniRoute
Node: v24.15.0
npm: 11.12.1
Binary: /usr/bin/omniroute -> /usr/lib/node_modules/omniroute/bin/omniroute.mjs
Data dir: /root/.omniroute
SQLite DB: /root/.omniroute/storage.sqlite
Backups: /root/.omniroute/db_backups
Call logs: /root/.omniroute/call_logs
Systemd unit: /etc/systemd/system/omniroute.service
```

The live service runs as root through systemd and listens on `0.0.0.0:20128`.

## Systemd service

Use the sanitized example:

```text
omniroute/systemd/omniroute.service.example
```

Copy it to:

```bash
cp /root/repos/multimedia-server/omniroute/systemd/omniroute.service.example /etc/systemd/system/omniroute.service
systemctl daemon-reload
systemctl enable --now omniroute.service
```

For a new rebuild, keep secrets in:

```text
/root/.omniroute/omniroute.env
```

Create it from:

```text
omniroute/config/omniroute.env.example
```

## Secrets and where to create them

Do **not** commit real values.

| Secret | Where used | How to create / obtain |
|---|---|---|
| `INITIAL_PASSWORD` | OmniRoute dashboard first login | Generate your own strong password, e.g. password manager or `openssl rand -base64 18`. |
| `JWT_SECRET` | Dashboard JWT session signing | `openssl rand -base64 48` |
| `API_KEY_SECRET` | Encrypting stored API keys in SQLite | `openssl rand -hex 32` |
| Provider credentials | OmniRoute provider connections | Add via OmniRoute dashboard provider login/API-key flow. Current live providers include Gemini, GitHub, Claude, Codex, and Cursor. |
| Hermes/Hindsight API key | Clients calling `http://192.168.1.109:20128/v1` | Create in OmniRoute dashboard API keys section after login. Store in Hermes/Hindsight env/config, never in this repo. |

## Current live settings snapshot, sanitized

From live SQLite `key_value` table:

```text
namespace=settings key=setupComplete value=true
namespace=settings key=requireLogin value=true
namespace=settings key=password value=[bcrypt hash redacted]
namespace=settings key=call_log_pipeline_enabled value=0
```

Model aliases currently used:

```text
gemini-3-flash-preview -> antigravity/gemini-3-flash-preview
gemini-3-pro-high -> antigravity/gemini-3-pro-preview
gemini-3-pro-low -> antigravity/gemini-3.1-pro-low
gemini-3-pro-preview -> antigravity/gemini-3-pro-preview
gemini-3.1-pro-preview -> antigravity/gemini-3-pro-preview
gemini-3.1-pro-preview-customtools -> antigravity/gemini-3-pro-preview
```

Provider account emails, tokens, API keys, and OAuth data are intentionally omitted.

## Rebuild install flow

From the Proxmox shell:

```bash
cd /root/repos/multimedia-server
CTID=107 IP_CIDR=192.168.1.109/24 HOSTNAME=omniroute INITIAL_PASSWORD='replace-with-strong-password' bash scripts/pve/create-omniroute-lxc.sh
```

Then inside the LXC:

```bash
pct exec 107 -- bash
nano /root/.omniroute/omniroute.env
systemctl restart omniroute.service
systemctl status omniroute.service --no-pager
```

Open:

```text
http://192.168.1.109:20128
```

Add provider connections and create the API key used by Hermes/Hindsight.

## Password / onboarding SQLite workaround

Preferred path:

1. Set `INITIAL_PASSWORD` before first start.
2. Start OmniRoute once.
3. Login and change password from the dashboard.

If onboarding or first login is broken, update the SQLite settings directly.

### Option A: use the packaged reset helper

OmniRoute includes this binary:

```text
/usr/bin/omniroute-reset-password -> /usr/lib/node_modules/omniroute/bin/reset-password.mjs
```

The upstream helper expects `DATA_DIR/settings.db`, but this live install uses:

```text
/root/.omniroute/storage.sqlite
```

If your fresh install uses `settings.db`, run:

```bash
DATA_DIR=/root/.omniroute omniroute-reset-password
systemctl restart omniroute.service
```

If it says the DB is not found, use Option B for the current `storage.sqlite` schema.

### Option B: current live `storage.sqlite` schema

This works with the live schema where auth settings are stored in the `key_value` table.

Install sqlite3 if needed:

```bash
apt-get update
apt-get install -y sqlite3
```

Update the settings with Node so the bcrypt hash is generated locally and the plaintext password is not stored in shell history:

```bash
cd /usr/lib/node_modules/omniroute
read -rsp 'New OmniRoute password: ' OMNI_PASS; echo
export OMNI_PASS
node <<'NODE'
const Database = require('better-sqlite3');
const bcrypt = require('bcryptjs');

const db = new Database('/root/.omniroute/storage.sqlite');
const hash = bcrypt.hashSync(process.env.OMNI_PASS, 12);
const upsert = db.prepare(`
  INSERT INTO key_value (namespace, key, value)
  VALUES ('settings', ?, ?)
  ON CONFLICT(namespace, key) DO UPDATE SET value=excluded.value
`);

// Live schema stores password as a JSON string value, while booleans are raw text.
upsert.run('password', JSON.stringify(hash));
upsert.run('setupComplete', 'true');
upsert.run('requireLogin', 'true');
db.close();
NODE
unset OMNI_PASS
systemctl restart omniroute.service
```

Verify the settings without exposing the hash:

```bash
sqlite3 /root/.omniroute/storage.sqlite   "select namespace,key,case when key='password' then '[REDACTED]' else value end from key_value where namespace='settings' order by key;"
```

Expected key rows:

```text
settings|password|[REDACTED]
settings|requireLogin|true
settings|setupComplete|true
```

## Health / verification

From inside LXC:

```bash
systemctl status omniroute.service --no-pager
ss -ltnp | grep 20128
curl -s http://127.0.0.1:20128/v1/models | jq .
```

From another machine/LXC, include the API key generated in the dashboard:

```bash
curl -s http://192.168.1.109:20128/v1/models \
  -H 'Authorization: Bearer ${OMNIROUTE_API_KEY}' | jq .
```

## Hermes and Hindsight integration

Hermes system config should use OmniRoute as the OpenAI-compatible provider:

```text
base_url: http://192.168.1.109:20128/v1
model: codex/gpt-5.5-medium
```

Hindsight env should point its LLM provider to the same API:

```env
HINDSIGHT_API_LLM_PROVIDER=openai
HINDSIGHT_API_LLM_BASE_URL=http://192.168.1.109:20128/v1
HINDSIGHT_API_LLM_MODEL=gemini/gemini-3-flash-preview
HINDSIGHT_API_LLM_API_KEY=replace-with-omniroute-or-provider-api-key
```

## Backup / restore

Back up the whole data directory, not only the DB:

```bash
systemctl stop omniroute.service
tar -C /root -czf /root/omniroute-backup-$(date +%F).tgz .omniroute
systemctl start omniroute.service
```

Restore:

```bash
systemctl stop omniroute.service
rm -rf /root/.omniroute
tar -C /root -xzf /path/to/omniroute-backup.tgz
systemctl start omniroute.service
```

## Troubleshooting

### Service active but dashboard not reachable

```bash
systemctl status omniroute.service --no-pager
journalctl -u omniroute.service -n 100 --no-pager
ss -ltnp | grep 20128
```

### Provider returns errors or circuit breaker opens

Check provider connection health in the dashboard. The gateway may be healthy while an upstream provider is unavailable, expired, rate-limited, or logged out.

### Do not expose dashboard publicly without auth/proxy controls

Dashboard and API share the same live port in single-port mode. If exposing through Caddy/Cloudflare, protect it with strong auth and avoid committing API keys.
