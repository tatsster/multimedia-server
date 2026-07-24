# OmniRoute metrics proxy

Small local HTTP proxy that exposes OmniRoute dashboard metrics in dashboard-friendly JSON.

## Why this exists

OmniRoute has useful dashboard metrics at `/api/usage/analytics`, but that endpoint is not authenticated with the normal OpenAI-compatible `/v1` API key. It expects the dashboard browser cookie named `auth_token`.

Copying a browser cookie into dashboard config is brittle because it expires and exposes a full dashboard session. This proxy keeps the setup simple:

```text
Dashboard/client -> OmniRoute metrics proxy -> OmniRoute dashboard API
```

The proxy:

1. Reads OmniRoute's local `JWT_SECRET` from `/root/services/omniroute/data/server.env`.
2. Creates a fresh short-lived dashboard JWT internally.
3. Sends that JWT to OmniRoute as `Cookie: auth_token=...`.
4. Returns simplified JSON from `/summary`.
5. Protects `/summary` with a separate shared Bearer token for dashboard clients.

## Live target used in this homelab

```text
CTID: 107
OmniRoute dashboard/API: http://192.168.1.109:20128
Metrics proxy: http://192.168.1.109:20129
OmniRoute data/secrets file on CT107: /root/services/omniroute/data/server.env
Proxy env file on CT107: /root/services/omniroute/metrics-proxy.env
Container name: omniroute-metrics-proxy
Image name: omniroute-metrics-proxy:local
```

Because the proxy runs in Docker, it usually cannot reach OmniRoute at `127.0.0.1` unless both services share a network namespace. For the current CT107 setup, use Docker host gateway:

```text
OMNIROUTE_URL=http://172.17.0.1:20128
```

## Files

```text
services/omniroute/metrics-infrastructure/proxy/server.js
services/omniroute/metrics-infrastructure/proxy/package.json
services/omniroute/metrics-infrastructure/proxy/Dockerfile
services/omniroute/metrics-infrastructure/proxy/docker-compose.example.yml
services/omniroute/metrics-infrastructure/proxy/.env.example
```

## API

### Health

No auth required.

```bash
curl -s http://127.0.0.1:20129/health
```

Expected:

```json
{"status":"ok"}
```

### Summary

Auth required when `OMNIROUTE_DASHBOARD_TOKEN` is set.

```bash
TOKEN="$(grep '^OMNIROUTE_DASHBOARD_TOKEN=' /root/services/omniroute/metrics-proxy.env | cut -d= -f2-)"

curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:20129/summary?range=7d" | jq
```

Response shape:

```json
{
  "status": "ok",
  "range": "7d",
  "summary": {
    "totalRequests": 123,
    "promptTokens": 1000,
    "completionTokens": 200,
    "totalTokens": 1200,
    "cacheReadTokens": 500,
    "cacheCreationTokens": 20,
    "cacheHitRatePct": 33.33,
    "successRatePct": 99.1,
    "avgLatencyMs": 1200,
    "fallbackCount": 0,
    "lastRequest": "2026-05-06T11:48:37.702Z"
  },
  "topModels": [],
  "dailyTrend": [],
  "updatedAt": "2026-05-06T12:00:00.000Z"
}
```

Supported range values are passed through to OmniRoute, for example:

```text
/summary?range=24h
/summary?range=7d
/summary?range=30d
```

## Environment variables

| Variable | Required | Default | Notes |
|---|---:|---|---|
| `PORT` | no | `20129` | Listen port inside the container. |
| `HOST` | no | `0.0.0.0` | Listen host inside the container. |
| `OMNIROUTE_URL` | no | `http://127.0.0.1:20128` | Base URL for OmniRoute from inside the proxy container. On CT107 Docker, use `http://172.17.0.1:20128`. |
| `OMNIROUTE_SERVER_ENV` | no | `/app/omniroute-data/server.env` | Path to mounted OmniRoute `server.env`. |
| `OMNIROUTE_DASHBOARD_TOKEN` | recommended | empty | Shared Bearer token for dashboards. If empty, `/summary` is unauthenticated; avoid that except for quick local testing. |
| `OMNIROUTE_METRICS_PROXY_CACHE_SECONDS` | no | `60` | Cache duration for `/summary`. |
| `OMNIROUTE_METRICS_PROXY_TIMEOUT_MS` | no | `10000` | Upstream OmniRoute request timeout. |

Backward-compatible env names from older installs still work:

```text
OMNIROUTE_METRICS_TOKEN
OMNIROUTE_GLANCE_PROXY_CACHE_SECONDS
OMNIROUTE_GLANCE_PROXY_TIMEOUT_MS
OMNIROUTE_GLANCE_PROXY_HOST
OMNIROUTE_GLANCE_PROXY_PORT
```

Prefer the generic names above for new installs.

## Build and run on CT107 from the Proxmox host

This is the full copy/paste style install from a PVE shell. It executes inside LXC `107`.

It does not print the generated token; read it from the env file only when you need to paste it into a dashboard config.

```bash
pct exec 107 -- bash -lc '
set -euo pipefail

mkdir -p /root/repos
cd /root/repos

if [ ! -d multimedia-server ]; then
  git clone https://github.com/tatsster/multimedia-server.git
else
  cd multimedia-server
  git pull --ff-only
  cd ..
fi

cd /root/repos/multimedia-server/services/omniroute/metrics-proxy

docker build -t omniroute-metrics-proxy:local .

mkdir -p /root/omniroute
if [ ! -f /root/services/omniroute/metrics-proxy.env ]; then
  cp .env.example /root/services/omniroute/metrics-proxy.env
  TOKEN="$(openssl rand -hex 32)"
  sed -i "s|^OMNIROUTE_DASHBOARD_TOKEN=.*|OMNIROUTE_DASHBOARD_TOKEN=${TOKEN}|" /root/services/omniroute/metrics-proxy.env
fi

chmod 600 /root/services/omniroute/metrics-proxy.env
sed -i "s|^OMNIROUTE_URL=.*|OMNIROUTE_URL=http://172.17.0.1:20128|" /root/services/omniroute/metrics-proxy.env
sed -i "s|^PORT=.*|PORT=20129|" /root/services/omniroute/metrics-proxy.env

docker rm -f omniroute-metrics-proxy 2>/dev/null || true

docker run -d \
  --name omniroute-metrics-proxy \
  --restart unless-stopped \
  --env-file /root/services/omniroute/metrics-proxy.env \
  -p 20129:20129 \
  -v /root/services/omniroute/data:/app/omniroute-data:ro \
  omniroute-metrics-proxy:local

curl -sS http://127.0.0.1:20129/health
TOKEN="$(grep "^OMNIROUTE_DASHBOARD_TOKEN=" /root/services/omniroute/metrics-proxy.env | cut -d= -f2-)"
curl -sS -o /dev/null -w "summary_http=%{http_code}\n" \
  -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:20129/summary?range=7d"
'
```

## Build manually from inside CT107

```bash
mkdir -p /root/repos
cd /root/repos

git clone https://github.com/tatsster/multimedia-server.git || true
cd /root/repos/multimedia-server
git pull --ff-only

cd /root/repos/multimedia-server/services/omniroute/metrics-proxy
docker build -t omniroute-metrics-proxy:local .
```

## Configure secrets manually

Create a private env file on CT107:

```bash
cp /root/repos/multimedia-server/services/omniroute/metrics-infrastructure/proxy/.env.example /root/services/omniroute/metrics-proxy.env
chmod 600 /root/services/omniroute/metrics-proxy.env
```

Generate the shared dashboard/proxy token:

```bash
TOKEN="$(openssl rand -hex 32)"
sed -i "s|^OMNIROUTE_DASHBOARD_TOKEN=.*|OMNIROUTE_DASHBOARD_TOKEN=$TOKEN|" /root/services/omniroute/metrics-proxy.env
```

Do not commit `/root/services/omniroute/metrics-proxy.env` or the generated token.

## Run with Docker

```bash
docker rm -f omniroute-metrics-proxy 2>/dev/null || true

docker run -d \
  --name omniroute-metrics-proxy \
  --restart unless-stopped \
  --env-file /root/services/omniroute/metrics-proxy.env \
  -p 20129:20129 \
  -v /root/services/omniroute/data:/app/omniroute-data:ro \
  omniroute-metrics-proxy:local
```

Verify:

```bash
curl -s http://127.0.0.1:20129/health

TOKEN="$(grep '^OMNIROUTE_DASHBOARD_TOKEN=' /root/services/omniroute/metrics-proxy.env | cut -d= -f2-)"
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:20129/summary?range=7d" | jq '.summary'
```

## Run with Compose

Copy the example compose file next to your private env file if you prefer Compose:

```bash
mkdir -p /root/services/omniroute/metrics-proxy
cp /root/repos/multimedia-server/services/omniroute/metrics-infrastructure/proxy/docker-compose.example.yml /root/services/omniroute/metrics-infrastructure/proxy/docker-compose.yml
cd /root/services/omniroute/metrics-proxy
docker compose up -d --build
```

## Dashboard client configuration

For any dashboard client, set:

```text
OMNIROUTE_METRICS_PROXY_URL=http://192.168.1.109:20129
OMNIROUTE_DASHBOARD_TOKEN=<same token from /root/services/omniroute/metrics-proxy.env>
```

Then call:

```text
${OMNIROUTE_METRICS_PROXY_URL}/summary?range=7d
```

with:

```text
Authorization: Bearer ${OMNIROUTE_DASHBOARD_TOKEN}
```

## Security notes

- Keep the proxy on LAN/internal networks only.
- Keep `OMNIROUTE_DASHBOARD_TOKEN` private. It is not an OmniRoute `/v1` API key, but it grants access to usage metrics through this proxy.
- Do not expose `/root/services/omniroute/data/server.env` to any container except this proxy.
- The mounted OmniRoute data directory is read-only.
- The proxy creates 5-minute JWTs internally and does not log secrets.
- Do not manually add `JWT_SECRET` to `/root/services/omniroute/.env`; OmniRoute manages it in `/root/services/omniroute/data/server.env`.
