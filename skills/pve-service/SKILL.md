---
name: pve-service
description: Install a new self-hosted service as a privileged Proxmox VE LXC, preferring community-scripts when available and falling back to manual Debian 13 CT creation when not.
usage_hint: "Trigger on: install service, new homelab service, create LXC, Proxmox service, PVE service, self-host app, deploy app in homelab."
metadata:
  trigger_text:
    - install service
    - new homelab service
    - create LXC
    - Proxmox service
    - PVE service
    - self-host app
    - deploy app in homelab
---

# PVE Service

Use this skill when T4tsster asks to install a new service in Proxmox VE as a new LXC container.

This is a high-use homelab workflow. Prefer simple, stable, repeatable steps over cutting-edge approaches.

## User defaults / requirements

- Target: the **current Proxmox VE host** being used for the task. Do not assume a hard-coded PVE IP unless the active environment/memory already confirms it; otherwise ask.
- Container type: **privileged LXC for all new service containers**.
  - In community-scripts variables this means `var_unprivileged=0`.
  - In manual `pct create`, explicitly use `--unprivileged 0` when supported.
- CTID: use Proxmox next available CTID automatically: `pvesh get /cluster/nextid`.
- OS for manual fallback: **Debian 13** by default.
- Versions: prefer the **latest stable** service version.
- Network/bridge/storage/SSH key: match existing/current LXCs on the PVE host.
  - Inspect existing LXC configs instead of inventing values.
  - Known environment pattern: LAN `192.168.1.0/24`, gateway often `192.168.1.1`, bridge commonly `vmbr0`, but always verify.
- SSH access: add the same shared root SSH public key used by other LXCs.
- Keep port exposure minimal. Prefer LAN-only service plus reverse proxy/tunnel/dashboard integration only when needed.

## Workflow

1. Identify requested service name and desired hostname.
2. Inspect current PVE/LXC defaults from existing containers.
3. Check community-scripts for a matching service script.
4. If a community script exists, use it to create the CT non-interactively when safe.
5. If the script is too interactive/unavailable, manually create a privileged Debian 13 LXC and follow the service's official repository installation instructions.
6. Verify CT, SSH, service health, and report the resulting details.

## Step 1 — Gather minimum inputs

If not already provided, ask only for what is missing:

- Service name.
- Desired hostname; default to normalized service name.
- Static IPv4 address, unless the user wants Hermes to pick one.
- Any special resource needs.
- Any known official repo/docs URL.

Do **not** ask for CTID; use next available.

## Step 2 — Inspect existing PVE/LXC defaults

Run on the current PVE host:

```bash
hostname -f || hostname
pveversion
pvesh get /cluster/nextid
pct list
```

Inspect representative existing CT configs to determine bridge, storage, subnet, gateway, DNS, and SSH-key pattern:

```bash
for id in $(pct list | awk 'NR>1 {print $1}' | head -20); do
  echo "===== CT $id ====="
  pct config "$id" | sed -n '1,120p'
done
```

Find existing network/storage defaults:

```bash
pct config <known-good-ctid> | grep -E '^(net0|rootfs|nameserver|searchdomain|features|unprivileged):'
```

Find the shared SSH key from an existing reachable LXC:

```bash
pct exec <known-good-ctid> -- sh -lc 'test -s /root/.ssh/authorized_keys && cat /root/.ssh/authorized_keys'
```

If no existing CT has the key, check the PVE host:

```bash
test -s /root/.ssh/authorized_keys && cat /root/.ssh/authorized_keys
```

Use the same key for the new CT. If multiple keys exist, preserve all unless the user says which to use.

## Step 3 — Choose static IP safely

If the user provided an IP, verify it is unused:

```bash
ping -c 2 <ip> || true
arping -D -c 2 -I <bridge-or-lan-iface> <ip> || true
grep -R "<ip>" /etc/pve/lxc /etc/pve/qemu-server 2>/dev/null || true
```

If Hermes must pick an IP:

1. Infer current subnet from existing CTs.
2. Avoid IPs already in `/etc/pve/lxc/*.conf` and `/etc/pve/qemu-server/*.conf`.
3. Probe with `ping`/`arping` when available.
4. Tell the user which IP was chosen.

## Step 4 — Check community-scripts first

Community-scripts sources:

- Website: `https://community-scripts.org/`
- Repo: `https://github.com/community-scripts/ProxmoxVE`
- CT scripts: `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/<script>.sh`
- Install scripts: `https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/<script>-install.sh`

Normalize the service name:

```text
Service Name -> lowercase -> remove/replace spaces -> try hyphenated aliases
```

Check direct script and repo tree:

```bash
curl -fsI "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/<name>.sh"

curl -fsSL https://api.github.com/repos/community-scripts/ProxmoxVE/git/trees/main?recursive=1 \
  | jq -r '.tree[].path' \
  | grep -i '<service-or-alias>'
```

If found, inspect before running:

```bash
curl -fsSL "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/<script>.sh" | sed -n '1,180p'
curl -fsSL "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/<script>-install.sh" | sed -n '1,240p'
```

Look for:

- `var_os`, `var_version`, `var_unprivileged`, `var_cpu`, `var_ram`, `var_disk` defaults.
- `read -p`, `whiptail`, `prompt_confirm`, `prompt_select`, and version prompts.
- Whether the install script respects unattended mode or uses raw `read -p`.

## Step 5A — If community script exists

Run from the PVE host with explicit variables and `default` mode:

```bash
SERVICE_SCRIPT="<script>"
HOSTNAME="<hostname>"
IP_CIDR="<ip>/<cidr>"
GATEWAY="<gateway>"
BRIDGE="<bridge>"
SSH_KEY='<authorized_keys content, one or more public keys>'

export var_unprivileged=0
export var_hostname="$HOSTNAME"
export var_brg="$BRIDGE"
export var_net="$IP_CIDR"
export var_gateway="$GATEWAY"
export var_ssh=yes
export var_ssh_authorized_key="$SSH_KEY"
export var_os=debian
export var_version=13
export var_verbose=no
# Optional when known from existing CTs:
# export var_container_storage=<storage>
# export var_template_storage=<template-storage>

bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/${SERVICE_SCRIPT}.sh)" _ default
```

Notes:

- `var_unprivileged=0` is mandatory.
- `var_net` must be static IPv4 CIDR, not DHCP.
- Prefer latest stable versions. If the script offers latest stable through a prompt, inspect whether an env var or unattended default exists.

### Interactive prompts

Community-scripts may still have whiptail or raw `read -p` prompts over SSH. Use this decision order:

1. Try explicit env vars + `default` mode.
2. If helper prompt functions support unattended mode, use that.
3. If the script requires whiptail/raw `read -p`, either:
   - run with a PTY only if the interaction is deterministic and safe: `ssh -tt <pve> '...'`, or
   - skip the community script and use the manual fallback.

Do not get stuck in an interactive menu over non-interactive SSH.

### MongoDB example

MongoDB CT script exists:

```text
ct/mongodb.sh
install/mongodb-install.sh
```

It defaults to Debian 13 but unprivileged:

```bash
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
```

Override:

```bash
var_unprivileged=0
```

The install script asks:

```bash
read -p "Do you want to install MongoDB 8.0 instead of 7.0? [y/N]: " install_mongodb_8
```

Because user preference is latest stable, prefer MongoDB 8.0 if it is currently stable. If the raw prompt cannot be driven safely, manually install MongoDB 8.0 in a Debian 13 CT.

## Step 5B — Manual fallback

Use manual CT creation when:

- No community-scripts LXC script exists.
- The script is VM/addon-only.
- The script cannot be made reliably non-interactive.
- Previous community-script attempts fail.

On PVE host:

```bash
CTID=$(pvesh get /cluster/nextid)
HOSTNAME="<hostname>"
IP_CIDR="<ip>/<cidr>"
GATEWAY="<gateway>"
BRIDGE="<bridge>"
STORAGE="<same-rootfs-storage-as-other-lxcs>"
TEMPLATE_STORAGE="<same-template-storage-as-other-lxcs>"
DISK_GB="8"
RAM_MB="1024"
CORES="1"
SSH_KEY_FILE="/tmp/${HOSTNAME}-authorized_keys"
```

Find/download latest Debian 13 template if needed:

```bash
pveam update
pveam available --section system | grep -i 'debian-13'
pveam download "$TEMPLATE_STORAGE" <debian-13-template-name>
```

Create privileged CT:

```bash
pct create "$CTID" "$TEMPLATE_STORAGE:vztmpl/<debian-13-template-name>" \
  --hostname "$HOSTNAME" \
  --ostype debian \
  --unprivileged 0 \
  --cores "$CORES" \
  --memory "$RAM_MB" \
  --rootfs "$STORAGE:${DISK_GB}" \
  --net0 "name=eth0,bridge=${BRIDGE},ip=${IP_CIDR},gw=${GATEWAY}" \
  --features nesting=1 \
  --onboot 1 \
  --start 1
```

Install SSH key:

```bash
pct exec "$CTID" -- sh -lc 'mkdir -p /root/.ssh && chmod 700 /root/.ssh'
pct push "$CTID" "$SSH_KEY_FILE" /root/.ssh/authorized_keys
pct exec "$CTID" -- sh -lc 'chmod 600 /root/.ssh/authorized_keys'
```

Bootstrap base packages:

```bash
pct exec "$CTID" -- bash -lc '
set -euo pipefail
apt-get update
apt-get install -y curl wget ca-certificates gnupg sudo nano vim-tiny git unzip tar systemd openssh-server
systemctl enable --now ssh || systemctl enable --now sshd || true
'
```

Then follow the official service repo/docs. Prefer:

1. Official apt repository/package.
2. Official release binary + systemd unit.
3. Docker only when it is the service-recommended/simple stable path or needed for maintainability.

Avoid complex custom builds unless required.

## Verification checklist

Always verify before reporting success:

```bash
pct list | grep "^$CTID"
pct status "$CTID"
pct config "$CTID"
pct config "$CTID" | grep '^unprivileged:' || echo 'No unprivileged flag usually means privileged'
pct config "$CTID" | grep '^net0:'
ping -c 2 <ip>
pct exec "$CTID" -- sh -lc 'test -s /root/.ssh/authorized_keys && wc -l /root/.ssh/authorized_keys'
pct exec "$CTID" -- bash -lc 'cat /etc/os-release; hostname -f || hostname; ip addr show eth0'
pct exec "$CTID" -- bash -lc 'systemctl --failed --no-pager || true'
pct exec "$CTID" -- systemctl status <service> --no-pager || true
pct exec "$CTID" -- ss -tulpn
curl -fsS http://<ip>:<port>/ || true
```

## Final response format

Always include a handoff block when the service has a Web UI, so `expose-service-public` can run next without asking again for service name or internal URL.

```text
Installed <service> in Proxmox LXC
- CTID: <id>
- Hostname: <hostname>
- IP: <ip>
- OS: Debian 13
- Privileged: yes
- Install method: community-scripts / manual from official repo
- Service version: <version>
- URL/port: <url>
- SSH key installed: yes
- Services verified: <systemd units>
- Notes/credentials: <path or instructions>

Service handoff for expose-service-public:
- Service name: <service>
- Internal service URL: http://<ip>:<port>
- Internal IP: <ip>
- Web UI port: <port>
- CTID: <id>
- Hostname: <hostname>
- Auth status: known-auth / no-auth / unknown
- Notes: <proxying notes, no secrets>
```

If installation failed, report:

- What failed.
- Logs/error snippets.
- Whether the CT was created and needs cleanup.
- Exact recommended next step.

## Pitfalls

- Do not assume community-scripts can be driven over non-interactive SSH.
- Do not create unprivileged CTs for this workflow.
- Do not use DHCP.
- Do not hard-code bridge/storage/SSH key without verifying current PVE state.
- Do not expose extra ports unnecessarily.
- Do not overwrite existing IPs or CTIDs.
- If a community script defaults to an older version, prefer latest stable only if safe and supported.

## When to ask the user

Ask only when necessary:

- No current PVE connection is known.
- Static IP cannot be safely selected.
- Multiple conflicting shared SSH keys are found.
- Service install docs offer materially different stable install paths.
- The service requires credentials, domain names, or external API keys.
