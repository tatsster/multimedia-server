#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lxc.sh"

require_pve_host

CTID="${CTID:-110}"
HOSTNAME="${HOSTNAME:-media-arr}"
IP_CIDR="${IP_CIDR:-192.168.1.110/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
STORAGE="${STORAGE:-vm_storage}"
TEMPLATE="${TEMPLATE:-general:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst}"
CORES="${CORES:-4}"
CPULIMIT="${CPULIMIT:-8}"
MEMORY="${MEMORY:-6144}"
SWAP="${SWAP:-512}"
DISK_GB="${DISK_GB:-40}"
REPO_URL="${REPO_URL:-https://github.com/tatsster/multimedia-server.git}"
REPO_DIR="${REPO_DIR:-/opt/multimedia-server}"
HOST_DOCKER_PATH="${HOST_DOCKER_PATH:-/main/docker}"
CT_DOCKER_PATH="${CT_DOCKER_PATH:-/docker}"
HOST_MEDIA_PATH="${HOST_MEDIA_PATH:-/data/media}"
CT_MEDIA_PATH="${CT_MEDIA_PATH:-/media}"

require_new_ctid "$CTID"
create_debian_lxc "$CTID" "$HOSTNAME" "$IP_CIDR" "$GATEWAY" "$CORES" "$MEMORY" "$SWAP" "$DISK_GB" "$STORAGE" "$TEMPLATE"

# Optional bind mounts. Create host paths first if they exist in your design.
if [[ -d "$HOST_DOCKER_PATH" ]]; then
  echo "Adding docker bind mount: $HOST_DOCKER_PATH -> $CT_DOCKER_PATH"
  pct set "$CTID" -mp0 "${HOST_DOCKER_PATH},mp=${CT_DOCKER_PATH},backup=1"
else
  echo "WARN: $HOST_DOCKER_PATH not found on host. Skipping docker bind mount. Add it later with:"
  echo "pct set $CTID -mp0 ${HOST_DOCKER_PATH},mp=${CT_DOCKER_PATH},backup=1"
fi

if [[ -d "$HOST_MEDIA_PATH" ]]; then
  echo "Adding media bind mount: $HOST_MEDIA_PATH -> $CT_MEDIA_PATH"
  pct set "$CTID" -mp1 "${HOST_MEDIA_PATH},mp=${CT_MEDIA_PATH}"
else
  echo "WARN: $HOST_MEDIA_PATH not found on host. Skipping media bind mount. Add it later with:"
  echo "pct set $CTID -mp1 ${HOST_MEDIA_PATH},mp=${CT_MEDIA_PATH}"
fi

start_and_wait_lxc "$CTID"
install_base_packages "$CTID"

pct_bash "$CTID" "install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && chmod a+r /etc/apt/keyrings/docker.asc"
pct_bash "$CTID" 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list'
pct_bash "$CTID" "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
pct_bash "$CTID" "systemctl enable --now docker"
pct_bash "$CTID" "git clone '$REPO_URL' '$REPO_DIR' || (cd '$REPO_DIR' && git pull)"
pct_bash "$CTID" "cd '$REPO_DIR/server-arr' && cp -n ../.env.example .env.example || true"

cat <<EOF

media-arr LXC created.

Next steps inside CT $CTID:
  cd $REPO_DIR/server-arr
  cp ../.env.example .env
  nano .env
  docker compose -f arr-stack.yml --env-file .env up -d

Then configure app UI settings from server-arr/Multimedia-Setup.md.
EOF
print_lxc_summary "$CTID"
