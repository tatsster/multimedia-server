# Glance dashboard rebuild guide

Glance is the homelab dashboard used to monitor service links, Proxmox/PBS status, Jellyfin sessions, qBittorrent activity, and update/news widgets.

Live deployment verified from the media LXC:

| Item | Current value |
|---|---|
| LXC | CT `101` / `multimedia` |
| Internal IP | `192.168.1.103` |
| Container | `glance` |
| Image | `glanceapp/glance` |
| Restart policy | `unless-stopped` |
| Host port | `8081` |
| Container port | `8080` |
| Config mount | `/docker/glance -> /app/config` |
| Entrypoint | `/app/glance --config /app/config/glance.yml` |

Internal URL:

```text
http://192.168.1.103:8081
```

Public/proxied URL is managed by Caddy/Cloudflare in the proxy docs.

## Files in this repo

```text
glance/glance.yml
glance/docker-compose.portainer.yml
glance/.env.example
glance/widgets/proxmox-ve.yml
glance/widgets/proxmox-pbs.yml
glance/widgets/jellyfin.yml
glance/widgets/qbittorrent.yml
glance/widgets/n8n.yml
glance/widgets/omniroute.yml
```

These files mirror the current live dashboard structure but keep secrets in environment variables.

## Fresh install / restore

Run Glance on CT `101` beside the media stack so it can read the same `/docker` mount and call QBWrapper/qbproxy on the local media network. Keep public access in the proxy LXC; Glance itself only needs to listen on LAN port `8081`.

Inside CT `101` after Docker is installed and `/docker` is mounted:

```bash
mkdir -p /docker/glance/widgets
cd /root/repos/multimedia-server
cp glance/glance.yml /docker/glance/glance.yml
cp glance/widgets/*.yml /docker/glance/widgets/
```

### Preferred: Portainer `dashboard` stack

Create or update the real Portainer stack named `dashboard` with this compose file:

```yaml
services:
  glance:
    image: glanceapp/glance
    restart: unless-stopped
    volumes:
      - /docker/glance:/app/config
    env_file:
      - stack.env
    environment:
      - TZ=${TZ:-Asia/Ho_Chi_Minh}
    ports:
      - 8081:8080
```

The same compose is stored at:

```text
glance/docker-compose.portainer.yml
```

Do **not** set `container_name: glance` in the Portainer-managed stack. Let Compose/Portainer name the container, for example `dashboard-glance-1`. This avoids conflicts with old standalone containers.

Add the variables from `glance/.env.example` to the stack environment in Portainer. Portainer stores them in `stack.env`; the widget files read them with `${VAR_NAME}`.

If an old standalone or broken stack container named `glance` exists, remove only that container before deploying the real `dashboard` stack:

```bash
docker rm -f glance
```

Do not redeploy old numeric projects like stack/project `10` from the CLI after Portainer says "created outside of Portainer". Delete that broken stack state and recreate/update the real `dashboard` stack in Portainer.

### Fallback: manual Docker run

Only use this if Portainer is not managing the dashboard:

```bash
cp glance/.env.example /docker/glance/.env
chmod 600 /docker/glance/.env
# edit /docker/glance/.env and replace placeholders with locally recreated secrets

docker run -d \
  --name glance \
  --restart unless-stopped \
  --env-file /docker/glance/.env \
  -p 8081:8080 \
  -v /docker/glance:/app/config \
  glanceapp/glance
```

## Environment variables / secrets

Start from:

```text
glance/.env.example
```

Required variables:

| Variable | Used by | Current pattern | Where to create/get it |
|---|---|---|---|
| `TZ` | Glance container | `Asia/Ho_Chi_Minh` | local preference |
| `PROXMOXVE_URL` | Proxmox VE widget | `192.168.1.101:8006` | Proxmox host/IP |
| `PROXMOXVE_KEY` | Proxmox VE widget | `user@pam!tokenid=replace-with-secret` | Proxmox VE UI -> Datacenter -> Permissions -> API Tokens |
| `PROXMOXBACKUP_URL` | PBS widget | `192.168.1.250:8007` | PBS host/IP |
| `PROXMOXBACKUP_KEY` | PBS widget | `user@pam!tokenid:replace-with-secret` or current PBS token format | PBS UI -> Access Control -> API Tokens |
| `JELLYFIN_URL` | Jellyfin session widget | `https://play.liftlab.dev` | Jellyfin internal/proxied URL |
| `JELLYFIN_KEY` | Jellyfin session widget | API key string | Jellyfin Dashboard -> API Keys |
| `QBW_URL` | qBittorrent widget | `192.168.1.103:9911` | QBWrapper/qbproxy service endpoint |
| `AUTH_TOKEN` | qBittorrent widget | random token | must match `AUTH_TOKEN` in `server-arr/.env` for QBWrapper/qbproxy |
| `N8N_API_URL` | n8n widget | `http://192.168.1.107:5678/api/v1` | n8n public API base URL |
| `N8N_API_KEY` | n8n widget | API key string | n8n UI -> Settings -> n8n API |
| `OMNIROUTE_METRICS_PROXY_URL` | OmniRoute widget | `http://192.168.1.109:20129` | OmniRoute metrics proxy base URL, no trailing slash |
| `OMNIROUTE_DASHBOARD_TOKEN` | OmniRoute widget/proxy | random token | must match the proxy `OMNIROUTE_DASHBOARD_TOKEN`; generate with `openssl rand -hex 32` |

Never commit `/docker/glance/.env` or real token values.

## How to create Proxmox VE API token

1. Open Proxmox portal.
2. Go to **Datacenter**.
3. Expand **Permissions** and click **Groups**.
4. Click **Create**.
5. Name the group something clear, for example `api-ro-users` (`ro` = read-only).
6. Click **Permissions**.
7. Click **Add -> Group Permission**:
   - Path: `/`
   - Group: group from step 5
   - Role: `PVEAuditor`
   - Propagate: checked
8. Expand **Permissions** and click **Users**.
9. Click **Add**:
   - User name: for example `api`
   - Realm: Linux PAM standard authentication
   - Group: group from step 5
10. Expand **Permissions** and click **API Tokens**.
11. Click **Add**:
   - User: user from step 9
   - Token ID: for example `glance`
   - Privilege Separation: checked
12. Go back to **Permissions**.
13. Click **Add -> API Token Permission**:
   - Path: `/`
   - API Token: select the token created in step 11
   - Role: `PVEAuditor`
   - Propagate: checked

Proxmox VE token format used by the widget:

```text
user@pam!tokenid=replace-with-secret
```

Example placeholder:

```text
api@pam!glance=replace-with-token-secret
```

Source: [gethomepage Proxmox widget docs](https://github.com/gethomepage/homepage/blob/main/docs/widgets/services/proxmox.md)

## How to create PBS API token

1. Open Proxmox Backup Server UI.
2. Go to **Configuration -> Access Control**.
3. Create or choose a read-only/audit user for dashboard usage.
4. Create an API token for Glance.
5. Grant only the minimum read permissions needed for datastore/node status.
6. Put the token into `/docker/glance/.env` as `PROXMOXBACKUP_KEY`.

Current widget endpoints:

```text
/api2/json/status/datastore-usage
/api2/json/nodes/pbs/status
/api2/json/nodes/pbs/tasks?errors=true&limit=100
```

## How to create Jellyfin API key

1. Open Jellyfin admin dashboard.
2. Go to **Dashboard -> API Keys**.
3. Create a key named `glance` or similar.
4. Put it in `/docker/glance/.env` as `JELLYFIN_KEY`.

Widget endpoint:

```text
${JELLYFIN_URL}/Sessions?api_key=${JELLYFIN_KEY}&activeWithinSeconds=30
```

## qBittorrent widget / QBWrapper auth

The qBittorrent widget does not call qBittorrent directly. It calls QBWrapper/qbproxy:

```text
http://${QBW_URL}/qb/torrents
```

Current live endpoint pattern:

```text
QBW_URL=192.168.1.103:9911
```

`AUTH_TOKEN` must match the QBWrapper/qbproxy token configured in:

```text
server-arr/.env
```

or the live equivalent used by the media stack. Generate it as a random local token, for example:

```bash
openssl rand -base64 32
```

Do not commit the generated value.

## OmniRoute widget / metrics proxy

The OmniRoute widget does not call OmniRoute dashboard APIs directly. Dashboard APIs such as `/api/usage/analytics` require the browser-style `auth_token` cookie, and the normal OmniRoute `/v1` API key is not accepted there.

Use the small generic metrics proxy in this repo instead:

```text
omniroute/metrics-proxy/
```

The proxy is not Glance-specific. Glance, Homepage, Grafana JSON/API panels, scripts, or any other trusted LAN dashboard can call it.

The proxy runs on CT `107`, reads the local OmniRoute-generated `JWT_SECRET` from `/root/omniroute/data/server.env`, creates a short-lived dashboard JWT per request, calls OmniRoute with `Cookie: auth_token=...`, then returns simplified JSON from `/summary`.

Glance only needs:

```text
OMNIROUTE_METRICS_PROXY_URL=http://192.168.1.109:20129
OMNIROUTE_DASHBOARD_TOKEN=<same random token configured on the proxy>
```

This avoids putting `JWT_SECRET` or a 30-day browser session cookie in Glance config.

Build and run instructions are in:

```text
omniroute/metrics-proxy/README.md
```

## Dashboard layout

Current pages:

### `Homelab`

Full column:

- Proxmox VE stats widget
- Proxmox Backup Server stats widget
- Services monitor:
  - Jellyfin
  - Jellyseerr
  - Portainer
  - VaultWarden
  - n8n
  - Omniroute
  - Hindsight
  - Proxmox Backup Server
- Arr-suite monitor:
  - Radarr
  - Sonarr
  - Prowlarr
  - Bazarr
  - Tdarr
  - FlareSolverr
  - Lingarr
  - qBittorrent

Small column:

- Clock
- Work tasks to-do widget
- Jellyfin active sessions widget
- qBittorrent widget via QBWrapper/qbproxy
- n8n status/executions widget
- OmniRoute model/cache summary widget

### `Update`

Widgets:

- YouTube videos from selected channels
- Reddit groups:
  - `dataisbeautiful`
  - `selfhosted`
  - `MonsterHunterMeta`
- Hacker News
- Calendar
- Weather for Ho Chi Minh City
- GitHub/Docker releases
- Steam specials for Vietnam store region

## Service list maintenance

When adding or changing a service:

1. Update `glance/glance.yml` service monitor entry.
2. Use the public/proxied URL for `url` if this is what you normally click.
3. Add `check-url` with the internal LAN URL when possible so dashboard health does not depend only on public DNS/proxy.
4. Use Dashboard Icons names where possible:
   - `di:<name>` for dashboard-icons
   - `si:<name>` for Simple Icons
   - `sh:<name>` if using selfh.st icons
5. If the service needs credentials, put them in `.env.example` as placeholders and document where to recreate them.
6. Copy updated files to `/docker/glance` and restart the container.

Restart after config changes:

For the Portainer-managed `dashboard` stack, redeploy/restart from Portainer. If you are checking from CT `101`, use the actual Compose-created container name from `docker ps`; do not assume it is named exactly `glance`.

Manual fallback only:

```bash
docker restart glance
docker logs --tail 50 glance
```

Glance also detects config file changes and reloads, but a restart/redeploy is the simplest restore-time check.

## Verification

From CT `101`:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i glance
# Replace <container> with the actual Portainer/Compose container name, e.g. dashboard-glance-1.
docker logs --tail 50 <container>
curl -fsS http://127.0.0.1:8081/ | head
```

From the LAN:

```bash
curl -fsS http://192.168.1.103:8081/ | head
```

Expected:

- HTML page returns.
- Container stays running.
- Proxmox/PBS widgets render without `401`/`403` errors.
- Jellyfin widget shows active sessions or `nothing is playing right now`.
- qBittorrent widget shows torrents or `No torrents found`.
- n8n widget shows health and recent execution counts without `401`/`403` errors.
- OmniRoute widget shows model count and cache stats without exposing keys.
- Monitor checks are green for expected running services.

## Backup / restore

Back up:

```bash
tar -C /docker -czf /root/glance-config-$(date +%F).tgz glance
```

Restore config files:

```bash
mkdir -p /docker
tar -C /docker -xzf /root/glance-config-YYYY-MM-DD.tgz
```

Then redeploy the Portainer `dashboard` stack with `glance/docker-compose.portainer.yml` and stack environment variables from `glance/.env.example`.

Manual fallback only:

```bash
docker rm -f glance || true
docker run -d \
  --name glance \
  --restart unless-stopped \
  --env-file /docker/glance/.env \
  -p 8081:8080 \
  -v /docker/glance:/app/config \
  glanceapp/glance
```

Before committing any restored config back to Git, scan for secrets:

```bash
grep -RInE 'token|secret|api[_-]?key|Authorization|Bearer|PVEAPIToken|PBSAPIToken' glance
```

Only placeholders/env variable references should be committed.
