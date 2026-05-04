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
glance/.env.example
glance/widgets/proxmox-ve.yml
glance/widgets/proxmox-pbs.yml
glance/widgets/jellyfin.yml
glance/widgets/qbittorrent.yml
```

These files mirror the current live dashboard structure but keep secrets in environment variables.

## Fresh install / restore

Inside CT `101` after Docker is installed and `/docker` is mounted:

```bash
mkdir -p /docker/glance/widgets
cd /root/repos/multimedia-server
cp glance/glance.yml /docker/glance/glance.yml
cp glance/widgets/*.yml /docker/glance/widgets/
cp glance/.env.example /docker/glance/.env
chmod 600 /docker/glance/.env
```

Edit `/docker/glance/.env` and replace all placeholders with locally recreated secrets.

Run Glance:

```bash
docker run -d \
  --name glance \
  --restart unless-stopped \
  --env-file /docker/glance/.env \
  -p 8081:8080 \
  -v /docker/glance:/app/config \
  glanceapp/glance
```

If the container already exists:

```bash
docker rm -f glance
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

```bash
docker restart glance
docker logs --tail 50 glance
```

Glance also detects config file changes and reloads, but a restart is the simplest restore-time check.

## Verification

From CT `101`:

```bash
docker ps --filter name=glance
docker logs --tail 50 glance
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
- Monitor checks are green for expected running services.

## Backup / restore

Back up:

```bash
tar -C /docker -czf /root/glance-config-$(date +%F).tgz glance
```

Restore:

```bash
mkdir -p /docker
tar -C /docker -xzf /root/glance-config-YYYY-MM-DD.tgz
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
