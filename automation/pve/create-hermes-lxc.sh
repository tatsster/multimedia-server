#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lxc.sh"

require_pve_host

CTID="${CTID:-120}"
HOSTNAME="${HOSTNAME:-hermes}"
IP_CIDR="${IP_CIDR:-192.168.1.120/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
STORAGE="${STORAGE:-vm_storage}"
TEMPLATE="${TEMPLATE:-general:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst}"
CORES="${CORES:-2}"
CPULIMIT="${CPULIMIT:-4}"
MEMORY="${MEMORY:-8192}"
SWAP="${SWAP:-512}"
DISK_GB="${DISK_GB:-20}"
REPO_URL="${REPO_URL:-https://github.com/tatsster/multimedia-server.git}"
REPO_DIR="${REPO_DIR:-/opt/multimedia-server}"

require_new_ctid "$CTID"
create_debian_lxc "$CTID" "$HOSTNAME" "$IP_CIDR" "$GATEWAY" "$CORES" "$MEMORY" "$SWAP" "$DISK_GB" "$STORAGE" "$TEMPLATE"
start_and_wait_lxc "$CTID"
install_base_packages "$CTID"

pct_bash "$CTID" "DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip pipx nodejs npm curl ca-certificates build-essential"
pct_bash "$CTID" "git clone '$REPO_URL' '$REPO_DIR' || (cd '$REPO_DIR' && git pull)"
pct_bash "$CTID" "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup"
pct_bash "$CTID" "cp '$REPO_DIR/.env.example' /root/.agent/hermes/.env.example"

cat <<'EOF'

Hermes LXC created and Hermes installer ran.

Next configure secrets and provider inside the LXC:

  nano /root/.agent/hermes/config.yaml
  cp /root/.agent/hermes/.env.example /root/.agent/hermes/.env
  nano /root/.agent/hermes/.env
  hermes config set model.base_url "http://<omniroute-lxc-ip>:20128/v1"
  hermes config set model.api_key "<omniroute-api-key>"
  hermes config set model.default "codex/gpt-5.5-medium"

Use exactly one gateway service. Current live preference is root user-level service, with system-level disabled completely:

  systemctl disable --now hermes-gateway.service
  loginctl enable-linger root
  systemctl --user daemon-reload
  systemctl --user enable --now hermes-gateway.service
  systemctl --user status hermes-gateway.service --no-pager

See agent/hermes/README.md for duplicate gateway troubleshooting.
EOF
print_lxc_summary "$CTID"
