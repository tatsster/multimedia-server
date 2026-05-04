# Proxmox VE rebuild scripts

Run these scripts from the **Proxmox VE host shell**, not inside an LXC.

Purpose:

- Quickly recreate manually managed LXCs with the current homelab defaults.
- Keep community-scripts-created LXCs documented instead of rewriting their upstream installers.
- Keep secrets out of Git. Scripts use placeholders and optional env vars.

## Current LXC creation strategy

| LXC/service | Creation method | Why |
| --- | --- | --- |
| proxy | Community Scripts Caddy LXC + manual post-install | One dedicated LXC that runs Caddy, Cloudflare Tunnel, and Cloudflare MCP together |
| media-arr Docker LXC | Manual script in this repo | Needs homelab-specific Docker, mounts, compose repo checkout |
| Hermes | Manual script in this repo | Custom Hermes config, gateway, OmniRoute/Hindsight integration |
| OmniRoute | Manual script in this repo | No confirmed community script; needs onboarding/password workaround docs |
| Hindsight | Manual script in this repo | No confirmed community script; exact install still to verify |

## Community Scripts notes

The current proxy rebuild uses the Community Scripts **Caddy** LXC as the base, then installs Cloudflare Tunnel and Cloudflare MCP into that same LXC:

```text
https://community-scripts.github.io/ProxmoxVE/scripts?id=caddy
```

Raw PVE shell command pattern:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/caddy.sh)"
```

Do **not** run the Cloudflared community script as a second LXC for the normal rebuild. See `../../proxy/Access-Setup.md` for the combined Caddy + Tunnel + MCP setup.

Important: upstream defaults currently use unprivileged containers for many scripts. During Advanced setup, adjust to match this homelab where needed:

```text
features: nesting=1
unprivileged: 0
```

After using a community script, record the CT ID/IP in:

```text
../../inventory/lxc-map.md
```

## Manual scripts

These scripts create a Debian LXC, apply standard homelab settings, start it, and run service install commands through `pct exec`.

They are intentionally simple and readable.

| Script | Purpose |
| --- | --- |
| `create-media-arr-lxc.sh` | Docker LXC for arr stack and Portainer-compatible workloads |
| `create-hermes-lxc.sh` | Hermes LXC starter with sanitized config example copied in |
| `create-omniroute-lxc.sh` | OmniRoute LXC starter using Node/npm package path if available |
| `create-hindsight-lxc.sh` | Hindsight LXC starter placeholder; exact install command still needs live verification |
| `audit-lxcs.sh` | Generate a secret-safe-ish Markdown audit of current live LXC configs to help fill `inventory/lxc-map.md` |

## Audit existing live LXCs

Before rebuilding, run this on the current Proxmox VE host to capture CT IDs, IP configs, nesting/privileged settings, mounts, and creation hints.

Check you are on the PVE host first:

```bash
command -v pct && pct list
```

If `pct` is not found, you are probably inside a container or another Linux host. Copy/pull the repo on the PVE host and run it there instead.

```bash
cd /root/repos/multimedia-server
./scripts/pve/audit-lxcs.sh
```

Default output:

```text
inventory/live-lxc-audit.md
```

This generated file is intentionally ignored by Git. Review it locally because live LXC descriptions/notes can contain private details:

```bash
grep -RInE 'password|token|secret|key|Bearer|eyJ|sk-' inventory/live-lxc-audit.md
```

Then copy only verified, non-secret values into:

```text
inventory/lxc-map.md
```

Commit `inventory/lxc-map.md`, not the raw generated audit.

## Before running

1. Review and edit script variables or pass env vars.
2. Confirm template exists:

```bash
pveam update
pveam available --section system | grep debian-13
pveam list general | grep debian-13 || pveam download general debian-13-standard_13.1-2_amd64.tar.zst
```

3. Confirm storage names:

```bash
pvesm status
```

4. Confirm bridge/network:

```bash
ip link show vmbr0
```

## Common env vars

Most scripts support:

```bash
CTID=120
HOSTNAME=hermes
IP_CIDR=192.168.1.120/24
GATEWAY=192.168.1.1
STORAGE=vm_storage
TEMPLATE=general:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst
CPULIMIT=4
PASSWORD='temporary-root-password'
```

If `PASSWORD` is unset, the scripts use `pct create --unprivileged 0` without setting a password and expect you to set/access through Proxmox as appropriate. For fresh rebuild, passing a temporary password can be convenient, then rotate it.

## Safety

- Scripts refuse to overwrite an existing CT ID.
- Scripts do not contain real API keys/tokens/passwords.
- Secrets are written as placeholders only.
- For API keys, create them later using service dashboards and follow each service README.
