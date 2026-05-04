#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lxc.sh"

require_pve_host

CTID="${CTID:-122}"
HOSTNAME="${HOSTNAME:-hindsight}"
IP_CIDR="${IP_CIDR:-192.168.1.122/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
STORAGE="${STORAGE:-local-zfs}"
TEMPLATE="${TEMPLATE:-local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst}"
CORES="${CORES:-2}"
MEMORY="${MEMORY:-2048}"
SWAP="${SWAP:-512}"
DISK_GB="${DISK_GB:-16}"
REPO_URL="${REPO_URL:-https://github.com/tatsster/multimedia-server.git}"
REPO_DIR="${REPO_DIR:-/opt/multimedia-server}"

require_new_ctid "$CTID"
create_debian_lxc "$CTID" "$HOSTNAME" "$IP_CIDR" "$GATEWAY" "$CORES" "$MEMORY" "$SWAP" "$DISK_GB" "$STORAGE" "$TEMPLATE"
start_and_wait_lxc "$CTID"
install_base_packages "$CTID"

pct_bash "$CTID" "DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip pipx nodejs npm"
pct_bash "$CTID" "git clone '$REPO_URL' '$REPO_DIR' || (cd '$REPO_DIR' && git pull)"
pct_bash "$CTID" "mkdir -p /opt/hindsight /var/lib/hindsight"

cat <<'EOF'

Hindsight LXC base created.

TODO: exact Hindsight install/run command still needs live verification from current LXC.
Capture and add:
  - package/source install command
  - config path
  - service port
  - data directory
  - systemd unit

See hindsight/README.md.
EOF
print_lxc_summary "$CTID"
