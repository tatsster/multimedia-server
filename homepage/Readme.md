# Homepage dashboard rebuild guide

Homepage is the main homelab dashboard replacing Glance. It is installed in a dedicated privileged LXC using the community-scripts Homepage installer and is proxied by Caddy at the root domain.

## Live deployment

| Item | Current value |
|---|---|
| LXC | CT `112` / `homepage` |
| Internal IP | `192.168.1.114` |
| Install method | Community Scripts: Homepage |
| Internal URL | `http://192.168.1.114:3000` |
| Public URL | `https://liftlab.dev` |
| Config path | `/opt/homepage/config` |
| Timezone | `Asia/Ho_Chi_Minh` |
| Proxy | Caddy on CT `201` proxies `liftlab.dev` to `http://192.168.1.114:3000` |

## Files in this repo

```text
homepage/settings.yaml
homepage/services.yaml
homepage/widgets.yaml
homepage/bookmarks.yaml
homepage/docker.yaml
homepage/kubernetes.yaml
homepage/.env.example
homepage/custom-src/pages/api/widgets/pvehealth.js
homepage/custom-src/components/widgets/pvehealth/pvehealth.jsx
homepage/custom-src/components/widgets/widget.jsx.patch.md
```

These files are secret-safe templates for the live `/opt/homepage/config` directory. Real tokens/passwords stay only in the live Homepage environment or local secret files.

## Restore / update config

From a machine with the repo and SSH/root access to the Homepage LXC/PVE host, copy the config files into the live config directory:

```bash
mkdir -p /opt/homepage/config
cp homepage/settings.yaml /opt/homepage/config/settings.yaml
cp homepage/services.yaml /opt/homepage/config/services.yaml
cp homepage/widgets.yaml /opt/homepage/config/widgets.yaml
cp homepage/bookmarks.yaml /opt/homepage/config/bookmarks.yaml
cp homepage/docker.yaml /opt/homepage/config/docker.yaml
cp homepage/kubernetes.yaml /opt/homepage/config/kubernetes.yaml
```

Custom widget source files must also be copied into the Homepage source tree and registered:

```bash
mkdir -p /opt/homepage/src/pages/api/widgets
mkdir -p /opt/homepage/src/components/widgets/pvehealth
cp homepage/custom-src/pages/api/widgets/pvehealth.js /opt/homepage/src/pages/api/widgets/pvehealth.js
cp homepage/custom-src/components/widgets/pvehealth/pvehealth.jsx /opt/homepage/src/components/widgets/pvehealth/pvehealth.jsx
# Apply the one-line mapping documented in:
# homepage/custom-src/components/widgets/widget.jsx.patch.md
```

Then rebuild if using a source/community-scripts install:

```bash
cd /opt/homepage
pnpm build
```

Then reload/restart Homepage using the live install method. For community-scripts installs, inspect the service name first:

```bash
systemctl list-units --type=service | grep -i homepage
systemctl restart homepage || systemctl restart homepage.service
systemctl status homepage --no-pager --lines=50
```

If Homepage was deployed with Docker instead, restart the container/stack instead of using systemd.

## Environment variables / secrets

Homepage only substitutes environment variables that start with `HOMEPAGE_VAR_` or `HOMEPAGE_FILE_`.

Start from:

```text
homepage/.env.example
```

Required variables:

| Variable | Used by | Notes |
|---|---|---|
| `TZ` | app runtime | `Asia/Ho_Chi_Minh` |
| `HOMEPAGE_ALLOWED_HOSTS` | app runtime | Include `liftlab.dev` and internal host/port |
| `HOMEPAGE_VAR_PROXMOXVE_USERNAME` | Proxmox widget | Token id, e.g. `api-ro@pam!homepage` |
| `HOMEPAGE_VAR_PROXMOXVE_PASSWORD` | Proxmox widget | Token secret only |
| `HOMEPAGE_VAR_PROXMOXBACKUP_USERNAME` | PBS widget | Token id |
| `HOMEPAGE_VAR_PROXMOXBACKUP_PASSWORD` | PBS widget | Token secret only |
| `HOMEPAGE_VAR_JELLYFIN_URL` | Jellyfin widget | Public/internal Jellyfin base URL |
| `HOMEPAGE_VAR_JELLYFIN_KEY` | Jellyfin widget | Jellyfin API key |
| `HOMEPAGE_VAR_JELLYSEERR_KEY` | Seerr/Jellyseerr widget | Jellyseerr API key |
| `HOMEPAGE_VAR_MEALIE_URL` | Mealie widget | Internal Mealie base URL |
| `HOMEPAGE_VAR_MEALIE_API_TOKEN` | Mealie widget | Mealie user API token |
| `HOMEPAGE_VAR_BESZEL_URL` | PVE health widget | Internal Beszel base URL, e.g. `http://192.168.1.115:8090` |
| `HOMEPAGE_VAR_BESZEL_USERNAME` | PVE health widget | Beszel superuser/API login for Homepage |
| `HOMEPAGE_VAR_BESZEL_PASSWORD` | PVE health widget | Beszel password; never commit real value |
| `HOMEPAGE_VAR_BESZEL_SYSTEM_ID` | PVE health widget | Proxmox Beszel system ID/name, currently `qmh9xghiecj8phu` |
| `HOMEPAGE_VAR_SPEEDTEST_URL` | Speedtest widget | Internal Speedtest Tracker base URL |
| `HOMEPAGE_VAR_SPEEDTEST_API_TOKEN` | Speedtest widget | Required for widget version 2 |
| `HOMEPAGE_VAR_QBITTORRENT_USERNAME` | qBittorrent widget | WebUI username |
| `HOMEPAGE_VAR_QBITTORRENT_PASSWORD` | qBittorrent widget | WebUI password |
| `HOMEPAGE_VAR_QBITTORRENT_DASHBOARD_TOKEN` | qBittorrent custom API widget | Token for qBittorrent dashboard proxy |
| `HOMEPAGE_VAR_RADARR_API_KEY` | Radarr widget | Radarr API key |
| `HOMEPAGE_VAR_SONARR_API_KEY` | Sonarr widget | Sonarr API key |
| `HOMEPAGE_VAR_PROWLARR_API_KEY` | Prowlarr widget | Prowlarr API key |
| `HOMEPAGE_VAR_OMNIROUTE_DASHBOARD_TOKEN` | OmniRoute custom API widget | Must match metrics proxy token |

Never commit real values.

## Service groups

Current config groups:

- `Infrastructure`: Proxmox VE, PBS, Beszel, OmniRoute Usage
- `Services`: Jellyfin, Mealie, Speedtest Tracker, Jellyseerr, Portainer, VaultWarden, n8n, OmniRoute, Hindsight
- `Arr-suite`: Radarr, Sonarr, Prowlarr, qBittorrent, Bazarr, Tdarr, FlareSolverr, Lingarr

## Public routing

Repo Caddy config already contains the root dashboard route:

```caddyfile
liftlab.dev {
    reverse_proxy http://192.168.1.114:3000
}
```

Keep Homepage public exposure on Caddy only unless you intentionally switch to Cloudflare Tunnel using the `expose-service-public` skill.

## Validation checklist

After updates:

```bash
# YAML syntax
python3 - <<'PY'
import yaml, pathlib
for p in pathlib.Path('homepage').glob('*.yaml'):
    yaml.safe_load(p.read_text())
    print('ok', p)
PY

# Internal service
curl -I http://192.168.1.114:3000

# Public route
curl -I https://liftlab.dev
```

In the UI, verify:

- Infrastructure widgets load without leaking credentials.
- Media and Arr service links open correctly.
- qBittorrent still only uses VPN-bound torrent traffic.
- Services with no public auth are not newly exposed.
