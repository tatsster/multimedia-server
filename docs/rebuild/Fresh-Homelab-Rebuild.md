# Fresh Homelab Rebuild Runbook

This is the main entry point for rebuilding the homelab. If you are starting from a fresh Proxmox install, begin here and follow the sections in order.

This repo is the source of truth to rebuild the homelab as close as possible to the current setup.

Goal: after a fresh Proxmox install, follow this checklist and recreate the same LXCs, storage, proxy, media stack, and local AI services without hunting through old chats/configs.

Related navigation:

- [README.md](../../README.md) — short documentation index.
- [ARCHITECTURE.md](../architecture.md) — high-level service map and source-of-truth table.

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

- [ARCHITECTURE.md](../architecture.md)
- [Homelab-Setup.md](../../infrastructure/proxmox/Homelab-Setup.md)
- [inventory/lxc-map.md](../../inventory/lxc-map.md)

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

- [automation/pve/README.md](../../automation/pve/README.md)

Some LXCs are intentionally created by [Community Scripts](https://community-scripts.org/) because upstream already maintains quick installers. Other homelab-specific LXCs have repo scripts that run from the Proxmox VE shell.

Minimum LXCs currently planned/documented:

| LXC | Creation method | Purpose | Doc/script |
| --- | --- | --- | --- |
| media-arr | Manual repo script | arr stack, qBittorrent, Jellyfin-related services | [services/media-arr/Multimedia-Setup.md](../../services/media-arr/Multimedia-Setup.md), [automation/pve/create-media-arr-lxc.sh](../../automation/pve/create-media-arr-lxc.sh) |
| proxy | Community Scripts Caddy LXC + manual post-install | Caddy + Cloudflare Tunnel + Cloudflare MCP in one dedicated LXC | [infrastructure/proxy/Access-Setup.md](../../infrastructure/proxy/Access-Setup.md) |
| hermes | Manual repo script | Hermes agent/gateway | [agent/hermes/README.md](../../agent/hermes/README.md), [automation/pve/create-hermes-lxc.sh](../../automation/pve/create-hermes-lxc.sh) |
| omniroute | Manual repo script | Local OpenAI-compatible provider/router | [services/omniroute/README.md](../../services/omniroute/README.md), [automation/pve/create-omniroute-lxc.sh](../../automation/pve/create-omniroute-lxc.sh) |

Example manual script usage from PVE shell:

```bash
cd /root/repos/multimedia-server
CTID=120 HOSTNAME=hermes IP_CIDR=192.168.1.120/24 ../../automation/pve/create-hermes-lxc.sh
```

### 3. Restore/create secrets

Never commit real secrets. Start from:

- [.env.example](../../.env.example)
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

- [infrastructure/proxy/Access-Setup.md](../../infrastructure/proxy/Access-Setup.md)
- [infrastructure/proxy/config/Caddyfile.example](../../infrastructure/proxy/config/Caddyfile.example)

Recommended:

- Use Cloudflare Tunnel for services that do not need direct inbound ports.
- Use Caddy with Cloudflare DNS challenge for services where direct reverse proxy is wanted.
- Keep Cloudflare Access in front of sensitive public services.

### 5. Media/arr stack

Read:

- [services/media-arr/Multimedia-Setup.md](../../services/media-arr/Multimedia-Setup.md)
- [services/media-arr/arr-live-settings.md](../../services/media-arr/arr-live-settings.md)
- [services/media-arr/arr-stack.yml](../../services/media-arr/arr-stack.yml)
- [services/media-arr/.env.example](../../services/media-arr/.env.example)

The current live UI/settings inventory has been captured for qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr, Tdarr, Lingarr, FlareSolverr, QBWrapper, Jellyfin, and Jellyseerr. Recreate secrets from the app UIs as documented instead of committing real keys/passwords.

### 6. AI services

Read in this order:

1. [services/ai/integration.md](../../services/ai/integration.md)
2. [services/omniroute/README.md](../../services/omniroute/README.md)
3. [agent/hermes/README.md](../../agent/hermes/README.md)

Current relationship:

```text
Hermes -> OmniRoute OpenAI-compatible API -> model provider
```

Current Hermes root user-level config example:

```text
agent/hermes/config/config.system.example.yaml
```

Known troubleshooting to preserve:

- Hermes duplicate gateway conflict: keep root user-level gateway active and system-level gateway disabled/inactive.
- OmniRoute onboarding/login issue: use `INITIAL_PASSWORD` or manually update `key_value` rows in SQLite as documented.

### 7. Backup, restore, and secret inventory

Before rebuilding or reinstalling a service LXC, capture the config/data that cannot be recreated from this repo alone.

Secret policy:

- Never commit real `.env` files, API keys, passwords, provider tokens, tunnel credentials, OAuth secrets, or private connection strings.
- Keep live values in the service LXC, password manager, provider dashboard, or encrypted/offline backup only.
- Use the root [.env.example](../../.env.example) and service-specific `.env.example` files as placeholders/checklists, not as live config.
- If a backup copy is unpacked into the repo for inspection, remove or redact it before committing.

Minimum backup map:

| Area | Back up / preserve | Restore target | Secret handling |
| --- | --- | --- | --- |
| Proxmox LXC configs | `/etc/pve/lxc/<CTID>.conf` for all documented CTs | Proxmox host `/etc/pve/lxc/` or recreate via UI/scripts | Review for private comments; preserve `nesting=1`, privileged status, mounts, GPU/USB mappings |
| Proxmox storage | pool/dataset layout and PBS datastore location | Recreate from [Homelab-Setup.md](../../infrastructure/proxmox/Homelab-Setup.md) | No secrets expected in docs |
| Media Docker configs | `/docker/server-arr` and other app config dirs under `/docker/*` | CT 101 `/docker/*` | App DBs may contain API keys; store backups privately |
| Media library | `/media` mount backed by `/data/media` | CT 101/102 `/media` | Do not duplicate into container rootfs |
| qBittorrent/VPN | qBittorrent config plus local VPN config/env if used | CT 101 app config path | Keep VPN username/password/private keys private; bind qBittorrent to VPN interface after restore |
| Proxy/Caddy | `/etc/caddy`, Caddy systemd override/env, `/root/.config/caddy` if needed | CT 201 | Cloudflare tokens/tunnel credentials stay private |
| Cloudflare Tunnel | `cloudflared.service` token install details or `/etc/cloudflared` if config-file mode is used | CT 201 | Prefer recreating connector token from Cloudflare dashboard if unsure |
| OmniRoute | `/root/.omniroute` and `/root/.services/omniroute/omniroute.env` | CT 107 `/root/.omniroute` | Contains local DB/provider credentials/API key material; stop service before tar backup |
| Jellyfin/Jellyseerr | app data from their LXCs and recreated API keys | CT 102/103 | Recreate API keys if restoring from scratch |
| Proxmox/PBS/Discord/provider accounts | token names/scopes and where they were generated | provider dashboards/UIs | Do not store actual token values in Git |

Suggested private backup commands, run from the relevant host/LXC and store archives outside the repo:

```bash
# PVE host: LXC configs only, no container rootfs data.
tar -czf /root/lxc-configs-$(date +%Y%m%d).tgz /etc/pve/lxc

# CT 101: media app config, with services stopped if doing a consistent DB backup.
tar -czf /root/server-arr-config-$(date +%Y%m%d).tgz /docker/server-arr

# CT 107: OmniRoute, stop service first for a consistent SQLite/data backup.
systemctl stop omniroute.service
tar -czf /root/omniroute-data-$(date +%Y%m%d).tgz /root/.omniroute
systemctl start omniroute.service
```

Secret/account recreation checklist:

- [ ] Cloudflare Tunnel connector token: Cloudflare Zero Trust -> Networks -> Tunnels.
- [ ] Cloudflare DNS/API token: scoped to the required zone with DNS edit/read permissions.
- [ ] Upstream model provider credentials configured in OmniRoute UI only.
- [ ] Proxmox VE token for Hermes with minimum necessary scope.
- [ ] Jellyfin and Jellyseerr API keys recreated from their UIs.
- [ ] qBittorrent WebUI password and QBWrapper/dashboard shared `AUTH_TOKEN`, if used.
- [ ] VPN credentials/interface name for qBittorrent, kept private and verified after restore.

### 8. Verification checklist

Use the dedicated checklist:

- [VERIFY.md](../verify.md)
- Optional service helper: [automation/smoke-test.sh](../../automation/smoke-test.sh)
- Optional env placeholder helper: [automation/check-env.sh](../../automation/check-env.sh)

Minimum final sign-off after rebuild:

- [ ] Proxmox pools and datasets exist.
- [ ] LXC inventory matches `inventory/lxc-map.md`.
- [ ] Required LXCs have `nesting=1` and `unprivileged: 0`.
- [ ] Shared mounts are visible inside CTs.
- [ ] Backup/restore inventory above is reviewed and private archives are stored outside the repo.
- [ ] Hermes gateway starts exactly once as the root user-level service; system-level gateway is disabled/inactive.
- [ ] No real secrets are committed.

## Current open documentation gaps

Use the Hermes Kanban feature for task tracking. Keep this repo focused on source-of-truth docs, not an in-repo Kanban board. Current documentation gap categories:

- Proxmox base install and storage documentation.
- Canonical LXC inventory, network map, ports, mounts, and cross-links.
- Hermes setup guide and duplicate gateway troubleshooting.
- Media/arr, proxy,  guide consistency.
- Backup, restore, and secret inventory documentation.
