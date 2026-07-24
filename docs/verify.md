# Homelab Verification Checklist

Use this after a rebuild, service move, or dashboard/proxy change.

## Inventory

- Confirm CT IDs and IPs against [`inventory/lxc-map.md`](../inventory/lxc-map.md).
- Confirm CT201 proxy and CT250 PBS were not unintentionally renumbered.
- Confirm service LXCs use the expected static IPs on `vmbr0`.

## Dashboard

- Validate Homepage YAML:

```bash
python3 - <<'PY'
import pathlib, yaml
for p in pathlib.Path('dashboards/homepage').glob('*.yaml'):
    yaml.safe_load(p.read_text())
    print('ok', p)
PY
```

- Verify public dashboard API:

```bash
curl -fsS https://liftlab.dev/api/services
```

## Proxy and public access

- Review [`infrastructure/proxy/Access-Setup.md`](../infrastructure/proxy/Access-Setup.md).
- Verify Caddy config syntax before reload.
- Verify Cloudflare Tunnel routes for public hostnames.

## Media stack

- Review [`services/media-arr/arr-live-settings.md`](../services/media-arr/arr-live-settings.md).
- Check qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr, Tdarr, Jellyfin, Jellyseerr, and related integrations.

## AI / agent services

- Review [`services/ai/integration.md`](../services/ai/integration.md).
- Verify Hermes configuration from [`agent/hermes/README.md`](../agent/hermes/README.md).
- Verify OmniRoute from [`services/omniroute/README.md`](../services/omniroute/README.md).
- Verify Proxmox MCP Plus at `http://192.168.1.116:8000/mcp`.
- Verify OpenViking at `http://192.168.1.118:1933`.

## Repo checks

```bash
./automation/check-env.sh
git diff --check
./automation/smoke-test.sh
```

Treat any real secret, token, API key, password, OAuth value, or tunnel credential in Git as a blocker before committing.
