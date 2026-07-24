# Media / Arr Stack Rebuild Guide

This guide is the practical rebuild flow for the media services. It should stay consistent with the canonical inventory in [`../../inventory/lxc-map.md`](../../inventory/lxc-map.md).

Related files:

- Live settings snapshot: [`arr-live-settings.md`](./arr-live-settings.md)
- Rebuild compose file: [`arr-stack.yml`](./arr-stack.yml)
- Secret-safe env template: [`.env.example`](./.env.example)
- Proxy/public access guide: [`../../infrastructure/proxy/Access-Setup.md`](../../infrastructure/proxy/Access-Setup.md)

> Secret-safety note: never commit real app passwords, API keys, webhook URLs, VPN credentials, or private tokens. Commit only placeholder values and recreate secrets in each app UI or local `.env` file.

---

## Target layout

### CT 101 — `multimedia`

| Item | Target value |
|---|---|
| IP | `192.168.1.103/24` |
| Role | Docker Arr/media stack |
| LXC type | privileged / `unprivileged: 0` |
| LXC feature | `features: nesting=1` |
| Main mounts | `/main/docker -> /docker`, `/data/media -> /media` |
| GPU passthrough | `/dev/dri/card0`, `/dev/dri/renderD128` when needed |
| Compose file | `services/media-arr/arr-stack.yml` |
| Local env file | `services/media-arr/.env` copied from `services/media-arr/.env.example` |

The live stack was originally managed by Portainer, but this repo's [`arr-stack.yml`](./arr-stack.yml) is the canonical rebuild compose file.

### Separate media LXCs

| CT | Service | IP | Notes |
|---|---|---|---|
| 102 | Jellyfin | `192.168.1.104` | Community Scripts LXC, `/data/media -> /media`, service port `8096` |
| 103 | Jellyseerr | `192.168.1.105` | Community Scripts LXC, service port `5055` |

Detailed inspected values are in [`arr-live-settings.md`](./arr-live-settings.md).

---

## Service map

| Service | Container/LXC | URL | Persistent config/data |
|---|---|---|---|
| qBittorrent | CT 101 Docker | `http://192.168.1.103:8080` | `/docker/qbittorrent`, downloads under `/media/downloads/qbittorrent` |
| Prowlarr | CT 101 Docker | `http://192.168.1.103:9696` | `/docker/prowlarr` |
| Sonarr | CT 101 Docker | `http://192.168.1.103:8989` | `/docker/sonarr`, library root `/data/tv` inside app |
| Radarr | CT 101 Docker | `http://192.168.1.103:7878` | `/docker/radarr`, library root `/data/movies` inside app |
| Bazarr | CT 101 Docker | `http://192.168.1.103:6767` | `/docker/bazarr` |
| Tdarr | CT 101 Docker | `http://192.168.1.103:8265` | `/docker/tdarr`, `/media`, `/dev/dri` |
| FlareSolverr | CT 101 Docker | `http://192.168.1.103:8191` | container only |
| QBWrapper/qbproxy | CT 101 Docker | `http://192.168.1.103:9911` | env only; token must match dashboard consumers |
| Lingarr | CT 101 Docker | `http://192.168.1.103:9876` | `/docker/lingarr`, `/media/movies`, `/media/tv` |
| Jellyfin | CT 102 service | `http://192.168.1.104:8096` | `/etc/jellyfin`, `/var/lib/jellyfin`, `/media` |
| Jellyseerr | CT 103 service | `http://192.168.1.105:5055` | `/etc/seerr`, `/opt/seerr/config`, optional legacy `/docker/jellyseerr` |

---

## LXC requirements

Use the same LXC defaults as the rest of the homelab unless intentionally changing the design:

```text
features: nesting=1
unprivileged: 0
```

For CT 101, also preserve the media bind mounts:

```text
mp0: /main/docker,mp=/docker
mp1: /data/media,mp=/media
```

For GPU passthrough, confirm devices on the Proxmox host:

```bash
ls -l /dev/dri
```

Typical CT config pattern:

```text
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```

---

## Start CT 101 Docker stack

Inside CT `101` after Docker is installed and the repo is available:

```bash
cd /root/repos/multimedia-server/server-arr
cp .env.example .env
chmod 0600 .env
nano .env
```

Fill only placeholder values:

```text
QB_USERNAME=replace-with-qbittorrent-webui-username
QB_PASSWORD=replace-with-qbittorrent-webui-password
AUTH_TOKEN=replace-with-random-qbwrapper-token
```

Start the stack:

```bash
docker compose --env-file .env -f arr-stack.yml up -d
docker compose --env-file .env -f arr-stack.yml ps
```

Verify:

```bash
docker ps
curl -fsS http://127.0.0.1:8080 >/dev/null
curl -fsS http://127.0.0.1:9696 >/dev/null
curl -fsS http://127.0.0.1:8989 >/dev/null
curl -fsS http://127.0.0.1:7878 >/dev/null
```

---

## qBittorrent setup

qBittorrent is used because it can be configured to operate only over the VPN connection/interface.

Fresh first login:

```bash
docker logs qbittorrent | grep -i password
```

Then open:

```text
http://192.168.1.103:8080
```

Minimum settings to restore:

1. Set permanent WebUI username/password in **Tools -> Options -> WebUI**.
2. Configure qBittorrent to bind torrent traffic only to the VPN interface/connection used in your final setup.
3. Keep UPnP disabled unless intentionally needed.
4. Use these download paths:
   - Completed: `/data/downloads/qbittorrent/completed`
   - Incomplete: `/data/downloads/qbittorrent/incomplete`
   - `.torrent` export: `/data/downloads/qbittorrent/torrents`
5. Enable incomplete downloads.
6. Use seeding/removal settings from [`arr-live-settings.md`](./arr-live-settings.md) if you want like-for-like behavior.

If VPN/Glutun is added later, update both `arr-stack.yml` and this guide together. Keep VPN credentials in local env/config only.

---

## Arr app configuration order

If restoring old `/docker/<app>` databases, most settings should come back automatically. If starting fresh, configure in this order:

1. **qBittorrent**
   - Set WebUI credentials.
   - Confirm download paths.
   - Confirm VPN/interface binding.
2. **Sonarr**
   - Root folder: `/data/tv/`.
   - Download client: qBittorrent at `172.18.0.1:8080` or the working Docker/LAN endpoint.
   - Category: `tv-sonarr`.
   - Enable remove completed/failed downloads.
3. **Radarr**
   - Root folder: `/data/movies/`.
   - Download client: qBittorrent at `172.18.0.1:8080` or the working Docker/LAN endpoint.
   - Category: `radarr`.
   - Enable remove completed/failed downloads.
4. **Prowlarr**
   - Add indexers.
   - Add FlareSolverr proxy if needed.
   - Add Sonarr/Radarr applications using their API keys.
   - Sync app indexers.
5. **Bazarr**
   - Connect Sonarr and Radarr using their API keys.
   - Add subtitle providers.
   - Recreate provider credentials from each provider account.
6. **Tdarr / Lingarr**
   - Confirm `/media` paths and GPU visibility where needed.
7. **Jellyfin**
   - Mount libraries from `/media/movies` and `/media/tv`.
8. **Jellyseerr**
   - Connect Jellyfin, Radarr, and Sonarr.
   - Recreate notification webhooks if used.

Current live settings, profile names, indexer list, and category mappings are captured in [`arr-live-settings.md`](./arr-live-settings.md).

---

## Public access / proxy

Public access is handled by the dedicated proxy LXC:

```text
CT 201 proxy / 192.168.1.201
Caddy + Cloudflare Tunnel + Cloudflare MCP in one LXC
```

Use [`../../infrastructure/proxy/Access-Setup.md`](../../infrastructure/proxy/Access-Setup.md) and [`../../infrastructure/proxy/config/Caddyfile.example`](../../infrastructure/proxy/config/Caddyfile.example) for proxy rebuild details.

Keep proxy hostnames and internal targets consistent with [`../../inventory/lxc-map.md`](../../inventory/lxc-map.md). Put Cloudflare tokens/tunnel credentials only in the proxy LXC or password manager, never in this repo.

---

## Backup / restore checklist

Back up before rebuilding:

- CT 101 Proxmox config, especially mounts and GPU passthrough.
- `/docker/qbittorrent`
- `/docker/prowlarr`
- `/docker/sonarr`
- `/docker/radarr`
- `/docker/bazarr`
- `/docker/tdarr`
- `/docker/lingarr`
- Jellyfin: `/etc/jellyfin`, `/var/lib/jellyfin`.
- Jellyseerr: `/etc/seerr`, `/opt/seerr/config`, and any active legacy config path.

Example CT 101 config backup:

```bash
cd /
tar -czf /root/servarr-config-backup-$(date +%F).tgz \
  docker/qbittorrent \
  docker/prowlarr \
  docker/sonarr \
  docker/radarr \
  docker/bazarr \
  docker/tdarr \
  docker/lingarr
```

Do not include local `.env` files in Git. Store real `.env` backups only in your private backup/password-manager process.

---

## Secret recreation checklist

| Secret | Where to recreate |
|---|---|
| qBittorrent temporary password | `docker logs qbittorrent` on first start |
| qBittorrent permanent password | qBittorrent -> Tools -> Options -> WebUI |
| QBWrapper `AUTH_TOKEN` | Generate locally, e.g. `openssl rand -hex 32` |
| Sonarr API key | Sonarr -> Settings -> General -> Security |
| Radarr API key | Radarr -> Settings -> General -> Security |
| Prowlarr API key | Prowlarr -> Settings -> General -> Security |
| Bazarr API key/provider credentials | Bazarr settings/provider account pages |
| Jellyfin API key | Jellyfin Dashboard -> Advanced -> API Keys |
| Jellyseerr service keys/webhooks | Jellyseerr Settings -> Services / Notifications |
| VPN credentials | VPN provider account/app; store only in local config/env |

---

## Maintenance

When changing the media stack:

1. Update [`arr-stack.yml`](./arr-stack.yml) for compose changes.
2. Update [`arr-live-settings.md`](./arr-live-settings.md) for UI/path/port behavior.
3. Update [`../../inventory/lxc-map.md`](../../inventory/lxc-map.md) for CT IDs, IPs, ports, or mounts.
5. Update [`../../infrastructure/proxy/config/Caddyfile.example`](../../infrastructure/proxy/config/Caddyfile.example) if public hostnames or reverse proxy targets change.
