# Dockge operations

## Live layout

- Dockge: `/opt/dockge/compose.yaml`
- Dockge data: `/opt/dockge/data`
- Managed stacks: `/opt/stacks`
- `servarr`: `/opt/stacks/servarr/compose.yaml`
- UI: `http://192.168.1.103:5001`
- Public URL: `https://dockge.liftlab.dev` through Cloudflare Tunnel + Access
- Managed services: qBittorrent, Prowlarr, Sonarr, Radarr, Bazarr, Tdarr, and FlareSolverr

## Manual Dockge update

Record current image ID, pull `latest`, recreate Dockge only, then verify:

```bash
docker inspect dockge --format '{{.Image}}'
cd /opt/dockge
docker compose pull
docker compose up -d
docker compose ps
curl -fsS http://127.0.0.1:5001/ >/dev/null
```

Rollback by setting `image:` to retained prior digest and running `docker compose up -d`.

## Stack verification

1. All seven `servarr` containers show `running` in Dockge.
2. Every defined Docker healthcheck reports `healthy`.
3. Service endpoint probes pass.
4. Names, images, ports, static IPs, mounts, restart policies, external FlareSolverr volume, and Tdarr `/dev/dri` match the canonical compose.

Never run `docker compose down -v` or `docker volume prune` during migration or rollback.
