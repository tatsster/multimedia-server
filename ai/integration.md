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
| Hermes LXC       |
| - agent runtime  |
| - tool gateway   |
| - config.yaml    |
+--------+---------+
         | model requests
         | OpenAI-compatible API
         v
+------------------+
| OmniRoute LXC    |
| - providers      |
| - models         |
| - API keys       |
| - SQLite config  |
+------------------+

+------------------+
| Hindsight LXC    |
| - retain/recall  |
| - persistent DB  |
+---------^--------+
          |
          | memory retain/recall/search
          |
+---------+--------+
| Hermes LXC       |
+------------------+
```

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

Fill this table during rebuild from `inventory/lxc-map.md`.

| Service | Internal URL | Public exposure | Notes |
|---|---|---|---|
| Hermes | `http://<hermes-lxc-ip>:<hermes-port>` | Usually private only | CLI/gateway host. Fill exact port after live verification. |
| OmniRoute dashboard | `http://<omniroute-lxc-ip>:20128` | Private or Cloudflare Access only | Admin UI and onboarding. |
| OmniRoute API | `http://<omniroute-lxc-ip>:20128/v1` | Private only | Hermes model `base_url`. |
| Hindsight | `http://<hindsight-lxc-ip>:<hindsight-port>` | Private only | Memory provider endpoint. Fill exact port after live verification. |

Current known Hermes model route:

```text
Hermes model.default = codex/gpt-5.5-medium
Hermes model.provider = custom
Hermes model.base_url = http://<omniroute-lxc-ip>:20128/v1
Hermes memory.provider = hindsight
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
hermes config set model.api_key "<omniroute-api-key>"
hermes config set model.default "codex/gpt-5.5-medium"
hermes config set memory.provider "hindsight"
hermes gateway restart
```

Do not commit the real API key. Store it in a private password manager or private env/config only.

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
systemctl status hindsight --no-pager
# or use the actual service/container command once captured from live setup
```

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
hermes config get model
hermes config get memory
hermes gateway restart
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
| Hermes uses wrong model/router | Duplicate user-level and system-level gateway/config | Inspect `/root/.hermes/config.yaml` and service/user config | Keep only one active gateway/provider config |
| OmniRoute login/onboarding stuck | Onboarding state/password missing or corrupted | `omniroute/README.md`; SQLite `key_value` settings | Use `INITIAL_PASSWORD`; fallback to SQLite update |
| Memory not retained | Hindsight unreachable or Hermes memory provider not set | `hermes config get memory`; service status | Start Hindsight; set `memory.provider=hindsight`; verify persistence |
| Works after boot but fails after restart | Service startup order or missing env file | `systemctl status`; journal logs | Add service dependencies/env files; document exact live units once captured |

## Secrets and where to create them

| Secret | Created in | Used by | Stored where after rebuild |
|---|---|---|---|
| OmniRoute admin password | OmniRoute onboarding or `INITIAL_PASSWORD` | OmniRoute UI login | Password manager only |
| OmniRoute Hermes API key | OmniRoute dashboard/API keys | Hermes model API calls | Private Hermes config/env only |
| Provider API/OAuth credentials | Provider dashboard or OmniRoute provider login flow | OmniRoute | OmniRoute encrypted/local DB or private env only |
| Hindsight auth token, if enabled | Hindsight setup | Hermes memory calls | Private Hermes/Hindsight env only |

Never commit real secrets. Commit only examples with placeholders.

## Open items to capture from live LXCs

- Exact Hermes install command and service unit.
- Exact OmniRoute deployment method currently used: npm, Docker, or other.
- Exact Hindsight install command, port, health endpoint, service name, and data directory.
- Exact startup dependencies between Hermes gateway, OmniRoute, and Hindsight.
