# Beszel monitoring config

Beszel is the main monitoring/history/alerts dashboard for the homelab and the single place to check Proxmox host metrics such as temperature and uptime.

Homepage keeps a normal Beszel service link/monitor card. The old custom `homepage-pve-metrics.service` and the later separate Homepage temp/uptime widget are no longer needed.

This keeps the setup simpler:

- no custom Homepage JavaScript widget
- no custom Proxmox metrics endpoint on port `9912`
- no extra host metrics web/API port for Homepage

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

## Proxmox Beszel agent environment

The Proxmox Beszel agent should select the CPU package sensor as its dashboard temperature.

A secret-safe example is tracked here:

```text
beszel/proxmox-agent.env.example
```

Copy those values into the live Beszel agent environment on the Proxmox host. Keep secrets such as the agent key/token out of the repo.

### Where to add the env vars

Recommended simple location on Proxmox:

```text
/etc/beszel-agent.env
```

Example file contents:

```env
# Keep the real KEY/TOKEN here too if your live agent uses one.
SENSORS=coretemp*
PRIMARY_SENSOR=coretemp_package_id_0
```

Then make sure the systemd unit reads that file. Create or edit a drop-in:

```bash
mkdir -p /etc/systemd/system/beszel-agent.service.d
nano /etc/systemd/system/beszel-agent.service.d/env.conf
```

Drop-in contents:

```ini
[Service]
EnvironmentFile=-/etc/beszel-agent.env
```

Reload and restart:

```bash
systemctl daemon-reload
systemctl restart beszel-agent
systemctl status beszel-agent --no-pager --lines=50
```

If the live `beszel-agent.service` already has an `EnvironmentFile=...` line, use that existing file instead of creating a new one.

### Required sensor env vars

```env
SENSORS=coretemp*
PRIMARY_SENSOR=coretemp_package_id_0
```

Why the normalized key matters:

- `Package id 0` is the human label from `sensors`.
- Beszel stores the detailed stats key as `coretemp_package_id_0`.
- Beszel's all-systems dashboard uses its dashboard/summary temperature (`info.dt`), which follows the primary sensor selection.

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

Homepage service config should keep Beszel simple/link/monitor-only:

```yaml
- Beszel:
    icon: beszel.png
    href: https://beszel.liftlab.dev
    siteMonitor: http://192.168.1.115:8090
    description: Proxmox monitoring
```

Do not add a separate custom PVE metrics widget just for temperature/uptime unless Beszel cannot provide the needed information.

## Removed old custom endpoint

The old Proxmox custom endpoint is no longer needed:

```bash
systemctl disable --now homepage-pve-metrics.service
rm -f /etc/systemd/system/homepage-pve-metrics.service
rm -f /opt/homepage-metrics-server.py
systemctl daemon-reload
```

Homepage should not call `http://192.168.1.101:9912/metrics` anymore.
