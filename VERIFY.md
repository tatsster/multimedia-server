# Post-Rebuild Verification Checklist

Use this after a fresh Proxmox rebuild or after restoring services from backup. The goal is a fast pass/fail smoke test that proves the new homelab matches the documented current setup.

Run checks from the place noted for each section:

- **PVE host**: Proxmox shell, where `pct`, `pvesm`, and `zfs` are available.
- **Inside LXC**: `pct enter <CTID>` or `pct exec <CTID> -- <command>` from the PVE host.
- **Admin browser**: your workstation browser.

Do not paste real API keys/tokens into this file. If a check needs a secret, create it from the service UI or provider dashboard as documented in each service README.

## 0. Expected live map

Canonical target map is maintained in [`inventory/lxc-map.md`](./inventory/lxc-map.md).

Current important service targets:

| Service | CTID | Hostname | Internal URL / port | Main guide |
|---|---:|---|---|---|
| media/arr stack | 101 | `multimedia` | `http://192.168.1.103` plus app ports | [`server-arr/arr-live-settings.md`](./server-arr/arr-live-settings.md) |
| Jellyfin | 102 | `jellyfin` | `http://192.168.1.104:8096` | [`server-arr/arr-live-settings.md`](./server-arr/arr-live-settings.md) |
| Jellyseerr | 103 | `jellyseerr` | `http://192.168.1.105:5055` | [`server-arr/arr-live-settings.md`](./server-arr/arr-live-settings.md) |
| OmniRoute | 107 | `omniroute` | `http://192.168.1.109:20128` / `/v1` | [`omniroute/README.md`](./omniroute/README.md) |
| Hermes | 108 | `hermes` | gateway/service as configured | [`hermes/README.md`](./hermes/README.md) |
| Hindsight | 109 | `hindsight` | `http://192.168.1.111:8888`, UI `:9999` | [`hindsight/README.md`](./hindsight/README.md) |
| proxy | 201 | `proxy` | `80`, `443`, Caddy admin `2019` | [`proxy/Access-Setup.md`](./proxy/Access-Setup.md) |

If you intentionally choose new CTIDs/IPs during rebuild, update `inventory/lxc-map.md` first, then run this checklist against the new map.

## 1. Proxmox host/storage checks

Run from the **PVE host**.

```bash
hostnamectl
pveversion
pvesm status
zpool status
zfs list
```

Pass criteria:

- [ ] Proxmox node boots cleanly.
- [ ] Expected storages exist, especially `vm_storage` for container rootfs.
- [ ] Expected datasets/pools from `Homelab-Setup.md` exist.
- [ ] No degraded ZFS pool unless intentionally accepted.
- [ ] Template exists for manual scripts:

```bash
pveam list general | grep -E 'debian-13-standard_13\.1-2_amd64|debian-13'
```

## 2. LXC inventory/defaults checks

Run from the **PVE host**.

```bash
pct list
for id in 101 102 103 107 108 109 201; do
  echo "===== CT $id ====="
  pct config "$id" | grep -E '^(hostname|ostype|memory|swap|cores|cpulimit|features|unprivileged|net0|rootfs|mp[0-9]+|onboot):'
done
```

Pass criteria:

- [ ] CTIDs/hostnames/IPs match `inventory/lxc-map.md`, or the map was intentionally updated.
- [ ] Service LXCs preserve current default: `features: nesting=1`.
- [ ] Service LXCs preserve current default: `unprivileged: 0` / privileged container.
- [ ] Mounts match the documented mount map.
- [ ] Media/Jellyfin/Tdarr containers that need GPU have `/dev/dri/card0` and `/dev/dri/renderD128` mappings.
- [ ] Containers that should start at boot have `onboot: 1`.

Optional audit helper:

```bash
cd /root/repos/multimedia-server
./scripts/pve/audit-lxcs.sh
less inventory/live-lxc-audit.md
```

Do not commit `inventory/live-lxc-audit.md`; copy only reviewed, non-secret values into docs.

## 3. Proxy LXC checks: Caddy + Cloudflare Tunnel + Cloudflare MCP

Run from the **PVE host** or inside **CT 201**.

```bash
pct exec 201 -- systemctl status caddy --no-pager
pct exec 201 -- caddy validate --config /etc/caddy/Caddyfile
pct exec 201 -- systemctl status cloudflared --no-pager
pct exec 201 -- cloudflared tunnel info
pct exec 201 -- test -x /usr/local/bin/cloudflare-mcp && echo cloudflare-mcp-wrapper-ok
```

Pass criteria:

- [ ] Caddy service is active.
- [ ] `caddy validate` succeeds.
- [ ] Cloudflare Tunnel service is active.
- [ ] Cloudflare dashboard shows tunnel connected/healthy.
- [ ] Public hostnames route to the correct internal apps.
- [ ] Sensitive services have Cloudflare Access policy applied where intended.
- [ ] Cloudflare MCP wrapper exists and uses environment variables/placeholders, not hardcoded secrets.

Browser checks:

- [ ] Main public app domains open over HTTPS.
- [ ] Cloudflare Access prompts on protected services.
- [ ] No origin certificate/private key/API token appears in repo files.

## 4. Media/arr stack checks

Run from the **PVE host** or inside **CT 101**.

```bash
pct exec 101 -- docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
pct exec 101 -- test -d /docker && echo docker-mount-ok
pct exec 101 -- test -d /media && echo media-mount-ok
pct exec 101 -- test -e /dev/dri/renderD128 && echo gpu-render-ok
```

If compose plugin is available and stack path matches the docs:

```bash
pct exec 101 -- bash -lc 'cd /docker/server-arr 2>/dev/null || cd /root/repos/multimedia-server/server-arr; docker compose --env-file .env -f arr-stack.yml ps'
```

Expected core app checks:

| App | URL | Pass criteria |
|---|---|---|
| qBittorrent | `http://192.168.1.103:8080` | Login works, categories exist, paths point under `/media` |
| Prowlarr | `http://192.168.1.103:9696` | Indexers test successfully, FlareSolverr proxy works if needed |
| Sonarr | `http://192.168.1.103:8989` | Root folder `/media/tv`, qBittorrent download client test succeeds |
| Radarr | `http://192.168.1.103:7878` | Root folder `/media/movies`, qBittorrent download client test succeeds |
| Bazarr | `http://192.168.1.103:6767` | Provider tests succeed; Sonarr/Radarr integrations connect |
| Tdarr | `http://192.168.1.103:8265` | Server/node online; library paths point to mounted media |
| FlareSolverr | `http://192.168.1.103:8191` | Health endpoint/UI responds |
| QBWrapper/qbproxy | `http://192.168.1.103:9911` | Glance/widget auth works with recreated token |
| Lingarr | `http://192.168.1.103:9876` | UI opens; configured paths/providers are recreated |
| Portainer | `https://192.168.1.103:9443` | UI opens if still used |
| Glance | `http://192.168.1.103:8081` | Dashboard widgets render without secret errors |

Functional media flow:

- [ ] Prowlarr can search at least one enabled indexer.
- [ ] Sonarr test search works.
- [ ] Radarr test search works.
- [ ] qBittorrent can download a harmless/test torrent or controlled private tracker item.
- [ ] Sonarr/Radarr import completed download from the correct category.
- [ ] Completed files land under documented `/media` paths.
- [ ] No app writes downloads into container rootfs by mistake.

## 5. Jellyfin and Jellyseerr checks

Run from browser and/or PVE host.

```bash
pct exec 102 -- systemctl status jellyfin --no-pager
pct exec 102 -- test -d /media && echo jellyfin-media-mount-ok
pct exec 102 -- test -e /dev/dri/renderD128 && echo jellyfin-gpu-render-ok
pct exec 103 -- systemctl status seerr --no-pager || pct exec 103 -- systemctl status jellyseerr --no-pager
```

Pass criteria:

- [ ] Jellyfin opens at `http://192.168.1.104:8096` or proxied domain.
- [ ] Jellyfin libraries point to `/media` and scan successfully.
- [ ] Hardware acceleration/GPU transcoding works if enabled.
- [ ] Jellyseerr opens at `http://192.168.1.105:5055` or proxied domain.
- [ ] Jellyseerr connects to Jellyfin.
- [ ] Jellyseerr connects to Sonarr/Radarr with recreated API keys.
- [ ] Default request paths/profiles match `server-arr/arr-live-settings.md`.

## 6. OmniRoute checks

Run from PVE host, CT 107, or any LAN machine.

```bash
pct exec 107 -- systemctl status omniroute.service --no-pager
pct exec 107 -- ss -ltnp | grep 20128
curl -fsS http://192.168.1.109:20128/ | head
```

After creating an OmniRoute API key from the UI, test the OpenAI-compatible API without committing the key:

```bash
OMNIROUTE_API_KEY='paste-temporary-key-here'
curl -fsS http://192.168.1.109:20128/v1/models \
  -H "Authorization: Bearer ${OMNIROUTE_API_KEY}" | jq .
unset OMNIROUTE_API_KEY
```

Pass criteria:

- [ ] OmniRoute service is active.
- [ ] Dashboard login works.
- [ ] `setupComplete=true` and `requireLogin=true` after onboarding.
- [ ] `/v1/models` returns configured models with a valid API key.
- [ ] Test chat completion works for the selected provider/model.
- [ ] If onboarding breaks, `omniroute/README.md` SQLite workaround works against `/root/.omniroute/storage.sqlite`.
- [ ] Provider credentials are only in OmniRoute UI/DB or local env; not in Git.

## 7. Hindsight checks

Run from PVE host or CT 109.

```bash
pct exec 109 -- docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
curl -fsS http://192.168.1.111:8888/health
curl -fsS http://192.168.1.111:9999/ | head
```

Pass criteria:

- [ ] Hindsight container is running.
- [ ] API health returns healthy/database connected.
- [ ] Control plane/UI port responds.
- [ ] Persistent data directory exists at `/root/.hindsight-docker` inside CT 109.
- [ ] Hindsight provider config points to reachable OmniRoute/model settings.
- [ ] If logs show `provider_circuit_open`, verify OmniRoute/upstream provider rather than assuming Hindsight storage is broken.

## 8. Hermes checks

Run inside **CT 108** or from PVE host.

```bash
pct exec 108 -- which hermes
pct exec 108 -- hermes --version || true
pct exec 108 -- systemctl status hermes-gateway.service --no-pager || true
pct exec 108 -- test -f /root/.hermes/config.yaml && echo hermes-config-exists
pct exec 108 -- test -f /root/.hermes/hindsight/config.json && echo hindsight-client-config-exists
```

Pass criteria:

- [ ] Hermes CLI runs.
- [ ] System-level config exists and is based on `hermes/config/config.system.example.yaml` with real secrets supplied locally only.
- [ ] `model.base_url` points to OmniRoute, normally `http://192.168.1.109:20128/v1`.
- [ ] Model name matches current intended provider/model.
- [ ] Hindsight client config points to `http://192.168.1.111:8888` with the intended bank.
- [ ] Gateway starts exactly once.
- [ ] Duplicate gateway conflict is fixed by disabling either user-level or system-level gateway, not both running.
- [ ] `hermes config set` can change model/provider settings when needed.
- [ ] A simple Hermes prompt returns a model answer through OmniRoute.
- [ ] A memory save/recall operation works through Hindsight.

## 9. End-to-end AI flow

Run after OmniRoute, Hindsight, and Hermes are all healthy.

Pass criteria:

- [ ] Hermes prompt returns text.
- [ ] OmniRoute call logs show the request.
- [ ] Hindsight health stays healthy.
- [ ] Hindsight memory operation succeeds.
- [ ] No provider `401`, `403`, `429`, or circuit-breaker errors remain after selecting a healthy model/provider.

Suggested manual flow:

1. In OmniRoute, confirm the current model/provider is available.
2. In Hermes, ask a simple question.
3. In OmniRoute dashboard/call logs, confirm the request routed through OmniRoute.
4. In Hermes, save a small test memory.
5. Recall that memory.
6. Delete the test memory if it was only a smoke-test artifact.

## 10. Backup/restore and secret inventory checks

Use this section with the backup map in [`Fresh-Homelab-Rebuild.md`](./Fresh-Homelab-Rebuild.md#7-backup-restore-and-secret-inventory). The goal is to prove that irreplaceable config/data is either backed up privately or can be recreated from provider dashboards without placing real secrets in Git.

### Proxmox and storage

- [ ] Proxmox LXC config backups exist for important CTs, especially `101`, `102`, `103`, `107`, `108`, `109`, `201`, and `250` if used.
- [ ] LXC config backups preserve `features: nesting=1`, `unprivileged: 0`, static `net0`, bind mounts, GPU passthrough, and USB/serial mappings where needed.
- [ ] Storage pool/dataset layout from `Homelab-Setup.md` is documented or backed up outside this repo.
- [ ] `/main/backup` / PBS datastore path is preserved if PBS is in scope.

### Service data/config

- [ ] CT 101 `/docker/server-arr` app configs are backed up privately.
- [ ] CT 101 `/docker/glance` dashboard config and local `.env` are backed up privately.
- [ ] `/media` is mounted/preserved and not duplicated into container rootfs.
- [ ] qBittorrent config is backed up, and VPN credentials/interface settings are kept private.
- [ ] qBittorrent is re-verified after restore so torrent traffic only operates over the intended VPN connection/interface.
- [ ] CT 201 `/etc/caddy`, Caddy systemd env override, Cloudflare tunnel service/config, and any Cloudflare MCP wrapper/env are backed up privately.
- [ ] CT 107 `/root/.omniroute` and `/root/.omniroute/omniroute.env` can be tarred/restored with OmniRoute stopped.
- [ ] CT 109 `/root/.hindsight-docker` and `/root/.hindsight.env` can be tarred/restored with Hindsight stopped.
- [ ] CT 108 `/root/.hermes` can be backed up/restored after protecting or regenerating secrets.

### Secret/account recreation

- [ ] Root `.env.example` and service `.env.example` files cover required placeholders without real values.
- [ ] Cloudflare Tunnel connector token recreation source is documented.
- [ ] Cloudflare DNS/API token scope is documented as zone-limited DNS edit/read where possible.
- [ ] OmniRoute admin password/API key recreation source is documented.
- [ ] Separate OmniRoute API keys are created for Hermes and Hindsight where practical.
- [ ] Upstream model provider keys live only in OmniRoute/provider config, not in Git.
- [ ] Hindsight LLM API key/base URL/model are set only in `/root/.hindsight.env` or equivalent private config.
- [ ] Hermes Discord token/channel/user IDs, Proxmox token, OmniRoute key, and optional image provider key are private.
- [ ] Glance Proxmox/PBS/Jellyfin/QBWrapper widget keys are private and scoped read-only/audit where possible.
- [ ] Jellyfin/Jellyseerr/Arr API keys are recreated from app UIs or restored from private app backups.
- [ ] `git status` and `./scripts/check-env.sh` show no committed live `.env` files or obvious secret leaks.

## 11. Optional automated smoke-test helper

A lightweight helper exists at:

```text
scripts/smoke-test.sh
```

It performs non-destructive HTTP checks against common internal endpoints and prints pass/fail status. It does not use secrets by default. For OmniRoute authenticated `/v1/models`, export a temporary key only in your shell:

```bash
OMNIROUTE_API_KEY='temporary-key' ./scripts/smoke-test.sh
unset OMNIROUTE_API_KEY
```

## 12. Final sign-off

Only mark rebuild complete when:

- [ ] All critical checkboxes above are green or documented as intentionally skipped.
- [ ] `inventory/lxc-map.md` matches the live rebuilt system.
- [ ] Service-specific docs match the actual rebuilt paths/settings.
- [ ] No real secrets are committed.
- [ ] `git status` is clean after committing doc/config updates.
