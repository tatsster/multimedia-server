# Homepage Widgets and Dockge Migration Design

## Intent

Fix failed Homepage OmniRoute 7-day usage widget, retain normal Wizarr card under Arr-suite, add useful Jellyseerr request metrics, and migrate CT101 container management from Portainer to Dockge without moving data or cloning LXC.

## Current state and evidence

### Homepage

- CT112 `homepage`, `192.168.1.114`, source installation managed by systemd. `/opt/homepage/package.json` already reports Homepage `2.6.0`; `next-server (v16.3.8)` is Next.js framework version, not Homepage version.
- Live config: `/opt/homepage/config/services.yaml`.
- Live environment: `/opt/homepage/.env`.
- Repo config: `dashboards/homepage/`.
- Live and repo OmniRoute widget point to `http://192.168.1.109:20129/summary?range=7d`.
- Live Wizarr card already sits in `Arr-suite`; keep it as normal service card without data widget.
- Live Jellyseerr card has no widget. Existing Jellyfin widget is unrelated and remains unchanged.
- Repo has unrelated uncommitted Finder changes in `dashboards/homepage/services.yaml` and `dashboards/homepage/Readme.md`. This work must preserve them and must not stage or rewrite them accidentally.

### OmniRoute metrics proxy

- CT107 `omniroute`, `192.168.1.109`.
- OmniRoute container: `diegosouzapw/omniroute:latest`, port `20128`, healthy.
- Metrics proxy: `omniroute-metrics-proxy:local`, port `20129`, healthy by shallow `/health` check.
- Homepage and proxy shared tokens exist and match.
- Authenticated `/summary?range=7d` returns HTTP 500:

  ```text
  EACCES: permission denied, open '/app/omniroute-data/server.env'
  ```

- Proxy image runs as `node` UID/GID 1000.
- Host data directory is `root:root 0750`; `server.env` is `root:root 0600`.
- `/health` does not read `server.env`, so Docker health remains green while summary requests fail.
- Running `/app/server.js` hash matches repo source. Failure is access design, not source drift.

### Wizarr

- CT109 `wizarr`, `192.168.1.119:5690`, app version `2026.10.1`.
- `/health` returns 200.
- Homepage `2.6.0` has no native `wizarr` widget. User chose normal service card with no extra metrics.

### Jellyseerr

- CT103 `jellyseerr`, `192.168.1.105:5055`, now runs Seerr `3.4.1`.
- `/api/v1/status` returns 200.
- Existing API key is present in `/opt/seerr/config/settings.json`; Homepage does not have `HOMEPAGE_VAR_JELLYSEERR_KEY` set live.
- Authenticated `/api/v1/request/count` and `/api/v1/issue/count` both return 200.
- Homepage `2.6.0` has native `type: seerr`; legacy `jellyseerr` and `overseerr` types are aliases.
- Allowed fields are `pending`, `approved`, `available`, `completed`, `processing`, and `issues`, with at most four displayed.

### Portainer and media stack

- CT101 `multimedia`, `192.168.1.103`, Docker `28.3.3`, Compose `v2.39.1`.
- Portainer image: `portainer/portainer-ce:lts`, standalone container, ports `8000` and `9443`, `portainer_data` volume.
- One Portainer-managed Compose project, `servarr`, contains:
  - `prowlarr`
  - `sonarr`
  - `tdarr`
  - `flaresolverr`
  - `qbittorrent`
  - `radarr`
  - `bazarr`
  - `qbproxy` (`qbwrapper` service)
- Source exists at `portainer_data/compose/3/docker-compose.yml`; environment file is `stack.env`.
- Persistent application data uses existing bind mounts under `/docker/*` and `/media`.
- Tdarr requires `/dev/dri`.
- FlareSolverr uses anonymous volume `ad8ad0d58ebbdf01785b61c4e5788b881c76ac413cd9df6f61af9eae10ecff38` at `/config`.
- Four Docker volumes exist and must not be deleted.
- `qbproxy` is already restart-looping because qBittorrent login fails. Migration must preserve configuration and report this as pre-existing, not count it as a new regression.
- `portainer.liftlab.dev` is protected by Cloudflare Access through remotely managed Cloudflare Tunnel.

## Selected approach

Use phased in-place migration.

- Install Dockge beside Portainer on CT101.
- Import exact `servarr` stack into Dockge-managed files.
- Validate config and runtime parity before cutover.
- Recreate only `servarr` under Dockge control.
- Keep Portainer and `portainer_data` intact until Dockge health gate passes.
- Make Dockge sole stack editor after cutover. After health gate passes, delete Portainer container and routes while retaining `portainer_data` for rollback.

Rejected:

- Big-bang Portainer removal: larger outage and weaker rollback.
- Permanent dual management: Portainer and Dockge can issue conflicting Compose operations.

## Design

### 1. OmniRoute metrics proxy

#### Privilege model

Do not relax permissions on OmniRoute secret files. Keep `/root/omniroute/data` mounted read-only and keep `server.env` at `root:root 0600`.

Proxy startup must:

1. Start with enough privilege to read `server.env`.
2. Read only `JWT_SECRET` into memory.
3. Fail before opening listener if file is absent, unreadable, or lacks `JWT_SECRET`.
4. Drop process privileges to UID/GID 1000.
5. Open HTTP listener only after successful privilege drop.

Use standard Node APIs (`process.setgid`, then `process.setuid`). No extra dependency or helper service.

`makeDashboardJwt()` must use cached in-memory secret instead of re-reading file per request. Never log secret or JWT.

#### Health

`/health` must reflect startup readiness. Since process does not listen until secret load and privilege drop succeed, HTTP 200 means proxy can mint dashboard JWTs. No separate deep-health endpoint needed.

#### Tests

Add one runnable Node test/self-check covering:

- unreadable or missing secret fails startup secret loading;
- missing `JWT_SECRET` fails;
- valid secret loads;
- JWT generation still works from cached secret;
- privilege-drop code can be injected/stubbed so call order is verified without requiring root in test process.

#### Deployment

Rebuild `omniroute-metrics-proxy:local` from repo source on CT107. Replace only `omniroute-metrics-proxy`; do not restart OmniRoute unless verification proves necessary. Preserve existing token, port, read-only mount, restart policy, and upstream URL.

#### Verification

- Container health: healthy.
- `/health`: HTTP 200.
- Authenticated `/summary?range=7d`: HTTP 200, `status: ok`, `range: 7d`, numeric summary fields.
- Homepage widget API: no error and real 7-day values displayed.
- Proxy logs: no `EACCES`, token, secret, or JWT output.

#### Rollback

Retag or retain previous local image ID before replacement. If new proxy fails, recreate old container from previous image ID with same env, port, mount, and restart policy.

### 2. Homepage 2.6.0 baseline

Target Homepage version is `2.6.0`. Live package metadata already reports `2.6.0`, so implementation must verify installed package and running site before changing widgets rather than perform an unnecessary reinstall. Back up live config and environment first. If preflight no longer reports `2.6.0`, update source installation to exact `v2.6.0`, rebuild production bundle with `pnpm install` and `pnpm build`, restart `homepage.service`, then verify package version, service status, `/api/healthcheck`, and `/api/services`.

### 3. Wizarr Homepage widget

Keep existing Wizarr card under `Arr-suite` as normal Homepage service card. Do not add `widget:` block, `customapi`, `WIZARR_API_KEY`, Homepage environment variable, or extra metrics. Do not restart Wizarr for Homepage work. Do not create duplicate card or new group.

Verification:

- Wizarr `/health`: 200.
- Homepage `/api/services`: exactly one Wizarr card in `Arr-suite`.
- Wizarr card has no `widget:` block and links to existing Wizarr URL.

No Wizarr change means no Wizarr rollback.

### 4. Jellyseerr Homepage widget

Leave existing Jellyfin widget unchanged. Extend Jellyseerr card with native Seerr widget:

```yaml
widget:
  type: seerr
  url: http://192.168.1.105:5055
  key: "{{HOMEPAGE_VAR_JELLYSEERR_KEY}}"
  fields:
    - pending
    - processing
    - completed
    - issues
```

Read existing API key from `/opt/seerr/config/settings.json` without printing it. Store matching value in Homepage live environment as `HOMEPAGE_VAR_JELLYSEERR_KEY`; repo `.env.example` gets placeholder only.

Four fields are selected because Homepage caps Seerr widgets at four. This set shows outstanding requests, active processing, completed requests, and open/total issues. Do not use custom API for Jellyseerr because Homepage `2.6.0` has native `type: seerr`.

Verification:

- `/api/v1/status`: HTTP 200.
- Authenticated `/api/v1/request/count`: HTTP 200 and required numeric fields.
- Authenticated `/api/v1/issue/count`: HTTP 200 and `open`/`total` fields.
- Homepage shows Pending, Processing, Completed, and Issues on existing Jellyseerr card.

Rollback: remove widget block and Homepage environment reference. Existing Jellyseerr card remains.

### 5. Dockge installation on CT101

Install Dockge on same CT and Docker daemon:

- app directory: `/opt/dockge`
- stacks directory: `/opt/stacks`
- UI: `http://192.168.1.103:5001`
- Docker socket mounted read-write as required by Dockge
- `DOCKGE_STACKS_DIR=/opt/stacks`

Use official Dockge Compose deployment with `louislam/dockge:latest`, as requested. Do not use `master` or development tags. Record resolved image digest after install and before every update for rollback.

Dockge must have its own Compose file under `/opt/dockge/compose.yaml`. Do not make Dockge manage itself during initial migration.

#### Manual Dockge updates

Use `louislam/dockge:latest`. Before update, record current image ID. Update with:

```bash
cd /opt/dockge
docker compose pull
docker compose up -d
docker compose ps
```

Then verify `http://192.168.1.103:5001`, Dockge version, `servarr` visibility, and container status. If update fails, set Compose image to retained prior image digest/ID and run `docker compose up -d`.

### 6. Stack import and data preservation

Create `/opt/stacks/servarr/compose.yaml` from Portainer source and `/opt/stacks/servarr/.env` from `stack.env` without printing secret values.

Preserve exactly:

- Compose project name `servarr`;
- all eight service names and container names;
- images and tags;
- static `172.18.0.2` through `172.18.0.9` addresses;
- network subnet `172.18.0.0/24`;
- host ports;
- bind mounts;
- PUID/PGID and other environment values;
- restart policies;
- Tdarr `/dev/dri` device mapping.

Convert FlareSolverr anonymous volume into an explicit external volume reference using existing volume name:

```yaml
volumes:
  flaresolverr_config:
    external: true
    name: ad8ad0d58ebbdf01785b61c4e5788b881c76ac413cd9df6f61af9eae10ecff38
```

Map `flaresolverr_config:/config` in FlareSolverr service. This prevents Compose from creating a new empty volume.

Do not rename, copy, chown, or move `/docker/*`, `/media`, `portainer_data`, or anonymous volumes. Do not use `docker compose down -v`, `docker volume prune`, or any command that deletes volumes.

### 7. Migration sequence

1. Capture redacted preflight inventory and current health/status.
2. Preserve Portainer Compose, `stack.env`, container inspect data, image IDs, networks, mounts, and volume IDs in root-readable rollback directory on CT101.
3. Install and verify Dockge while Portainer and `servarr` continue running.
4. Place imported stack files under `/opt/stacks/servarr`.
5. Run `docker compose --project-name servarr config` and compare rendered config with live container inspect data.
6. Have Dockge scan stacks folder and confirm `servarr` appears.
7. Schedule controlled outage.
8. Stop/recreate `servarr` through Compose/Dockge without volumes deletion. Use same project name so network and container identity remain stable.
9. Verify every service before declaring Dockge owner.
10. Check all eight services in Dockge. Every service must show running; every service with a Docker healthcheck must show healthy; app endpoint probes must pass.
11. Treat `qbproxy` restart-loop as failed gate. Portainer cleanup cannot proceed until `qbproxy` is fixed and running, even though its failure predates migration. Fixing `qbproxy` remains separate work; if it is still unhealthy, stop after successful Dockge migration and leave Portainer container/routes intact.
12. After gate passes, delete Portainer container only. Keep `portainer_data` volume and preserved Portainer stack files for rollback.
13. Remove `portainer.liftlab.dev` Cloudflare Tunnel route, Access application/policy, and DNS record. Verify hostname no longer exposes Portainer.
14. Remove Portainer Homepage card, leaving Dockge as sole container-management card.

Expected downtime: only time needed to recreate eight `servarr` containers. Persistent data remains in place.

### 8. Public route and Homepage

Create `dockge.liftlab.dev` in current remotely managed Cloudflare Tunnel, origin `http://192.168.1.103:5001`.

Add Cloudflare Access application/policy matching protection level used by `portainer.liftlab.dev`. Do not expose Dockge without Access.

Keep `portainer.liftlab.dev` and Portainer origin working until Dockge health gate passes. Then remove Portainer route, Access application/policy, and DNS record after deleting Portainer container. Keep `portainer_data` volume for rollback.

Replace Homepage Portainer card with Dockge:

- name: `Dockge`
- icon: `dockge.png` if supported, otherwise `mdi-docker`
- href: `https://dockge.liftlab.dev`
- site monitor: `http://192.168.1.103:5001`
- description: `Compose stack management`

Do not retain duplicate Portainer card on Homepage after health gate passes. Before gate passes, Portainer remains reachable directly for rollback.

Update:

- live Homepage config/environment as needed;
- `dashboards/homepage/services.yaml`;
- `dashboards/homepage/.env.example`;
- `dashboards/homepage/Readme.md`;
- relevant architecture, inventory, Portainer/Dockge docs, and smoke tests;
- OmniRoute metrics proxy source/tests/docs.

Preserve unrelated Finder edits. Use path-limited staging and review staged diff before commit.

### 9. Verification and acceptance

#### OmniRoute

- Authenticated 7-day summary returns 200 with numeric values.
- Homepage OmniRoute card renders without failure.
- Secret file permissions remain `root:root 0600` and mount remains read-only.
- Proxy HTTP process runs as UID/GID 1000 after startup.

#### Homepage

- `/opt/homepage/package.json` reports `2.6.0`.
- `homepage.service` is active after any rebuild/restart.
- `/api/healthcheck` and `/api/services` return successfully.

#### Wizarr

- Exactly one normal Wizarr service card remains in `Arr-suite`.
- No Wizarr API key, custom API widget, or metrics are added.

#### Jellyseerr

- Existing Jellyfin card remains unchanged.
- Jellyseerr card shows Pending, Processing, Completed, and Issues.
- Both Seerr count endpoints work through Homepage proxy without exposing API key.

#### Dockge

- Dockge UI works internally at `192.168.1.103:5001`.
- Dockge lists `servarr` and all eight services.
- All eight services show running in Dockge before Portainer deletion.
- Every defined Docker healthcheck shows healthy and app endpoint probes pass.
- Pre-existing `qbproxy` restart-loop blocks Portainer deletion until fixed and running. If gate fails, Dockge remains manager but Portainer container/routes stay available; no cleanup claim is made.
- Container names, images, ports, network addresses, bind mounts, external volume, restart policies, and Tdarr device mapping match preflight.
- Existing app data remains present.
- After gate passes, Portainer container is deleted; `portainer_data` remains intact.

#### Public and repository

- `dockge.liftlab.dev` reaches Cloudflare Access, then Dockge after authentication.
- Before health gate, `portainer.liftlab.dev` still reaches Cloudflare Access. After cleanup, Portainer route, Access app/policy, and DNS are absent.
- Homepage `/api/services` shows Dockge, Jellyseerr native widget, normal Wizarr card, and OmniRoute widget; Portainer card is absent after cleanup.
- Homepage YAML parses.
- Repo tests and smoke checks pass.
- Commit contains only intended files plus already-present Finder edits if user explicitly chooses to include them; otherwise Finder edits remain unstaged.
- Push succeeds and commit hash is reported.

## Rollback

### OmniRoute

Recreate metrics proxy from previous image ID and original run parameters. No OmniRoute data rollback needed.

### Widgets

Restore prior live Homepage blocks and environment references, restart Homepage, and verify `/api/services`. Wizarr needs no rollback because its normal card remains unchanged.

### Dockge migration

Before Portainer cleanup:

1. Stop Dockge-managed `servarr` without deleting volumes.
2. Recreate `servarr` from preserved Portainer Compose and `stack.env` with project name `servarr`.
3. Verify original container identities, mounts, network addresses, ports, and service health.
4. Keep Dockge installed but inactive for `servarr`, or stop Dockge.
5. Leave Portainer container, route, and `portainer_data` untouched.

After Portainer container and route deletion:

1. Recreate Portainer container from preserved run/Compose data and existing `portainer_data` volume.
2. Restore Cloudflare Tunnel route, Access application/policy, and DNS if public rollback UI is needed.
3. Recreate `servarr` from preserved Portainer Compose and `stack.env` without deleting volumes.
4. Verify original runtime parity and service health.

Rollback must never use `down -v` or volume prune.

## Non-goals

- Fixing pre-existing `qbproxy` authentication failure.
- Upgrading Homepage beyond `2.6.0`.
- Moving CT101 data to another LXC or host.
- Changing media ownership or recursively chowning `/media`.
- Deleting `portainer_data`.
- Refactoring unrelated Homepage cards or Finder changes.
- Migrating standalone Portainer itself into Dockge.

## Execution model

After written-spec approval, create implementation plan and execute with subagent-driven development:

- fresh implementer per workstream;
- task-scoped review after each workstream;
- no parallel implementation against shared live services;
- final cross-system review;
- stop for destructive, irreversible, security-sensitive, or shared-branch publish actions as required.
