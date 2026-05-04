# LXC Inventory and Rebuild Defaults

This file is the canonical place to record CT IDs, IPs, ports, mounts, and service roles for a fresh rebuild.

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

Example LXC config lines/patterns:

```text
features: nesting=1
unprivileged: 0
```

For GPU passthrough to media/Jellyfin/Tdarr containers, see `server-arr/Multimedia-Setup.md`.

## LXC map

Fill exact CT IDs/IPs from the live homelab.

To speed this up, run the audit helper from the Proxmox VE host:

```bash
cd /root/repos/multimedia-server
./scripts/pve/audit-lxcs.sh
```

It writes `inventory/live-lxc-audit.md`, which is ignored by Git. Review that generated file for private notes before committing anything copied from it. See [`live-lxc-audit.example.md`](./live-lxc-audit.example.md) for the expected sanitized format.

| CT ID | Name | IP | Creation method | Role | Key ports | Mounts | Guide / script |
|---|---|---|---|---|---|---|---|
| 100 | ubuntu | 192.168.1.102 | Existing manual / legacy | General Ubuntu Docker/helper LXC | TBD | `/main/docker -> /docker`, `/data/media -> /media` | TBD |
| 101 | multimedia | 192.168.1.103 | Manual repo script or media guide | Arr/media Docker stack | 8080, 9696, 8989, 7878, 6767, 8265, 8266, 8191, 9911, 9876 | `/main/docker -> /docker`, `/data/media -> /media`, `/dev/dri/*` | `server-arr/Multimedia-Setup.md`, `scripts/pve/create-media-arr-lxc.sh` |
| 102 | jellyfin | 192.168.1.104 | Community Scripts: verify exact script | Separate Jellyfin LXC | 8096 | `/data/media -> /media`, `/dev/dri`, optional USB/serial mappings | `server-arr/Multimedia-Setup.md` |
| 103 | jellyseerr | 192.168.1.105 | Community Scripts: verify exact script | Jellyseerr requests UI | 5055 | `/main/docker -> /docker`, optional USB/serial mappings | `server-arr/Multimedia-Setup.md` |
| 104 | vaultwarden | 192.168.1.106 | Community Scripts: verify exact script | Password manager | 80/8080 internally, proxied by Caddy | optional USB/serial mappings | TBD |
| 105 | n8n | 192.168.1.107 | Community Scripts: verify exact script | Automation workflows | 5678 | `/dev/dri/*`, optional USB/serial mappings | TBD |
| 106 | redis | 192.168.1.108 | Community Scripts: verify exact script | Redis database/cache | 6379 | optional USB/serial mappings | TBD |
| 107 | omniroute | 192.168.1.109 | Manual repo script | AI model router/API gateway | 20128 | app data under OmniRoute data dir | `omniroute/README.md`, `scripts/pve/create-omniroute-lxc.sh` |
| 108 | hermes | 192.168.1.110 | Manual repo script | Hermes agent/gateway | Hermes gateway/API ports as configured | `/root/.hermes` | `hermes/README.md`, `scripts/pve/create-hermes-lxc.sh` |
| 109 | hindsight | 192.168.1.111 | Manual repo script | Hermes memory backend | Hindsight API port as configured | Hindsight data directory | `hindsight/README.md`, `scripts/pve/create-hindsight-lxc.sh` |
| 201 | proxy | 192.168.1.201 | Community Scripts: Caddy, then post-install Cloudflare Tunnel/MCP | Caddy reverse proxy + Cloudflare Tunnel/MCP | 80, 443, 2019, cloudflared outbound | `/etc/caddy`, env/secrets | `proxy/Access-Setup.md` |
| 250 | pbs | 192.168.1.250 | Community Scripts: verify exact script | Proxmox Backup Server | 8007 | `/main/backup -> /backup`, optional USB/serial mappings | TBD |

## Internal service URLs

| Service | Internal URL template | Notes |
|---|---|---|
| OmniRoute API | `http://<omniroute-lxc-ip>:20128/v1` | Used by Hermes `model.base_url` |
| OmniRoute dashboard | `http://<omniroute-lxc-ip>:20128` | Used to create API keys/providers |
| Proxmox | `https://<proxmox-ip>:8006` | Used by Glance/Hermes tools |
| Jellyfin | `http://<jellyfin-ip>:8096` | May be proxied by Caddy/Tunnel |

## Mount map

| Host path | Container | Container path | Purpose |
|---|---|---|---|
| `/main/docker` | ubuntu, multimedia, jellyseerr | `/docker` | Docker app/config storage |
| `/data/media` | ubuntu, multimedia, Jellyfin | `/media` | media library/storage |
| `/main/backup` | pbs | `/backup` | PBS datastore / backup storage |
| `/dev/dri/card0` | media/Jellyfin/Tdarr/n8n where needed | `/dev/dri/card0` | GPU passthrough |
| `/dev/dri/renderD128` | media/Jellyfin/Tdarr/n8n where needed | `/dev/dri/renderD128` | GPU render passthrough |
| `/dev/ttyUSB*`, `/dev/ttyACM*`, `/dev/serial/by-id` | selected Community Scripts LXCs | matching `/dev/...` path | Optional USB/serial passthrough copied from live configs |

Update this file whenever CT IDs, IPs, or mounts change.
