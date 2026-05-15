# Glances for Homepage PVE widget

Glances is used only for Homepage's native top-row Proxmox host widget. Beszel remains the main monitoring/history/alerts dashboard.

This replaces the previous custom Homepage `pvehealth` JavaScript widget. The goal is a boring, native Homepage setup:

- no custom Homepage JS
- no custom Homepage API route
- no custom Python metrics script
- no old `homepage-pve-metrics.service`

## Live target

| Item | Value |
|---|---|
| Host | Proxmox PVE |
| Host IP | `192.168.1.101` |
| Glances URL for Homepage | `http://192.168.1.101:61208` |
| Homepage widget | Native `glances` info widget |
| Glances API version | `4` |

## Install on Proxmox

Debian/Proxmox package install:

```bash
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  glances lm-sensors python3-jinja2 python3-aiofiles python3-python-multipart \
  python3-itsdangerous python3-h2 python3-httpcore python3-httpx
```

The extra Python packages are needed by the Debian Glances web/API mode.

## Systemd override

The Debian package defaults to XML-RPC server mode bound to localhost. Homepage needs the HTTP API, so apply the drop-in tracked in this repo:

```bash
mkdir -p /etc/systemd/system/glances.service.d
cp glances/glances.service.d-homepage.conf /etc/systemd/system/glances.service.d/homepage.conf
systemctl daemon-reload
systemctl enable --now glances
systemctl restart glances
systemctl status glances --no-pager --lines=50
```

Expected live command after the drop-in:

```text
/usr/bin/glances -w -B 0.0.0.0
```

Expected listener:

```bash
ss -tlnp | grep 61208
```

## Debian package static directory note

On this Proxmox/Debian version, Glances `4.3.1+dfsg-1` expected this path for web/API static files:

```text
/usr/lib/python3/dist-packages/glances/outputs/static/public
```

But the package installed the files directly under:

```text
/usr/lib/python3/dist-packages/glances/outputs/static
```

If Glances web mode fails with `Directory .../static/public does not exist`, fix with:

```bash
test -d /usr/lib/python3/dist-packages/glances/outputs/static/public || \
  ln -s . /usr/lib/python3/dist-packages/glances/outputs/static/public
systemctl restart glances
```

## Verification

From the Proxmox host:

```bash
curl -fsS http://127.0.0.1:61208/api/4/status
curl -fsS http://127.0.0.1:61208/api/4/sensors
curl -fsS http://127.0.0.1:61208/api/4/uptime
```

From the Homepage LXC, the Homepage API should also be able to proxy Glances. For the current top-row widget order, Glances is index `2`:

```bash
curl -fsS "http://127.0.0.1:3000/api/widgets/glances?index=2&version=4&cputemp=true&uptime=true"
```

Expected sensor data includes `Package id 0`, for example:

```json
{"label":"Package id 0","unit":"C","value":50}
```

From Homepage, use:

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

## Security note

This exposes Glances on the LAN only via the Proxmox host IP. Do not expose port `61208` publicly. If firewalling is enabled later, allow only the Homepage CT (`192.168.1.114`) to reach `192.168.1.101:61208`.
