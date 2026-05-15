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
```

These files are secret-safe templates for the live `/opt/homepage/config` directory. Real tokens/passwords stay only in the live Homepage environment or local secret files.

There are no custom Homepage JavaScript widgets required for the PVE temperature/uptime card. Homepage now uses its native `glances` info widget against Glances running on the Proxmox host.

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

Then reload/restart Homepage using the live install method. For community-scripts installs, inspect the service name first:

```bash
systemctl list-units --type=service | grep -i homepage
systemctl restart homepage || systemctl restart homepage.service
systemctl status homepage --no-pager --lines=50
```

If Homepage was deployed with Docker instead, restart the container/stack instead of using systemd.

## PVE temperature/uptime widget

The top-row PVE card uses the native Homepage Glances info widget:

```yaml
- glances:
    url: http://192.168.1.101:61208
    version: 4
    label: PVE Main
    cpu: true
    mem: true
    cputemp: true
    cpuSensorLabel: Package id
    uptime: true
```

Glances runs on the Proxmox host so it can see real host sensors. See `glances/README.md` for the PVE-side service config.

Beszel is still kept as the main monitoring/history/alerts dashboard and service link, but Homepage does not need custom Beszel-backed JS for the PVE top-row card anymore.

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

# Glances API from Proxmox
curl -fsS http://127.0.0.1:61208/api/4/status
curl -fsS http://127.0.0.1:61208/api/4/sensors

# Homepage proxy for the Glances info widget
curl -fsS "http://127.0.0.1:3000/api/widgets/glances?index=2&version=4&cputemp=true&uptime=true"

# Internal service
curl -I http://192.168.1.114:3000

# Public route
curl -I https://liftlab.dev
```

In the UI, verify:

- Top-row Glances widget shows PVE CPU/mem/temp/uptime.
- Infrastructure widgets load without leaking credentials.
- Media and Arr service links open correctly.
- qBittorrent still only uses VPN-bound torrent traffic.
- Services with no public auth are not newly exposed.
