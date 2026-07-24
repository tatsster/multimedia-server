#!/usr/bin/env bash
set -euo pipefail

# Audit current Proxmox LXC configs into a secret-safe Markdown report.
# Run from the Proxmox VE host shell:
#   ./automation/pve/audit-lxcs.sh
# Optional:
#   OUT=inventory/live-lxc-audit.md ./automation/pve/audit-lxcs.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT="${OUT:-${REPO_ROOT}/inventory/live-lxc-audit.md}"

if ! command -v pct >/dev/null 2>&1; then
  echo "ERROR: pct not found. Run this from the Proxmox VE host shell." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

sanitize_config() {
  # Keep infrastructure fields needed for rebuild, remove/flag fields that can carry secrets.
  # LXC config usually does not contain app tokens, but hookscript/description/tags can leak notes.
  sed -E \
    -e 's/(password|token|secret|apikey|api_key|authorization|bearer)([^[:alnum:]_-]*)(.*)/\1\2[REDACTED]/Ig' \
    -e 's/(description:).*/\1 [REVIEW-LIVE-NOTES-BEFORE-COMMIT]/I'
}

creation_hint() {
  local name="$1"
  local notes="$2"

  if grep -Eiq 'community-scripts|tteck|ProxmoxVE|caddy|cloudflared' <<<"${name} ${notes}"; then
    if grep -Eiq 'caddy' <<<"${name} ${notes}"; then
      echo "Community Scripts: Caddy"
      return
    fi
    if grep -Eiq 'cloudflared' <<<"${name} ${notes}"; then
      echo "Community Scripts: Cloudflared"
      return
    fi
    echo "Community Scripts: verify script name"
    return
  fi

  case "$name" in
    *media*|*arr*|*sonarr*|*radarr*|*jellyfin*|*qbittorrent*) echo "Manual repo script or media guide" ;;
    *hermes*) echo "Manual repo script: create-hermes-lxc.sh" ;;
    *omniroute*) echo "Manual repo script: create-omniroute-lxc.sh" ;;
    *) echo "TBD - inspect live notes" ;;
  esac
}

{
  echo "# Live LXC Audit"
  echo
  echo "Generated from Proxmox VE host on: $(date -Iseconds)"
  echo
  echo "> Secret-safety: review this file before committing. The audit sanitizes common secret words, but live descriptions/notes can still contain private details."
  echo
  echo "## Summary table"
  echo
  echo "| CT ID | Name | Status | IP config | Unprivileged | Features | Creation hint |"
  echo "|---|---|---|---|---|---|---|"

  mapfile -t ctids < <(pct list | awk 'NR>1 {print $1}' | sort -n)
  for ctid in "${ctids[@]}"; do
    cfg="$(pct config "$ctid" 2>/dev/null || true)"
    name="$(awk -F': ' '/^hostname:/ {print $2; exit}' <<<"$cfg")"
    status="$(pct status "$ctid" 2>/dev/null | awk '{print $2}')"
    net0="$(awk -F': ' '/^net0:/ {print $2; exit}' <<<"$cfg" | sed -E 's/,/; /g')"
    unpriv="$(awk -F': ' '/^unprivileged:/ {print $2; exit}' <<<"$cfg")"
    features="$(awk -F': ' '/^features:/ {print $2; exit}' <<<"$cfg")"
    notes="$(awk -F': ' '/^(description|tags):/ {print $0}' <<<"$cfg")"
    hint="$(creation_hint "${name:-unknown}" "$notes")"

    echo "| ${ctid} | ${name:-TBD} | ${status:-TBD} | \`${net0:-TBD}\` | ${unpriv:-TBD} | \`${features:-TBD}\` | ${hint} |"
  done

  echo
  echo "## Detailed sanitized configs"
  echo
  for ctid in "${ctids[@]}"; do
    cfg="$(pct config "$ctid" 2>/dev/null || true)"
    name="$(awk -F': ' '/^hostname:/ {print $2; exit}' <<<"$cfg")"
    echo "### CT ${ctid} — ${name:-unknown}"
    echo
    echo '```text'
    printf '%s\n' "$cfg" | sanitize_config
    echo '```'
    echo
  done
} > "$OUT"

echo "Wrote $OUT"
echo "Review before commit: grep -RInE 'password|token|secret|key|Bearer|eyJ|sk-' '$OUT'"
