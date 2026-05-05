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

### HL-DOC-001 — Normalize documentation scope and links
- Labels: `docs`
- Goal: make sure the documentation set reads as one coherent rebuild guide instead of disconnected notes.
- Files:
  - `Fresh-Homelab-Rebuild.md`
  - `ARCHITECTURE.md`
  - `VERIFY.md`
  - `inventory/lxc-map.md`
  - service guides under `server-arr/`, `proxy/`, `glance/`, `hermes/`, `omniroute/`, `hindsight/`, and `ai/`
- Include:
  - One clear top-level entry point.
  - Consistent links from the runbook to every service guide.
  - Consistent wording for current homelab defaults: nesting enabled, privileged LXCs, and preserved CPU defaults.
  - Clear note that secrets must be recreated from dashboards/env examples, not committed.
- Acceptance criteria:
  - [ ] A fresh reader knows which file to open first.
  - [ ] Every major service guide is linked from the main runbook.
  - [ ] Old/duplicate wording is removed or made clearly historical.

---

## Ready

### HL-DOC-010 — Finish Proxmox base install and storage guide
- Labels: `docs`
- File: `Homelab-Setup.md`
- Goal: turn the Proxmox base notes into reproducible documentation.
- Include:
  - Disk selection and ZFS RAID0 boot setup.
  - SSD/HDD pool layout.
  - Partition commands with placeholders.
  - ZFS properties: `recordsize=1M`, `atime=off`, `xattr=off`, `compression=zstd-4`, `special_small_blocks=512K`.
  - Dataset layout.
  - Proxmox storage UI settings.
  - LXC defaults that preserve the current setup: nesting enabled, privileged container / `Unprivileged container=No`, and CPU defaults.
  - Bind mount pattern `/data/general` -> `/mnt/general`.
  - Link to canonical inventory/defaults file: `inventory/lxc-map.md`.
- Acceptance criteria:
  - [ ] Commands are copy/paste-safe with placeholders.
  - [ ] Screenshots are optional, not required to understand the steps.

### HL-DOC-020 — Normalize canonical LXC inventory and network map
- Labels: `docs`
- File: `inventory/lxc-map.md`
- Goal: make the inventory the canonical place for CT IDs, roles, IPs, ports, mounts, and rebuild method.
- Include:
  - Current CT IDs/IPs for all known LXCs.
  - Current common mounts and LXC defaults.
  - Creation method: Community Scripts vs repo manual script vs manual documented setup.
  - Ports exposed by compose, Caddy, Tunnel, and AI services.
  - Links back to relevant service docs.
- Acceptance criteria:
  - [ ] Fresh rebuild has a clear target IP/hostname/port plan.
  - [ ] All major ports exposed by compose/Caddy/Tunnel/AI services are captured.

### HL-DOC-030 — Finish Hermes setup guide normalization
- Labels: `docs`, `secret-safe`
- Files:
  - `hermes/README.md`
  - `hermes/config/config.system.example.yaml`
  - `ai/integration.md`
- Goal: make Hermes install/config/gateway docs complete enough to rebuild without remembering manual steps.
- Include:
  - LXC assumptions: nesting enabled and privileged container.
  - Sanitized system-level Hermes config example.
  - OmniRoute connection details using placeholders.
  - Hindsight memory connection details using placeholders.
  - Duplicate user/system gateway troubleshooting: symptom, cause, fix, and verification.
  - Useful command: `hermes config set` to change the model.
  - Secret guide: where to create OmniRoute API key, Proxmox token, and Discord allowlist ID.
- Acceptance criteria:
  - [ ] Fresh Hermes LXC can be configured from docs without guessing.
  - [ ] Troubleshooting explains the duplicate gateway issue clearly.

### HL-DOC-040 — Normalize AI service docs
- Labels: `docs`, `secret-safe`
- Files:
  - `omniroute/README.md`
  - `hindsight/README.md`
  - `ai/integration.md`
- Goal: make Hermes + OmniRoute + Hindsight docs consistent and secret-safe.
- Include:
  - OmniRoute install/service/storage paths.
  - OmniRoute onboarding/password recovery notes using placeholders only.
  - Hindsight Docker ports, health endpoint, and data path.
  - Integration startup order and end-to-end request flow.
  - Common failure modes: provider errors, OmniRoute onboarding/login issue, Hindsight health vs upstream provider errors.
- Acceptance criteria:
  - [ ] AI stack can be understood from the docs without inspecting live LXCs.
  - [ ] No provider keys, API keys, passwords, or tokens are committed.

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

### HL-DOC-900 — Remove non-documentation tasks from board
- Labels: `docs`
- Status: completed by reducing this board to documentation normalization tasks only.
- Notes:
  - Removed script smoke-test tasks.
  - Removed fresh restore/live validation tasks as active board items.
  - Removed optional automation tasks such as proxy script creation and extra validators.
  - Kept documentation-only normalization tasks as the current focus.
