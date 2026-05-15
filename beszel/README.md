# Beszel monitoring config

Beszel is the main monitoring/history/alerts dashboard for the homelab. It also shows the Proxmox dashboard temperature correctly in Beszel's own all-systems table.

Homepage keeps a normal Beszel service link/monitor card, but the top-row PVE temperature/uptime card no longer uses custom Beszel-backed Homepage JavaScript. Homepage now uses its native Glances widget for that card. See `glances/README.md`.

This avoids the old custom `homepage-pve-metrics.service` and removes the need for the extra `9912` metrics port on Proxmox.

## Live services

| Item | Value |
|---|---|
| Beszel URL | `https://beszel.liftlab.dev` |
| Internal Beszel URL | `http://192.168.1.115:8090` |
| Proxmox system name | `proxmox` |
| Proxmox system ID | `qmh9xghiecj8phu` |
| Proxmox host | `192.168.1.101` |

## Beszel hub service

Beszel hub currently runs directly under systemd in CT `113`:

```text
/etc/systemd/system/beszel-hub.service
```

A secret-free copy is tracked as `beszel/beszel-hub.service`.

Apply/reload if needed:

```bash
cp beszel/beszel-hub.service /etc/systemd/system/beszel-hub.service
systemctl daemon-reload
systemctl enable --now beszel-hub
systemctl status beszel-hub --no-pager --lines=50
```

## Proxmox Beszel agent sensor config

The Proxmox agent must select the CPU package sensor as its dashboard temperature.

Use this in the Beszel agent environment/config on the Proxmox host:

```env
SENSORS=coretemp*
PRIMARY_SENSOR=coretemp_package_id_0
```

Why the normalized key matters:

- `Package id 0` is the human label from `sensors`.
- Beszel stores the detailed stats key as `coretemp_package_id_0`.
- Beszel's all-systems dashboard uses its dashboard/summary temperature (`info.dt`), which follows the primary sensor selection.

After changing the config:

```bash
systemctl restart beszel-agent
systemctl status beszel-agent --no-pager --lines=50
```

Then wait 1-2 minutes and refresh Beszel.

## Expected verification

On Proxmox, `sensors` should show something like:

```text
coretemp-isa-0000
Package id 0:  +50.0°C
Core 0:        +49.0°C
```

Beszel agent debug/API should show:

```text
coretemp_package_id_0: 50°C
DashboardTemp: 50
```

Beszel API summary should have a correct dashboard temperature:

```json
{
  "info": {
    "dt": 50
  }
}
```

`info.t` may still be a different/low sensor value on this host. Do not use it as the CPU package temperature.

## Homepage integration

Homepage service config should keep Beszel simple/link/monitor-only, for example:

```yaml
- Beszel:
    icon: beszel.png
    href: https://beszel.liftlab.dev
    siteMonitor: http://192.168.1.115:8090
    description: Proxmox monitoring
```

For Homepage top-row host temp/uptime, use Glances instead of Beszel because Homepage's native Beszel widget currently supports only:

```text
name, status, updated, cpu, memory, disk, network
```

It does not expose Beszel `info.dt` or uptime as native fields yet.

## Removed old custom endpoint

The old Proxmox custom endpoint is no longer needed:

```bash
systemctl disable --now homepage-pve-metrics.service
rm -f /etc/systemd/system/homepage-pve-metrics.service
rm -f /opt/homepage-metrics-server.py
systemctl daemon-reload
```

Homepage should not call `http://192.168.1.101:9912/metrics` anymore.
