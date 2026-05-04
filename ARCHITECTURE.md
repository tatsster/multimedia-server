# Homelab Architecture

This diagram is the high-level rebuild map. Use it with:

- [`Fresh-Homelab-Rebuild.md`](./Fresh-Homelab-Rebuild.md)
- [`inventory/lxc-map.md`](./inventory/lxc-map.md)
- [`VERIFY.md`](./VERIFY.md)

The exact CT IDs, IPs, ports, mounts, and creation methods live in [`inventory/lxc-map.md`](./inventory/lxc-map.md). This file is intentionally secret-free.

## Standard LXC defaults

Most service LXCs should preserve the current homelab defaults unless a service guide says otherwise:

```text
features: nesting=1
unprivileged: 0
```

This matters especially for Docker-in-LXC, media/GPU workloads, and consistency with the current Proxmox setup.

## High-level service map

```mermaid
flowchart TB
  internet((Internet))
  cf[Cloudflare DNS / Zero Trust]
  users[Users / Devices]

  subgraph pve[Proxmox VE host - 192.168.1.101]
    storage[(Host storage / ZFS datasets)]
    dockerData[(/main/docker)]
    mediaData[(/data/media)]
    backupData[(/main/backup)]
    gpu[/dev/dri GPU devices/]

    subgraph proxy[CT 201 proxy - 192.168.1.201]
      caddy[Caddy reverse proxy]
      tunnel[Cloudflare Tunnel]
      cfmcp[Cloudflare MCP wrapper]
    end

    subgraph media[CT 101 multimedia - 192.168.1.103]
      qb[qBittorrent :8080]
      prowlarr[Prowlarr :9696]
      sonarr[Sonarr :8989]
      radarr[Radarr :7878]
      bazarr[Bazarr :6767]
      tdarr[Tdarr :8265/:8266]
      flaresolverr[FlareSolverr :8191]
      qbproxy[QBWrapper/qbproxy :9911]
      lingarr[Lingarr :9876]
      portainer[Portainer :9443/:8000]
      glance[Glance dashboard :8081]
    end

    jellyfin[CT 102 Jellyfin - 192.168.1.104:8096]
    jellyseerr[CT 103 Jellyseerr - 192.168.1.105:5055]
    vaultwarden[CT 104 Vaultwarden - 192.168.1.106]
    n8n[CT 105 n8n - 192.168.1.107:5678]
    redis[CT 106 Redis - 192.168.1.108:6379]

    subgraph ai[AI services]
      omniroute[CT 107 OmniRoute - 192.168.1.109:20128]
      hermes[CT 108 Hermes - 192.168.1.110]
      hindsight[CT 109 Hindsight - 192.168.1.111:8888/:9999]
    end

    pbs[CT 250 PBS - 192.168.1.250:8007]
  end

  internet --> cf
  users --> cf
  cf --> tunnel
  cf --> caddy
  tunnel --> caddy

  caddy --> jellyfin
  caddy --> jellyseerr
  caddy --> glance
  caddy --> vaultwarden
  caddy --> n8n
  caddy --> hermes
  caddy --> omniroute
  caddy --> hindsight

  dockerData --> media
  mediaData --> media
  mediaData --> jellyfin
  backupData --> pbs
  gpu --> media
  gpu --> jellyfin

  prowlarr --> sonarr
  prowlarr --> radarr
  sonarr --> qb
  radarr --> qb
  qbproxy --> qb
  glance --> qbproxy
  glance --> jellyfin
  glance --> pve
  glance --> pbs
  jellyseerr --> jellyfin
  jellyseerr --> sonarr
  jellyseerr --> radarr

  hermes -->|OpenAI-compatible API| omniroute
  hermes -->|memory API| hindsight
  hindsight -->|LLM provider via OpenAI-compatible API| omniroute
  omniroute --> providers[External/local model providers]
```

## Rebuild flow

```mermaid
flowchart LR
  base[Install Proxmox + storage] --> inventory[Confirm inventory/lxc-map.md]
  inventory --> proxy[Create proxy LXC]
  inventory --> media[Create media/arr LXC]
  inventory --> ai[Create AI LXCs]
  proxy --> secrets[Recreate secrets from dashboards]
  media --> secrets
  ai --> secrets
  secrets --> verify[Run VERIFY.md + smoke-test helpers]
  verify --> backup[Confirm backup/restore plan]
```

## Main network paths

| Flow | Path | Notes |
| --- | --- | --- |
| External HTTPS | Internet -> Cloudflare -> Cloudflare Tunnel/Caddy -> internal service | Keep Cloudflare Access in front of sensitive services. |
| Direct LAN access | LAN device -> LXC IP:port | Use for first setup and troubleshooting. |
| Media requests | Jellyseerr -> Sonarr/Radarr -> qBittorrent -> media folders | Prowlarr syncs indexers to Sonarr/Radarr. |
| Media playback | Jellyfin -> `/media` bind mount -> client | GPU passthrough supports transcoding where configured. |
| Dashboard | Glance -> Proxmox/PBS/Jellyfin/QBWrapper/services | Tokens live only in Glance `.env`, not Git. |
| Hermes model calls | Hermes -> OmniRoute `/v1` -> providers | Current pattern uses OmniRoute as the OpenAI-compatible gateway. |
| Hermes memory | Hermes -> Hindsight API | Hindsight stores long-term memory in its persistent data path. |
| Hindsight LLM calls | Hindsight -> OmniRoute `/v1` -> providers | Hindsight can be healthy while provider calls fail upstream. |

## Storage and mount paths

| Host path/device | Consumed by | Purpose |
| --- | --- | --- |
| `/main/docker` | CT 101 media, legacy Docker/helper LXCs, some app LXCs | Docker app config/data. |
| `/data/media` | CT 101 media, CT 102 Jellyfin | Shared media library. |
| `/main/backup` | CT 250 PBS | Backup datastore. |
| `/dev/dri/card0`, `/dev/dri/renderD128` | media/Jellyfin/Tdarr where needed | GPU passthrough/transcoding. |

## Secret boundaries

Do not commit real values for:

- Cloudflare Tunnel token
- Cloudflare API token
- Cloudflare MCP account/token values
- Caddy DNS challenge token
- OmniRoute admin password, JWT secret, API key secret, provider keys, endpoint API keys
- Hermes provider keys or Discord/user allowlists
- Hindsight LLM API key
- Proxmox/PBS API tokens
- Jellyfin API key
- qBittorrent password / QBWrapper token

Use committed `*.example` files only, then create local ignored files during restore.

Run these before committing config changes:

```bash
./scripts/check-env.sh
git diff --check
```

## Source files by area

| Area | Source of truth |
| --- | --- |
| Rebuild order | [`Fresh-Homelab-Rebuild.md`](./Fresh-Homelab-Rebuild.md) |
| CT IDs/IPs/mounts | [`inventory/lxc-map.md`](./inventory/lxc-map.md) |
| Proxmox/LXC scripts | [`scripts/pve/README.md`](./scripts/pve/README.md) |
| Proxy/Caddy/Cloudflare | [`proxy/Access-Setup.md`](./proxy/Access-Setup.md) |
| Media/arr exact settings | [`server-arr/arr-live-settings.md`](./server-arr/arr-live-settings.md) |
| Glance dashboard | [`glance/Readme.md`](./glance/Readme.md) |
| AI integration | [`ai/integration.md`](./ai/integration.md) |
| Hermes | [`hermes/README.md`](./hermes/README.md) |
| OmniRoute | [`omniroute/README.md`](./omniroute/README.md) |
| Hindsight | [`hindsight/README.md`](./hindsight/README.md) |
| Verification | [`VERIFY.md`](./VERIFY.md) |
