# Fresh Homelab Rebuild Runbook

This repo is the source of truth to rebuild the homelab as close as possible to the current setup.

Goal: after a fresh Proxmox install, follow this checklist and recreate the same LXCs, storage, proxy, media stack, and local AI services without hunting through old chats/configs.

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
| proxy-caddy | Community Scripts | Caddy reverse proxy | [proxy/Access-Setup.md](./proxy/Access-Setup.md) |
| proxy-cloudflared | Community Scripts | Cloudflare Tunnel connector | [proxy/Access-Setup.md](./proxy/Access-Setup.md) |
| proxy | Manual/post-install merge if desired | Caddy + Cloudflare Tunnel + Cloudflare MCP in one LXC | [proxy/Access-Setup.md](./proxy/Access-Setup.md) |
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
- [server-arr/arr-stack.yml](./server-arr/arr-stack.yml)

TODO: exact UI settings still need to be exported/documented for Sonarr/Radarr/Prowlarr/Bazarr/qBittorrent/Jellyfin.

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

Current Hermes system-level config example:

```text
hermes/config/config.system.example.yaml
```

Known troubleshooting to preserve:

- Hermes duplicate gateway conflict: keep only one of user-level/system-level gateway active.
- OmniRoute onboarding/login issue: use `INITIAL_PASSWORD` or manually update `key_value` rows in SQLite as documented.

### 7. Verification checklist

After rebuild, verify:

- [ ] Proxmox pools and datasets exist.
- [ ] LXC inventory matches `inventory/lxc-map.md`.
- [ ] Required LXCs have `nesting=1` and `unprivileged: 0`.
- [ ] Shared mounts are visible inside CTs.
- [ ] Cloudflare Tunnel is connected/healthy.
- [ ] Caddy starts and obtains certificates.
- [ ] Internal service DNS/proxy routes work.
- [ ] Arr stack containers are healthy.
- [ ] qBittorrent downloads to correct mounted paths.
- [ ] Sonarr/Radarr can import completed downloads.
- [ ] Jellyfin can scan libraries.
- [ ] OmniRoute UI login works.
- [ ] OmniRoute API key works with `/v1/models` or a chat completion test.
- [ ] Hindsight service is reachable from Hermes.
- [ ] Hermes CLI works.
- [ ] Hermes gateway starts exactly once, with no duplicate user/system gateway conflict.
- [ ] Discord/CLI tool permissions match current intended config.

## Current open documentation gaps

Track detailed work in [KANBAN.md](./KANBAN.md). Biggest remaining gaps:

- Exact CT IDs, IPs, hostnames, and mounts from the live Proxmox node.
- Exact Hindsight install/run config.
- Exact OmniRoute deployment method used in the current LXC.
- Exact arr stack UI settings and backup/restore procedure.
- Current Cloudflare MCP install/config details.
