# AI Services Integration

This guide shows how the AI-related LXCs work together after a fresh rebuild.

Services:

- **Hermes**: CLI/Discord/API agent runtime and tool gateway.
- **OmniRoute**: local OpenAI-compatible model router/provider gateway.
- **Hindsight**: long-term memory backend used by Hermes.

## Target architecture

```text
User / Discord / CLI
        |
        v
+------------------+
| Hermes LXC 108   |
| 192.168.1.110    |
| - agent runtime  |
| - system gateway |
| - config.yaml    |
+----+---------+---+
     |         |
     |         | memory retain/recall/search
     |         v
     |   +------------------+
     |   | Hindsight LXC109 |
     |   | 192.168.1.111    |
     |   | - API :8888      |
     |   | - CP  :9999      |
     |   | - persistent DB  |
     |   +---------+--------+
     |             |
     |             | optional LLM extraction/summarization
     |             v
     | model requests / OpenAI-compatible API
     v
+------------------+
| OmniRoute LXC107 |
| 192.168.1.109    |
| - API/UI :20128  |
| - providers      |
| - API keys       |
| - SQLite config  |
+------------------+
```

Normal request flow:

1. User talks to Hermes through CLI or Discord.
2. Hermes sends model requests to OmniRoute at `http://192.168.1.109:20128/v1`.
3. OmniRoute selects the configured provider/model and returns the response.
4. Hermes sends memory retain/recall/search requests to Hindsight at `http://192.168.1.111:8888`.
5. Hindsight persists memory in `/root/.hindsight-docker` and may call OmniRoute for its own LLM extraction work.

## Canonical LXC requirements

Use the same LXC defaults documented in [`inventory/lxc-map.md`](../inventory/lxc-map.md):

```text
features: nesting=1
unprivileged: 0
```

Reason:

- This preserves the current homelab behavior.
- It avoids surprises with nested services, Docker, package installs, and bind mounts.
- Community Scripts LXCs may default differently, so always verify after creation.

Check from the Proxmox VE host:

```bash
pct config <ctid> | grep -E '^(features|unprivileged|cores|cpulimit|memory|net0)'
```

## Ports and URLs

Canonical network targets come from [`inventory/lxc-map.md`](../inventory/lxc-map.md).

| Service | Internal URL | Public exposure | Notes |
|---|---|---|---|
| Hermes | `192.168.1.110` / system gateway | Usually private only | CLI/Discord/API agent host; gateway ports depend on enabled platforms. |
| OmniRoute dashboard | `http://192.168.1.109:20128` | Private or Cloudflare Access only | Admin UI and onboarding. |
| OmniRoute API | `http://192.168.1.109:20128/v1` | Private only | Hermes and Hindsight OpenAI-compatible `base_url`. |
| Hindsight API | `http://192.168.1.111:8888` | Private only | Hermes memory provider endpoint. Health: `/health`. |
| Hindsight control plane | `http://192.168.1.111:9999/dashboard` | Private only / Cloudflare Access if exposed | Optional UI. |

Current known Hermes routes:

```text
Hermes model.default = codex/gpt-5.5-medium
Hermes model.provider = custom
Hermes model.base_url = http://192.168.1.109:20128/v1
Hermes memory.provider = hindsight
Hermes Hindsight API URL = http://192.168.1.111:8888
```

## Startup order

Use this order on a fresh rebuild:

1. **OmniRoute**
   - It provides the model endpoint used by Hermes.
   - Complete onboarding or set `INITIAL_PASSWORD`.
   - Add provider/account credentials.
   - Create a Hermes-specific API key.
2. **Hindsight**
   - It provides memory persistence for Hermes.
   - Confirm its data directory is on persistent storage and backed up.
3. **Hermes**
   - Copy sanitized config example.
   - Replace OmniRoute URL/API key placeholders.
   - Confirm memory provider is `hindsight`.
   - Start/restart Hermes gateway once.

## Hermes config links

Primary example:

```text
hermes/config/config.system.example.yaml
```

Important fields:

```yaml
model:
  default: codex/gpt-5.5-medium
  provider: custom
  base_url: ${OMNIROUTE_BASE_URL}
  api_key: ${OMNIROUTE_API_KEY}
  max_tokens: 65536
memory:
  provider: hindsight
```

Set/update values on the live Hermes LXC:

```bash
hermes config set model.base_url "http://<omniroute-lxc-ip>:20128/v1"
# Prefer env-backed config for secrets. If setting directly, paste only on the live LXC and never into Git.
hermes config set model.api_key '${OMNIROUTE_API_KEY}'
hermes config set model.default "codex/gpt-5.5-medium"
hermes config set memory.provider "hindsight"
hermes gateway restart --system
```

Do not commit the real API key. Store it in a private password manager or private env/config only. Use `hermes config set` to change model/provider values so the live change is explicit and repeatable.

## OmniRoute integration checklist

On OmniRoute LXC:

```bash
curl http://127.0.0.1:20128
```

From Hermes LXC:

```bash
curl http://<omniroute-lxc-ip>:20128/v1/models \
  -H 'Authorization: Bearer <omniroute-api-key>'
```

Expected:

- HTTP response is reachable from Hermes LXC.
- Authentication succeeds with the Hermes-specific OmniRoute API key.
- The model list includes the configured/default provider models, including the model Hermes will use.

If onboarding/login is broken, use the documented OmniRoute guide:

```text
omniroute/README.md
```

Known SQLite settings keys:

```text
namespace=settings, key=password
namespace=settings, key=setupComplete
namespace=settings, key=requireLogin
```

Prefer `INITIAL_PASSWORD` before manual SQLite editing.

## Hindsight integration checklist

On Hindsight LXC:

```bash
docker ps --filter name=hindsight
curl -fsS http://127.0.0.1:8888/health
curl -I http://127.0.0.1:9999/dashboard
```

Current live Hindsight uses Docker container `hindsight` from image `ghcr.io/vectorize-io/hindsight:latest`; persistent data is bind-mounted from `/root/.hindsight-docker` to `/home/hindsight/.pg0`.

From Hermes LXC:

```bash
hermes config get memory
```

Expected:

```text
provider: hindsight
```

Functional test from Hermes after the exact Hindsight endpoint/tooling is confirmed:

1. Store a harmless test memory.
2. Recall/search that memory.
3. Restart Hindsight.
4. Recall/search again.
5. Confirm persistence survives restart.

## End-to-end verification

After all three services are running:

```bash
hermes config check
hermes config get model
hermes config get memory
hermes gateway restart --system
hermes gateway status --system
```

Then run a simple Hermes prompt from CLI or Discord:

```text
Say which model/provider you are using and store a temporary test memory named homelab-rebuild-test.
```

Verify:

- Hermes answers without provider errors.
- OmniRoute shows request activity/logs if available.
- Hindsight retains and recalls the test memory.
- Only one Hermes gateway/service is active.

## Troubleshooting map

| Symptom | Likely cause | First checks | Fix |
|---|---|---|---|
| Hermes says provider/API error | Wrong OmniRoute base URL or API key | `hermes config get model`; `curl /v1/models` from Hermes LXC | Update `model.base_url` and `model.api_key`; restart Hermes gateway |
| Hermes uses wrong model/router | Duplicate user-level and system-level gateway/config | Inspect `/root/.hermes/config.yaml`; `hermes gateway status --system`; user/system units | Keep only the system gateway active; remove/disable user unit |
| OmniRoute login/onboarding stuck | Onboarding state/password missing or corrupted | `omniroute/README.md`; SQLite `key_value` settings | Use `INITIAL_PASSWORD`; fallback to SQLite update |
| Memory not retained | Hindsight unreachable or Hermes memory provider not set | `hermes config get memory`; service status | Start Hindsight; set `memory.provider=hindsight`; verify persistence |
| Works after boot but fails after restart | Service startup order or missing env file | `systemctl status`; journal logs | Add service dependencies/env files; document exact live units once captured |

## Secrets and where to create them

| Secret | Created in | Used by | Stored where after rebuild |
|---|---|---|---|
| OmniRoute admin password | OmniRoute onboarding or `INITIAL_PASSWORD` | OmniRoute UI login | Password manager only |
| OmniRoute Hermes API key | OmniRoute dashboard/API keys | Hermes model API calls | Private Hermes config/env only |
| Provider API/OAuth credentials | Provider dashboard or OmniRoute provider login flow | OmniRoute | OmniRoute encrypted/local DB or private env only |
| Hindsight API auth token, if enabled later | Hindsight setup | Hermes memory calls | Private Hermes/Hindsight env only; current documented local setup does not enable one |
| Proxmox API token ID/secret | Proxmox -> Datacenter -> Permissions -> API Tokens | Hermes Proxmox tools | `/root/.hermes/.env` or password manager only |
| Discord bot token | Discord Developer Portal | Hermes Discord gateway | `/root/.hermes/.env` only |
| Discord allowlist/user/channel IDs | Discord developer mode / channel settings | Hermes Discord routing/allowlist | Config/env placeholders; no private notes |

Never commit real secrets. Commit only examples with placeholders.

## Rebuild summary

Use these service-specific guides for the exact rebuild commands and private config locations:

| Service | Guide | Critical private data/config |
|---|---|---|
| Hermes | [`../hermes/README.md`](../hermes/README.md) | `/root/.hermes`, system Hermes config, private `.env` |
| OmniRoute | [`../omniroute/README.md`](../omniroute/README.md) | `/root/.omniroute`, `/root/.omniroute/omniroute.env`, `storage.sqlite` |
| Hindsight | [`../hindsight/README.md`](../hindsight/README.md) | `/root/.hindsight-docker`, `/root/.hindsight.env` |

Minimum recovery order:

1. Restore/start OmniRoute and confirm `/v1/models` is reachable with a private API key.
2. Restore/start Hindsight and confirm `/health` reports a connected database.
3. Restore/start Hermes system gateway and confirm `model` and `memory` config point to OmniRoute/Hindsight.
4. Run one harmless end-to-end model request and one harmless retain/recall memory check.
