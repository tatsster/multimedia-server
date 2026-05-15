# Beszel monitoring config

Beszel is the monitoring source for both:

- Beszel's own all-systems dashboard temperature column.
- Homepage's top-row `pvehealth` widget for Proxmox temperature and uptime.

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

`info.t` may still be a different/low sensor value on this host. Do not use it for the Homepage top-row PVE temperature.

## Homepage integration

Homepage uses a custom `pvehealth` widget that logs in to Beszel and reads the latest detailed `system_stats.t` record for Proxmox. This is intentional because detailed Beszel stats contain the reliable CPU/core/package values.

Required Homepage env vars:

```env
HOMEPAGE_VAR_BESZEL_URL=http://192.168.1.115:8090
HOMEPAGE_VAR_BESZEL_USERNAME=homepage-widget@example.local
HOMEPAGE_VAR_BESZEL_PASSWORD=replace-with-beszel-superuser-password
HOMEPAGE_VAR_BESZEL_SYSTEM_ID=qmh9xghiecj8phu
```

The live username is stored only in the live Homepage environment. Do not commit the real password.

Homepage widget config lives in `homepage/widgets.yaml`:

```yaml
- pvehealth:
    label: PVE Main
    href: https://beszel.liftlab.dev
    source: beszel
    systemId: "{{HOMEPAGE_VAR_BESZEL_SYSTEM_ID}}"
    refresh: 30000
    tempwarn: 70
    tempcrit: 85
    tempmax: 90
```

## Removed old custom endpoint

The old Proxmox custom endpoint is no longer needed:

```bash
systemctl disable --now homepage-pve-metrics.service
rm -f /etc/systemd/system/homepage-pve-metrics.service
rm -f /opt/homepage-metrics-server.py
systemctl daemon-reload
```

Homepage should not call `http://192.168.1.101:9912/metrics` anymore.
