## Portainer rollback status

Portainer is no longer stack owner. Dockge manages `/opt/stacks/servarr/compose.yaml`.

Portainer container and `portainer_data` remain temporarily because `qbproxy` fails health gate. Do not edit or control `servarr` from Portainer.

After all eight services run and endpoint probes pass:

1. Delete Portainer container only.
2. Keep `portainer_data` and preserved stack source for rollback.
3. Remove `portainer.liftlab.dev` Tunnel route, Access app/policy, DNS, and Homepage card.

See [`Dockge-Operations.md`](./Dockge-Operations.md) for update, verification, and rollback commands.
