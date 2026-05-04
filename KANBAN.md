# Homelab Rebuild Kanban

Goal: make this repo a reproducible source of truth so a fresh Proxmox homelab can be rebuilt to match the current setup with minimal guessing.

## Board conventions

Statuses:
- Backlog: known work not started
- Ready: clear enough to work next
- In Progress: actively being edited/researched
- Blocked: needs credentials, live machine details, screenshots, or decisions
- Done: documented, verified, and linked from main guide

Labels:
- `docs`: Markdown guide/update
- `config`: compose/config/example files
- `secret-safe`: must avoid committing real tokens/passwords
- `verify`: needs live validation on homelab
- `parallel`: safe for subagent/research work

---

## In Progress


### HL-130 — Add Proxmox shell scripts for manual LXCs
- Labels: `config`, `docs`, `parallel`, `verify`
- Status: initial scripts added under `scripts/pve/`.
- Progress:
  - Added shared helper: `scripts/pve/lib-lxc.sh`.
  - Added `create-media-arr-lxc.sh`.
  - Added `create-hermes-lxc.sh`.
  - Added `create-omniroute-lxc.sh`.
  - Added `create-hindsight-lxc.sh`.
  - Added `scripts/pve/README.md` with Community Scripts vs manual creation strategy.
  - Updated default storage/template values from live PVE audit: `vm_storage` rootfs and `general:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst` template.
  - Added optional `CPULIMIT` support and matched Hermes/Hindsight/media defaults from live configs where known.
  - First live PVE script test found `pct set --unprivileged 0` fails because `unprivileged` is read-only after create; fixed helper to keep it only in `pct create` args.
  - Verified `create-omniroute-lxc.sh` end-to-end on PVE with temporary CTID 901; script created the container, installed packages/service, printed expected config, and cleanup removed CT 901.
- Remaining:
  - Smoke-test Hermes/media scripts on actual PVE host with temporary CTIDs, or verify from a fresh rebuild.
  - Optional: smoke-test Hindsight script with a temporary CTID through Docker install; exact live Docker run pattern has been captured.
  - Retest OmniRoute fresh login/onboarding flow after latest script update; live package/service/DB layout is now documented.
- Hermes script update:
  - Live Hermes install layout verified from CT `108`: `/usr/local/lib/hermes-agent`, `/usr/local/bin/hermes`, `/root/.hermes`.
  - `create-hermes-lxc.sh` now runs the official Hermes installer with `--skip-setup` and copies sanitized Hermes + Hindsight client config examples.
  - Live PVE smoke test with temporary CTID `902` successfully created the LXC and ran the Hermes installer, but failed copying the new Hindsight example because the test archive missed the untracked file; cleanup removed CT `902` and temp files. Retest after commit if desired.
- Acceptance criteria:
  - [x] Scripts are secret-safe and use placeholders/env vars.
  - [x] Scripts preserve `nesting=1` and privileged container defaults.
  - [ ] Scripts have been run successfully on fresh Proxmox.

### HL-080 — Update proxy LXC guide for Caddy + Cloudflare Tunnel + Cloudflare MCP
- Labels: `docs`, `config`, `secret-safe`, `parallel`, `verify`
- Existing file: `proxy/Access-Setup.md`
- Progress:
  - Expanded proxy LXC rebuild guide.
  - Added sanitized `proxy/config/Caddyfile.example`.
  - Documented Cloudflare Tunnel, Access, Caddy DNS challenge, DDNS, and `CF_API_TOKEN` storage.
  - Verified live proxy LXC `201` via PVE SSH: it runs Caddy, Cloudflare Tunnel, Node/npm/npx, and `/usr/local/bin/cloudflare-mcp` together in one LXC.
  - Rewrote `proxy/Access-Setup.md` to make the one-LXC pattern canonical and removed confusing separate-Caddy/separate-Cloudflared guidance.
  - Documented the sanitized Cloudflare MCP wrapper flow using `npx --yes @cloudflare/mcp-server-cloudflare run` with `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` placeholders.
- Remaining:
  - Optional: create a full automated `create-proxy-lxc.sh`; current documented path is Community Scripts Caddy LXC plus manual post-install.
- Acceptance criteria:
  - [x] Token scopes are documented without real secrets.
  - [x] Caddy and Tunnel validation commands are included.
  - [x] Cloudflare MCP restore steps are documented and verified from live LXC layout.

### HL-001 — Repository audit and rebuild scope
- Labels: `docs`, `parallel`
- Goal: inventory existing files and define what must be added for repeatable fresh setup.
- Current findings:
  - Existing guides: `Homelab-Setup.md`, `server-arr/Multimedia-Setup.md`, `proxy/Access-Setup.md`, `glance/Readme.md`
  - Existing configs: `server-arr/arr-stack.yml`, `proxy/config/Caddyfile`, `glance/*.yml`, `.env`
  - Missing areas: Hermes LXC, OmniRoute LXC, Hindsight LXC, how they link together, Cloudflare MCP, troubleshooting notes.
- Acceptance criteria:
  - Main roadmap exists.
  - Workstreams are split into actionable tasks.

---

## Ready

### HL-010 — Create top-level fresh rebuild runbook
- Labels: `docs`
- Status: initial version added at `Fresh-Homelab-Rebuild.md`; proxy/Hermes sections updated from live inspection.
- Proposed file: `README.md` or `Fresh-Homelab-Rebuild.md`
- Goal: one entrypoint that orders the full rebuild from bare Proxmox to working services.
- Include:
  - Hardware/storage assumptions
  - Required domains/accounts/secrets checklist
  - LXC inventory table
  - Creation method for each LXC: Community Scripts vs repo manual script
  - Network/IP/DNS map
  - Rebuild order
  - Validation checklist
- Acceptance criteria:
  - A new user can follow the runbook and know which file to open next.
  - Every LXC/service links to its detailed guide.

### HL-020 — Document Proxmox base install and storage exactly
- Labels: `docs`, `verify`
- Existing file: `Homelab-Setup.md`
- Goal: turn current notes into reproducible steps.
- Include:
  - Disk selection and ZFS RAID0 boot setup
  - SSD/HDD pool layout
  - Partition commands with placeholders
  - ZFS properties: `recordsize=1M`, `atime=off`, `xattr=off`, `compression=zstd-4`, `special_small_blocks=512K`
  - Dataset layout
  - Proxmox storage UI settings
  - LXC defaults must preserve current setup: nesting enabled, privileged container / `Unprivileged container=No`, CPU advanced settings
  - Bind mount pattern `/data/general` -> `/mnt/general`
  - Link to canonical inventory/defaults file: `inventory/lxc-map.md`
- Acceptance criteria:
  - Commands are copy/paste-safe with placeholders.
  - Screenshots are optional, not required to understand the steps.

### HL-030 — Define canonical LXC inventory and network map
- Labels: `docs`, `config`, `verify`
- File: `inventory/lxc-map.md`
- Goal: list every LXC and its role/IP/ports/mounts plus whether it is created by Community Scripts or repo scripts.
- Progress:
  - Added canonical LXC defaults and service table.
  - Added creation method column for Community Scripts vs manual repo scripts.
  - Added `scripts/pve/audit-lxcs.sh` to capture live CT config into ignored local file `inventory/live-lxc-audit.md` for review.
  - Added `inventory/live-lxc-audit.example.md` to show the safe committed format.
  - Ran the audit on the Proxmox host via SSH and copied only reviewed, non-secret inventory values into `inventory/lxc-map.md`.
  - Captured current CT IDs/IPs for CTs 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 201, and 250.
  - Captured current common mounts and LXC defaults from live configs.
- Include known LXCs:
  - media/arr stack LXC
  - proxy LXC: Caddy + Cloudflare Tunnel + Cloudflare MCP
  - hermes LXC
  - omniroute LXC
  - hindsight LXC
  - optional Jellyfin custom LXC if separated from arr stack
- Acceptance criteria:
  - [x] Fresh rebuild has a clear target IP/hostname plan.
  - [ ] All ports exposed by compose/Caddy/Tunnel are captured.
  - [x] There is a repeatable way to audit current live LXC config before rebuild.

### HL-040 — Add Hermes LXC setup guide
- Labels: `docs`, `config`, `parallel`, `verify`
- Proposed file: `ai/hermes-setup.md`
- Goal: document install, config, model/provider setup, gateway configuration, and links to OmniRoute/Hindsight.
- Include from current status:
  - New LXC setup for Hermes using current LXC defaults: nesting enabled and privileged container
  - Current sanitized system-level Hermes config example copied from live config: `hermes/config/config.system.example.yaml`
  - How Hermes connects to OmniRoute gateway/router
  - How Hermes uses Hindsight memory service
  - Troubleshooting: disable duplicate gateway when both user-level and system-level gateway exist
  - Useful command: `hermes config set` to change the model
  - Secret guide: explain where to create OmniRoute API key, Proxmox token, Discord allowlist ID
- Acceptance criteria:
  - Fresh Hermes LXC can be configured without remembering manual steps.
  - Troubleshooting section explains symptom, cause, fix, and verification.

### HL-050 — Add OmniRoute LXC setup guide
- Labels: `docs`, `config`, `parallel`, `verify`
- File: `omniroute/README.md`
- Goal: document OmniRoute install, onboarding, password/database workaround, gateway endpoints, and Hermes integration.
- Progress:
  - Verified live OmniRoute LXC `107` via PVE SSH: Debian 13, IP `192.168.1.109`, privileged (`unprivileged: 0`), `features: nesting=1`, `memory: 4096`, `swap: 512`, rootfs `4G`.
  - Verified live package/deployment: npm package `omniroute@3.7.8`, binary `/usr/bin/omniroute -> /usr/lib/node_modules/omniroute/bin/omniroute.mjs`, Node `v24.15.0`.
  - Verified live service: `/etc/systemd/system/omniroute.service`, `ExecStart=/usr/bin/omniroute`, `PORT=20128`, `DATA_DIR=/root/.omniroute`, listens on `0.0.0.0:20128`.
  - Verified persistence path: `/root/.omniroute/storage.sqlite`, WAL/SHM files, `db_backups`, and `call_logs`.
  - Added sanitized examples: `omniroute/config/omniroute.env.example` and `omniroute/systemd/omniroute.service.example`.
  - Documented live sanitized SQLite settings rows and model aliases without real credentials/tokens.
  - Documented onboarding/password fix: prefer `INITIAL_PASSWORD`; fallback to `key_value` rows `password`, `setupComplete`, `requireLogin` in `storage.sqlite`.
  - Updated `create-omniroute-lxc.sh` to match the live binary path/service shape and keep secrets in `/root/.omniroute/omniroute.env`.
- Acceptance criteria:
  - [x] Workaround is documented safely with placeholders.
  - [x] The exact DB update command is captured from the live schema.
  - [ ] Full fresh login/onboarding flow retested after the script update.

### HL-060 — Add Hindsight LXC setup guide
- Labels: `docs`, `config`, `parallel`, `verify`
- File: `hindsight/README.md`
- Goal: document Hindsight install, persistence/storage, API endpoint, and Hermes integration.
- Progress:
  - Verified live Hindsight LXC `109` via PVE SSH: Debian 12, privileged, `features: nesting=1`, IP `192.168.1.111`, `memory: 8192`, `swap: 1024`, `cpulimit: 4`, rootfs `20G`.
  - Verified deployment uses Docker container `hindsight` from `ghcr.io/vectorize-io/hindsight:latest`, restart policy `unless-stopped`.
  - Verified ports: API `8888`, control plane/UI `9999`.
  - Verified persistent data bind mount: `/root/.hindsight-docker -> /home/hindsight/.pg0`.
  - Verified health endpoint: `http://127.0.0.1:8888/health` returns `{"status":"healthy","database":"connected"}`.
  - Added sanitized `hindsight/config/hindsight.env.example` copied from live env shape, with secret/API key placeholder only.
  - Updated `create-hindsight-lxc.sh` to install Docker, copy env example, create `/root/.hindsight-docker`, and print the live Docker run command.
  - Documented live provider warning: Hindsight can be healthy while OmniRoute/upstream provider returns `provider_circuit_open` errors.
- Acceptance criteria:
  - [x] Memory data path is documented for backup/restore.
  - [x] Hermes client endpoint and bank are documented.
  - [x] Health checks are documented.
  - [ ] Full backup/restore test performed on a disposable or rebuilt LXC.

### HL-070 — Document AI services integration: Hermes + OmniRoute + Hindsight
- Labels: `docs`, `config`, `parallel`, `verify`
- File: `ai/integration.md`
- Status: initial integration guide added and linked from `Fresh-Homelab-Rebuild.md`.
- Goal: one diagram/table showing how the three AI LXCs link together.
- Progress:
  - Added architecture/request-flow diagram.
  - Documented Hermes -> OmniRoute model flow.
  - Documented Hermes -> Hindsight memory flow.
  - Added startup order and end-to-end verification checklist.
  - Added troubleshooting map for provider, onboarding, duplicate gateway, and memory issues.
  - Verified Hermes live install/service layout from CT `108`: system service `hermes-gateway.service`, install dir `/usr/local/lib/hermes-agent`, Hindsight client config `/root/.hermes/hindsight/config.json`.
  - Verified Hermes uses external Hindsight endpoint pattern `http://<hindsight-lxc-ip>:8888` with bank `hermes`.
  - Verified Hindsight live API/control-plane ports and Docker container/data path from CT `109`.
- Acceptance criteria:
  - [x] Clear enough to debug broken integration after fresh install.
  - [x] All live service names/ports have been verified, including Hindsight server.

### HL-090 — Convert Caddyfile into safer template
- Labels: `config`, `secret-safe`, `verify`
- Existing file: `proxy/config/Caddyfile`
- Status: initial sanitized template added at `proxy/config/Caddyfile.example`
- Remaining:
  - Optional `Caddyfile.current.md` notes for real internal mapping if not secret.
  - Fix naming mismatch if `flaresolverr` vs `flaresolver` hostname is intentional/not intentional.
- Acceptance criteria:
  - [x] Fresh setup can copy template and replace placeholders.
  - [x] No private tokens committed.

### HL-100 — Document arr stack exact settings
- Labels: `docs`, `config`, `verify`
- Existing files: `server-arr/Multimedia-Setup.md`, `server-arr/arr-stack.yml`
- Goal: capture all UI settings needed after docker compose starts.
- Include from current status:
  - qBittorrent first password/log lookup and final settings
  - Prowlarr indexer choices, auth, minimum seeders
  - Prowlarr app links to Radarr/Sonarr
  - Radarr/Sonarr root folders, torrent client, remove completed
  - Bazarr providers and language profile
  - Jellyfin/Jellyseerr setup
  - Lingarr/Tdarr/Flaresolverr/QBWrapper settings
- Acceptance criteria:
  - All manual UI steps are listed in order.
  - API key placeholders and where to find them are documented.

### HL-110 — Improve arr stack compose/env safety
- Labels: `config`, `secret-safe`, `verify`
- Existing files: `server-arr/arr-stack.yml`, `.env`
- Goal: make compose portable and secret-safe.
- Include:
  - Add `.env.example`
  - Replace hard-coded PUID/PGID/TZ where useful
  - Normalize `/media` vs `/data` volume paths
  - Check qBittorrent/qbwrapper credentials are all externalized
  - Optional healthchecks
- Acceptance criteria:
  - `docker compose --env-file .env up -d` works after copying `.env.example`.
  - No real secrets in repo.

### HL-120 — Add post-rebuild verification checklist
- Labels: `docs`, `verify`
- Proposed file: `VERIFY.md`
- Goal: fast smoke test after fresh rebuild.
- Include:
  - Proxmox storage and mounts
  - Docker compose containers healthy
  - Caddy validates and serves TLS
  - Cloudflare Tunnel public hostnames reachable
  - Cloudflare Access policy applied
  - Arr stack can search/download/import
  - Jellyfin can scan/play media with GPU if applicable
  - Hermes can route model request through OmniRoute
  - Hermes can save/recall memory via Hindsight
- Acceptance criteria:
  - Pass/fail checklist exists for each critical service.

---

## Backlog

### HL-130 — Add backup and restore plan
- Labels: `docs`, `verify`
- Goal: document what must be backed up to recreate current state exactly.
- Include:
  - Proxmox LXC config files
  - Docker config directories under `/docker/*`
  - Media/data mounts
  - Caddy config/env
  - Cloudflare tunnel credentials if locally stored
  - Hermes/OmniRoute/Hindsight data/config/db
  - Glance config/API keys
- Acceptance criteria:
  - Restore steps are documented and tested for at least one service.

### HL-140 — Add service ownership and secret inventory
- Labels: `docs`, `secret-safe`
- Goal: create a private checklist of required accounts/tokens without storing the actual values.
- Include:
  - Cloudflare DNS token
  - Cloudflare Tunnel token
  - Cloudflare MCP token/config
  - Proxmox API token
  - PBS API token
  - Jellyfin API key
  - qBittorrent/qbwrapper auth
  - AI provider keys used by OmniRoute/Hermes
- Acceptance criteria:
  - `.env.example` has every required variable.
  - Docs say where to generate each secret and minimum scopes.

### HL-150 — Update Glance/dashboard docs
- Labels: `docs`, `config`, `verify`
- Existing folder: `glance/`
- Goal: document dashboard deployment and widgets.
- Include:
  - Proxmox/PBS API token setup already in `glance/Readme.md`
  - Jellyfin widget API key
  - qBittorrent/qbwrapper widget auth
  - Service list maintenance process
- Acceptance criteria:
  - Dashboard can be recreated after fresh setup.

### HL-160 — Add automation scripts where simple and stable
- Labels: `config`, `parallel`
- Goal: reduce manual repetition without overengineering.
- Candidate scripts:
  - `scripts/check-env.sh`
  - `scripts/validate-compose.sh`
  - `scripts/render-caddy-template.sh`
  - `scripts/smoke-test.sh`
- Acceptance criteria:
  - Scripts are simple, readable, and optional.

### HL-170 — Add architecture diagram
- Labels: `docs`
- Goal: visual map of LXCs, DNS, proxy paths, storage, and AI services.
- Acceptance criteria:
  - Diagram exists in Mermaid or Markdown table.

---

## Blocked / Needs user or live homelab details

### HL-200 — Capture exact current IPs, hostnames, CT IDs, and mounts
- Labels: `docs`, `verify`
- Needed:
  - Proxmox node name
  - LXC IDs/names/IPs
  - Storage pool/dataset names
  - Bind mount source/destination paths
  - Domain/subdomain list

### HL-210 — Capture exact Hermes/OmniRoute/Hindsight install/config commands
- Labels: `docs`, `config`, `verify`
- Needed:
  - Install method used for each service
  - Config file paths
  - Service manager commands
  - Ports and health endpoints
  - Exact duplicate gateway fix
  - Exact OmniRoute password DB update command

### HL-220 — Capture current arr UI settings screenshots/exports if available
- Labels: `docs`, `verify`
- Needed:
  - Radarr/Sonarr/Prowlarr/Bazarr settings screenshots or config export
  - qBittorrent settings
  - Jellyfin libraries/transcoding settings

---

## Suggested parallel subagent workstreams

1. AI stack docs: research/structure Hermes + OmniRoute + Hindsight guides and integration doc.
2. Proxy docs: update Caddy/Cloudflare Tunnel/Cloudflare MCP guide and Caddyfile template.
3. Arr stack docs/config: expand manual settings and improve `.env.example`/compose portability.
4. Proxmox/rebuild docs: improve top-level runbook, LXC inventory, storage, verification, backups.

