#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lxc.sh"

require_pve_host

CTID="${CTID:-121}"
HOSTNAME="${HOSTNAME:-omniroute}"
IP_CIDR="${IP_CIDR:-192.168.1.121/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
STORAGE="${STORAGE:-vm_storage}"
TEMPLATE="${TEMPLATE:-general:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst}"
CORES="${CORES:-2}"
MEMORY="${MEMORY:-4096}"
SWAP="${SWAP:-512}"
DISK_GB="${DISK_GB:-4}"
INITIAL_PASSWORD="${INITIAL_PASSWORD:-CHANGE_ME_AFTER_FIRST_LOGIN}"

require_new_ctid "$CTID"
create_debian_lxc "$CTID" "$HOSTNAME" "$IP_CIDR" "$GATEWAY" "$CORES" "$MEMORY" "$SWAP" "$DISK_GB" "$STORAGE" "$TEMPLATE"
start_and_wait_lxc "$CTID"
install_base_packages "$CTID"

pct_bash "$CTID" "DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm"
pct_bash "$CTID" "mkdir -p /opt/omniroute /root/.omniroute"

# Install path may change upstream. This tries npm first because the live docs identify Node/SQLite behavior.
pct_bash "$CTID" "npm view omniroute version >/tmp/omniroute-npm-version 2>/dev/null && npm install -g omniroute || true"

pct_bash "$CTID" "cat >/etc/systemd/system/omniroute.service <<'SERVICE'
[Unit]
Description=OmniRoute
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=HOST=0.0.0.0
Environment=PORT=20128
Environment=DATA_DIR=/root/.omniroute
Environment=INITIAL_PASSWORD=$INITIAL_PASSWORD
ExecStart=/usr/local/bin/omniroute
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE"

pct_bash "$CTID" "if command -v omniroute >/dev/null 2>&1; then systemctl daemon-reload && systemctl enable --now omniroute; else echo 'WARN: omniroute npm package not installed. Check upstream install method and update this script.'; fi"

cat <<EOF

OmniRoute LXC base created.

If service installed successfully:
  Dashboard: http://${IP_CIDR%/*}:20128
  API:       http://${IP_CIDR%/*}:20128/v1

Initial password source:
  INITIAL_PASSWORD env var passed to this script, or placeholder CHANGE_ME_AFTER_FIRST_LOGIN.

If onboarding/login is broken, see omniroute/README.md for SQLite key_value workaround.
EOF
print_lxc_summary "$CTID"
