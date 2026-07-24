#!/usr/bin/env bash
set -u

# Non-destructive homelab smoke tests.
# Run from any LAN host that can reach the internal service IPs.
# Optional: export OMNIROUTE_API_KEY for authenticated /v1/models check.

TIMEOUT="${TIMEOUT:-5}"

MEDIA_IP="${MEDIA_IP:-192.168.1.103}"
JELLYFIN_IP="${JELLYFIN_IP:-192.168.1.104}"
JELLYSEERR_IP="${JELLYSEERR_IP:-192.168.1.105}"
OMNIROUTE_IP="${OMNIROUTE_IP:-192.168.1.109}"
HERMES_IP="${HERMES_IP:-192.168.1.110}"
HINDSIGHT_IP="${HINDSIGHT_IP:-192.168.1.111}"
PROXY_IP="${PROXY_IP:-192.168.1.201}"

PASS=0
FAIL=0
SKIP=0

ok() {
  printf 'PASS  %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  FAIL=$((FAIL + 1))
}

skip() {
  printf 'SKIP  %s\n' "$1"
  SKIP=$((SKIP + 1))
}

check_http() {
  local name="$1"
  local url="$2"
  local expected="${3:-}"

  local body status
  body="$(curl -kfsS --max-time "$TIMEOUT" "$url" 2>/tmp/smoke-test-curl.err)"
  status=$?

  if [ "$status" -ne 0 ]; then
    fail "$name ($url) - $(tr '\n' ' ' </tmp/smoke-test-curl.err)"
    return
  fi

  if [ -n "$expected" ] && ! printf '%s' "$body" | grep -qiE "$expected"; then
    fail "$name ($url) - response did not match /$expected/"
    return
  fi

  ok "$name ($url)"
}

check_tcp() {
  local name="$1"
  local host="$2"
  local port="$3"

  if timeout "$TIMEOUT" bash -c "</dev/tcp/${host}/${port}" 2>/dev/null; then
    ok "$name (${host}:${port})"
  else
    fail "$name (${host}:${port})"
  fi
}

printf '# Homelab smoke test\n'
printf 'TIMEOUT=%s seconds\n\n' "$TIMEOUT"

printf '## Proxy/network\n'
check_tcp "proxy HTTP" "$PROXY_IP" 80
check_tcp "proxy HTTPS" "$PROXY_IP" 443
check_tcp "Caddy admin" "$PROXY_IP" 2019
printf '\n'

printf '## Media/arr stack\n'
check_http "qBittorrent WebUI" "http://${MEDIA_IP}:8080" "qbittorrent|login|forbidden|unauthorized"
check_http "Prowlarr" "http://${MEDIA_IP}:9696" "prowlarr|login|window"
check_http "Sonarr" "http://${MEDIA_IP}:8989" "sonarr|login|window"
check_http "Radarr" "http://${MEDIA_IP}:7878" "radarr|login|window"
check_http "Bazarr" "http://${MEDIA_IP}:6767" "bazarr|login|window"
check_http "Tdarr" "http://${MEDIA_IP}:8265" "tdarr|html|window"
check_http "FlareSolverr" "http://${MEDIA_IP}:8191" "flaresolverr|ok|FlareSolverr"
check_tcp "QBWrapper/qbproxy" "$MEDIA_IP" 9911
check_tcp "Lingarr" "$MEDIA_IP" 9876
check_tcp "Portainer HTTPS" "$MEDIA_IP" 9443
printf '\n'

printf '## Jellyfin/Jellyseerr\n'
check_http "Jellyfin" "http://${JELLYFIN_IP}:8096" "jellyfin|login|html"
check_http "Jellyseerr" "http://${JELLYSEERR_IP}:5055" "jellyseerr|overseerr|login|html"
printf '\n'

printf '## AI services\n'
check_http "OmniRoute dashboard" "http://${OMNIROUTE_IP}:20128" "omniroute|html|login|window"
if [ -n "${OMNIROUTE_API_KEY:-}" ]; then
  if curl -fsS --max-time "$TIMEOUT" "http://${OMNIROUTE_IP}:20128/v1/models" \
    -H "Authorization: Bearer ${OMNIROUTE_API_KEY}" >/tmp/smoke-test-omniroute-models.json 2>/tmp/smoke-test-curl.err; then
    ok "OmniRoute /v1/models with OMNIROUTE_API_KEY"
  else
    fail "OmniRoute /v1/models - $(tr '\n' ' ' </tmp/smoke-test-curl.err)"
  fi
else
  skip "OmniRoute /v1/models authenticated check (set OMNIROUTE_API_KEY)"
fi
check_tcp "Hermes host reachable/gateway candidate" "$HERMES_IP" 80
printf '\n'

rm -f /tmp/smoke-test-curl.err /tmp/smoke-test-omniroute-models.json

printf 'Summary: PASS=%s FAIL=%s SKIP=%s\n' "$PASS" "$FAIL" "$SKIP"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
