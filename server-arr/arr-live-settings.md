# Live Arr/Media Settings

This file records the settings inspected from the live media LXCs so a fresh rebuild can be made to behave like the current homelab.

All secrets are intentionally omitted. API keys, qBittorrent passwords, Jellyfin keys, subtitle-provider credentials, webhook URLs, and private tokens must be recreated from each app UI after restore.

## Live LXC inventory

### CT 101 — `multimedia`

| Setting | Live value |
|---|---|
| IP | `192.168.1.103/24` |
| OS | Ubuntu 22.04 LTS |
| Role | Docker arr/media stack |
| Tags | `media` |
| Privilege | privileged / `unprivileged: 0` |
| Nesting | `features: nesting=1` |
| CPU | `cpulimit: 8` |
| Memory / swap | `6144 MB` / `512 MB` |
| Rootfs | `40G` on `vm_storage` |
| Mounts | `/main/docker -> /docker`, `/data/media -> /media` |
| GPU passthrough | `/dev/dri/card0`, `/dev/dri/renderD128` |
| Docker | Docker 28.x with Compose v2 |

Running containers on CT 101:

| Container | Image | Port(s) | Persistent path |
|---|---|---:|---|
| `qbittorrent` | `ghcr.io/linuxserver/qbittorrent` | `8080` | `/docker/qbittorrent` |
| `prowlarr` | `lscr.io/linuxserver/prowlarr:latest` | `9696` | `/docker/prowlarr` |
| `sonarr` | `ghcr.io/linuxserver/sonarr:latest` | `8989` | `/docker/sonarr` |
| `radarr` | `ghcr.io/linuxserver/radarr:latest` | `7878` | `/docker/radarr` |
| `bazarr` | `lscr.io/linuxserver/bazarr:latest` | `6767` | `/docker/bazarr` |
| `tdarr` | `ghcr.io/haveagitgat/tdarr:latest` | `8265`, `8266` | `/docker/tdarr`, `/media` |
| `flaresolverr` | `ghcr.io/flaresolverr/flaresolverr:latest` | `8191` | container only |
| `qbproxy` | `ghcr.io/panonim/qbwrapper:latest` | `9911` | env only |
| `lingarr` | `lingarr/lingarr:latest` | `9876` | `/docker/lingarr` |
| `portainer` | `portainer/portainer-ce:lts` | `9443`, `8000` | Portainer-managed |

The live arr stack was originally created by Portainer. Docker labels show compose project `servarr` and service config path `/data/compose/3/docker-compose.yml`, but that Portainer internal path is not visible in this LXC shell. The repo copy `server-arr/arr-stack.yml` is therefore the canonical rebuild compose file.

### CT 102 — `jellyfin`

| Setting | Live value |
|---|---|
| IP | `192.168.1.104/24` |
| Creation method | Community Scripts Jellyfin LXC |
| OS | Ubuntu 22.04 |
| Port | `8096` |
| Service | `jellyfin.service` |
| Mount | `/data/media -> /media` |
| Data/config | `/var/lib/jellyfin`, `/etc/jellyfin` |
| GPU passthrough | `/dev/dri`, `/dev/dri/renderD128`, `/dev/fb0` |

Backup before rebuild:

```bash
systemctl stop jellyfin
sudo tar -czf /root/jellyfin-backup-$(date +%F).tgz /etc/jellyfin /var/lib/jellyfin
systemctl start jellyfin
```

After a fresh Community Scripts install, restore those directories or rerun the wizard and point libraries to `/media/movies` and `/media/tv`.

### CT 103 — `jellyseerr`

| Setting | Live value |
|---|---|
| IP | `192.168.1.105/24` |
| Creation method | Community Scripts Jellyseerr/Seerr LXC |
| OS | Debian 12 |
| Port | `5055` |
| Service | `seerr.service` |
| Install path | `/opt/seerr` |
| Runtime config | `/etc/seerr/seerr.conf`, `/opt/seerr/config/settings.json` |
| Extra legacy/backup config | `/docker/jellyseerr/config/settings.json` |

Current `/etc/seerr/seerr.conf` shape:

```env
PORT=5055
# HOST=0.0.0.0
# JELLYFIN_TYPE=emby
```

Important current Jellyseerr links, sanitized:

| Link | Current setting |
|---|---|
| Media server type | Jellyfin |
| Jellyfin external endpoint | `play.liftlab.dev:443` with SSL |
| Jellyfin libraries | `Movies`, `Shows` |
| Radarr host | `192.168.1.103:7878` |
| Radarr default directory | `/data/movies` |
| Radarr profile | `HD-1080p` |
| Sonarr host | `192.168.1.103:8989` |
| Sonarr default directory | `/data/tv` |
| Sonarr profile | `HD-1080p` |
| Sonarr anime type | `anime` |

Secrets to recreate:

- Jellyfin API key: Jellyfin Dashboard -> Advanced -> API Keys.
- Radarr API key: Radarr -> Settings -> General -> Security/API Key.
- Sonarr API key: Sonarr -> Settings -> General -> Security/API Key.
- Jellyseerr Discord webhook, if re-enabled: Discord channel -> Integrations -> Webhooks.

## qBittorrent settings

Live config path:

```text
/docker/qbittorrent/qBittorrent/qBittorrent.conf
```

Important current settings:

| Setting | Live value |
|---|---|
| WebUI port | `8080` |
| WebUI address/domain | `*` |
| Username/password | Secret; set manually after first boot |
| Completed downloads | `/data/downloads/qbittorrent/completed` |
| Incomplete downloads | `/data/downloads/qbittorrent/incomplete` |
| Incomplete enabled | `true` |
| `.torrent` export | `/data/downloads/qbittorrent/torrents` |
| Queueing | enabled |
| Max active downloads | `5` |
| Max active uploads | `1` |
| Upload speed limit | `100 KiB/s` |
| Anonymous mode | enabled |
| UPnP | disabled |
| Share limit action | stop torrent |
| Inactive seeding limit | `5` minutes |

Fresh login/password recovery:

```bash
docker logs qbittorrent | grep -i password
```

Then open `http://192.168.1.103:8080`, log in with the temporary password, and set the permanent WebUI username/password in qBittorrent -> Tools -> Options -> WebUI.

## Prowlarr settings

Live paths:

```text
/docker/prowlarr/config.xml
/docker/prowlarr/prowlarr.db
```

Current app-level settings:

| Setting | Value |
|---|---|
| Port | `9696` |
| Authentication | Forms, required |
| Log level | debug |
| Update mechanism | Docker |
| FlareSolverr proxy | `http://172.18.0.1:8191/` |
| qBittorrent client host | `172.18.0.1:8080` |
| qBittorrent category mapping | `tv-sonarr -> TV categories`, `radarr -> movie categories` |

Current enabled indexers copied from live DB:

| Indexer | Priority | Minimum seeders | Notes |
|---|---:|---:|---|
| TheRARBG | 2 | 10 | General/movie/TV |
| The Pirate Bay | 1 | 5 | General/movie/TV |
| Bangumi Moe | 5 | 10 | Anime |
| showRSS | 25 | 5 | TV |
| Tokyo Toshokan | 5 | 5 | Anime |
| Nyaa.si | 2 | 5 | Anime/general |
| 1337x | 3 | 5 | Uses FlareSolverr tag |
| kickasstorrents.to | 5 | 5 | Uses FlareSolverr tag |
| Anime Time | 10 | default | Anime |
| Shana Project | 25 | default | Anime |
| EXT Torrents | 3 | 5 | Movies |
| 52BT | 25 | 5 | Movies |

Application sync:

| App | URL used by live config | Sync level | API key source |
|---|---|---|---|
| Sonarr | `http://172.18.0.1:8989` | full sync | Sonarr Settings -> General |
| Radarr | `http://172.18.0.1:7878` | full sync | Radarr Settings -> General |

When rebuilding, create Sonarr/Radarr first, copy their API keys into Prowlarr Applications, then press Sync App Indexers.

## Sonarr settings

Live paths:

```text
/docker/sonarr/config.xml
/docker/sonarr/sonarr.db
```

Current settings:

| Setting | Value |
|---|---|
| Port | `8989` |
| Authentication | Forms, required |
| Root folder | `/data/tv/` |
| Download client | qBittorrent at `172.18.0.1:8080` |
| qBittorrent category | `tv-sonarr` |
| Remove completed downloads | enabled |
| Remove failed downloads | enabled |
| Naming | rename episodes enabled |
| Standard format | `{Series Title} - S{season:0}E{episode:0} - {Episode Title} {Quality Title}` |
| Anime format | `{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Title}` |
| Season folder format | `Season {season}` |
| Series folder format | `{Series Title}` |
| Quality profile used by current library | `HD-1080p` / profile id `4` |
| Remote path mappings | none |

Prowlarr currently syncs these Sonarr indexers: TheRARBG, The Pirate Bay, Bangumi Moe, showRSS, Tokyo Toshokan, Nyaa.si, 1337x, kickasstorrents.to, Anime Time, Shana Project.

## Radarr settings

Live paths:

```text
/docker/radarr/config.xml
/docker/radarr/radarr.db
```

Current settings:

| Setting | Value |
|---|---|
| Port | `7878` |
| Authentication | Forms, required |
| Root folder | `/data/movies/` |
| Download client | qBittorrent at `172.18.0.1:8080` |
| qBittorrent category | `radarr` |
| Remove completed downloads | enabled |
| Remove failed downloads | enabled |
| Naming | rename movies enabled |
| Movie format | `{Movie Title} ({Release Year}) {Quality Full}` |
| Movie folder format | `{Movie Title} ({Release Year})` |
| Quality profile used by current library | `HD-1080p` / profile id `4` |
| Remote path mappings | none |

Prowlarr currently syncs these Radarr indexers: The Pirate Bay, TheRARBG, Bangumi Moe, Nyaa.si, 1337x, kickasstorrents.to, EXT Torrents, 52BT.

## Bazarr settings

Live paths:

```text
/docker/bazarr/config/config.yaml
/docker/bazarr/db/bazarr.db
```

Current settings:

| Setting | Value |
|---|---|
| Port | `6767` |
| Auth | form login |
| Backup folder | `/config/backup` |
| Backup frequency | weekly, Saturday 03:00, retention 15 |
| Minimum score: series | `90` |
| Minimum score: movies | `70` |
| Default series language profile | profile id `1` |
| Default movie language profile | profile id `1` |
| Use Sonarr | enabled |
| Use Radarr | enabled |
| Adaptive searching | enabled |
| Wanted search frequency | `6` |
| Upgrade subtitles | enabled |

Enabled subtitle providers observed:

- OpenSubtitles.com
- Anime Tosho
- TVSubtitles
- YIFY Subtitles
- Wizdom
- Embedded subtitles
- SuperSubtitles
- Addic7ed
- Subf2m

Provider credentials are not stored here. Recreate them from each provider account page and enter them in Bazarr -> Settings -> Providers.

## Tdarr, Lingarr, FlareSolverr, QBWrapper

### Tdarr

| Setting | Value |
|---|---|
| UI port | `8265` |
| Server port | `8266` |
| Internal node | enabled |
| Node name | `MyInternalNode` |
| ffmpeg version | `7` |
| Temporary chunk size | `500M` |
| GPU device | `/dev/dri:/dev/dri` |
| Volumes | `/docker/tdarr/server`, `/docker/tdarr/configs`, `/docker/tdarr/logs`, `/media` |

### Lingarr

| Setting | Value |
|---|---|
| Port | `9876` |
| Max concurrent jobs | `2` |
| Movie mount | `/media/movies -> /movies` |
| TV mount | `/media/tv -> /tv` |
| Config | `/docker/lingarr -> /app/config` |

### FlareSolverr

| Setting | Value |
|---|---|
| Port | `8191` |
| Log level | `info` |
| HTML logging | disabled |
| Captcha solver | none |

### QBWrapper / `qbproxy`

| Setting | Value |
|---|---|
| Port | `9911` |
| qBittorrent base URL | `http://172.18.0.2:8080` inside Docker network |
| Username/password | Use `QB_USERNAME` / `QB_PASSWORD` from `.env` |
| Auth token | Use random `AUTH_TOKEN` from `.env` |

## Backup and restore

Because all CT 101 app config lives under `/docker` and media lives under `/media`, backup config separately from media files.

Backup app configs on CT 101:

```bash
cd /
sudo tar -czf /root/servarr-config-backup-$(date +%F).tgz \
  docker/qbittorrent \
  docker/prowlarr \
  docker/sonarr \
  docker/radarr \
  docker/bazarr \
  docker/tdarr \
  docker/lingarr
```

Restore order:

1. Recreate CT 101 with `/main/docker -> /docker` and `/data/media -> /media` bind mounts.
2. Restore `/docker/<app>` config directories if starting from backup.
3. Copy `server-arr/.env.example` to `server-arr/.env` and fill `QB_USERNAME`, `QB_PASSWORD`, and `AUTH_TOKEN`.
4. Start containers:

```bash
cd /opt/multimedia-server/server-arr
docker compose --env-file .env -f arr-stack.yml up -d
```

5. If not restoring old databases, configure apps in this order:
   - qBittorrent WebUI password and paths.
   - Sonarr/Radarr root folders and qBittorrent download client.
   - Prowlarr indexers, FlareSolverr proxy, and Sonarr/Radarr applications.
   - Bazarr Sonarr/Radarr connections and subtitle providers.
   - Jellyfin libraries.
   - Jellyseerr Jellyfin/Radarr/Sonarr integrations.

## Secret checklist

Do not commit any of these values:

- qBittorrent WebUI username/password.
- Sonarr/Radarr/Prowlarr/Bazarr API keys.
- Jellyfin API keys and server IDs if you treat them as private.
- Jellyseerr `main.apiKey`, Jellyfin API key, Radarr/Sonarr API keys, webhook URLs, VAPID private key.
- Subtitle provider usernames/passwords/cookies/tokens.
- QBWrapper `AUTH_TOKEN`.

Where to recreate secrets:

| Secret | Where to get/create |
|---|---|
| qBittorrent temporary password | `docker logs qbittorrent` on first start |
| qBittorrent permanent password | qBittorrent -> Tools -> Options -> WebUI |
| Prowlarr API key | Prowlarr -> Settings -> General -> Security |
| Sonarr API key | Sonarr -> Settings -> General -> Security |
| Radarr API key | Radarr -> Settings -> General -> Security |
| Bazarr API key | Bazarr -> Settings -> General/Security |
| Jellyfin API key | Jellyfin Dashboard -> Advanced -> API Keys |
| Jellyseerr integrations | Jellyseerr Settings -> Services / Notifications |
| QBWrapper token | Generate locally: `openssl rand -hex 32` |
