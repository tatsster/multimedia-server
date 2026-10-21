# Dockge operations

## Live layout

- Dockge: `/opt/dockge/compose.yaml`
- Dockge data: `/opt/dockge/data`
- Managed stacks: `/opt/stacks`
- `servarr`: `/opt/stacks/servarr/compose.yaml`
- UI: `http://192.168.1.103:5001`
- Public URL: `https://dockge.liftlab.dev` through Cloudflare Tunnel + Access

Portainer remains available while `qbproxy` fails health gate. Keep `portainer_data` for rollback even after Portainer container cleanup.

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

## Stack health gate

Before deleting Portainer container/routes:

1. All eight `servarr` containers show `running` in Dockge.
2. Every defined Docker healthcheck reports `healthy`.
3. Service endpoint probes pass.
4. Names, images, ports, static IPs, mounts, restart policies, external FlareSolverr volume, and Tdarr `/dev/dri` match preflight.
5. `qbproxy` must be running and reachable on port `9911`.

Current `qbproxy` qBittorrent login failure blocks cleanup. Do not delete Portainer container, `portainer.liftlab.dev`, Access policy, DNS, or Homepage card while gate fails.

Never run `docker compose down -v` or `docker volume prune` during migration or rollback.
