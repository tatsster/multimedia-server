# Multimedia Homelab Rebuild Docs

This repository is the documentation source of truth for rebuilding the current Proxmox-based multimedia and local-AI homelab.

## Start here

Open the main runbook first:

- [`Fresh-Homelab-Rebuild.md`](./Fresh-Homelab-Rebuild.md)

That runbook links out to the architecture map, LXC inventory, service guides, secret/env examples, and verification checklist in the intended rebuild order.

## Documentation map

| Need | File |
| --- | --- |
| Rebuild order / main checklist | [`Fresh-Homelab-Rebuild.md`](./Fresh-Homelab-Rebuild.md) |
| High-level architecture and service paths | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Proxmox base install/storage notes | [`Homelab-Setup.md`](./Homelab-Setup.md) |
| Canonical LXC IDs, IPs, ports, mounts | [`inventory/lxc-map.md`](./inventory/lxc-map.md) |
| Post-rebuild verification checklist | [`VERIFY.md`](./VERIFY.md) |
| Current documentation task board | [`KANBAN.md`](./KANBAN.md) |

## Service guides

| Area | Guide |
| --- | --- |
| Media/arr stack | [`server-arr/Multimedia-Setup.md`](./server-arr/Multimedia-Setup.md) |
| Live arr/UI settings inventory | [`server-arr/arr-live-settings.md`](./server-arr/arr-live-settings.md) |
| Proxy, Caddy, Cloudflare Tunnel, Cloudflare MCP | [`proxy/Access-Setup.md`](./proxy/Access-Setup.md) |
| Glance dashboard | [`glance/Readme.md`](./glance/Readme.md) |
| AI integration overview | [`ai/integration.md`](./ai/integration.md) |
| Hermes | [`hermes/README.md`](./hermes/README.md) |
| OmniRoute | [`omniroute/README.md`](./omniroute/README.md) |
| Hindsight | [`hindsight/README.md`](./hindsight/README.md) |

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
./scripts/check-env.sh
git diff --check
```
