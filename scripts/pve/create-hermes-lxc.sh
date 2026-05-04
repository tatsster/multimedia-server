#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lxc.sh"

require_pve_host

CTID="${CTID:-120}"
HOSTNAME="${HOSTNAME:-hermes}"
IP_CIDR="${IP_CIDR:-192.168.1.120/24}"
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
pct_bash "$CTID" "mkdir -p /root/.hermes && cp '$REPO_DIR/hermes/config/config.system.example.yaml' /root/.hermes/config.yaml"
pct_bash "$CTID" "cp '$REPO_DIR/.env.example' /root/.hermes/.env.example"

cat <<'EOF'

Hermes LXC base created.

Manual install step still depends on the Hermes distribution used in the live setup.
After installing Hermes, configure secrets and provider:

  nano /root/.hermes/config.yaml
  nano /root/.hermes/.env
  hermes config set model.base_url "http://<omniroute-lxc-ip>:20128/v1"
  hermes config set model.api_key "<omniroute-api-key>"
  hermes config set model.default "codex/gpt-5.5-medium"
  hermes gateway restart

See hermes/README.md for duplicate gateway troubleshooting.
EOF
print_lxc_summary "$CTID"
