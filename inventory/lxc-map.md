# LXC Inventory and Network Map

This file is the canonical place for CT IDs, names, target IPs, roles, service ports, host/container mounts, and rebuild method. Use it as the first reference when recreating containers or wiring infrastructure/proxy/Homepage/Hermes integrations.

Related docs:

- Main rebuild runbook: [`../docs/rebuild/Fresh-Homelab-Rebuild.md`](../docs/rebuild/Fresh-Homelab-Rebuild.md)
- Proxmox base/storage guide: [`../infrastructure/proxmox/Homelab-Setup.md`](../infrastructure/proxmox/Homelab-Setup.md)
- Architecture overview: [`../docs/architecture.md`](../docs/architecture.md)
- Verification checklist: [`../docs/verify.md`](../docs/verify.md)

> Secret-safety note: keep this file to addresses, ports, paths, and placeholders. Do not add real tokens, passwords, API keys, OAuth values, or private tunnel credentials.

---

## Network defaults

| Item | Current homelab default |
|---|---|
| LAN subnet | `192.168.1.0/24` |
| Gateway | `192.168.1.1` |
| Proxmox host | `192.168.1.101` / `https://192.168.1.101:8006` |
| LXC bridge | `vmbr0` |
| LXC IP style | Static IPs in this map unless intentionally changed |
| Public access pattern | Cloudflare Tunnel / Caddy on proxy LXC |
| Internal docs convention | Use `<service-lxc-ip>` placeholders when documenting reusable commands |

Use `192.168.1.100-199` for regular LXCs and keep infrastructure helpers such as infrastructure/proxy/PBS in clearly separated IDs where possible.

---

## Standard LXC defaults

Keep these defaults unless a service guide says otherwise:

| Setting | Current homelab default |
|---|---|
| Container privilege | Privileged / `Unprivileged container=No` |
| Nesting | Enabled, `nesting=1` |
| CPU | Advanced CPU tab: cores unlimited; CPU limit can be set as desired |
| Storage | Use configured Proxmox ZFS/container storage |
| Mounts | Bind mount host datasets into containers as needed |
| Docker-in-LXC | Requires nesting enabled; privileged has been used for this homelab |
| Network | `net0` on `vmbr0`, static IP, gateway `192.168.1.1` |

Example LXC config lines/patterns:

```text
features: nesting=1
unprivileged: 0
net0: name=eth0,bridge=vmbr0,ip=<LXC_IP>/24,gw=192.168.1.1,type=veth
```

For GPU passthrough to media/Jellyfin/Tdarr containers, see [`../services/media-arr/Multimedia-Setup.md`](../services/media-arr/Multimedia-Setup.md).

---

## Canonical LXC map

| CT ID | Name | Target IP | Creation method | Role | Key ports | Host mounts / devices | Guide / script |
|---|---|---|---|---|---|---|---|
| 100 | ubuntu | `192.168.1.102` | Existing manual / legacy | General Ubuntu Docker/helper LXC | TBD | `/main/docker -> /docker`; `/data/media -> /media` | TBD |
| 101 | multimedia | `192.168.1.103` | Manual repo script or media guide | Arr/media Docker stack | 8080 qBittorrent; 9696 Prowlarr; 8989 Sonarr; 7878 Radarr; 6767 Bazarr; 8265/8266 Tdarr; 8191 FlareSolverr; 9911 QBWrapper; 9876 Lingarr | `/main/docker -> /docker`; `/data/media -> /media`; `/dev/dri/*` | [`../services/media-arr/Multimedia-Setup.md`](../services/media-arr/Multimedia-Setup.md), [`../automation/pve/create-media-arr-lxc.sh`](../automation/pve/create-media-arr-lxc.sh), [`../services/media-arr/arr-stack.yml`](../services/media-arr/arr-stack.yml) |
| 102 | jellyfin | `192.168.1.104` | Community Scripts: verify exact script | Separate Jellyfin LXC | 8096 Jellyfin HTTP | `/data/media -> /media`; `/dev/dri`; optional USB/serial mappings | [`../services/media-arr/Multimedia-Setup.md`](../services/media-arr/Multimedia-Setup.md) |
| 103 | jellyseerr | `192.168.1.105` | Community Scripts: verify exact script | Jellyseerr requests UI | 5055 Jellyseerr | `/main/docker -> /docker`; optional USB/serial mappings | [`../services/media-arr/Multimedia-Setup.md`](../services/media-arr/Multimedia-Setup.md) |
| 104 | vaultwarden | `192.168.1.106` | Community Scripts: verify exact script | Password manager | 80/8080 internally; proxied by Caddy/Tunnel | app data path TBD; optional USB/serial mappings | TBD |
| 105 | n8n | `192.168.1.107` | Community Scripts: verify exact script | Automation workflows | 5678 n8n | `/dev/dri/*` if needed; optional USB/serial mappings | TBD |
| 106 | redis | `192.168.1.108` | Community Scripts: verify exact script | Redis database/cache | 6379 Redis | optional USB/serial mappings | TBD |
| 107 | omniroute | `192.168.1.109` | Manual repo script | AI model router/OpenAI-compatible API gateway | 20128 dashboard and `/v1` API | `/root/.omniroute` data on rootfs unless bind-mounted later | [`../services/omniroute/README.md`](../services/omniroute/README.md), [`../automation/pve/create-omniroute-lxc.sh`](../automation/pve/create-omniroute-lxc.sh) |
| 110 | mealie | `192.168.1.112` | Manual documented setup | Recipe manager, meal planner, daily meal suggestion API | 9925 Mealie; 8777 daily random meal fallback API | `/opt/mealie/data`; `/opt/daily-meal` | Dedicated service guide TBD |
| 111 | speedtest | `192.168.1.113` | Community Scripts / manual service tuning | Speedtest Tracker | app port as installed; proxied/linked in Homepage | app data path TBD | Dedicated service guide TBD |
| 114 | proxmox-mcp-plus | `192.168.1.116` | Docker/MCP service in LXC | Proxmox MCP Plus endpoint for Hermes | 8000 MCP HTTP | Docker data path TBD | [`../agent/hermes/README.md`](../agent/hermes/README.md) |
| 115 | esp32 | `192.168.1.117` | Manual app LXC | ESP32 / Mini Happie Manager | 8080 web UI | app data path TBD | Dedicated service guide TBD |
| 116 | openviking | `192.168.1.118` | OpenViking service LXC | OpenViking knowledge base/API | 1933 HTTP API | `/opt/openviking`, `/root/.openviking` | Dedicated service guide TBD |
| 201 | proxy | `192.168.1.201` | Community Scripts: Caddy, then post-install Cloudflare Tunnel/MCP | Caddy reverse proxy + Cloudflare Tunnel/MCP | 80 HTTP; 443 HTTPS; 2019 Caddy admin if enabled; cloudflared outbound | `/etc/caddy`; Caddy/Cloudflare env and tunnel credentials | [`../infrastructure/proxy/Access-Setup.md`](../infrastructure/proxy/Access-Setup.md), [`../infrastructure/proxy/config/Caddyfile.example`](../infrastructure/proxy/config/Caddyfile.example) |
| 250 | pbs | `192.168.1.250` | Community Scripts: verify exact script | Proxmox Backup Server | 8007 PBS UI/API | `/main/backup -> /backup`; optional USB/serial mappings | TBD |

---

## Service port map

### Proxmox and infrastructure

| Service | LXC / host | Internal URL | Public/proxied hostname pattern | Notes |
|---|---|---|---|---|
| Proxmox VE | host `192.168.1.101` | `https://192.168.1.101:8006` | optional `proxmox.<domain>` | Used by Homepage/Hermes tools with scoped token |
| Proxmox Backup Server | `pbs` / `192.168.1.250` | `https://192.168.1.250:8007` | `pbs.<domain>` | Backup datastore mounted from `/main/backup` |
| Caddy | `proxy` / `192.168.1.201` | `http://192.168.1.201:80`, `https://192.168.1.201:443` | `*.example.com` in docs | Reverse proxy front door |
| Caddy admin | `proxy` / `192.168.1.201` | `http://localhost:2019` preferred | not public | Example keeps admin on localhost by default |
| Cloudflare Tunnel | `proxy` / `192.168.1.201` | outbound only | public hostnames | Tunnel credentials stay out of repo |

### Media and Arr stack

Ports below are from [`../services/media-arr/arr-stack.yml`](../services/media-arr/arr-stack.yml) and the current Homepage monitor config.

| Service | LXC | Internal URL | Public/proxied hostname pattern | Source |
|---|---|---|---|---|
| qBittorrent | `multimedia` / `192.168.1.103` | `http://192.168.1.103:8080` | `torrent.<domain>` | compose port `8080:8080` |
| Prowlarr | `multimedia` / `192.168.1.103` | `http://192.168.1.103:9696` | `prowlarr.<domain>` | compose port `9696:9696` |
| Sonarr | `multimedia` / `192.168.1.103` | `http://192.168.1.103:8989` | `sonarr.<domain>` | compose port `8989:8989` |
| Radarr | `multimedia` / `192.168.1.103` | `http://192.168.1.103:7878` | `radarr.<domain>` | compose port `7878:7878` |
| Bazarr | `multimedia` / `192.168.1.103` | `http://192.168.1.103:6767` | `bazarr.<domain>` | compose port `6767:6767` |
| Tdarr UI | `multimedia` / `192.168.1.103` | `http://192.168.1.103:8265` | `tdarr.<domain>` | compose port `8265:8265` |
| Tdarr server | `multimedia` / `192.168.1.103` | `192.168.1.103:8266` | usually not public | compose port `8266:8266` |
| FlareSolverr | `multimedia` / `192.168.1.103` | `http://192.168.1.103:8191` | `flaresolverr.<domain>` if exposed | compose port `8191:8191` |
| QBWrapper/qbproxy | `multimedia` / `192.168.1.103` | `http://192.168.1.103:9911` | usually internal for dashboard widget | compose port `9911:9911` |
| Lingarr | `multimedia` / `192.168.1.103` | `http://192.168.1.103:9876` | `lingarr.<domain>` | compose port `9876:9876` |
| Jellyfin | `jellyfin` / `192.168.1.104` | `http://192.168.1.104:8096` | `play.<domain>` | Homepage check URL |
| Jellyseerr | `jellyseerr` / `192.168.1.105` | `http://192.168.1.105:5055` | `media.<domain>` | Homepage check URL |

qBittorrent rebuild note: configure qBittorrent so torrent traffic only operates over the VPN connection/interface. Keep any VPN credentials in local env/config only, never in this repo.

### AI and agent services

| Service | LXC | Internal URL | Client / public usage | Source |
|---|---|---|---|---|
| OmniRoute dashboard | `omniroute` / `192.168.1.109` | `http://192.168.1.109:20128` | `omniroute.<domain>` if proxied | [`../services/omniroute/README.md`](../services/omniroute/README.md) |
| Hermes gateway | `hermes` / `192.168.1.110` | service-managed; ports depend on enabled platform integrations | Discord/CLI gateway as configured | [`../agent/hermes/README.md`](../agent/hermes/README.md) |

### Utility services

| Service | LXC | Internal URL | Public/proxied hostname pattern | Notes |
|---|---|---|---|---|
| Vaultwarden | `vaultwarden` / `192.168.1.106` | `http://192.168.1.106:<vaultwarden-port>` | `vaultwarden.<domain>` | Exact internal port depends on Community Script install |
| n8n | `n8n` / `192.168.1.107` | `http://192.168.1.107:5678` | `n8n.<domain>` | Homepage check URL |
| Redis | `redis` / `192.168.1.108` | `192.168.1.108:6379` | internal only | Do not expose publicly |
| Mealie | `mealie` / `192.168.1.112` | `http://192.168.1.112:9925` | `mealie.<domain>` / current `mealie.liftlab.dev` | Cloudflare Tunnel route; recipe manager and meal planner |
| Daily meal fallback API | `mealie` / `192.168.1.112` | `http://192.168.1.112:8777` | internal dashboard custom API only | Deterministic random daily meal until Mealie meal plans are populated |
| Speedtest Tracker | `speedtest` / `192.168.1.113` | app URL as installed | linked/widget in Homepage | Homepage widget uses API token stored only in live Homepage env |

---

## Mount map

| Host path / device | Containers | Container path | Purpose | Source / notes |
|---|---|---|---|---|
| `/main/docker` | `ubuntu`, `multimedia`, `jellyseerr` | `/docker` | Docker app/config storage | Main Docker config dataset |
| `/data/media` | `ubuntu`, `multimedia`, `jellyfin` | `/media` | Media library/storage | Shared media dataset |
| `/main/backup` | `pbs` | `/backup` | PBS datastore / backup storage | Backup dataset |
| `/data/general` | selected LXCs | `/mnt/general` | General shared dataset | Standard bind mount pattern from [`../infrastructure/proxmox/Homelab-Setup.md`](../infrastructure/proxmox/Homelab-Setup.md) |
| `/root/.omniroute` | `omniroute` | `/root/.omniroute` | OmniRoute DB, backups, call logs | Currently on rootfs unless later moved to dataset |
| `/etc/caddy` | `proxy` | `/etc/caddy` | Caddyfile and Caddy state/config | Pair with Cloudflare env/tunnel backup notes |
| `/dev/dri/card0` | media/Jellyfin/Tdarr/n8n where needed | `/dev/dri/card0` | GPU passthrough | Preserve cgroup/device config when rebuilding |
| `/dev/dri/renderD128` | media/Jellyfin/Tdarr/n8n where needed | `/dev/dri/renderD128` | GPU render passthrough | Preserve cgroup/device config when rebuilding |
| `/dev/ttyUSB*`, `/dev/ttyACM*`, `/dev/serial/by-id` | selected Community Scripts LXCs | matching `/dev/...` path | Optional USB/serial passthrough | Copy from live CT config only if still needed |

Bind mount config example:

```text
mp0: /data/general,mp=/mnt/general
```

More examples are in [`../infrastructure/proxmox/Homelab-Setup.md`](../infrastructure/proxmox/Homelab-Setup.md).

---

## Rebuild method legend

| Method | Meaning | Where to document details |
|---|---|---|
| Manual repo script | Use a script from `automation/pve/` plus the service README | Service README and script comments |
| Community Scripts | Recreate with the Proxmox Community Scripts project, then apply this inventory's IP/mount/port defaults | Service guide or this file until a dedicated guide exists |
| Existing manual / legacy | Current service exists but rebuild path still needs normalization | Leave `TBD` until a service doc captures it |
| Manual documented setup | Create LXC manually and follow repo docs | Service guide |

---

## Inventory audit helper

To refresh this file from a live Proxmox host, run the audit helper:

```bash
cd /root/repos/multimedia-server
../automation/pve/audit-lxcs.sh
```

It writes `inventory/live-lxc-audit.md`, which is ignored by Git. Review generated content for private notes before copying any sanitized values here. See [`live-lxc-audit.example.md`](./live-lxc-audit.example.md) for the expected sanitized format.

---

## Update checklist

Update this file whenever any of these change:

- CT ID, hostname, IP address, or gateway.
- Rebuild method or source script.
- Public/proxied hostname.
- Docker compose port mapping.
- Caddy reverse proxy target.
- Homepage monitor check URL.
- Bind mount, GPU passthrough, USB passthrough, or service data path.
