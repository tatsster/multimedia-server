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

| CT ID | Name | IP | Role | Key ports | Mounts | Guide |
|---|---|---|---|---|---|---|
| TBD | media-arr | TBD | Arr stack, qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr, Tdarr, Flaresolverr, QBWrapper, Lingarr | 8080, 9696, 8989, 7878, 6767, 8265, 8266, 8191, 9911, 9876 | `/media`, `/docker/*` | `server-arr/Multimedia-Setup.md` |
| TBD | proxy | TBD | Caddy, Cloudflare Tunnel, Cloudflare MCP | 80, 443, 2019, cloudflared outbound | `/etc/caddy`, env/secrets | `proxy/Access-Setup.md` |
| TBD | hermes | TBD | Hermes agent/gateway | TBD | `/root/.hermes` | `hermes/README.md` |
| TBD | omniroute | TBD | AI model router/API gateway | 20128 | `~/.omniroute` or `/app/data` | `omniroute/README.md` |
| TBD | hindsight | TBD | Hermes memory backend | TBD | Hindsight data directory | `hindsight/README.md` |
| TBD | jellyfin | TBD | Optional separate Jellyfin LXC | 8096 | media libraries, `/dev/dri` if GPU | `server-arr/Multimedia-Setup.md` |

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
