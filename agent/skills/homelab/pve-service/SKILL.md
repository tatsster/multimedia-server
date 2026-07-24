---
name: pve-service
description: Install a self-hosted service as a privileged Proxmox VE LXC, preferring ProxmoxMCP-Plus for supported operations, community-scripts when available, and SSH/manual fallback only when needed.
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

- Primary control plane: **ProxmoxMCP-Plus via Hermes MCP server `proxmox_plus`**.
  - Prefer MCP tools for supported read/write Proxmox operations: inventory, node/status/storage queries, VM/LXC lifecycle/config operations, snapshots, backups/restores, jobs, and other structured API-supported actions.
  - Before using raw SSH for a Proxmox operation, check whether an MCP tool can do it. Use SSH only when MCP is unavailable/unhealthy, lacks the required operation, cannot run the necessary host/container command, or the task explicitly requires Proxmox host shell behavior.
  - Known MCP endpoint in this homelab: `http://192.168.1.116:8000/mcp`, configured in Hermes as `proxmox_plus`.
- SSH fallback: `root@192.168.1.101` is still allowed for gaps, bootstrap, repair, and community-scripts.
  - Community-scripts are host shell scripts and currently still require running on the PVE host over SSH/TTY; ProxmoxMCP-Plus does not replace that path unless a future MCP tool explicitly supports running the script safely.
  - Never run Proxmox commands or community-scripts on the current Hermes host unless `pveversion` confirms the current host is actually PVE.
- Container type: **privileged LXC for all new service containers**.
  - In community-scripts variables this means `var_unprivileged=0`.
  - In manual `pct create`, explicitly use `--unprivileged 0` when supported.
- CTID: normally use Proxmox next available CTID automatically; when exact CTID is requested and MCP cannot reserve it directly, use a safe SSH fallback/reservation workflow.
- OS for manual fallback: **Debian 13** by default.
- Default boot/root disk: **8 GB** unless the service clearly needs more.
- Versions: prefer the **latest stable** service version.
- Network/bridge/storage/SSH key: match existing/current LXCs on the PVE host.
  - Inspect existing LXC configs instead of inventing values.
  - Known environment pattern: LAN `192.168.1.0/24`, gateway often `192.168.1.1`, bridge commonly `vmbr0`, rootfs storage commonly `vm_storage`, template storage commonly `general`, but always verify.
- SSH access: add the same shared root SSH public key used by other LXCs when using SSH/manual/community-script paths.
- Root password: **ask the user what root password to set every time a new LXC is created**. Do not assume a default, do not leave it unset, and do not reuse/guess a previous password unless the user explicitly provides it for this container.
- Keep port exposure minimal. Prefer LAN-only service plus reverse infrastructure/proxy/tunnel/dashboard integration only when needed.

## Workflow

1. Identify requested service name and desired hostname.
2. Verify `proxmox_plus` MCP connectivity and use MCP for supported inventory/status/config/lifecycle actions.
3. Inspect PVE/LXC defaults through MCP where possible; use SSH fallback only for details/tools MCP cannot provide.
4. Check community-scripts for a matching service script from Hermes or PVE, but execute creation scripts only through a safe PVE-host execution path. Today that means SSH fallback with TTY unless MCP gains a safe host command tool.
5. If a community script exists, use it to create the CT non-interactively when safe.
6. If the script is too interactive/unavailable, manually create a privileged Debian 13 LXC, preferring MCP lifecycle tools if they support the needed options; otherwise use SSH `pct create` fallback.
7. Verify CT, SSH/service health, and report the resulting details.

## Step 1 — Gather minimum inputs

If not already provided, ask only for what is missing:

- Service name.
- Desired hostname; default to normalized service name.
- Static IPv4 address, unless the user wants Hermes to pick one.
- Root password to set for the new LXC. Ask every time; never leave it unset.
- Any special resource needs.
- Any known official repo/docs URL.

Do **not** ask for CTID; use next available.

## Step 2 — Prefer ProxmoxMCP-Plus, then inspect/augment with SSH only when needed

Start by checking Hermes MCP connectivity from the Hermes/runtime host:

```bash
hermes mcp test proxmox_plus
hermes tools list | sed -n '/MCP servers/,$p'
```

When `proxmox_plus` is healthy, prefer its tools for inventory and lifecycle work, for example:

- `get_nodes`, `get_node_status`, `get_storage`, `get_cluster_status`
- `get_containers`, `get_container_config`, `get_container_ip`
- `create_container`, `update_container_resources`, `update_container_ssh_keys`
- `start_container`, `stop_container`, `restart_container`, `delete_container`
- `execute_container_command` for commands inside an LXC, when the MCP command policy permits it
- backup/snapshot/template tools where applicable

Use SSH fallback only for operations MCP does not currently cover or cannot safely perform, especially:

- running Proxmox community-scripts on the PVE host
- reserving an exact CTID when app-defaults only use `nextid`
- reading/writing host files such as `/usr/local/community-scripts/defaults/*.vars`
- restoring root password hashes from preserved state
- repairing ProxmoxMCP-Plus itself when its MCP endpoint is down

If SSH fallback is needed, first determine/connect to the local Proxmox host. Known target in this homelab is `root@192.168.1.101`; otherwise prefer an existing SSH alias/config entry. Verify before running PVE commands:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 <pve-ssh-target> 'hostname -f || hostname; pveversion; pvesh get /cluster/nextid; pct list'
```

Never run Proxmox commands or community-scripts on the Hermes/current host unless `pveversion` confirms it is actually PVE.

Inspect defaults via MCP where possible; otherwise use SSH on the PVE host:

```bash
pct list
for id in $(pct list | awk 'NR>1 {print $1}' | head -20); do
  echo "===== CT $id ====="
  pct config "$id" | sed -n '1,120p'
done
```

Find existing network/storage defaults:

```bash
pct config <known-good-ctid> | grep -E '^(net0|rootfs|nameserver|searchdomain|features|unprivileged):'
```

Find the shared SSH key from an existing reachable LXC only when using SSH/manual/community-script paths:

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

## Step 4 — Community-scripts discovery and execution rules

Discovery/inspection is read-only and can be done from Hermes or PVE. Any community-script that creates or modifies a CT must run on the PVE host, not on the Hermes/runtime host. Today this is normally an SSH/TTY fallback because community-scripts are host shell scripts, not Proxmox API operations.

Golden rules:

- Use `mode=<preset>` as an environment variable. Do **not** rely on trailing args such as `bash -c "$(curl ...)" appdefaults`; current scripts may ignore them and open the menu.
- Use `ssh -tt` plus `TERM=xterm` for scripts that clear the screen or prompt over `/dev/tty`.
- Verify the resulting CT config after creation; defaults can be ignored or overridden by script logic.
- If an exact CTID is required, remember app-defaults do not whitelist `var_ctid`; reserve lower free CTIDs so `pvesh get /cluster/nextid` returns the requested ID, or use manual/MCP creation.

Never run this destructive pattern on Hermes/current host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/<script>.sh)" _ default
```

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

## Step 5A — If a community script exists

Use the least-interactive mode that fits the script:

1. `mode=default` with exported `var_*` values for most scripts.
2. `mode=mydefaults` with `/usr/local/community-scripts/default.vars` for shared global defaults.
3. `mode=appdefaults` with `/usr/local/community-scripts/defaults/<script>.vars` for app-specific defaults, such as Docker.

Generic default-mode pattern:

```bash
ssh -tt <pve-ssh-target> 'TERM=xterm bash -s' <<'REMOTE_PVE_SCRIPT'
set -euo pipefail
pveversion >/dev/null

SERVICE_SCRIPT="<script>"
export var_unprivileged=0
export var_hostname="<hostname>"
export var_brg="<bridge>"
export var_net="<ip>/<cidr>"
export var_gateway="<gateway>"
export var_disk=8
export var_cpu=1
export var_ram=1024
export var_ssh=yes
export var_ssh_authorized_key='<authorized_keys content>'
export var_os=debian
export var_version=13
export var_verbose=no
export var_container_storage=<rootfs-storage>
export var_template_storage=<template-storage>
export mode=default

bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/${SERVICE_SCRIPT}.sh)"
REMOTE_PVE_SCRIPT
```

Docker app-defaults pattern proven in this homelab:

```bash
ssh <pve-ssh-target> 'bash -s' <<'REMOTE_PVE_SCRIPT'
set -euo pipefail
pveversion >/dev/null
install -d -m 0755 /usr/local/community-scripts/defaults
cat >/usr/local/community-scripts/defaults/docker.vars <<'DOCKER_VARS'
var_unprivileged=0
var_hostname=<hostname>
var_disk=8
var_cpu=2
var_ram=2048
var_swap=512
var_brg=vmbr0
var_net=<ip>/<cidr>
var_gateway=<gateway>
var_os=debian
var_version=13
var_nesting=1
var_keyctl=1
var_timezone=Asia/Ho_Chi_Minh
var_container_storage=vm_storage
var_template_storage=general
var_tags=docker;community-script
DOCKER_VARS
REMOTE_PVE_SCRIPT

ssh -tt <pve-ssh-target>   'TERM=xterm mode=appdefaults bash -lc "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)"'
```

Docker prompts observed in this homelab; answer safely unless the user requested otherwise:

- PVE host package upgrade prompt: `2` to ignore during service creation; option `1` runs host `apt upgrade`.
- Portainer UI: `N` unless requested.
- Portainer Agent: `N` unless requested.
- Expose Docker TCP socket: `n` unless explicitly requested.

After any community-script install, verify/apply critical settings explicitly:

```bash
pct config <ctid> | grep -E '^(rootfs|features|net0|tags):'
pct set <ctid> --features nesting=1,keyctl=1   # if Docker needs it and missing
```

Prefer latest stable versions. If the script offers latest stable through a prompt, inspect whether an env var or unattended default exists.

### Interactive prompts

Community-scripts may still have whiptail or raw `read -p` prompts over SSH. Use this decision order:

1. Try explicit env vars + `export mode=default`.
2. Try `/usr/local/community-scripts/default.vars` + `export mode=mydefaults`.
3. If the script prompts about a Proxmox LXC stack/host package upgrade (`pve-container`/`lxc-pve`) over `/dev/tty`, do **not** blindly choose the host upgrade. Prefer manual fallback unless the user explicitly approves running host package upgrades. Do **not** try to answer this with `printf '2\n' | ssh -tt ... <<'REMOTE' ...`; the heredoc consumes stdin for the remote script, so the piped answer usually never reaches the remote `/dev/tty` prompt and the SSH session closes after `Select option [1/2/3]:`.
4. If a raw prompt is genuinely safe and deterministic, avoid mixing a local pipe with an SSH heredoc. Use one of these patterns instead:
   - create a temporary remote script file with `scp`, then run it under an allocated TTY and feed the answer: `printf '2\n' | ssh -tt <pve> 'bash /tmp/script.sh'`; or
   - use `expect` to wait for the exact prompt text and send the exact answer.
   Only use this for low-risk prompts after inspecting the script; never automate destructive choices blindly.
5. If the script requires whiptail beyond the initial mode menu, use `ssh -tt <pve> '...'` only for supervised/deterministic interaction. Do not automate blind keypresses through a TUI for destructive choices.
6. If the script remains unreliable or prompts are not deterministic, skip the community script and use the manual fallback.

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
ROOT_PASSWORD='<root-password-provided-by-user>'
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
  --password "$ROOT_PASSWORD" \
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

Always verify before reporting success. Prefer MCP checks when available, then use SSH fallback for shell/service checks MCP cannot perform:

```bash
hermes mcp test proxmox_plus
```

Use MCP tools when available: `get_containers`, `get_container_config`, `get_container_ip`, `get_node_status`, `get_storage`.

SSH fallback checklist:

```bash
pct list | grep "^$CTID"
pct status "$CTID"
pct config "$CTID"
pct config "$CTID" | grep -E '^(rootfs|features|net0|tags|unprivileged):'
ping -c 2 <ip>
pct exec "$CTID" -- sh -lc 'test -s /root/.ssh/authorized_keys && wc -l /root/.ssh/authorized_keys'
pct exec "$CTID" -- bash -lc 'cat /etc/os-release; hostname -f || hostname; ip -br addr show eth0'
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

- Do not assume community-scripts are fully non-interactive; inspect prompts and use `ssh -tt TERM=xterm` only for deterministic choices.
- Do not run community-scripts on the Hermes/current host. Execute creation scripts only on the PVE host after confirming `pveversion` works there.
- Do not create unprivileged CTs for this workflow.
- Do not use DHCP.
- Do not hard-code bridge/storage/SSH key without verifying current PVE state.
- Do not expose extra ports unnecessarily.
- Do not overwrite existing IPs or CTIDs.
- If a community script defaults to an older version, prefer latest stable only if safe and supported.

## When to ask the user

Ask only when necessary:

- No local PVE SSH target is known and no working SSH alias/config entry can be found.
- Static IP cannot be safely selected.
- Multiple conflicting shared SSH keys are found.
- Service install docs offer materially different stable install paths.
- The service requires credentials, domain names, or external API keys.
