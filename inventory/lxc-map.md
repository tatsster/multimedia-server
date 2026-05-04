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
| TBD | media-arr | TBD | Manual repo script | Arr stack, qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr, Tdarr, Flaresolverr, QBWrapper, Lingarr | 8080, 9696, 8989, 7878, 6767, 8265, 8266, 8191, 9911, 9876 | `/media`, `/docker/*` | `server-arr/Multimedia-Setup.md`, `scripts/pve/create-media-arr-lxc.sh` |
| TBD | proxy-caddy | TBD | Community Scripts: Caddy | Caddy reverse proxy | 80, 443, 2019 | `/etc/caddy`, env/secrets | `proxy/Access-Setup.md` |
| TBD | proxy-cloudflared | TBD | Community Scripts: Cloudflared | Cloudflare Tunnel connector | outbound only | cloudflared token/config | `proxy/Access-Setup.md` |
| TBD | proxy | TBD | Manual merge or post-install combination | Optional combined Caddy + Cloudflare Tunnel + Cloudflare MCP LXC | 80, 443, 2019, cloudflared outbound | `/etc/caddy`, env/secrets | `proxy/Access-Setup.md` |
| TBD | hermes | TBD | Manual repo script | Hermes agent/gateway | TBD | `/root/.hermes` | `hermes/README.md`, `scripts/pve/create-hermes-lxc.sh` |
| TBD | omniroute | TBD | Manual repo script | AI model router/API gateway | 20128 | `~/.omniroute` or `/app/data` | `omniroute/README.md`, `scripts/pve/create-omniroute-lxc.sh` |
| TBD | hindsight | TBD | Manual repo script | Hermes memory backend | TBD | Hindsight data directory | `hindsight/README.md`, `scripts/pve/create-hindsight-lxc.sh` |
| TBD | jellyfin | TBD | TBD, maybe community script or part of media-arr | Optional separate Jellyfin LXC | 8096 | media libraries, `/dev/dri` if GPU | `server-arr/Multimedia-Setup.md` |

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
| `/data/general` | media-arr or Jellyfin | `/mnt/general` or `/media` | media/data storage |
| `/dev/dri/card0` | media/Jellyfin/Tdarr | `/dev/dri/card0` | GPU passthrough |
| `/dev/dri/renderD128` | media/Jellyfin/Tdarr | `/dev/dri/renderD128` | GPU render passthrough |

Update this file whenever CT IDs, IPs, or mounts change.
