#!/usr/bin/env bash
set -euo pipefail

require_pve_host() {
  if ! command -v pct >/dev/null 2>&1; then
    echo "ERROR: pct not found. Run this from the Proxmox VE host shell." >&2
    exit 1
  fi
}

require_new_ctid() {
  local ctid="$1"
  if pct status "$ctid" >/dev/null 2>&1; then
    echo "ERROR: CTID $ctid already exists. Choose another CTID or destroy it manually." >&2
    exit 1
  fi
}

create_debian_lxc() {
  local ctid="$1"
  local hostname="$2"
  local ip_cidr="$3"
  local gateway="$4"
  local cores="$5"
  local memory="$6"
  local swap="$7"
  local disk_gb="$8"
  local storage="$9"
  local template="${10}"

  local net0="name=eth0,bridge=${BRIDGE:-vmbr0},ip=${ip_cidr},gw=${gateway}"

  local args=(
    "$ctid" "$template"
    --hostname "$hostname"
    --storage "$storage"
    --rootfs "${storage}:${disk_gb}"
    --cores "$cores"
    --memory "$memory"
    --swap "$swap"
    --net0 "$net0"
    --features nesting=1
    --unprivileged 0
    --onboot 1
    --start 0
  )

  if [[ -n "${CPULIMIT:-}" ]]; then
    args+=(--cpulimit "$CPULIMIT")
  fi

  if [[ -n "${PASSWORD:-}" ]]; then
    args+=(--password "$PASSWORD")
  fi

  echo "Creating privileged Debian LXC $ctid ($hostname)..."
  pct create "${args[@]}"

  # Keep explicit homelab defaults even if pct create behavior changes.
  # `unprivileged` is a create-time-only/read-only option on current PVE,
  # so it must stay in pct create args and must not be changed afterward.
  pct set "$ctid" --features nesting=1
}

start_and_wait_lxc() {
  local ctid="$1"
  pct start "$ctid"
  echo "Waiting for CT $ctid network/init..."
  sleep 8
}

pct_bash() {
  local ctid="$1"
  shift
  pct exec "$ctid" -- bash -lc "$*"
}

install_base_packages() {
  local ctid="$1"
  pct_bash "$ctid" "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates gnupg git nano sqlite3 jq ufw"
}

print_lxc_summary() {
  local ctid="$1"
  echo
  echo "Created CT $ctid"
  pct config "$ctid"
  echo
  echo "Remember to update inventory/lxc-map.md with CTID/IP/mounts."
}
