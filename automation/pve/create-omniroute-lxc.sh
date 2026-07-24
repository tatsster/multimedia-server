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

# Live CT 107 runs omniroute@3.7.8 from npm:
#   /usr/bin/omniroute -> /usr/lib/node_modules/services/omniroute/bin/omniroute.mjs
pct_bash "$CTID" "npm install -g omniroute"

pct_bash "$CTID" "cat >/root/.services/omniroute/omniroute.env <<ENV
PORT=20128
DATA_DIR=/root/.omniroute
INITIAL_PASSWORD=$INITIAL_PASSWORD
# Fill these after creation if you want fixed/known secrets instead of generated defaults:
# JWT_SECRET=replace-with-generated-jwt-secret
# API_KEY_SECRET=replace-with-generated-api-key-secret
ENV
chmod 600 /root/.services/omniroute/omniroute.env"

pct_bash "$CTID" "cat >/etc/systemd/system/omniroute.service <<'SERVICE'
[Unit]
Description=OmniRoute AI Gateway
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/omniroute
WorkingDirectory=/root/.omniroute
Restart=always
RestartSec=5
Environment=PORT=20128
Environment=DATA_DIR=/root/.omniroute
EnvironmentFile=-/root/.services/omniroute/omniroute.env
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE"

pct_bash "$CTID" "systemctl daemon-reload && systemctl enable --now omniroute.service"

cat <<EOF

OmniRoute LXC base created.

If service installed successfully:
  Dashboard: http://${IP_CIDR%/*}:20128
  API:       http://${IP_CIDR%/*}:20128/v1

Initial password source:
  INITIAL_PASSWORD env var passed to this script, or placeholder CHANGE_ME_AFTER_FIRST_LOGIN.

If onboarding/login is broken, see services/omniroute/README.md for SQLite key_value workaround.

Useful checks:
  pct exec $CTID -- systemctl status omniroute.service --no-pager
  pct exec $CTID -- curl -s http://127.0.0.1:20128/v1/models
EOF
print_lxc_summary "$CTID"
