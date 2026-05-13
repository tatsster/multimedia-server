# Fresh Homelab Rebuild Runbook

This is the main entry point for rebuilding the homelab. If you are starting from a fresh Proxmox install, begin here and follow the sections in order.

This repo is the source of truth to rebuild the homelab as close as possible to the current setup.

Goal: after a fresh Proxmox install, follow this checklist and recreate the same LXCs, storage, proxy, media stack, and local AI services without hunting through old chats/configs.

Related navigation:

- [README.md](./README.md) — short documentation index.
- [ARCHITECTURE.md](./ARCHITECTURE.md) — high-level service map and source-of-truth table.

## Repo location

Persistent local working copy:

```bash
/root/repos/multimedia-server
```

Remote:

```bash
https://github.com/tatsster/multimedia-server
```

## Rebuild order

### 1. Proxmox base

Read first:

- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [Homelab-Setup.md](./Homelab-Setup.md)
- [inventory/lxc-map.md](./inventory/lxc-map.md)

Base rules to keep from the current setup:

- ZFS boot/root as documented in `Homelab-Setup.md`.
- Separate HDD/general data pool and SSD VM/container storage pool.
- Keep LXC defaults for service containers:
  - `features: nesting=1`
  - `unprivileged: 0` / `Unprivileged container=No`
  - CPU advanced setting: cores unlimited, CPU limit as needed.
- Mount shared storage into CTs through `/etc/pve/lxc/<ct_id>.conf` when required.

### 2. Create LXCs

Use `inventory/lxc-map.md` as the living map for CT IDs, IPs, mounts, purpose, and creation method.

Script docs:

- [scripts/pve/README.md](./scripts/pve/README.md)

Some LXCs are intentionally created by [Community Scripts](https://community-scripts.org/) because upstream already maintains quick installers. Other homelab-specific LXCs have repo scripts that run from the Proxmox VE shell.

Minimum LXCs currently planned/documented:

| LXC | Creation method | Purpose | Doc/script |
| --- | --- | --- | --- |
| media-arr | Manual repo script | arr stack, qBittorrent, Jellyfin-related services | [server-arr/Multimedia-Setup.md](./server-arr/Multimedia-Setup.md), [scripts/pve/create-media-arr-lxc.sh](./scripts/pve/create-media-arr-lxc.sh) |
| proxy | Community Scripts Caddy LXC + manual post-install | Caddy + Cloudflare Tunnel + Cloudflare MCP in one dedicated LXC | [proxy/Access-Setup.md](./proxy/Access-Setup.md) |
| hermes | Manual repo script | Hermes agent/gateway | [hermes/README.md](./hermes/README.md), [scripts/pve/create-hermes-lxc.sh](./scripts/pve/create-hermes-lxc.sh) |
| omniroute | Manual repo script | Local OpenAI-compatible provider/router | [omniroute/README.md](./omniroute/README.md), [scripts/pve/create-omniroute-lxc.sh](./scripts/pve/create-omniroute-lxc.sh) |
| hindsight | Manual repo script | Hermes long-term memory provider | [hindsight/README.md](./hindsight/README.md), [scripts/pve/create-hindsight-lxc.sh](./scripts/pve/create-hindsight-lxc.sh) |

Example manual script usage from PVE shell:

```bash
cd /root/repos/multimedia-server
CTID=120 HOSTNAME=hermes IP_CIDR=192.168.1.120/24 ./scripts/pve/create-hermes-lxc.sh
```

### 3. Restore/create secrets

Never commit real secrets. Start from:

- [.env.example](./.env.example)
- service-specific README files

Secrets to recreate from dashboards/apps:

- Cloudflare Tunnel token: Cloudflare Zero Trust -> Networks -> Tunnels.
- Cloudflare API token for DNS challenge/DDNS: Cloudflare profile -> API Tokens.
- OmniRoute API key: OmniRoute UI after login/onboarding.
- Proxmox API token: Proxmox UI -> Datacenter -> Permissions -> API Tokens.
- Proxmox Backup Server token: PBS UI -> Access Control -> API Tokens.
- Jellyfin API key: Jellyfin dashboard -> API Keys.
- Discord allowed user ID: Discord developer/user profile copy ID.
- qBittorrent password / QBWrapper token: local app configuration.

### 4. Proxy first, then apps

Bring up proxy networking early so public/private access patterns are known:

- [proxy/Access-Setup.md](./proxy/Access-Setup.md)
- [proxy/config/Caddyfile.example](./proxy/config/Caddyfile.example)

Recommended:

- Use Cloudflare Tunnel for services that do not need direct inbound ports.
- Use Caddy with Cloudflare DNS challenge for services where direct reverse proxy is wanted.
- Keep Cloudflare Access in front of sensitive public services.

### 5. Media/arr stack

Read:

- [server-arr/Multimedia-Setup.md](./server-arr/Multimedia-Setup.md)
- [server-arr/arr-live-settings.md](./server-arr/arr-live-settings.md)
- [server-arr/arr-stack.yml](./server-arr/arr-stack.yml)
- [server-arr/.env.example](./server-arr/.env.example)
- [glance/Readme.md](./glance/Readme.md)
- [glance/.env.example](./glance/.env.example)

The current live UI/settings inventory has been captured for qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr, Tdarr, Lingarr, FlareSolverr, QBWrapper, Jellyfin, Jellyseerr, and Glance. Recreate secrets from the app UIs as documented instead of committing real keys/passwords.

### 6. AI services

Read in this order:

1. [ai/integration.md](./ai/integration.md)
2. [omniroute/README.md](./omniroute/README.md)
3. [hindsight/README.md](./hindsight/README.md)
4. [hermes/README.md](./hermes/README.md)

Current relationship:

```text
Hermes -> OmniRoute OpenAI-compatible API -> model provider
Hermes -> Hindsight memory provider
```

Current Hermes root user-level config example:

```text
hermes/config/config.system.example.yaml
```

Known troubleshooting to preserve:

- Hermes duplicate gateway conflict: keep root user-level gateway active and system-level gateway disabled/inactive.
- OmniRoute onboarding/login issue: use `INITIAL_PASSWORD` or manually update `key_value` rows in SQLite as documented.

### 7. Backup, restore, and secret inventory

Before rebuilding or reinstalling a service LXC, capture the config/data that cannot be recreated from this repo alone.

Secret policy:

- Never commit real `.env` files, API keys, passwords, provider tokens, tunnel credentials, OAuth secrets, or private connection strings.
- Keep live values in the service LXC, password manager, provider dashboard, or encrypted/offline backup only.
- Use the root [.env.example](./.env.example) and service-specific `.env.example` files as placeholders/checklists, not as live config.
- If a backup copy is unpacked into the repo for inspection, remove or redact it before committing.

Minimum backup map:

| Area | Back up / preserve | Restore target | Secret handling |
| --- | --- | --- | --- |
| Proxmox LXC configs | `/etc/pve/lxc/<CTID>.conf` for all documented CTs | Proxmox host `/etc/pve/lxc/` or recreate via UI/scripts | Review for private comments; preserve `nesting=1`, privileged status, mounts, GPU/USB mappings |
| Proxmox storage | pool/dataset layout and PBS datastore location | Recreate from [Homelab-Setup.md](./Homelab-Setup.md) | No secrets expected in docs |
| Media Docker configs | `/docker/server-arr` and other app config dirs under `/docker/*` | CT 101 `/docker/*` | App DBs may contain API keys; store backups privately |
| Media library | `/media` mount backed by `/data/media` | CT 101/102 `/media` | Do not duplicate into container rootfs |
| qBittorrent/VPN | qBittorrent config plus local VPN config/env if used | CT 101 app config path | Keep VPN username/password/private keys private; bind qBittorrent to VPN interface after restore |
| Glance | `/docker/glance` including dashboard config and local `.env` | CT 101 `/docker/glance` | Widget tokens/API keys are private; examples only in Git |
| Proxy/Caddy | `/etc/caddy`, Caddy systemd override/env, `/root/.config/caddy` if needed | CT 201 | Cloudflare tokens/tunnel credentials stay private |
| Cloudflare Tunnel | `cloudflared.service` token install details or `/etc/cloudflared` if config-file mode is used | CT 201 | Prefer recreating connector token from Cloudflare dashboard if unsure |
| OmniRoute | `/root/.omniroute` and `/root/.omniroute/omniroute.env` | CT 107 `/root/.omniroute` | Contains local DB/provider credentials/API key material; stop service before tar backup |
| Hindsight | `/root/.hindsight-docker` and `/root/.hindsight.env` | CT 109 | Contains memory DB/provider key settings; stop container before tar backup |
| Hermes | `/root/.hermes` | CT 108 | Contains agent config, platform tokens, Hindsight client config; protect or regenerate secrets |
| Jellyfin/Jellyseerr | app data from their LXCs and recreated API keys | CT 102/103 | Recreate API keys if restoring from scratch |
| Proxmox/PBS/Discord/provider accounts | token names/scopes and where they were generated | provider dashboards/UIs | Do not store actual token values in Git |

Suggested private backup commands, run from the relevant host/LXC and store archives outside the repo:

```bash
# PVE host: LXC configs only, no container rootfs data.
tar -czf /root/lxc-configs-$(date +%Y%m%d).tgz /etc/pve/lxc

# CT 101: media app config, with services stopped if doing a consistent DB backup.
tar -czf /root/server-arr-config-$(date +%Y%m%d).tgz /docker/server-arr /docker/glance

# CT 107: OmniRoute, stop service first for a consistent SQLite/data backup.
systemctl stop omniroute.service
tar -czf /root/omniroute-data-$(date +%Y%m%d).tgz /root/.omniroute
systemctl start omniroute.service

# CT 109: Hindsight, stop Docker container first for a consistent DB backup.
docker stop hindsight || true
tar -czf /root/hindsight-data-$(date +%Y%m%d).tgz /root/.hindsight-docker /root/.hindsight.env
docker start hindsight || true
```

Secret/account recreation checklist:

- [ ] Cloudflare Tunnel connector token: Cloudflare Zero Trust -> Networks -> Tunnels.
- [ ] Cloudflare DNS/API token: scoped to the required zone with DNS edit/read permissions.
- [ ] OmniRoute admin password and separate API keys for Hermes and Hindsight.
- [ ] Upstream model provider credentials configured in OmniRoute UI only.
- [ ] Hindsight LLM API key/base URL/model in `/root/.hindsight.env`.
- [ ] Hermes OmniRoute key, Hindsight config, Discord token/channel/user IDs, and optional image provider key.
- [ ] Proxmox VE token for Hermes/Glance with minimum necessary scope.
- [ ] PBS token for Glance with read-only/audit scope where possible.
- [ ] Jellyfin and Jellyseerr API keys recreated from their UIs.
- [ ] qBittorrent WebUI password and QBWrapper/Glance shared `AUTH_TOKEN`.
- [ ] VPN credentials/interface name for qBittorrent, kept private and verified after restore.

### 8. Verification checklist

Use the dedicated checklist:

- [VERIFY.md](./VERIFY.md)
- Optional service helper: [scripts/smoke-test.sh](./scripts/smoke-test.sh)
- Optional env placeholder helper: [scripts/check-env.sh](./scripts/check-env.sh)

Minimum final sign-off after rebuild:

- [ ] Proxmox pools and datasets exist.
- [ ] LXC inventory matches `inventory/lxc-map.md`.
- [ ] Required LXCs have `nesting=1` and `unprivileged: 0`.
- [ ] Shared mounts are visible inside CTs.
- [ ] Backup/restore inventory above is reviewed and private archives are stored outside the repo.
- [ ] Proxy, media, Jellyfin/Jellyseerr, OmniRoute, Hindsight, and Hermes pass `VERIFY.md`.
- [ ] Hermes gateway starts exactly once as the root user-level service; system-level gateway is disabled/inactive.
- [ ] No real secrets are committed.

## Current open documentation gaps

Use the Hermes Kanban feature for task tracking. Keep this repo focused on source-of-truth docs, not an in-repo Kanban board. Current documentation gap categories:

- Proxmox base install and storage documentation.
- Canonical LXC inventory, network map, ports, mounts, and cross-links.
- Hermes setup guide and duplicate gateway troubleshooting.
- AI service documentation for Hermes, OmniRoute, and Hindsight.
- Media/arr, proxy, and Glance guide consistency.
- Backup, restore, and secret inventory documentation.
