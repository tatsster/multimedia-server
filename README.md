# Multimedia Homelab Rebuild Docs

This repository is the documentation source of truth for rebuilding the current Proxmox-based multimedia and local-AI homelab.

## Start here

Open the main runbook first:

- [`docs/rebuild/Fresh-Homelab-Rebuild.md`](./docs/rebuild/Fresh-Homelab-Rebuild.md)

That runbook links out to the architecture map, LXC inventory, service guides, secret/env examples, and verification checklist in the intended rebuild order.

## Repository layout

| Area | Path | Purpose |
| --- | --- | --- |
| Rebuild docs | [`docs/`](./docs/) | Architecture, rebuild flow, verification checklist. |
| Inventory | [`inventory/`](./inventory/) | Canonical CT IDs, IPs, ports, mounts, and live-audit examples. |
| Proxmox/proxy infrastructure | [`infrastructure/`](./infrastructure/) | Proxmox base setup, storage notes, Caddy/Cloudflare access docs. |
| Services | [`services/`](./services/) | Service-specific app guides and compose/example config. |
| Agent config and skills | [`agent/`](./agent/) | Hermes examples and exported custom Hermes skills. |
| Automation | [`automation/`](./automation/) | PVE creation/audit scripts and smoke checks. |
| Assets | [`assets/`](./assets/) | Images referenced by docs. |

## Documentation map

| Need | File |
| --- | --- |
| Rebuild order / main checklist | [`docs/rebuild/Fresh-Homelab-Rebuild.md`](./docs/rebuild/Fresh-Homelab-Rebuild.md) |
| High-level architecture and service paths | [`docs/architecture.md`](./docs/architecture.md) |
| Proxmox base install/storage notes | [`infrastructure/proxmox/Homelab-Setup.md`](./infrastructure/proxmox/Homelab-Setup.md) |
| Canonical LXC IDs, IPs, ports, mounts | [`inventory/lxc-map.md`](./inventory/lxc-map.md) |
| Post-rebuild verification checklist | [`docs/verify.md`](./docs/verify.md) |
| PVE automation scripts | [`automation/pve/README.md`](./automation/pve/README.md) |

## Service guides

| Area | Guide |
| --- | --- |
| Media/arr stack | [`services/media-arr/Multimedia-Setup.md`](./services/media-arr/Multimedia-Setup.md) |
| Live arr/UI settings inventory | [`services/media-arr/arr-live-settings.md`](./services/media-arr/arr-live-settings.md) |
| Homepage dashboard | [`dashboards/homepage/Readme.md`](./dashboards/homepage/Readme.md) |
| Proxy, Caddy, Cloudflare Tunnel, Cloudflare MCP | [`infrastructure/proxy/Access-Setup.md`](./infrastructure/proxy/Access-Setup.md) |
| AI integration overview | [`services/ai/integration.md`](./services/ai/integration.md) |
| Hermes | [`agent/hermes/README.md`](./agent/hermes/README.md) |
| OmniRoute | [`services/omniroute/README.md`](./services/omniroute/README.md) |
| Beszel | [`services/beszel/README.md`](./services/beszel/README.md) |

## Agent skills

Custom Hermes skills exported from this profile live under [`agent/skills/`](./agent/skills/), preserving Hermes category/name layout. Runtime state, curator backups, locks, and usage files are intentionally excluded.

## Current homelab defaults to preserve

Unless a specific service guide says otherwise, service LXCs should preserve the current setup:

```text
features: nesting=1
unprivileged: 0 / Unprivileged container=No
CPU advanced/default behavior preserved unless a service explicitly needs a limit
```

## Secret safety

Do not commit real secrets. Use committed examples such as `.env.example` and service-specific `*.env.example` files, then create local ignored `.env` files during restore.

Before committing config/example changes, run:

```bash
./automation/check-env.sh
git diff --check
```
