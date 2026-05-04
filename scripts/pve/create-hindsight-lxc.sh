#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lxc.sh"

require_pve_host

CTID="${CTID:-122}"
HOSTNAME="${HOSTNAME:-hindsight}"
IP_CIDR="${IP_CIDR:-192.168.1.122/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
STORAGE="${STORAGE:-vm_storage}"
TEMPLATE="${TEMPLATE:-general:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst}"
CORES="${CORES:-2}"
CPULIMIT="${CPULIMIT:-4}"
MEMORY="${MEMORY:-8192}"
SWAP="${SWAP:-1024}"
DISK_GB="${DISK_GB:-20}"
REPO_URL="${REPO_URL:-https://github.com/tatsster/multimedia-server.git}"
REPO_DIR="${REPO_DIR:-/opt/multimedia-server}"

require_new_ctid "$CTID"
create_debian_lxc "$CTID" "$HOSTNAME" "$IP_CIDR" "$GATEWAY" "$CORES" "$MEMORY" "$SWAP" "$DISK_GB" "$STORAGE" "$TEMPLATE"
start_and_wait_lxc "$CTID"
install_base_packages "$CTID"

pct_bash "$CTID" "DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io"
pct_bash "$CTID" "systemctl enable --now docker"
pct_bash "$CTID" "git clone '$REPO_URL' '$REPO_DIR' || (cd '$REPO_DIR' && git pull)"
pct_bash "$CTID" "mkdir -p /root/.hindsight-docker"
pct_bash "$CTID" "cp '$REPO_DIR/hindsight/config/hindsight.env.example' /root/.hindsight.env.example"

cat <<EOF

Hindsight LXC base created.

Live/current pattern:
  - Docker container: hindsight
  - Image: ghcr.io/vectorize-io/hindsight:latest
  - API: http://${IP_CIDR%/*}:8888
  - Control plane: http://${IP_CIDR%/*}:9999/dashboard
  - Data directory: /root/.hindsight-docker -> /home/hindsight/.pg0

Next steps inside CT $CTID:
  cp /root/.hindsight.env.example /root/.hindsight.env
  nano /root/.hindsight.env   # fill HINDSIGHT_API_LLM_API_KEY and adjust model if needed
  chmod 0600 /root/.hindsight.env
  docker run -d \\
    --name hindsight \\
    --restart unless-stopped \\
    --env-file /root/.hindsight.env \\
    -p 8888:8888 \\
    -p 9999:9999 \\
    -v /root/.hindsight-docker:/home/hindsight/.pg0 \\
    ghcr.io/vectorize-io/hindsight:latest

Verify:
  curl -fsS http://127.0.0.1:8888/health

See hindsight/README.md.
EOF
print_lxc_summary "$CTID"
