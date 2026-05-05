# Homelab Rebuild Kanban

Goal: keep the repo focused on the remaining documentation normalization work. Script smoke tests, fresh restore tests, proxy automation, and other optional validation/automation items were intentionally removed from this board for now.

## Board conventions

Statuses:
- In Progress: actively being edited/researched
- Ready: clear enough to work next
- Done: documentation normalized and linked from the main guide

Labels:
- `docs`: Markdown guide/update
- `secret-safe`: must avoid committing real tokens/passwords

---

## In Progress

### HL-DOC-050 — Normalize media/arr, proxy, and Glance docs
- Labels: `docs`, `secret-safe`
- Files:
  - `server-arr/Multimedia-Setup.md`
  - `server-arr/arr-live-settings.md`
  - `server-arr/arr-stack.yml`
  - `proxy/Access-Setup.md`
  - `proxy/config/Caddyfile.example`
  - `glance/Readme.md`
  - `glance/.env.example`
- Goal: make service docs consistent with the top-level rebuild flow.
- Include:
  - Media LXC paths, mounts, Docker compose usage, and UI settings summary.
  - qBittorrent note: configure it to operate only over the VPN connection.
  - Proxy LXC one-container pattern: Caddy + Cloudflare Tunnel + Cloudflare MCP.
  - Caddy/Cloudflare placeholders and secret storage guidance.
  - Glance deployment, widget env vars, and maintenance process.
- Acceptance criteria:
  - [ ] Service docs have consistent structure and links.
  - [ ] Secret placeholders/env vars are used everywhere.

---

## Ready

### HL-DOC-060 — Normalize backup, restore, and secret inventory docs
- Labels: `docs`, `secret-safe`
- Files:
  - `Fresh-Homelab-Rebuild.md`
  - `VERIFY.md`
  - `.env.example`
  - service-specific `.env.example` files
- Goal: document what must be backed up and which secrets/accounts must be recreated, without storing actual values.
- Include:
  - Proxmox LXC config files.
  - Docker config directories under `/docker/*`.
  - Media/data mounts.
  - Caddy config/env and Cloudflare tunnel credentials if locally stored.
  - Hermes/OmniRoute/Hindsight data/config/db paths.
  - Glance config/API keys.
  - Secret/account inventory with generation location and minimum scopes.
- Acceptance criteria:
  - [ ] Restore checklist says what to back up and where each item lives.
  - [ ] `.env.example` files cover required variables without real secrets.

---

## Done

### HL-DOC-040 — Normalize AI service docs
- Labels: `docs`, `secret-safe`
- Status: completed.
- Files:
  - `omniroute/README.md`
  - `hindsight/README.md`
  - `ai/integration.md`
- Goal: make Hermes + OmniRoute + Hindsight docs consistent and secret-safe.
- Progress:
  - Clarified the end-to-end AI request flow: Hermes -> OmniRoute for model calls, Hermes -> Hindsight for memory, and Hindsight -> OmniRoute for its own LLM extraction work.
  - Normalized canonical AI service URLs and LXC targets from `inventory/lxc-map.md`.
  - Expanded OmniRoute rebuild notes for private env creation, generated secrets, systemd checks, separate Hermes/Hindsight API keys, and placeholder-only onboarding/password recovery.
  - Clarified Hindsight Docker startup dependency on OmniRoute, persistent data path, health endpoint, and system-level Hermes gateway restart.
  - Replaced stale open-capture notes in the integration guide with a practical rebuild summary and private data/config locations.
  - Documented common failure separation between healthy local services and upstream provider/provider-circuit errors.
- Acceptance criteria:
  - [x] AI stack can be understood from the docs without inspecting live LXCs.
  - [x] No provider keys, API keys, passwords, or tokens are committed.

### HL-DOC-030 — Finish Hermes setup guide normalization
- Labels: `docs`, `secret-safe`
- Status: completed.
- Files:
  - `hermes/README.md`
  - `hermes/config/config.system.example.yaml`
  - `ai/integration.md`
- Goal: make Hermes install/config/gateway docs complete enough to rebuild without remembering manual steps.
- Progress:
  - Clarified Hermes LXC target assumptions: privileged container, `nesting=1`, static IP, OmniRoute model route, Hindsight memory route, and system gateway only.
  - Simplified and sanitized the system-level Hermes config example around current model, memory, platform toolsets, custom OmniRoute provider, Proxmox placeholders, and optional image generation placeholders.
  - Documented placeholder-safe OmniRoute and Hindsight connection details.
  - Added explicit `hermes config set` usage for model/provider changes.
  - Expanded duplicate user/system gateway troubleshooting with symptom, cause, fix, `--system` helper usage, and verification commands.
  - Added secret source guidance for OmniRoute API key, Proxmox token, Discord bot/channel/allowlist IDs, and image generation provider secrets.
- Acceptance criteria:
  - [x] Fresh Hermes LXC can be configured from docs without guessing.
  - [x] Troubleshooting explains the duplicate gateway issue clearly.

### HL-DOC-020 — Normalize canonical LXC inventory and network map
- Labels: `docs`
- Status: completed.
- File: `inventory/lxc-map.md`
- Goal: make the inventory the canonical place for CT IDs, roles, IPs, ports, mounts, and rebuild method.
- Progress:
  - Rewrote the inventory as the canonical network, LXC, service port, and mount map.
  - Added network defaults for subnet, gateway, Proxmox host, `vmbr0`, and proxy/Tunnel pattern.
  - Preserved standard LXC defaults: privileged containers, `nesting=1`, CPU defaults, and static `vmbr0` networking.
  - Expanded CT map with current CT IDs/IPs, creation methods, roles, key ports, mounts/devices, and guide/script links.
  - Added service port tables for Proxmox/PBS/proxy, media/arr, AI/agent services, and utilities.
  - Added mount map, rebuild method legend, audit-helper instructions, and update checklist.
- Acceptance criteria:
  - [x] Fresh rebuild has a clear target IP/hostname/port plan.
  - [x] All major ports exposed by compose/Caddy/Tunnel/AI services are captured.

### HL-DOC-010 — Finish Proxmox base install and storage guide
- Labels: `docs`
- Status: completed.
- File: `Homelab-Setup.md`
- Goal: turn the Proxmox base notes into reproducible documentation.
- Progress:
  - Rewrote the guide as a reproducible Proxmox base install and storage checklist.
  - Added placeholder-safe disk, partition, pool, special vdev, dataset, and verification commands.
  - Documented ZFS properties: `recordsize=1M`, `atime=off`, `xattr=off`, `compression=zstd-4`, `special_small_blocks=512K`.
  - Added Proxmox storage UI settings, LXC defaults, and bind mount pattern `/data/general` -> `/mnt/general`.
  - Linked back to the canonical inventory/defaults file: `inventory/lxc-map.md`.
- Acceptance criteria:
  - [x] Commands are copy/paste-safe with placeholders.
  - [x] Screenshots are optional, not required to understand the steps.

### HL-DOC-001 — Normalize documentation scope and links
- Labels: `docs`
- Status: completed.
- Goal: make sure the documentation set reads as one coherent rebuild guide instead of disconnected notes.
- Progress:
  - Added `README.md` as a short documentation index that points fresh readers to the rebuild runbook first.
  - Updated `Fresh-Homelab-Rebuild.md` to state that it is the main entry point and to link README/architecture/kanban.
  - Replaced old optional smoke-test focused gap list with documentation-normalization gaps only.
  - Updated `ARCHITECTURE.md` navigation wording to point to README, the ordered runbook, inventory, and verification checklist.
- Acceptance criteria:
  - [x] A fresh reader knows which file to open first.
  - [x] Every major service guide is linked from the main runbook.
  - [x] Old/duplicate wording is removed or made clearly historical.

### HL-DOC-900 — Remove non-documentation tasks from board
- Labels: `docs`
- Status: completed by reducing this board to documentation normalization tasks only.
- Notes:
  - Removed script smoke-test tasks.
  - Removed fresh restore/live validation tasks as active board items.
  - Removed optional automation tasks such as proxy script creation and extra validators.
  - Kept documentation-only normalization tasks as the current focus.
